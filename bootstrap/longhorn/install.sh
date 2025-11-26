#!/bin/bash
# =============================================================================
# Phase 3b: Longhorn Bootstrap Script
# =============================================================================
# Installs Longhorn distributed storage and configures it for single-HDD setup.
#
# Key Configuration:
#   - Single replica (only 1 HDD available)
#   - Storage only on rpi4-1 (Control Plane with HDD)
#   - Workers locked out (protect SD cards from writes)
#
# Prerequisites:
#   - HDD mounted at /var/lib/longhorn on rpi4-1
#   - iSCSI tools installed (Phase 1)
#   - kubectl and helm configured
#
# Usage: bash bootstrap/longhorn/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 3: LONGHORN BOOTSTRAP                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding Longhorn Helm Repository                             │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add longhorn https://charts.longhorn.io
helm repo update

# =============================================================================
# 2. Install Longhorn
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing Longhorn v1.10.1                                 │"
echo "└─────────────────────────────────────────────────────────────────────┘"
# Single replica because we only have 1 HDD
# createDefaultDiskLabeledNodes: auto-create disk on nodes with the label
# allowNodeDrainWithLastHealthyReplica: allow maintenance with single replica
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.10.1 \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=1 \
  --set defaultSettings.createDefaultDiskLabeledNodes=true \
  --set defaultSettings.allowNodeDrainWithLastHealthyReplica=true \
  --wait

echo ""
echo "Waiting for Longhorn pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n longhorn-system --timeout=300s

# =============================================================================
# 3. Configure Control Plane as Storage Node
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Configuring Control Plane (HDD) Storage                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"
kubectl label node rpi4-1 node.longhorn.io/create-default-disk=true --overwrite
echo "✅ Label applied: node.longhorn.io/create-default-disk=true on rpi4-1"

# =============================================================================
# 4. Protect Worker SD Cards
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 4: Locking Workers (Protect SD Cards)                          │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Wait for Longhorn to create node CRDs
echo "Waiting for Longhorn Node CRDs to be created..."
sleep 10

WORKERS=("rpi4-2" "rpi4-3" "rpi4-4")

for NODE in "${WORKERS[@]}"; do
    echo "Disabling storage scheduling on $NODE..."
    # Patch the Longhorn Node CRD to prevent storage scheduling
    kubectl patch nodes.longhorn.io "$NODE" -n longhorn-system \
        --type=merge \
        -p '{"spec":{"allowScheduling": false}}' 2>/dev/null || \
        echo "  ⚠️  Node CRD not yet created for $NODE (this is OK if node just joined)"
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              LONGHORN INSTALLED & CONFIGURED                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Storage Configuration:"
echo "  • Data Path: /var/lib/longhorn"
echo "  • Replica Count: 1 (single HDD)"
echo "  • Storage Node: rpi4-1 only"
echo "  • Workers: Protected (allowScheduling: false)"
echo ""
echo "Access Longhorn UI:"
echo "  kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80"
echo "  Open: http://localhost:8080"
echo ""
echo "Verify with:"
echo "  bash tests/03_storage_test.sh"
echo ""
