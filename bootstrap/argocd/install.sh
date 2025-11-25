#!/bin/bash
set -e
echo "=== PHASE 4b: ARGOCD BOOTSTRAP ==="

# 1. Add Repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Install ArgoCD
# We use --insecure to offload TLS to Traefik
echo "Deploying ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.0 \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set global.logging.format=json \
  --wait

# 3. Expose UI via Ingress
echo "Creating Ingress Rule..."
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

echo "=== ARGOCD READY ==="
echo "URL: http://argocd.192.168.0.210.nip.io"
echo "Get Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
