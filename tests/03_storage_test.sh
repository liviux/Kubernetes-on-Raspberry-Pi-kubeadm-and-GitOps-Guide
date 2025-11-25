#!/bin/bash
echo "=== STORAGE VERIFICATION SUITE ==="

# 1. Check System Pods
echo "Checking Longhorn System..."
PODS=$(kubectl get pods -n longhorn-system | grep Running | wc -l)
if [ "$PODS" -gt 10 ]; then
    echo "✅ Longhorn System is Running"
else
    echo "❌ Longhorn pods are missing or crashed"
    kubectl get pods -n longhorn-system
    exit 1
fi

# 2. Check Node Configuration
echo "Checking Disk Scheduling..."
# rpi4-1 should be true, others false
CP_SCHED=$(kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}')
WORKER_SCHED=$(kubectl get nodes.longhorn.io rpi4-2 -n longhorn-system -o jsonpath='{.spec.allowScheduling}')

if [ "$CP_SCHED" == "true" ] && [ "$WORKER_SCHED" == "false" ]; then
    echo "✅ HDD Affinity Configured (Only CP stores data)"
else
    echo "❌ Node Scheduling config is wrong! CP: $CP_SCHED, Worker: $WORKER_SCHED"
    exit 1
fi

# 3. Create Test Workload
echo "Deploying Test PVC & Pod..."
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
    image: busybox
    command: ["/bin/sh", "-c", "echo 'Storage Works' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: test-storage-verify
EOF

echo "Waiting for Pod to start (This verifies volume attach)..."
kubectl wait --for=condition=Ready pod/test-storage-pod --timeout=120s

if [ $? -eq 0 ]; then
    echo "✅ Storage Attached Successfully over Network"
    # Cleanup
    kubectl delete pod test-storage-pod
    kubectl delete pvc test-storage-verify
else
    echo "❌ Test Pod failed to start (Volume Attach Error?)"
    kubectl describe pod test-storage-pod
    exit 1
fi

echo "=== PHASE 3 COMPLETE ==="
