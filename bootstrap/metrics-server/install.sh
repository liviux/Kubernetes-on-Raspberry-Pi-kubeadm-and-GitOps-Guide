#!/bin/bash
set -e
echo "=== METRICS SERVER BOOTSTRAP ==="

# Metrics Server is required for:
# - kubectl top nodes/pods
# - Horizontal Pod Autoscaler (HPA)
# - Vertical Pod Autoscaler (VPA)
# - Kubernetes Dashboard resource displays

# Install Metrics Server with ARM64 compatibility
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.12.2 \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="200Mi" \
  --set resources.limits.cpu="250m" \
  --set resources.limits.memory="300Mi"

echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s

echo "=== METRICS SERVER INSTALLED ==="
echo "Verify with: kubectl top nodes"
