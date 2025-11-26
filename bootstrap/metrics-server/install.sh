#!/bin/bash
# =============================================================================
# Metrics Server Bootstrap Script
# =============================================================================
# Metrics Server is a cluster-wide aggregator of resource usage data.
#
# Required for:
#   - kubectl top nodes/pods commands
#   - Horizontal Pod Autoscaler (HPA)
#   - Vertical Pod Autoscaler (VPA)
#   - Kubernetes Dashboard resource displays
#
# Raspberry Pi Considerations:
#   - --kubelet-insecure-tls: Required because kubeadm uses self-signed certs
#   - --kubelet-preferred-address-types=InternalIP: Use internal cluster IPs
#   - Resource limits tuned for ARM64 with limited RAM
#
# Usage: bash bootstrap/metrics-server/install.sh
# =============================================================================

set -e
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              METRICS SERVER BOOTSTRAP                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"

# Add Helm repository
echo "Adding Metrics Server Helm repository..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install Metrics Server with ARM64 compatibility
echo "Installing Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.12.2 \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="200Mi" \
  --set resources.limits.cpu="250m" \
  --set resources.limits.memory="300Mi"

echo ""
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              METRICS SERVER INSTALLED                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Verification commands:"
echo "  kubectl top nodes        # View node resource usage"
echo "  kubectl top pods -A      # View pod resource usage across all namespaces"
echo ""
