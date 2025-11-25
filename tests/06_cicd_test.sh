#!/bin/bash
echo "=== CI/CD PIPELINE VERIFICATION ==="

# 1. Argo Workflows Status
echo "Checking Argo Workflows Controller..."
kubectl get pods -n argo-workflows -l app.kubernetes.io/name=argo-workflows-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Argo Workflows Controller is Running"
else
    echo "❌ Argo Workflows is down"
    exit 1
fi

# 2. Argo Events Status
echo "Checking Argo Events..."
kubectl get pods -n argo-events -l app.kubernetes.io/name=argo-events-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Argo Events Controller is Running"
else
    echo "❌ Argo Events is down"
    exit 1
fi

# 3. Trivy Scanning
echo "Checking Security Scans..."
REPORTS=$(kubectl get vulnerabilityreports -A | wc -l)
if [ "$REPORTS" -gt 0 ]; then
    echo "✅ Trivy is generating reports ($REPORTS found)"
else
    echo "⚠️  No Vulnerability Reports found yet (Trivy might still be scanning)"
fi

echo "=== CI/CD CHECK COMPLETE ==="
