#!/bin/bash
set -e

echo "=== PHASE 3: LONGHORN BOOTSTRAP ==="

# 1. Add Repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# 2. Install Longhorn (Version locked)
# We set replicaCount=1 because we only have 1 HDD.
echo "Installing Longhorn Chart..."
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.10.1 \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=1 \
  --set defaultSettings.createDefaultDiskLabeledNodes=true \
  --set defaultSettings.allowNodeDrainWithLastHealthyReplica=true \
  --wait

# 3. Configure Control Plane Storage
echo "Configuring Control Plane (HDD) storage..."
kubectl label node rpi4-1 node.longhorn.io/create-default-disk=true --overwrite

# 4. Protect Worker SD Cards
# We disable storage scheduling on all small nodes
echo "Locking out worker nodes from storage duties..."
WORKERS=("rpi4-2" "rpi4-3" "rpi4-4")

for NODE in "${WORKERS[@]}"; do
    echo "Disabling scheduling on $NODE..."
    # We use 'patch' to modify the Longhorn Node CRD directly
    kubectl patch nodes.longhorn.io $NODE -n longhorn-system --type=merge -p '{"spec":{"allowScheduling": false}}' || true
done

echo "=== LONGHORN INSTALLED & CONFIGURED ==="
