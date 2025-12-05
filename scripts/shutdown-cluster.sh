#!/bin/bash
# =============================================================================
# Graceful Cluster Shutdown Script
# =============================================================================
# This script prepares the Kubernetes cluster for a clean shutdown.
# It handles volume detachment, workload draining, and ordered node shutdown.
#
# Usage: bash scripts/shutdown-cluster.sh [--skip-scale-down] [--skip-shutdown]
#
# Options:
#   --skip-scale-down  Skip scaling down stateful workloads (faster but riskier)
#   --skip-shutdown    Only prepare cluster, don't SSH shutdown nodes
#   --dry-run          Show what would happen without executing
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
VOLUME_DETACH_WAIT=30

# How long to wait between worker shutdowns (seconds)
WORKER_SHUTDOWN_DELAY=5

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
SKIP_SCALE_DOWN=false
SKIP_SHUTDOWN=false
DRY_RUN=false

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
        --help|-h)
            echo "Usage: $0 [--skip-scale-down] [--skip-shutdown] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --skip-scale-down  Skip scaling down stateful workloads"
            echo "  --skip-shutdown    Only prepare cluster, don't shutdown nodes"
            echo "  --dry-run          Show what would happen without executing"
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
NC='\033[0m'

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        eval "$@"
    fi
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
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
run_cmd "kubectl cordon -l kubernetes.io/os=linux --dry-run=client -o name 2>/dev/null | xargs -r kubectl cordon 2>/dev/null || kubectl cordon --all"
log_success "All nodes cordoned"

# -----------------------------------------------------------------------------
# STEP 2: Scale down stateful workloads (optional but recommended)
# -----------------------------------------------------------------------------
if [ "$SKIP_SCALE_DOWN" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 2: Scaling down stateful workloads                             │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    for ns in "${STATEFUL_NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_step "Scaling down workloads in namespace: $ns"
            
            # Scale deployments
            DEPLOYMENTS=$(kubectl get deployments -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$DEPLOYMENTS" ]; then
                run_cmd "kubectl scale deployment -n $ns --replicas=0 --all 2>/dev/null || true"
            fi
            
            # Scale statefulsets
            STATEFULSETS=$(kubectl get statefulsets -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$STATEFULSETS" ]; then
                run_cmd "kubectl scale statefulset -n $ns --replicas=0 --all 2>/dev/null || true"
            fi
        fi
    done
    log_success "Stateful workloads scaled down"

    # Wait for volumes to detach
    echo ""
    log_step "Waiting ${VOLUME_DETACH_WAIT}s for volumes to detach cleanly..."
    if [ "$DRY_RUN" = false ]; then
        sleep "$VOLUME_DETACH_WAIT"
    fi
    log_success "Volume detach wait complete"
else
    log_warning "Skipping scale-down (--skip-scale-down specified)"
fi

# -----------------------------------------------------------------------------
# STEP 3: Check for stuck pods or volumes
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ STEP 3: Checking for stuck resources                                │"
echo "└─────────────────────────────────────────────────────────────────────┘"

log_step "Checking for pods in Terminating state..."
TERMINATING=$(kubectl get pods -A --field-selector=status.phase=Running -o json 2>/dev/null | grep -c '"phase": "Terminating"' || echo "0")
if [ "$TERMINATING" -gt 0 ]; then
    log_warning "$TERMINATING pods still terminating. Consider waiting or using --skip-scale-down next time."
else
    log_success "No terminating pods detected"
fi

log_step "Checking Longhorn volume status..."
if kubectl get volumes.longhorn.io -n longhorn-system &> /dev/null; then
    ATTACHED=$(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].status.state}' 2>/dev/null | tr ' ' '\n' | grep -c "attached" || echo "0")
    if [ "$ATTACHED" -gt 0 ]; then
        log_warning "$ATTACHED Longhorn volumes still attached. This is normal if workloads are running."
    else
        log_success "All Longhorn volumes detached"
    fi
fi

# -----------------------------------------------------------------------------
# STEP 4: Shutdown nodes in order
# -----------------------------------------------------------------------------
if [ "$SKIP_SHUTDOWN" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 4: Shutting down nodes (workers first, then control plane)    │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    # Shutdown workers first (in reverse order)
    for worker in "${WORKERS[@]}"; do
        log_step "Shutting down worker: $worker"
        run_cmd "ssh ${SSH_USER}@${worker} 'sudo shutdown -h now' 2>/dev/null || true"
        log_success "$worker shutdown signal sent"
        
        if [ "$DRY_RUN" = false ]; then
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
    run_cmd "ssh ${SSH_USER}@${CONTROL_PLANE} 'sudo shutdown -h now' 2>/dev/null || true"
    log_success "$CONTROL_PLANE shutdown signal sent"
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
