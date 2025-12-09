#!/bin/bash
# =============================================================================
# Graceful Cluster Shutdown Script
# =============================================================================
# This script prepares the Kubernetes cluster for a clean shutdown.
# It handles volume detachment, workload draining, and ordered node shutdown.
#
# Usage: bash scripts/shutdown-cluster.sh [OPTIONS]
#
# Options:
#   --skip-scale-down  Skip scaling down stateful workloads (faster but riskier)
#   --skip-shutdown    Only prepare cluster, don't SSH shutdown nodes
#   --dry-run          Show what would happen without executing
#   --verbose, -v      Enable verbose output for debugging
#
# Prerequisites:
#   - kubectl configured with cluster access
#   - SSH access to all nodes (key-based recommended)
#   - Run from the repository root directory
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION - Adjust these to match your environment
# =============================================================================
SSH_USER="${SSH_USER:-user}"
CONTROL_PLANE="rpi4-1"
WORKERS=("rpi4-4" "rpi4-3" "rpi4-2")  # Shutdown order: last worker first

# Namespaces with stateful workloads to scale down
STATEFUL_NAMESPACES=(
    "monitoring"
    "observability"
    "logging"
    "gitea"
    "harbor"
    "storage"
    "openbao"
    "velero"
)

# How long to wait for volumes to detach (seconds)
VOLUME_DETACH_WAIT=60

# How long to wait between worker shutdowns (seconds)
WORKER_SHUTDOWN_DELAY=5

# Critical workloads to scale down first (in order)
# These should match the workloads in startup-cluster.sh DEFAULT_REPLICAS
CRITICAL_WORKLOADS=(
    "gitea/deployment/gitea"
    "gitea/statefulset/gitea-postgresql"
    "gitea/statefulset/gitea-valkey-cluster"
    "monitoring/deployment/observability-stack-grafana"
    "monitoring/deployment/observability-stack-kube-state-metrics"
    "monitoring/deployment/prometheus-operator"
    "monitoring/statefulset/prometheus-prometheus-prometheus"
    "monitoring/statefulset/alertmanager-prometheus-alertmanager"
    "observability/statefulset/loki"
    "storage/deployment/minio"
)

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
SKIP_SCALE_DOWN=false
SKIP_SHUTDOWN=false
DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --skip-scale-down)
            SKIP_SCALE_DOWN=true
            shift
            ;;
        --skip-shutdown)
            SKIP_SHUTDOWN=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-scale-down] [--skip-shutdown] [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --skip-scale-down  Skip scaling down stateful workloads"
            echo "  --skip-shutdown    Only prepare cluster, don't shutdown nodes"
            echo "  --dry-run          Show what would happen without executing"
            echo "  --verbose, -v      Enable verbose output for debugging"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
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


run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
        return 0
    else
        log_verbose "Executing: $*"
        eval "$@"
    fi
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    log_verbose "Checking for kubectl..."
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    log_verbose "kubectl found: $(command -v kubectl)"
    
    log_verbose "Testing cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        log_verbose "KUBECONFIG=${KUBECONFIG:-~/.kube/config}"
        exit 1
    fi
    log_verbose "Cluster connection successful"
    
    log_success "Prerequisites check passed"
}

# =============================================================================
# MAIN SHUTDOWN SEQUENCE
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              GRACEFUL CLUSTER SHUTDOWN SEQUENCE                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY-RUN MODE - No changes will be made"
    echo ""
fi

check_prerequisites

# -----------------------------------------------------------------------------
# STEP 1: Cordon all nodes to prevent new scheduling
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 1: Cordoning all nodes                                         │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Cordoning all nodes to prevent new pod scheduling..."

# Get all node names and cordon each one individually
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
log_verbose "Found nodes: $NODES"

CORDON_COUNT=0
for node in $NODES; do
    log_verbose "Cordoning node: $node"
    if run_cmd "kubectl cordon '$node'"; then
        log_success "Cordoned: $node"
        CORDON_COUNT=$((CORDON_COUNT + 1))
    else
        log_warning "Failed to cordon: $node (may already be cordoned)"
    fi
done

log_success "Cordoned $CORDON_COUNT nodes"

# -----------------------------------------------------------------------------
# STEP 2: Scale down in reverse dependency order
# -----------------------------------------------------------------------------
if [ "$SKIP_SCALE_DOWN" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 2: Scaling down workloads (reverse dependency order)           │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    log_info "Shutdown order: User workloads → ArgoCD → Longhorn consumers → MinIO"

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2a: Pause ArgoCD sync to prevent reconciliation during shutdown
    # ─────────────────────────────────────────────────────────────────────────
    log_step "2a. Pausing ArgoCD auto-sync..."
    if kubectl get namespace argocd &> /dev/null; then
        # Pause all ArgoCD applications to prevent them from recreating scaled-down workloads
        ARGOCD_APPS=$(kubectl get applications -n argocd -o name 2>/dev/null || true)
        if [ -n "$ARGOCD_APPS" ]; then
            for app in $ARGOCD_APPS; do
                APP_NAME=$(echo "$app" | sed 's|application.argoproj.io/||')
                log_verbose "Pausing ArgoCD app: $APP_NAME"
                run_cmd "kubectl patch application $APP_NAME -n argocd --type=merge -p '{\"spec\":{\"syncPolicy\":null}}' 2>/dev/null || true"
            done
            log_success "ArgoCD applications paused"
        else
            log_verbose "No ArgoCD applications found"
        fi
    else
        log_verbose "ArgoCD namespace not found"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2b: Scale down user workloads first (Gitea, Grafana, etc.)
    # ─────────────────────────────────────────────────────────────────────────
    log_step "2b. Scaling down user workloads..."
    for workload in "${CRITICAL_WORKLOADS[@]}"; do
        IFS='/' read -r ns type name <<< "$workload"
        if kubectl get "$type" "$name" -n "$ns" &> /dev/null; then
            log_verbose "Scaling down $name in $ns"
            run_cmd "kubectl scale $type $name -n $ns --replicas=0 2>/dev/null || true"
            log_success "Scaled down: $name"
        fi
    done
    
    # Wait for critical workloads to terminate
    log_step "    Waiting 30s for workloads to terminate..."
    if [ "$DRY_RUN" = false ]; then
        sleep 30
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2c: Scale down remaining namespaced workloads
    # ─────────────────────────────────────────────────────────────────────────
    log_step "2c. Scaling down remaining workloads by namespace..."
    SCALED_COUNT=0
    for ns in "${STATEFUL_NAMESPACES[@]}"; do
        log_verbose "Checking namespace: $ns"
        if kubectl get namespace "$ns" &> /dev/null; then
            log_step "    Processing namespace: $ns"
            
            # Scale deployments
            DEPLOYMENTS=$(kubectl get deployments -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$DEPLOYMENTS" ]; then
                DEP_COUNT=$(echo "$DEPLOYMENTS" | wc -l)
                log_verbose "Found $DEP_COUNT deployments in $ns"
                run_cmd "kubectl scale deployment -n $ns --replicas=0 --all 2>/dev/null || true"
                SCALED_COUNT=$((SCALED_COUNT + DEP_COUNT))
            fi
            
            # Scale statefulsets
            STATEFULSETS=$(kubectl get statefulsets -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$STATEFULSETS" ]; then
                STS_COUNT=$(echo "$STATEFULSETS" | wc -l)
                log_verbose "Found $STS_COUNT statefulsets in $ns"
                run_cmd "kubectl scale statefulset -n $ns --replicas=0 --all 2>/dev/null || true"
                SCALED_COUNT=$((SCALED_COUNT + STS_COUNT))
            fi
        else
            log_verbose "Namespace $ns does not exist, skipping"
        fi
    done
    log_success "Scaled down $SCALED_COUNT total workloads"

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2d: Scale down ArgoCD itself (so it doesn't restart workloads)
    # ─────────────────────────────────────────────────────────────────────────
    log_step "2d. Scaling down ArgoCD..."
    if kubectl get namespace argocd &> /dev/null; then
        run_cmd "kubectl scale deployment -n argocd --replicas=0 --all 2>/dev/null || true"
        run_cmd "kubectl scale statefulset -n argocd --replicas=0 --all 2>/dev/null || true"
        log_success "ArgoCD scaled down"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2d.5: Explicitly cleanup repo-server to prevent git locks
    # ─────────────────────────────────────────────────────────────────────────
    log_step "2d.5. Cleaning up ArgoCD repo-server pods..."
    if kubectl get namespace argocd &> /dev/null; then
        # Force delete the pods to ensure the emptyDir cache is wiped
        # This prevents index.lock files from persisting if using persistent storage
        kubectl delete pods -n argocd -l app.kubernetes.io/name=argocd-repo-server --force --grace-period=0 2>/dev/null || true
        log_success "Repo-server pods deleted"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2e: Wait for volumes to detach
    # ─────────────────────────────────────────────────────────────────────────
    echo ""
    log_step "2e. Waiting ${VOLUME_DETACH_WAIT}s for volumes to detach cleanly..."
    if [ "$DRY_RUN" = false ]; then
        sleep "$VOLUME_DETACH_WAIT"
    fi
    log_success "Volume detach wait complete"
else
    log_warning "Skipping scale-down (--skip-scale-down specified)"
fi

# -----------------------------------------------------------------------------
# STEP 3: Check for stuck pods or volumes and clean up
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 3: Checking and cleaning stuck resources                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Checking for pods in Terminating state..."
log_verbose "Running: kubectl get pods -A | grep Terminating"
TERMINATING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -i "Terminating" || true)
TERMINATING_COUNT=$(echo "$TERMINATING_PODS" | grep -c "Terminating" 2>/dev/null || echo "0")
if [ "$TERMINATING_COUNT" -gt 0 ]; then
    log_warning "$TERMINATING_COUNT pods still terminating. Force deleting..."
    echo "$TERMINATING_PODS" | awk '{print $1 " " $2}' | while read -r ns pod; do
        if [ -n "$ns" ] && [ -n "$pod" ]; then
            log_verbose "Force deleting $pod in $ns"
            run_cmd "kubectl delete pod '$pod' -n '$ns' --force --grace-period=0 2>/dev/null || true"
        fi
    done
    log_success "Terminating pods force deleted"
    
    # Wait for pods to be gone
    log_step "Waiting 15s for pods to be removed..."
    if [ "$DRY_RUN" = false ]; then
        sleep 15
    fi
else
    log_success "No terminating pods detected"
fi

log_step "Checking Longhorn volume status..."
if kubectl get crd volumes.longhorn.io &> /dev/null; then
    log_verbose "Longhorn CRD found, checking volumes..."
    if kubectl get namespace longhorn-system &> /dev/null; then
        VOLUME_STATES=$(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}={.status.state}{"\n"}{end}' 2>/dev/null || true)
        if [ -n "$VOLUME_STATES" ]; then
            log_verbose "Volume states:"
            if [ "$VERBOSE" = true ]; then
                echo "$VOLUME_STATES"
            fi
            ATTACHED=$(echo "$VOLUME_STATES" | grep -c "attached" || echo "0")
            if [ "$ATTACHED" -gt 0 ]; then
                log_warning "$ATTACHED Longhorn volumes still attached."
                
                # Wait a bit more for volumes to detach
                log_step "Waiting additional 30s for volumes to detach..."
                if [ "$DRY_RUN" = false ]; then
                    sleep 30
                fi
                
                # Check again
                ATTACHED=$(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}={.status.state}{"\n"}{end}' 2>/dev/null | grep -c "attached" || echo "0")
                if [ "$ATTACHED" -gt 0 ]; then
                    log_warning "Still $ATTACHED volumes attached. They will detach when nodes shut down."
                else
                    log_success "All volumes now detached"
                fi
            else
                log_success "All Longhorn volumes detached"
            fi
        else
            log_verbose "No Longhorn volumes found"
            log_success "No Longhorn volumes to detach"
        fi
    else
        log_verbose "longhorn-system namespace not found"
    fi
else
    log_verbose "Longhorn CRD not found, skipping volume check"
fi

# -----------------------------------------------------------------------------
# STEP 4: Shutdown nodes in order
# -----------------------------------------------------------------------------
if [ "$SKIP_SHUTDOWN" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 4: Shutting down nodes (workers first, then control plane)    │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    log_verbose "SSH user: $SSH_USER"
    log_verbose "Workers shutdown order: ${WORKERS[*]}"
    log_verbose "Control plane: $CONTROL_PLANE"

    # Shutdown workers first (in reverse order)
    for worker in "${WORKERS[@]}"; do
        log_step "Shutting down worker: $worker"
        log_verbose "Running: ssh ${SSH_USER}@${worker} 'sudo shutdown -h now'"
        if run_cmd "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${SSH_USER}@${worker} 'sudo shutdown -h now' 2>&1"; then
            log_success "$worker shutdown signal sent"
        else
            log_warning "$worker shutdown command returned error (node may already be shutting down)"
        fi
        
        if [ "$DRY_RUN" = false ]; then
            log_verbose "Waiting ${WORKER_SHUTDOWN_DELAY}s before next worker..."
            sleep "$WORKER_SHUTDOWN_DELAY"
        fi
    done

    # Wait a bit for workers to fully shutdown
    log_step "Waiting 10s for workers to complete shutdown..."
    if [ "$DRY_RUN" = false ]; then
        sleep 10
    fi

    # Shutdown control plane last
    log_step "Shutting down control plane: $CONTROL_PLANE"
    log_verbose "Running: ssh ${SSH_USER}@${CONTROL_PLANE} 'sudo shutdown -h now'"
    if run_cmd "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${SSH_USER}@${CONTROL_PLANE} 'sudo shutdown -h now' 2>&1"; then
        log_success "$CONTROL_PLANE shutdown signal sent"
    else
        log_warning "$CONTROL_PLANE shutdown command returned error (node may already be shutting down)"
    fi
else
    log_warning "Skipping node shutdown (--skip-shutdown specified)"
    echo ""
    echo "To manually shutdown nodes, run these commands in order:"
    echo ""
    for worker in "${WORKERS[@]}"; do
        echo "  ssh ${SSH_USER}@${worker} 'sudo shutdown -h now'"
    done
    echo "  ssh ${SSH_USER}@${CONTROL_PLANE} 'sudo shutdown -h now'"
fi

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                     SHUTDOWN SEQUENCE COMPLETE                        ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                       ║"
if [ "$SKIP_SHUTDOWN" = false ]; then
echo "║  ✅ All nodes have received shutdown signal                           ║"
echo "║                                                                       ║"
echo "║  To start the cluster again:                                          ║"
echo "║    1. Power on rpi4-1 (control plane) first                           ║"
echo "║    2. Wait 2-3 minutes for it to boot                                 ║"
echo "║    3. Power on workers: rpi4-2, rpi4-3, rpi4-4                        ║"
echo "║    4. Run: bash scripts/startup-cluster.sh                            ║"
else
echo "║  ✅ Cluster prepared for shutdown (nodes not powered off)             ║"
echo "║                                                                       ║"
echo "║  Run with full shutdown:                                              ║"
echo "║    bash scripts/shutdown-cluster.sh                                   ║"
fi
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
