#!/bin/bash
# =============================================================================
# Phase 4b: ArgoCD GitOps Controller Bootstrap Script
# =============================================================================
# Installs ArgoCD, the GitOps engine that watches Git repositories and
# automatically syncs the cluster state to match the desired configuration.
#
# Features:
#   - Insecure mode (TLS offloaded to Traefik)
#   - JSON logging for Loki integration
#   - Ingress for UI access
#
# Prerequisites:
#   - Traefik installed with Gateway/Ingress support
#   - kubectl and helm configured
#
# Usage: bash bootstrap/argocd/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 4b: ARGOCD GITOPS BOOTSTRAP                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding ArgoCD Helm Repository                               │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# =============================================================================
# 2. Install ArgoCD
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing ArgoCD                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Deploying ArgoCD with insecure mode (TLS offload to Traefik)..."

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.0 \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set global.logging.format=json \
  --set server.resources.requests.cpu="100m" \
  --set server.resources.requests.memory="128Mi" \
  --set server.resources.limits.cpu="500m" \
  --set server.resources.limits.memory="256Mi" \
  --set controller.resources.requests.cpu="100m" \
  --set controller.resources.requests.memory="256Mi" \
  --set controller.resources.limits.cpu="500m" \
  --set controller.resources.limits.memory="512Mi" \
  --set repoServer.resources.requests.cpu="100m" \
  --set repoServer.resources.requests.memory="128Mi" \
  --set repoServer.resources.limits.cpu="500m" \
  --set repoServer.resources.limits.memory="256Mi" \
  --wait

# =============================================================================
# 3. Create Ingress for UI Access
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Creating Ingress for ArgoCD UI                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Creating Ingress for ArgoCD..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: argocd.192.168.0.210.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

# =============================================================================
# 4. Retrieve Initial Admin Password
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 4: Retrieving Admin Credentials                                │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Wait for secret to be created
sleep 5
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "pending")

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              ARGOCD GITOPS CONTROLLER INSTALLED                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Access Information:"
echo "  • URL: http://argocd.192.168.0.210.nip.io"
echo "  • Username: admin"
echo "  • Password: $ARGOCD_PASSWORD"
echo ""
echo "Retrieve Password Later:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Verify with:"
echo "  kubectl get pods -n argocd"
echo "  argocd app list"
echo ""
echo "Next command:"
echo "  kubectl apply -f gitops/services/gitea.yaml"