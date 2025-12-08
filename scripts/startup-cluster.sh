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
#   --wait-only       Only wait for nodes, don't uncordon or restore
#   --skip-restore    Uncordon nodes but don't scale up workloads
#   --timeout <s>     Max seconds to wait for nodes (default: 300)
#   --verbose, -v     Enable verbose output for debugging
#
# Prerequisites:
#   - All nodes physically powered on
#   - kubectl configured with cluster access
#   - Control plane should be powered on 2-3 min before workers
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
EXPECTED_NODES=4
MAX_WAIT=${MAX_WAIT:-300}  # 5 minutes default

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
declare -A DEFAULT_REPLICAS=(
    ["storage/deployment/minio"]="1"
    ["gitea/statefulset/gitea"]="1"
    ["monitoring/statefulset/prometheus-kube-prometheus-stack-prometheus"]="1"
    ["monitoring/statefulset/alertmanager-kube-prometheus-stack-alertmanager"]="1"
    ["observability/statefulset/loki"]="1"
    ["harbor/statefulset/harbor-registry"]="1"
    ["harbor/statefulset/harbor-database"]="1"
)

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
WAIT_ONLY=false
SKIP_RESTORE=false
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
        --timeout)
            MAX_WAIT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--wait-only] [--skip-restore] [--timeout <seconds>] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --wait-only     Only wait for nodes to be ready"
            echo "  --skip-restore  Don't scale up workloads after uncordoning"
            echo "  --timeout <s>   Max seconds to wait (default: 300)"
            echo "  --verbose, -v   Enable verbose output for debugging"
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
            NOT_RUNNING=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
            if [ "$NOT_RUNNING" -gt 0 ]; then
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
# STEP 4: Check critical system pods
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 4: Verifying critical system components                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Wait a bit for pods to stabilize
log_step "Waiting 15s for pods to stabilize..."
log_verbose "Sleeping 15 seconds..."
sleep 15

check_critical_pods

# Check Cilium status
log_step "Checking Cilium CNI status..."
if command -v cilium &> /dev/null; then
    log_verbose "Cilium CLI found, running status check..."
    if cilium status --wait 2>&1 | tee /dev/null; then
        log_success "Cilium CNI is healthy"
    else
        log_warning "Cilium status check failed. Run 'cilium status' for details."
    fi
else
    log_verbose "Cilium CLI not installed, checking pods instead..."
    CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -v "Running" | wc -l || echo "0")
    if [ "$CILIUM_PODS" -eq 0 ]; then
        log_success "Cilium pods are running"
    else
        log_warning "Some Cilium pods are not running"
    fi
fi

# Check Longhorn
log_step "Checking Longhorn storage..."
if kubectl get namespace longhorn-system &> /dev/null; then
    log_verbose "longhorn-system namespace exists, checking pods..."
    LH_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
    if [ "$LH_PODS" -eq 0 ]; then
        log_success "Longhorn storage is healthy"
    else
        log_warning "Longhorn has $LH_PODS pods not running. Storage may be recovering."
        if [ "$VERBOSE" = true ]; then
            kubectl get pods -n longhorn-system --no-headers | grep -v "Running\|Completed" | head -5
        fi
    fi
else
    log_verbose "longhorn-system namespace not found"
fi

log_step "Waiting for Longhorn Nodes to be schedulable..."
# We loop until all Longhorn nodes report "allowScheduling: true" (or at least the HDD node)
while true; do
    # Check if rpi4-1 (our storage node) is ready in Longhorn
    LH_READY=$(kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null || echo "false")
    
    if [ "$LH_READY" == "true" ]; then
        log_success "Longhorn storage node is active."
        break
    fi
    
    echo "   Waiting for Longhorn storage node to initialize... (Retrying in 10s)"
    sleep 10
done

log_step "Waiting an extra 30s for volume metadata sync..."
sleep 30

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
    log_step "Checking for workloads scaled to 0..."
    RESTORED_COUNT=0
    for key in "${!DEFAULT_REPLICAS[@]}"; do
        IFS='/' read -r ns type name <<< "$key"
        replicas="${DEFAULT_REPLICAS[$key]}"
        
        log_verbose "Checking $type/$name in $ns..."
        if kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
            CURRENT=$(kubectl get "$type" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            log_verbose "Current replicas: $CURRENT, desired: $replicas"
            if [ "$CURRENT" -eq 0 ]; then
                log_step "Scaling up $type/$name in $ns to $replicas replicas"
                if kubectl scale "$type" "$name" -n "$ns" --replicas="$replicas" 2>/dev/null; then
                    log_success "Scaled: $type/$name"
                    RESTORED_COUNT=$((RESTORED_COUNT + 1))
                else
                    log_warning "Failed to scale: $type/$name"
                fi
            fi
        else
            log_verbose "$type/$name not found in $ns"
        fi
    done
    
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
KUBE_SYSTEM_TOTAL=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$KUBE_SYSTEM_TOTAL" -gt 10 ]; then
    echo "  ... and $((KUBE_SYSTEM_TOTAL - 10)) more pods"
fi

echo ""
echo "Problem Pods (if any):"
PROBLEM_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | head -10 || true)
if [ -n "$PROBLEM_PODS" ]; then
    echo "$PROBLEM_PODS"
    PROBLEM_COUNT=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
    if [ "$PROBLEM_COUNT" -gt 10 ]; then
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
# SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                     STARTUP SEQUENCE COMPLETE                         ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                       ║"
echo "║  ✅ All $EXPECTED_NODES nodes are Ready                                        ║"
echo "║  ✅ Nodes uncordoned and schedulable                                  ║"
echo "║                                                                       ║"
echo "║  Useful commands:                                                     ║"
echo "║    kubectl get pods -A              # View all pods                   ║"
echo "║    kubectl top nodes                # Check resource usage            ║"
echo "║    argocd app list                  # View ArgoCD applications        ║"
echo "║    cilium status                    # Check CNI health                ║"
echo "║    bash tests/01_infra_test.sh      # Run infrastructure tests        ║"
echo "║                                                                       ║"
echo "║  If workloads are slow to start, wait 2-3 minutes for:               ║"
echo "║    - Longhorn volumes to reattach                                     ║"
echo "║    - ArgoCD to reconcile applications                                 ║"
echo "║    - Health checks to pass                                            ║"
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
