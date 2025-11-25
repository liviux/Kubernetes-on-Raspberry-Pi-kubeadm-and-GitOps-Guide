#!/bin/bash
echo "=== CI/CD PIPELINE VERIFICATION ==="

# 1. Jenkins Status
echo "Checking Jenkins Controller..."
kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Jenkins Controller is Running"
else
    echo "❌ Jenkins is down"
    exit 1
fi

# 2. Trivy Scanning
echo "Checking Security Scans..."
REPORTS=$(kubectl get vulnerabilityreports -A | wc -l)
if [ "$REPORTS" -gt 0 ]; then
    echo "✅ Trivy is generating reports ($REPORTS found)"
else
    echo "⚠️  No Vulnerability Reports found yet (Trivy might still be scanning)"
fi

echo "=== CI/CD CHECK COMPLETE ==="
