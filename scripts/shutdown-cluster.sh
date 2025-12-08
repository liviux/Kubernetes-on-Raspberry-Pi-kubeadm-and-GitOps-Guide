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
#   --verbose          Enable verbose output for debugging
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
# STEP 2: Scale down stateful workloads (optional but recommended)
# -----------------------------------------------------------------------------
if [ "$SKIP_SCALE_DOWN" = false ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ STEP 2: Scaling down stateful workloads                             │"
    echo "└─────────────────────────────────────────────────────────────────────┘"

    SCALED_COUNT=0
    for ns in "${STATEFUL_NAMESPACES[@]}"; do
        log_verbose "Checking namespace: $ns"
        if kubectl get namespace "$ns" &> /dev/null; then
            log_step "Scaling down workloads in namespace: $ns"
            
            # Scale deployments
            DEPLOYMENTS=$(kubectl get deployments -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$DEPLOYMENTS" ]; then
                DEP_COUNT=$(echo "$DEPLOYMENTS" | wc -l)
                log_verbose "Found $DEP_COUNT deployments in $ns"
                for dep in $DEPLOYMENTS; do
                    log_verbose "Scaling down $dep"
                done
                run_cmd "kubectl scale deployment -n $ns --replicas=0 --all 2>/dev/null || true"
                SCALED_COUNT=$((SCALED_COUNT + DEP_COUNT))
            else
                log_verbose "No deployments found in $ns"
            fi
            
            # Scale statefulsets
            STATEFULSETS=$(kubectl get statefulsets -n "$ns" -o name 2>/dev/null || true)
            if [ -n "$STATEFULSETS" ]; then
                STS_COUNT=$(echo "$STATEFULSETS" | wc -l)
                log_verbose "Found $STS_COUNT statefulsets in $ns"
                for sts in $STATEFULSETS; do
                    log_verbose "Scaling down $sts"
                done
                run_cmd "kubectl scale statefulset -n $ns --replicas=0 --all 2>/dev/null || true"
                SCALED_COUNT=$((SCALED_COUNT + STS_COUNT))
            else
                log_verbose "No statefulsets found in $ns"
            fi
        else
            log_verbose "Namespace $ns does not exist, skipping"
        fi
    done
    log_success "Scaled down $SCALED_COUNT workloads"

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
log_verbose "Running: kubectl get pods -A | grep Terminating"
TERMINATING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -i "Terminating" || true)
TERMINATING_COUNT=$(echo "$TERMINATING_PODS" | grep -c "Terminating" 2>/dev/null || echo "0")
if [ "$TERMINATING_COUNT" -gt 0 ]; then
    log_warning "$TERMINATING_COUNT pods still terminating:"
    if [ "$VERBOSE" = true ]; then
        echo "$TERMINATING_PODS" | head -10
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
                log_warning "$ATTACHED Longhorn volumes still attached. This is normal if workloads are running."
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
