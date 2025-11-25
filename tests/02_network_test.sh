#!/bin/bash
echo "=== NETWORK & CLUSTER VERIFICATION SUITE ==="

# 1. Check Node Readiness
echo "Checking Node Status..."
READY_COUNT=$(kubectl get nodes | grep "Ready" | wc -l)
if [ "$READY_COUNT" -eq 4 ]; then
    echo "✅ All 4 Nodes are Ready"
else
    echo "❌ Waiting for nodes... (Found $READY_COUNT/4 Ready)"
    exit 1
fi

# 2. Check Cilium Pods
echo "Checking Cilium..."
PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium | grep Running | wc -l)
if [ "$PODS" -eq 4 ]; then
    echo "✅ Cilium Agents Running on all nodes"
else
    echo "❌ Cilium pods missing or failed"
    exit 1
fi

# 3. Check Hubble
echo "Checking Hubble..."
kubectl get svc -n kube-system hubble-ui > /dev/null && echo "✅ Hubble UI Service exists"

# 4. Check Labels
echo "Checking Control Plane Labels..."
LABELS=$(kubectl get node rpi4-1 --show-labels)
if [[ $LABELS == *"hardware/unique-hdd=true"* ]]; then
    echo "✅ CP Label (unique-hdd) matches"
else
    echo "❌ CP Labels missing"
    exit 1
fi

echo "=== PHASE 2 COMPLETE ==="
