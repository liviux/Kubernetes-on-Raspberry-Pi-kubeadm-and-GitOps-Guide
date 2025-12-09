#!/bin/bash
# =============================================================================
# Cluster Startup & Recovery Script
# =============================================================================
# This script validates cluster health after powering on and restores workloads.
# Run this after physically powering on all Raspberry Pi nodes.
#
# Usage: bash scripts/startup-cluster.sh [OPTIONS]
#
# Options:
#   --wait-only            Only wait for nodes, don't uncordon or restore
#   --skip-restore         Uncordon nodes but don't scale up workloads
#   --timeout <s>          Max seconds to wait for nodes (default: 300)
#   --workload-timeout <s> Max seconds to wait for workloads (default: 900)
#   --verbose, -v          Enable verbose output for debugging
#   --skip-wait            Skip waiting for critical workloads to be ready
#
# Prerequisites:
#   - All nodes physically powered on
#   - kubectl configured with cluster access
#   - Control plane should be powered on 2-3 min before workers
#
# The script will NOT complete successfully until all critical workloads
# (ArgoCD, MinIO, Grafana, Gitea) are fully ready and running.
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
EXPECTED_NODES=4
MAX_WAIT=${MAX_WAIT:-300}  # 5 minutes default for node readiness
WORKLOAD_WAIT=${WORKLOAD_WAIT:-900}  # 15 minutes for critical workloads (RPi can be slow)
STARTUP_SUCCESS=true  # Track overall success

# Namespaces with stateful workloads to restore (reverse of shutdown order)
STATEFUL_NAMESPACES=(
    "storage"
    "openbao"
    "monitoring"
    "observability"
    "logging"
    "harbor"
    "gitea"
    "velero"
)

# Default replica counts for known stateful workloads
# Format: "namespace/resource-type/name:replicas"
# IMPORTANT: These are restored in order, so dependencies must come first!
declare -A DEFAULT_REPLICAS=(
    # ArgoCD components (must be restored first for GitOps to work)
    ["argocd/deployment/argocd-redis"]="1"
    ["argocd/deployment/argocd-applicationset-controller"]="1"
    ["argocd/deployment/argocd-notifications-controller"]="1"
    # Storage (needed before workloads that use PVCs)
    ["storage/deployment/minio"]="1"
    # Monitoring - Prometheus stack
    ["monitoring/deployment/prometheus-operator"]="1"
    ["monitoring/deployment/observability-stack-kube-state-metrics"]="1"
    ["monitoring/statefulset/prometheus-prometheus-prometheus"]="1"
    ["monitoring/statefulset/alertmanager-prometheus-alertmanager"]="1"
    ["monitoring/deployment/observability-stack-grafana"]="1"
    # Observability
    ["observability/statefulset/loki"]="1"
    # Gitea and its dependencies (postgresql and valkey must start before gitea)
    ["gitea/statefulset/gitea-postgresql"]="1"
    ["gitea/statefulset/gitea-valkey-cluster"]="3"
    ["gitea/deployment/gitea"]="1"
    # Harbor (if installed)
    ["harbor/statefulset/harbor-registry"]="1"
    ["harbor/statefulset/harbor-database"]="1"
)

# Critical workloads to wait for before declaring startup complete
# Format: "namespace/resource-type/name"
CRITICAL_WORKLOADS=(
    "argocd/deployment/argocd-redis"
    "argocd/deployment/argocd-server"
    "storage/deployment/minio"
    "monitoring/deployment/observability-stack-grafana"
    "gitea/deployment/gitea"
)

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
WAIT_ONLY=false
SKIP_RESTORE=false
SKIP_WAIT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --wait-only)
            WAIT_ONLY=true
            shift
            ;;
        --skip-restore)
            SKIP_RESTORE=true
            shift
            ;;
        --skip-wait)
            SKIP_WAIT=true
            shift
            ;;
        --timeout)
            MAX_WAIT="$2"
            shift 2
            ;;
        --workload-timeout)
            WORKLOAD_WAIT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--wait-only] [--skip-restore] [--skip-wait] [--timeout <seconds>] [--workload-timeout <seconds>] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --wait-only            Only wait for nodes to be ready"
            echo "  --skip-restore         Don't scale up workloads after uncordoning"
            echo "  --skip-wait            Skip waiting for critical workloads"
            echo "  --timeout <s>          Max seconds to wait for nodes (default: 300)"
            echo "  --workload-timeout <s> Max seconds to wait for workloads (default: 900)"
            echo "  --verbose, -v          Enable verbose output for debugging"
            exit 0
            ;;
        *)
            # Skip unknown args
            shift
            ;;
    esac
done

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ️${NC} $1"; }
log_verbose() { 
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}  [VERBOSE]${NC} $1"
    fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

wait_for_api() {
    local elapsed=0
    local interval=5
    
    log_step "Waiting for Kubernetes API server..."
    log_verbose "Timeout set to ${MAX_WAIT}s"
    log_verbose "KUBECONFIG=${KUBECONFIG:-~/.kube/config}"
    
    while ! kubectl cluster-info &> /dev/null; do
        if [ $elapsed -ge $MAX_WAIT ]; then
            log_error "Timeout waiting for API server after ${MAX_WAIT}s"
            echo ""
            echo "Troubleshooting steps:"
            echo "  1. Check if control plane (rpi4-1) is powered on and booted"
            echo "  2. Verify network connectivity: ping rpi4-1"
            echo "  3. Check kubelet: ssh rpi4-1 'sudo systemctl status kubelet'"
            echo "  4. Check API server: ssh rpi4-1 'sudo crictl ps | grep kube-apiserver'"
            exit 1
        fi
        
        printf "\r  Waiting... %ds / %ds" $elapsed $MAX_WAIT
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo ""
    log_verbose "API server responded successfully"
    log_success "API server is responding"
}

wait_for_nodes() {
    local elapsed=0
    local interval=10
    local ready_nodes=0
    
    log_step "Waiting for all $EXPECTED_NODES nodes to be Ready..."
    log_verbose "Checking node readiness every ${interval}s"
    
    while [ $ready_nodes -lt $EXPECTED_NODES ]; do
        if [ $elapsed -ge $MAX_WAIT ]; then
            log_error "Timeout waiting for nodes after ${MAX_WAIT}s"
            echo ""
            kubectl get nodes
            echo ""
            echo "Not all nodes are ready. Check:"
            echo "  1. Are all Raspberry Pis powered on?"
            echo "  2. Network connectivity to nodes"
            echo "  3. Kubelet status: ssh <node> 'sudo systemctl status kubelet'"
            exit 1
        fi
        
        ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
        log_verbose "Ready nodes: $ready_nodes / $EXPECTED_NODES"
        printf "\r  Ready nodes: %d / %d (waiting %ds / %ds)" $ready_nodes $EXPECTED_NODES $elapsed $MAX_WAIT
        
        if [ $ready_nodes -lt $EXPECTED_NODES ]; then
            sleep $interval
            elapsed=$((elapsed + interval))
        fi
    done
    
    echo ""
    log_success "All $EXPECTED_NODES nodes are Ready"
}

check_critical_pods() {
    log_step "Checking critical system pods..."
    
    local critical_namespaces=("kube-system" "longhorn-system" "argocd")
    local all_healthy=true
    
    for ns in "${critical_namespaces[@]}"; do
        log_verbose "Checking namespace: $ns"
        if kubectl get namespace "$ns" &> /dev/null; then
            NOT_RUNNING=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l | tr -d '[:space:]')
            NOT_RUNNING=${NOT_RUNNING:-0}
            if [ "$NOT_RUNNING" != "0" ] 2>/dev/null; then
                log_warning "Namespace $ns has $NOT_RUNNING pods not running"
                if [ "$VERBOSE" = true ]; then
                    kubectl get pods -n "$ns" --no-headers | grep -v "Running\|Completed" | head -5
                fi
                all_healthy=false
            else
                log_verbose "All pods in $ns are Running/Completed"
            fi
        else
            log_verbose "Namespace $ns does not exist"
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        log_success "Critical system pods are healthy"
    else
        log_warning "Some critical pods are not running. This may resolve shortly."
    fi
}

# =============================================================================
# MAIN STARTUP SEQUENCE
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              CLUSTER STARTUP & RECOVERY SEQUENCE                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Wait for API server
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 1: Connecting to Kubernetes API                                │"
echo "└─────────────────────────────────────────────────────────────────────┘"

wait_for_api

# -----------------------------------------------------------------------------
# STEP 2: Wait for all nodes
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 2: Waiting for all nodes to be Ready                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"

wait_for_nodes

echo ""
kubectl get nodes -o wide

if [ "$WAIT_ONLY" = true ]; then
    echo ""
    log_success "All nodes are ready (--wait-only mode)"
    exit 0
fi

# -----------------------------------------------------------------------------
# STEP 3: Uncordon all nodes
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 3: Uncordoning nodes                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Uncordoning all nodes to allow scheduling..."
log_verbose "Checking for cordoned nodes..."

# Get all nodes and check which are cordoned
UNCORDON_COUNT=0
ALL_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
log_verbose "Found nodes: $ALL_NODES"

for node in $ALL_NODES; do
    IS_UNSCHEDULABLE=$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "false")
    log_verbose "Node $node unschedulable: $IS_UNSCHEDULABLE"
    
    if [ "$IS_UNSCHEDULABLE" = "true" ]; then
        log_verbose "Uncordoning node: $node"
        if kubectl uncordon "$node"; then
            log_success "Uncordoned: $node"
            UNCORDON_COUNT=$((UNCORDON_COUNT + 1))
        else
            log_warning "Failed to uncordon: $node"
        fi
    fi
done

if [ $UNCORDON_COUNT -eq 0 ]; then
    log_info "No cordoned nodes found - all nodes already schedulable"
else
    log_success "Uncordoned $UNCORDON_COUNT nodes"
fi

# -----------------------------------------------------------------------------
# STEP 3.5: Clean up Completed, Failed, and Zombie pods
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 3.5: Cleaning up Completed, Failed, and Zombie pods            │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Cleaning up garbage pods (Completed, Evicted, Failed)..."

# 1. Fast cleanup using Kubernetes field selectors (Standard cleanup)
# This removes "Completed" (Succeeded) and "Evicted/Error" (Failed) pods efficiently
kubectl delete pods -A --field-selector=status.phase=Succeeded --grace-period=0 2>/dev/null || true
kubectl delete pods -A --field-selector=status.phase=Failed --grace-period=0 2>/dev/null || true

# 2. Aggressive cleanup for "Stuck" states (Zombie cleanup)
# Captures: Unknown, Terminating, NodeLost, ImagePullBackOff, CrashLoopBackOff, CreateContainerConfigError
log_step "Force deleting stuck/zombie pods..."

ZOMBIE_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | \
    awk '$4 == "Unknown" || $4 ~ /Terminating/ || $4 ~ /NodeLost/ || $4 ~ /Error/ || $4 ~ /BackOff/ || $4 ~ /ConfigError/ {print $1, $2}' || true)

if [ -n "$ZOMBIE_PODS" ]; then
    ZOMBIE_COUNT=$(echo "$ZOMBIE_PODS" | wc -l | tr -d '[:space:]')
    
    # Only print if count > 0 to avoid empty "Found 0..." logs
    if [ "$ZOMBIE_COUNT" != "0" ]; then
        log_warning "Found $ZOMBIE_COUNT stuck pods. Force deleting..."
        echo "$ZOMBIE_PODS" | while read -r ns pod; do
            if [ -n "$ns" ] && [ -n "$pod" ]; then
                log_verbose "Force deleting: $pod in $ns"
                kubectl delete pod "$pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
            fi
        done
        log_success "Stuck pods deleted"
        
        log_step "Waiting 10s for Kubernetes to process deletions..."
        sleep 10
    else
        log_success "No stuck pods found"
    fi
else
    log_success "No stuck pods found"
fi

# -----------------------------------------------------------------------------
# STEP 4: Wait for Infrastructure Components (in order)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 4: Waiting for infrastructure (Cilium → Longhorn → ArgoCD)     │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_info "Infrastructure must start in order: Cilium (CNI) → Longhorn (Storage) → ArgoCD (GitOps)"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4a: Wait for Cilium CNI (required for pod networking)
# ─────────────────────────────────────────────────────────────────────────────
log_step "4a. Waiting for Cilium CNI (pod networking)..."

set +e
CILIUM_WAIT=0
CILIUM_TIMEOUT=180  # 3 minutes for Cilium pods

while [ $CILIUM_WAIT -lt $CILIUM_TIMEOUT ]; do
    # Run kubectl with a strict system timeout (10s) to prevent hanging
    timeout 10s kubectl get pods -n kube-system -l k8s-app=cilium --no-headers > /tmp/cilium_debug.out 2> /tmp/cilium_debug.err
    CMD_EXIT=$?

    if [ $CMD_EXIT -ne 0 ]; then
        if [ $CMD_EXIT -eq 124 ]; then
             echo -e "\n  [DEBUG] kubectl command timed out (hung). API Server might be slow."
        fi
        TOTAL_PODS=0
    else
        TOTAL_PODS=$(wc -l < /tmp/cilium_debug.out)
    fi

    if [ "$TOTAL_PODS" -eq 0 ]; then
        printf "\r  Waiting for Cilium pods to appear... (%ds/%ds)   " "$CILIUM_WAIT" "$CILIUM_TIMEOUT"
    else
        NOT_RUNNING=$(grep -v "Running" /tmp/cilium_debug.out | wc -l)
        
        if [ "$NOT_RUNNING" -eq 0 ]; then
            printf "\r\033[K"
            log_success "Cilium CNI ready ($TOTAL_PODS pods running)"
            break
        fi
        
        RUNNING=$((TOTAL_PODS - NOT_RUNNING))
        printf "\r  Waiting for Cilium pods... (%d/%d ready, %ds/%ds)   " "$RUNNING" "$TOTAL_PODS" "$CILIUM_WAIT" "$CILIUM_TIMEOUT"
    fi

    sleep 5
    CILIUM_WAIT=$((CILIUM_WAIT + 5))
done
echo ""

if [ $CILIUM_WAIT -ge $CILIUM_TIMEOUT ]; then
    log_warning "Cilium pods not ready after ${CILIUM_TIMEOUT}s - continuing anyway"
    kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null || echo "Could not list pods"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4b: Wait for CoreDNS (required for service discovery)
# ─────────────────────────────────────────────────────────────────────────────
log_step "4b. Waiting for CoreDNS (service discovery)..."

COREDNS_WAIT=0
COREDNS_TIMEOUT=120  # 2 minutes for CoreDNS

while [ $COREDNS_WAIT -lt $COREDNS_TIMEOUT ]; do
    timeout 10s kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers > /tmp/coredns_debug.out 2>/dev/null
    CMD_EXIT=$?

    if [ $CMD_EXIT -eq 0 ]; then
        TOTAL_PODS=$(wc -l < /tmp/coredns_debug.out)
        NOT_RUNNING=$(grep -v "Running" /tmp/coredns_debug.out | wc -l)
        
        if [ "$TOTAL_PODS" -gt 0 ] && [ "$NOT_RUNNING" -eq 0 ]; then
            printf "\r\033[K"
            log_success "CoreDNS ready ($TOTAL_PODS pods running)"
            break
        fi
        
        RUNNING=$((TOTAL_PODS - NOT_RUNNING))
        printf "\r  Waiting for CoreDNS pods... (%d/%d ready, %ds/%ds)   " "$RUNNING" "$TOTAL_PODS" "$COREDNS_WAIT" "$COREDNS_TIMEOUT"
    else
        printf "\r  Waiting for CoreDNS pods... (%ds/%ds)   " "$COREDNS_WAIT" "$COREDNS_TIMEOUT"
    fi

    sleep 5
    COREDNS_WAIT=$((COREDNS_WAIT + 5))
done
echo ""

if [ $COREDNS_WAIT -ge $COREDNS_TIMEOUT ]; then
    log_warning "CoreDNS not ready after ${COREDNS_TIMEOUT}s - continuing anyway"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4c: Wait for Longhorn Storage (required for PVCs)
# ─────────────────────────────────────────────────────────────────────────────
log_step "4c. Waiting for Longhorn storage system..."

if kubectl get namespace longhorn-system &> /dev/null; then
    LH_WAIT=0
    LH_TIMEOUT=240  # 4 minutes for Longhorn pods
    
    while [ $LH_WAIT -lt $LH_TIMEOUT ]; do
        timeout 10s kubectl get pods -n longhorn-system --no-headers > /tmp/lh_debug.out 2>/dev/null
        CMD_EXIT=$?

        if [ $CMD_EXIT -eq 0 ]; then
            TOTAL_PODS=$(wc -l < /tmp/lh_debug.out)
            NOT_RUNNING=$(grep -v -E "Running|Completed" /tmp/lh_debug.out | wc -l)
            
            if [ "$TOTAL_PODS" -gt 0 ] && [ "$NOT_RUNNING" -eq 0 ]; then
                printf "\r\033[K"
                log_success "Longhorn storage ready ($TOTAL_PODS pods running)"
                break
            fi
            
            RUNNING=$((TOTAL_PODS - NOT_RUNNING))
            printf "\r  Waiting for Longhorn pods... (%d/%d ready, %ds/%ds)   " "$RUNNING" "$TOTAL_PODS" "$LH_WAIT" "$LH_TIMEOUT"
        else
            printf "\r  Waiting for Longhorn pods... (%ds/%ds)   " "$LH_WAIT" "$LH_TIMEOUT"
        fi

        sleep 10
        LH_WAIT=$((LH_WAIT + 10))
    done
    echo ""
    
    if [ $LH_WAIT -ge $LH_TIMEOUT ]; then
        log_warning "Longhorn not fully ready after ${LH_TIMEOUT}s - continuing anyway"
        kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -v -E "Running|Completed" | head -5 || true
    fi
    
    # Wait for storage node to be schedulable
    log_step "    Waiting for storage node (rpi4-1) to be schedulable..."
    LH_NODE_WAIT=0
    LH_NODE_TIMEOUT=120
    
    while [ $LH_NODE_WAIT -lt $LH_NODE_TIMEOUT ]; do
        LH_READY=$(timeout 5s kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null || echo "false")
        
        if [ "$LH_READY" == "true" ]; then
            log_success "    Storage node is schedulable"
            break
        fi
        
        printf "\r      Waiting for storage node... (%ds/%ds)" $LH_NODE_WAIT $LH_NODE_TIMEOUT
        sleep 10
        LH_NODE_WAIT=$((LH_NODE_WAIT + 10))
    done
    echo ""
    
    if [ "$LH_READY" != "true" ]; then
        log_warning "    Storage node not schedulable after ${LH_NODE_TIMEOUT}s - continuing"
    fi
else
    log_warning "Longhorn namespace not found - skipping storage wait"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4d: Wait for ArgoCD (required for GitOps workload management)
# ─────────────────────────────────────────────────────────────────────────────
log_step "4d. Waking up ArgoCD..."

if kubectl get namespace argocd &> /dev/null; then
    # 0. CLEAN UP STALE GIT LOCKS IN REPO-SERVER
    # After a hard shutdown, git processes may leave behind .git/index.lock files
    # that prevent ArgoCD from syncing repositories
    log_step "  Cleaning up ArgoCD repo-server cache (stale git locks)..."
    
    # Delete repo-server pods to clear any stale /tmp/_argocd-repo cache
    REPO_SERVER_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server --no-headers 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$REPO_SERVER_PODS" ]; then
        log_verbose "  Force deleting repo-server pods to clear git cache..."
        echo "$REPO_SERVER_PODS" | while read -r pod; do
            if [ -n "$pod" ]; then
                kubectl delete pod "$pod" -n argocd --force --grace-period=0 2>/dev/null || true
            fi
        done
        sleep 5
    fi
    
    # 1. DETECT & SCALE UP
    # If replicas are 0, we must scale up manually because the shutdown script scaled them down.
    # IMPORTANT: Redis must come up first, then other components
    
    REDIS_REPLICAS=$(kubectl get deployment -n argocd argocd-redis -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    SERVER_REPLICAS=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [ "$REDIS_REPLICAS" == "0" ] || [ "$SERVER_REPLICAS" == "0" ]; then
        log_warning "ArgoCD is sleeping (0 replicas). Waking it up..."
        
        # Scale up Redis FIRST (required for ArgoCD caching)
        log_step "  Scaling up ArgoCD Redis (required for caching)..."
        kubectl scale deployment -n argocd argocd-redis --replicas=1 2>/dev/null || true
        
        # Wait for Redis to be ready before scaling other components
        log_step "  Waiting for Redis to be ready..."
        kubectl rollout status deployment/argocd-redis -n argocd --timeout=120s 2>/dev/null || true
        
        # Now scale up the rest of ArgoCD
        log_step "  Scaling up remaining ArgoCD components..."
        kubectl scale deployment -n argocd --replicas=1 argocd-server argocd-repo-server argocd-dex-server argocd-applicationset-controller argocd-notifications-controller 2>/dev/null || true
        kubectl scale statefulset -n argocd --replicas=1 argocd-application-controller 2>/dev/null || true
        log_info "Scale up commands sent."
    fi

    # 2. WAIT LOOP
    ARGO_WAIT=0
    ARGO_TIMEOUT=180
    
    while [ $ARGO_WAIT -lt $ARGO_TIMEOUT ]; do
        # Get counts safely using wc -l and tr to prevent integer errors
        TOTAL_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
        
        if [ "$TOTAL_PODS" == "0" ]; then
            printf "\r  Waiting for ArgoCD pods to be created... (%ds/%ds)   " "$ARGO_WAIT" "$ARGO_TIMEOUT"
        else
            # Check for Running pods
            RUNNING_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep "Running" | wc -l | tr -d '[:space:]')
            
            # Check specifically for server ready status
            SERVER_READY=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            
            if [ "$SERVER_READY" == "1" ]; then
                echo ""
                log_success "ArgoCD Server is Ready!"
                break
            fi
            
            printf "\r  Waiting for ArgoCD... (%d/%d pods running, Server Ready: %s) %ds   " "$RUNNING_PODS" "$TOTAL_PODS" "$SERVER_READY" "$ARGO_WAIT"
        fi
        
        sleep 5
        ARGO_WAIT=$((ARGO_WAIT + 5))
    done
    
    if [ $ARGO_WAIT -ge $ARGO_TIMEOUT ]; then
        echo ""
        log_warning "ArgoCD not fully ready, but continuing to allow restore attempts..."
    fi
else
    log_warning "ArgoCD namespace not found - skipping"
fi

set -e
log_success "Infrastructure components ready!"

# -----------------------------------------------------------------------------
# STEP 4.5: FIX STUCK VOLUMES / ZOMBIE PODS
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 4.5: Cleaning up Stuck Volume Locks (Zombie Pods)              │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Second pass: cleaning any remaining stuck pods..."

# Find stuck pods (Terminating, Unknown, or any bad state) - handle empty results properly
STUCK_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4 == "Unknown" || $4 ~ /Terminating/ || $4 ~ /NodeLost/ || $4 ~ /Error/ || $4 ~ /ImagePullBackOff/ || $4 ~ /CrashLoopBackOff/ {print $1, $2}' || true)

if [ -n "$STUCK_PODS" ]; then
    STUCK_COUNT=$(echo "$STUCK_PODS" | wc -l | tr -d '[:space:]')
    log_warning "Found $STUCK_COUNT stuck/problematic pods. Force deleting..."
    echo "$STUCK_PODS" | while read -r ns pod; do
        if [ -n "$ns" ] && [ -n "$pod" ]; then
            log_verbose "Force deleting $pod in $ns"
            kubectl delete pod "$pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
        fi
    done
    log_success "Stuck pods cleared."
    
    log_step "Waiting 15s for Kubernetes to recreate pods..."
    sleep 15
else
    log_success "No stuck pods detected"
fi

# Clean up ALL non-running pods in critical namespaces (argocd, monitoring, gitea, storage)
log_step "Cleaning up non-running pods in critical namespaces..."
for ns in "argocd" "monitoring" "gitea" "storage" "observability"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        # Find ALL pods that are not Running/Completed and delete them
        BAD_PODS=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -v "Running\|Completed" | awk '{print $1}' || true)
        if [ -n "$BAD_PODS" ]; then
            log_warning "Found non-running pods in $ns namespace, cleaning up..."
            echo "$BAD_PODS" | while read -r pod; do
                if [ -n "$pod" ]; then
                    log_verbose "Deleting non-running pod: $pod in $ns"
                    kubectl delete pod "$pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
                fi
            done
        fi
    fi
done
log_success "Critical namespace cleanup complete"

# Proactively clean up stale VolumeAttachments that reference old pods
log_step "Checking for stale VolumeAttachments..."
STALE_VA=$(kubectl get volumeattachments -o json 2>/dev/null | jq -r '.items[] | select(.status.attached == false or .status.attached == null) | .metadata.name' 2>/dev/null || true)
if [ -n "$STALE_VA" ]; then
    log_warning "Found stale VolumeAttachments, cleaning up..."
    echo "$STALE_VA" | while read -r va; do
        if [ -n "$va" ]; then
            log_verbose "Deleting stale VolumeAttachment: $va"
            kubectl delete volumeattachment "$va" --force --grace-period=0 2>/dev/null || true
        fi
    done
    log_success "Stale VolumeAttachments cleaned"
else
    log_success "No stale VolumeAttachments found"
fi

# Reset Longhorn volumes that are stuck in attaching/detaching state
if kubectl get namespace longhorn-system &> /dev/null; then
    log_step "Checking for stuck Longhorn volumes..."
    STUCK_VOLUMES=$(kubectl get volumes.longhorn.io -n longhorn-system -o json 2>/dev/null | \
        jq -r '.items[] | select(.status.state == "attaching" or .status.state == "detaching") | .metadata.name' 2>/dev/null || true)
    
    if [ -n "$STUCK_VOLUMES" ]; then
        log_warning "Found volumes stuck in attaching/detaching state..."
        echo "$STUCK_VOLUMES" | while read -r vol; do
            if [ -n "$vol" ]; then
                log_verbose "Detaching stuck volume: $vol"
                # Force detach by removing attachedNodes
                kubectl patch volumes.longhorn.io "$vol" -n longhorn-system \
                    --type='json' -p='[{"op": "remove", "path": "/status/currentNodeID"}]' 2>/dev/null || true
            fi
        done
        log_step "Waiting 15s for volume state to settle..."
        sleep 15
    else
        log_success "No stuck Longhorn volumes"
    fi
fi

# Pre-cycle problematic workloads to clear potential volume locks
if [ "$SKIP_RESTORE" = false ]; then
    log_step "Pre-cycling workloads to clear potential volume locks..."
    
    # First, scale down to 0 and delete ALL pods for workloads with volume issues
    for workload in "monitoring/deployment/observability-stack-grafana" "gitea/deployment/gitea" "storage/deployment/minio"; do
        IFS='/' read -r ns type name <<< "$workload"
        if kubectl get namespace "$ns" &> /dev/null; then
            # Scale to 0
            if kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
                log_verbose "Scaling down $name in $ns"
                kubectl scale "$type" "$name" -n "$ns" --replicas=0 2>/dev/null || true
            fi
        fi
    done
    
    # Also handle gitea dependencies (postgresql and valkey) if they exist
    if kubectl get statefulset gitea-postgresql -n gitea &> /dev/null; then
        log_verbose "Scaling down gitea-postgresql statefulset"
        kubectl scale statefulset gitea-postgresql -n gitea --replicas=0 2>/dev/null || true
    fi
    if kubectl get statefulset gitea-valkey-cluster -n gitea &> /dev/null; then
        log_verbose "Scaling down gitea-valkey-cluster statefulset"
        kubectl scale statefulset gitea-valkey-cluster -n gitea --replicas=0 2>/dev/null || true
    fi
    
    # Wait a moment for scale down to take effect
    sleep 5
    
    # Force delete ALL pods in namespaces that use persistent volumes
    # This is aggressive but necessary to release volume locks
    log_step "Force deleting all pods in critical namespaces to release volumes..."
    for ns in "monitoring" "gitea" "storage" "observability"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
            if [ "$POD_COUNT" != "0" ]; then
                log_warning "Force deleting $POD_COUNT pods in $ns namespace..."
                kubectl delete pods -n "$ns" --all --force --grace-period=0 2>/dev/null || true
            fi
        fi
    done
    
    log_step "Waiting 45s for volumes to fully detach..."
    sleep 45
    
    # Verify volumes are detached
    log_step "Verifying volumes are detached..."
    if kubectl get namespace longhorn-system &> /dev/null; then
        # Wait for volumes to detach with a loop
        DETACH_WAIT=0
        DETACH_TIMEOUT=120
        while [ $DETACH_WAIT -lt $DETACH_TIMEOUT ]; do
            ATTACHED_VOLS=$(kubectl get volumes.longhorn.io -n longhorn-system -o json 2>/dev/null | \
                jq -r '.items[] | select(.status.state == "attached") | .metadata.name' 2>/dev/null | wc -l | tr -d '[:space:]')
            ATTACHED_VOLS=${ATTACHED_VOLS:-0}
            
            if [ "$ATTACHED_VOLS" = "0" ]; then
                log_success "All volumes detached"
                break
            fi
            
            printf "\r  Waiting for %d volumes to detach... (%ds/%ds)" "$ATTACHED_VOLS" "$DETACH_WAIT" "$DETACH_TIMEOUT"
            sleep 10
            DETACH_WAIT=$((DETACH_WAIT + 10))
        done
        echo ""
        
        if [ "$ATTACHED_VOLS" != "0" ]; then
            log_warning "Still $ATTACHED_VOLS volumes attached after ${DETACH_TIMEOUT}s"
            log_step "Force detaching remaining volumes..."
            kubectl get volumes.longhorn.io -n longhorn-system -o json 2>/dev/null | \
                jq -r '.items[] | select(.status.state == "attached") | .metadata.name' 2>/dev/null | \
                while read -r vol; do
                    if [ -n "$vol" ]; then
                        log_verbose "Force detaching: $vol"
                        kubectl patch volumes.longhorn.io "$vol" -n longhorn-system \
                            --type='merge' -p='{"spec":{"nodeID":""}}' 2>/dev/null || true
                    fi
                done
            sleep 15
        fi
    fi
fi

# -----------------------------------------------------------------------------
# STEP 5: Restore workloads (optional)
# -----------------------------------------------------------------------------
if [ "$SKIP_RESTORE" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 5: Restoring stateful workloads                                │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    log_info "ArgoCD will automatically sync and restore most workloads."
    log_info "Manually scaled workloads may need attention."
    
    # Check if ArgoCD is running
    log_verbose "Checking ArgoCD status..."
    if kubectl get deployment -n argocd argocd-server &> /dev/null; then
        ARGOCD_READY=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        log_verbose "ArgoCD server ready replicas: $ARGOCD_READY"
        if [ "$ARGOCD_READY" -gt 0 ]; then
            log_success "ArgoCD is running - GitOps reconciliation will restore workloads"
            
            # Re-enable auto-sync for ArgoCD applications (shutdown script disables it)
            log_step "Re-enabling ArgoCD auto-sync for all applications..."
            ARGOCD_APPS=$(kubectl get applications -n argocd -o name 2>/dev/null || true)
            if [ -n "$ARGOCD_APPS" ]; then
                for app in $ARGOCD_APPS; do
                    APP_NAME=$(echo "$app" | sed 's|application.argoproj.io/||')
                    log_verbose "Re-enabling auto-sync for: $APP_NAME"
                    # Re-enable automated sync policy
                    kubectl patch application "$APP_NAME" -n argocd --type=merge \
                        -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' 2>/dev/null || true
                done
                log_success "Auto-sync re-enabled for ArgoCD applications"
            else
                log_verbose "No ArgoCD applications found"
            fi
            
            # Optionally trigger a sync
            if command -v argocd &> /dev/null; then
                log_step "Triggering ArgoCD sync for all applications..."
                log_verbose "Running: argocd app list -o name | xargs argocd app sync --async"
                APPS=$(argocd app list -o name 2>/dev/null || true)
                if [ -n "$APPS" ]; then
                    echo "$APPS" | xargs -r -I {} argocd app sync {} --async 2>/dev/null || true
                    log_info "ArgoCD sync initiated (running in background)"
                else
                    log_verbose "No ArgoCD applications found or not logged in"
                fi
            else
                log_verbose "ArgoCD CLI not installed, skipping sync trigger"
            fi
        else
            log_warning "ArgoCD server not ready yet. Workloads will sync once it's up."
        fi
    else
        log_verbose "ArgoCD deployment not found"
    fi
    
    # Restore known stateful workloads that might have been scaled to 0
    # IMPORTANT: Order matters! Dependencies must be restored first.
    # Each workload waits to be READY before starting the next (resource constraints on RPi)
    log_step "Scaling up workloads SEQUENTIALLY (one at a time, waiting for ready)..."
    log_info "This prevents resource exhaustion on Raspberry Pi nodes."
    RESTORED_COUNT=0
    
    # Define restore order explicitly (dependencies first)
    # Format: "namespace/resource-type/name:replicas:wait_timeout"
    # Wait timeout is in seconds (0 = don't wait, just scale)
    RESTORE_ORDER=(
        # 1. ArgoCD components (Redis must come first for ArgoCD to function)
        "argocd/deployment/argocd-redis:1:120"
        "argocd/deployment/argocd-applicationset-controller:1:60"
        "argocd/deployment/argocd-notifications-controller:1:60"
        # 2. Storage backend (critical - many things depend on it)
        "storage/deployment/minio:1:180"
        # 3. Monitoring infrastructure (operator first, then workloads)
        "monitoring/deployment/prometheus-operator:1:120"
        "monitoring/deployment/observability-stack-kube-state-metrics:1:90"
        "monitoring/statefulset/prometheus-prometheus-prometheus:1:180"
        "monitoring/statefulset/alertmanager-prometheus-alertmanager:1:120"
        # Grafana has init-chown-data init container and needs extra time
        "monitoring/deployment/observability-stack-grafana:1:300"
        # 4. Observability (if installed)
        "observability/statefulset/loki:1:180"
        # 5. Gitea (dependencies first: postgresql -> valkey -> gitea)
        "gitea/statefulset/gitea-postgresql:1:180"
        "gitea/statefulset/gitea-valkey-cluster:3:120"
        "gitea/deployment/gitea:1:180"
        # 6. Harbor (if installed)
        "harbor/statefulset/harbor-database:1:180"
        "harbor/statefulset/harbor-registry:1:120"
    )
    
    # Function to delete pods for a workload (to release volume locks)
    delete_workload_pods() {
        local ns="$1"
        local name="$2"
        
        # Delete ALL pods matching this workload name (including old replicasets)
        local pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | awk '{print $1}')
        if [ -n "$pods" ]; then
            log_verbose "  Deleting existing pods for $name to release volumes..."
            echo "$pods" | while read -r pod; do
                if [ -n "$pod" ]; then
                    kubectl delete pod "$pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
                fi
            done
            sleep 5
        fi
    }
    
    # Function to wait for a workload to be ready
    wait_for_workload_ready() {
        local ns="$1"
        local type="$2"
        local name="$3"
        local timeout="$4"
        local elapsed=0
        
        if [ "$timeout" = "0" ]; then
            return 0
        fi
        
        log_step "  Waiting for $name to be ready (timeout: ${timeout}s)..."
        
        while [ $elapsed -lt $timeout ]; do
            local desired=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            local ready=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            ready=${ready:-0}
            
            # Also check that pods are actually Running (not just readyReplicas count)
            local running_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | grep -c "Running" 2>/dev/null || echo "0")
            
            if [ "$ready" = "$desired" ] && [ "$ready" != "0" ] && [ "$running_pods" -ge "$desired" ]; then
                log_success "  $name is ready ($ready/$desired)"
                return 0
            fi
            
            # Get pod status for more info - show the pod that's NOT ready
            local pod_info=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | grep -v "Running" | head -1 || true)
            if [ -z "$pod_info" ]; then
                pod_info=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | head -1 || true)
            fi
            local pod_status=$(echo "$pod_info" | awk '{print $2, $3}' || echo "unknown")
            
            # Check for volume attachment errors and handle them
            local pod_name=$(echo "$pod_info" | awk '{print $1}')
            if [ -n "$pod_name" ]; then
                local events=$(kubectl get events -n "$ns" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' 2>/dev/null | tail -3)
                if echo "$events" | grep -q "Multi-Attach"; then
                    log_warning "  Volume Multi-Attach error detected - cleaning up old pods..."
                    # Find and delete the OLD pod holding the volume
                    local old_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | grep -v "$pod_name" | awk '{print $1}')
                    if [ -n "$old_pods" ]; then
                        echo "$old_pods" | while read -r old_pod; do
                            if [ -n "$old_pod" ]; then
                                log_verbose "    Force deleting old pod: $old_pod"
                                kubectl delete pod "$old_pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
                            fi
                        done
                    fi
                fi
            fi
            
            printf "\r    Waiting: %s (%s) %ds/%ds   " "$name" "$pod_status" "$elapsed" "$timeout"
            
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        echo ""
        log_warning "  $name not ready after ${timeout}s - continuing anyway"
        return 1
    }
    
    echo ""
    for entry in "${RESTORE_ORDER[@]}"; do
        # Parse "namespace/type/name:replicas:timeout"
        workload_and_replicas="${entry%:*}"
        timeout="${entry##*:}"
        workload="${workload_and_replicas%:*}"
        replicas="${workload_and_replicas#*:}"
        # Handle case where there's no timeout specified (backward compat)
        if [ "$replicas" = "$workload" ]; then
            replicas="${entry#*:}"
            replicas="${replicas%:*}"
            timeout="120"
        fi
        IFS='/' read -r ns type name <<< "$workload"
        
        log_verbose "Checking $type/$name in $ns..."
        if kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
            CURRENT=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            CURRENT=${CURRENT:-0}
            READY=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            READY=${READY:-0}
            
            # Check if already running and ready
            if [ "$READY" = "$replicas" ] && [ "$READY" != "0" ]; then
                log_success "▶ $name: already running ($READY/$replicas ready)"
                continue
            fi
            
            # Scale up if needed
            if [ "$CURRENT" = "0" ] || [ "$CURRENT" != "$replicas" ]; then
                # For workloads with persistent volumes, delete existing pods first to release volume locks
                case "$name" in
                    *grafana*|*gitea*|*minio*|*postgresql*|*loki*|*prometheus*|*alertmanager*)
                        delete_workload_pods "$ns" "$name"
                        ;;
                esac
                
                log_step "▶ Starting $name in $ns ($replicas replicas)..."
                if kubectl scale "$type" "$name" -n "$ns" --replicas="$replicas" 2>/dev/null; then
                    RESTORED_COUNT=$((RESTORED_COUNT + 1))
                    
                    # Wait for it to be ready before continuing to next workload
                    wait_for_workload_ready "$ns" "$type" "$name" "$timeout"
                else
                    log_warning "  Failed to scale: $type/$name"
                fi
            else
                # Already scaled but not ready - wait for it
                log_step "▶ $name: waiting to become ready..."
                # Delete old pods if stuck
                case "$name" in
                    *grafana*|*gitea*|*minio*|*postgresql*|*loki*|*prometheus*|*alertmanager*)
                        delete_workload_pods "$ns" "$name"
                        ;;
                esac
                wait_for_workload_ready "$ns" "$type" "$name" "$timeout"
            fi
        else
            log_verbose "$type/$name not found in $ns - may not be installed"
        fi
    done
    echo ""
    
    if [ $RESTORED_COUNT -gt 0 ]; then
        log_success "Restored $RESTORED_COUNT workloads"
    else
        log_info "No workloads needed manual restoration"
    fi
else
    log_info "Skipping workload restore (--skip-restore specified)"
fi

# -----------------------------------------------------------------------------
# STEP 6: Final health check
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 6: Final cluster health check                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Running cluster health summary..."

echo ""
echo "Node Status:"
kubectl get nodes -o wide

echo ""
echo "System Pods (kube-system):"
kubectl get pods -n kube-system --no-headers 2>/dev/null | head -10
KUBE_SYSTEM_TOTAL=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
KUBE_SYSTEM_TOTAL=${KUBE_SYSTEM_TOTAL:-0}
if [ "$KUBE_SYSTEM_TOTAL" -gt 10 ] 2>/dev/null; then
    echo "  ... and $((KUBE_SYSTEM_TOTAL - 10)) more pods"
fi

echo ""
echo "Problem Pods (if any):"
PROBLEM_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | head -10 || true)
if [ -n "$PROBLEM_PODS" ]; then
    echo "$PROBLEM_PODS"
    PROBLEM_COUNT=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l | tr -d '[:space:]')
    PROBLEM_COUNT=${PROBLEM_COUNT:-0}
    if [ "$PROBLEM_COUNT" -gt 10 ] 2>/dev/null; then
        echo "  ... and $((PROBLEM_COUNT - 10)) more problem pods"
    fi
    echo ""
    log_warning "Some pods are not running. They may still be starting up."
else
    log_success "No problem pods detected"
fi

# Show resource usage if metrics-server is available
log_verbose "Checking for metrics-server..."
if kubectl top nodes &> /dev/null; then
    echo ""
    echo "Resource Usage:"
    kubectl top nodes
fi

# -----------------------------------------------------------------------------
# STEP 7: Final verification of critical workloads
# -----------------------------------------------------------------------------
if [ "$SKIP_WAIT" = false ] && [ "$SKIP_RESTORE" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 7: Final verification of critical workloads                    │"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    
    log_info "Verifying all critical workloads are running..."
    echo ""
    
    ALL_READY=true
    
    # Quick check - since we already waited for each workload sequentially,
    # this should mostly be a verification pass
    for workload in "${CRITICAL_WORKLOADS[@]}"; do
        IFS='/' read -r ns type name <<< "$workload"
        
        if ! kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
            log_verbose "$type/$name in $ns not found, skipping..."
            continue
        fi
        
        DESIRED=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        READY=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        READY=${READY:-0}
        
        if [ "$READY" = "$DESIRED" ] && [ "$READY" != "0" ]; then
            echo -e "  ${GREEN}✅${NC} $name ($ns): $READY/$DESIRED ready"
        else
            echo -e "  ${YELLOW}⏳${NC} $name ($ns): $READY/$DESIRED ready"
            ALL_READY=false
        fi
    done
    echo ""
    
    # If any workload is not ready, do an extended wait
    if [ "$ALL_READY" = false ]; then
        log_warning "Some workloads are not yet ready. Doing extended wait..."
        WORKLOAD_START=$(date +%s)
        
        while [ $(($(date +%s) - WORKLOAD_START)) -lt $WORKLOAD_WAIT ]; do
            ALL_READY=true
            ELAPSED=$(($(date +%s) - WORKLOAD_START))
            NOT_READY_LIST=""
            
            for workload in "${CRITICAL_WORKLOADS[@]}"; do
                IFS='/' read -r ns type name <<< "$workload"
                
                if ! kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
                    continue
                fi
                
                DESIRED=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                READY=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                READY=${READY:-0}
                
                if [ "$READY" != "$DESIRED" ] || [ "$READY" = "0" ]; then
                    ALL_READY=false
                    NOT_READY_LIST="${NOT_READY_LIST}${name}($READY/$DESIRED) "
                fi
            done
            
            if [ "$ALL_READY" = true ]; then
                echo ""
                log_success "All critical workloads are ready!"
                break
            fi
            
            printf "\r  Waiting for: %s (%ds/%ds)   " "$NOT_READY_LIST" "$ELAPSED" "$WORKLOAD_WAIT"
            sleep 10
        done
    else
        log_success "All critical workloads are ready!"
    fi
    
    # Set success based on final state
    if [ "$ALL_READY" = false ]; then
        echo ""
        log_error "Some critical workloads are not ready after waiting"
        echo ""
        echo "Current status of critical workloads:"
        for workload in "${CRITICAL_WORKLOADS[@]}"; do
            IFS='/' read -r ns type name <<< "$workload"
            if kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
                READY=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                READY=${READY:-0}
                DESIRED=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "?")
                echo "  - $name ($ns): $READY/$DESIRED ready"
                if [ "$READY" != "$DESIRED" ] || [ "$READY" = "0" ]; then
                    echo "    Pods:"
                    kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "^${name}" | head -3 | sed 's/^/      /'
                fi
            fi
        done
        echo ""
        log_warning "You may need to investigate manually."
        log_info "Try: kubectl describe pod -n <namespace> <pod-name>"
        STARTUP_SUCCESS=false
    else
        STARTUP_SUCCESS=true
    fi
else
    if [ "$SKIP_WAIT" = true ]; then
        log_info "Skipping wait for critical workloads (--skip-wait specified)"
    fi
    STARTUP_SUCCESS=true
fi

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
echo ""
if [ "$STARTUP_SUCCESS" = true ] 2>/dev/null; then
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                     STARTUP SEQUENCE COMPLETE                         ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                       ║"
    echo "║  ✅ All $EXPECTED_NODES nodes are Ready                                        ║"
    echo "║  ✅ Nodes uncordoned and schedulable                                  ║"
    echo "║  ✅ All critical workloads are running and ready                      ║"
    echo "║                                                                       ║"
    echo "║  Useful commands:                                                     ║"
    echo "║    kubectl get pods -A              # View all pods                   ║"
    echo "║    kubectl top nodes                # Check resource usage            ║"
    echo "║    argocd app list                  # View ArgoCD applications        ║"
    echo "║    cilium status                    # Check CNI health                ║"
    echo "║    bash tests/01_infra_test.sh      # Run infrastructure tests        ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                 STARTUP SEQUENCE COMPLETED WITH WARNINGS              ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                       ║"
    echo "║  ✅ All $EXPECTED_NODES nodes are Ready                                        ║"
    echo "║  ✅ Nodes uncordoned and schedulable                                  ║"
    echo "║  ⚠️  Some workloads are not yet ready                                  ║"
    echo "║                                                                       ║"
    echo "║  Check workload status:                                               ║"
    echo "║    kubectl get pods -A | grep -v Running                              ║"
    echo "║    kubectl describe pod -n <namespace> <pod-name>                     ║"
    echo "║    kubectl logs -n <namespace> <pod-name>                             ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
fi
echo ""