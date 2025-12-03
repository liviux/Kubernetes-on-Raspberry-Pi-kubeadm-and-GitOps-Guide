#!/bin/bash
# =============================================================================
# Phase 4a: Traefik Gateway Bootstrap Script
# =============================================================================
# Installs Traefik v3 as the cluster's ingress controller and Gateway API
# implementation. All external traffic flows through this single entry point.
#
# Features:
#   - LoadBalancer IP from Cilium L2 pool (192.168.68.210)
#   - Cross-namespace routing support
#   - Prometheus metrics enabled
#   - JSON access logs for Loki
#
# Prerequisites:
#   - Cilium CNI with L2 announcements enabled
#   - kubectl and helm configured
#
# Usage: bash bootstrap/traefik/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 4a: TRAEFIK GATEWAY BOOTSTRAP                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding Traefik Helm Repository                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add traefik https://traefik.github.io/charts
helm repo update

# =============================================================================
# 2. Install Traefik
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing Traefik v3                                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Deploying Traefik with Gateway API support..."

helm upgrade --install traefik traefik/traefik \
  --namespace traefik-system \
  --create-namespace \
  --version 37.3.0 \
  --set service.type=LoadBalancer \
  --set service.spec.loadBalancerIP=192.168.68.210 \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set providers.kubernetesCRD.enabled=true \
  --set providers.kubernetesCRD.allowCrossNamespace=true \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesGateway.enabled=true \
  --set gateway.enabled=true \
  --set logs.general.level=INFO \
  --set logs.access.enabled=true \
  --set logs.access.format=json \
  --set metrics.prometheus.enabled=true \
  --set metrics.prometheus.addEntryPointsLabels=true \
  --set metrics.prometheus.addRoutersLabels=true \
  --set metrics.prometheus.addServicesLabels=true \
  --set-string service.annotations."prometheus\.io/scrape"="true" \
  --set-string service.annotations."prometheus\.io/port"="9100" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="100Mi" \
  --set resources.limits.cpu="500m" \
  --set resources.limits.memory="300Mi" \
  --wait

# =============================================================================
# 3. Create Shared Gateway Resource
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Creating Shared Gateway for All Services                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Creating Gateway API Gateway resource..."

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway
  namespace: traefik-system
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: websecure
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs: []
EOF

# =============================================================================
# 4. Verify Installation
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 4: Verifying Installation                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

echo "Waiting for LoadBalancer IP assignment..."
sleep 5

EXTERNAL_IP=$(kubectl get svc traefik -n traefik-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              TRAEFIK GATEWAY INSTALLED                                ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  • Namespace: traefik-system"
echo "  • External IP: $EXTERNAL_IP"
echo "  • HTTP Port: 80 (web)"
echo "  • HTTPS Port: 443 (websecure)"
echo "  • Metrics: :9100/metrics"
echo ""
echo "Verify with:"
echo "  kubectl get svc -n traefik-system"
echo "  curl -I http://$EXTERNAL_IP"
echo ""
echo "Next command:"
echo "  bash bootstrap/argocd/install.sh"