#!/bin/bash
set -e
echo "=== PHASE 4a: TRAEFIK BOOTSTRAP ==="

# 1. Add Repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 2. Install Traefik v3
# We use --set-string for annotations to avoid Helm integer parsing errors on port "9100"
echo "Deploying Traefik..."
helm upgrade --install traefik traefik/traefik \
  --namespace traefik-system \
  --create-namespace \
  --version 37.3.0 \
  --set service.type=LoadBalancer \
  --set loadBalancerIP=192.168.0.210 \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set providers.kubernetesCRD.allowCrossNamespace=true \
  --set logs.general.level=INFO \
  --set logs.access.enabled=true \
  --set logs.access.format=json \
  --set metrics.prometheus.enabled=true \
  --set metrics.prometheus.addEntryPointsLabels=true \
  --set metrics.prometheus.addRoutersLabels=true \
  --set-string service.annotations."prometheus\.io/scrape"="true" \
  --set-string service.annotations."prometheus\.io/port"="9100" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="100Mi" \
  --set resources.limits.cpu="500m" \
  --set resources.limits.memory="300Mi" \
  --wait

echo "=== TRAEFIK INSTALLED ==="
echo "External IP should be assigned shortly."
