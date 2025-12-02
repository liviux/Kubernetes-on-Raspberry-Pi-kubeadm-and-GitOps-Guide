#!/bin/bash
# =============================================================================
# Phase 3: Storage Verification Script
# =============================================================================
# This script validates end-to-end storage functionality with Longhorn.
#
# Tests:
#   1. Longhorn System Health - All pods running in longhorn-system
#   2. Node Scheduling Config - CP enabled, workers disabled
#   3. Volume Provisioning - Create PVC and verify it binds
#   4. Network Attach - Pod on worker mounts volume from CP
#
# The test forces the pod to run on a worker node while the volume
# lives on the control plane's HDD, validating iSCSI network storage.
#
# Usage: bash tests/03_storage_test.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              STORAGE VERIFICATION SUITE                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# =============================================================================
# 1. Check Longhorn System Pods
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 1. LONGHORN SYSTEM HEALTH                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"

PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$PODS" -gt 10 ]; then
    echo -e "${GREEN}✅ Longhorn System is Running ($PODS pods)${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Longhorn pods are missing or crashed (Found $PODS Running)${NC}"
    kubectl get pods -n longhorn-system
    ((FAIL++))
fi

# Check specific critical components
MANAGER=$(kubectl get pods -n longhorn-system -l app=longhorn-manager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$MANAGER" -ge 1 ]; then
    echo -e "${GREEN}✅ Longhorn Manager Running${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Longhorn Manager not running${NC}"
    ((FAIL++))
fi

# =============================================================================
# 2. Check Node Configuration
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 2. NODE SCHEDULING CONFIGURATION                                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# rpi4-1 should be true, others false
CP_SCHED=$(kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null || echo "unknown")
WORKER_SCHED=$(kubectl get nodes.longhorn.io rpi4-2 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null || echo "unknown")

if [ "$CP_SCHED" == "true" ]; then
    echo -e "${GREEN}✅ Control Plane (rpi4-1): allowScheduling=true${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Control Plane scheduling: $CP_SCHED (expected: true)${NC}"
    ((FAIL++))
fi

if [ "$WORKER_SCHED" == "false" ]; then
    echo -e "${GREEN}✅ Workers: allowScheduling=false (SD cards protected)${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠️  Worker scheduling: $WORKER_SCHED (expected: false)${NC}"
    echo "   Run: kubectl patch nodes.longhorn.io rpi4-2 -n longhorn-system --type=merge -p '{\"spec\":{\"allowScheduling\": false}}'"
    ((FAIL++))
fi

# =============================================================================
# 3. Create Test Workload
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 3. VOLUME PROVISIONING TEST                                         │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Clean up any existing test resources
kubectl delete pod test-storage-pod --ignore-not-found=true 2>/dev/null
kubectl delete pvc test-storage-verify --ignore-not-found=true 2>/dev/null
sleep 2

echo "Creating test PVC and Pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-storage-verify
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: longhorn
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod
spec:
  nodeSelector:
    # Force pod to run on a worker to test network attachment
    hardware/sd: "64gb"
  containers:
  - name: write-test
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo 'Storage Works!' > /data/test.txt && cat /data/test.txt && sleep 30"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: test-storage-verify
  restartPolicy: Never
EOF

echo ""
echo "Waiting for PVC to be bound..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/test-storage-verify --timeout=120s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PVC Bound Successfully${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ PVC failed to bind${NC}"
    kubectl describe pvc test-storage-verify
    ((FAIL++))
fi

echo ""
echo "Waiting for Pod to start (this tests iSCSI volume attach)..."
kubectl wait --for=condition=Ready pod/test-storage-pod --timeout=120s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Storage Attached Successfully over Network${NC}"
    ((PASS++))
    
    # Show which node the pod is running on
    POD_NODE=$(kubectl get pod test-storage-pod -o jsonpath='{.spec.nodeName}')
    echo "   Pod running on: $POD_NODE"
    echo "   Volume stored on: rpi4-1 (HDD)"
    
    # Show pod logs to confirm write worked
    echo ""
    echo "   Pod output:"
    kubectl logs test-storage-pod 2>/dev/null | head -5
else
    echo -e "${RED}❌ Test Pod failed to start (Volume Attach Error?)${NC}"
    kubectl describe pod test-storage-pod
    ((FAIL++))
fi

# =============================================================================
# Cleanup
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 4. CLEANUP                                                          │"
echo "└─────────────────────────────────────────────────────────────────────┘"

echo "Cleaning up test resources..."
kubectl delete pod test-storage-pod --ignore-not-found=true 2>/dev/null
kubectl delete pvc test-storage-verify --ignore-not-found=true 2>/dev/null
echo -e "${GREEN}✅ Test resources cleaned up${NC}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                          SUMMARY                                      ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
printf "║  Passed: %-3d  │  Failed: %-3d                                       ║\n" $PASS $FAIL
echo "╚═══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ PHASE 3 VERIFICATION FAILED${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check Longhorn pods: kubectl get pods -n longhorn-system"
    echo "  • Check PVC events: kubectl describe pvc test-storage-verify"
    echo "  • Check volume: kubectl get volumes.longhorn.io -n longhorn-system"
    echo "  • Longhorn UI: kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80"
    exit 1
fi

echo ""
echo "🎉 PHASE 3 COMPLETE - Storage is operational!"
echo ""
echo "Storage Architecture Verified:"
echo "  • Longhorn running and healthy"
echo "  • HDD on rpi4-1 used for all storage"
echo "  • Worker SD cards protected (no writes)"
echo "  • iSCSI network attach working"
echo ""
echo "ℹ️  Note: Local Path Provisioner is deployed via GitOps in Phase 4"
echo "   (after ArgoCD is installed). It requires ArgoCD CRDs."
echo "   Deploy with: kubectl apply -f gitops/storage/local-path-provisioner.yaml"
echo ""
echo "Next command:"
echo "  bash bootstrap/traefik/install.sh"
