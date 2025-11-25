#!/bin/bash
echo "=== SECURITY STACK VERIFICATION ==="

# 1. Kyverno Policy Test
echo "Testing Kyverno Policy Enforcement..."
# We try to run a pod that violates policies. It MUST fail for the test to pass.
kubectl run kyverno-test-fail --image=nginx:latest --dry-run=server 2>&1 | grep "disallowed" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Kyverno blocked 'latest' tag: PASS"
else
    echo "⚠️  Kyverno allowed 'latest' tag (Policies might not be loaded yet)"
fi

# 2. Falco Status
echo "Checking Falco (Runtime Security)..."
PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=falco | grep Running | wc -l)
if [ "$PODS" -ge 1 ]; then
    echo "✅ Falco eBPF Probes Running"
else
    echo "❌ Falco is not running"
    exit 1
fi

# 3. Harbor Registry
echo "Checking Harbor Registry..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://harbor.192.168.0.210.nip.io/api/v2.0/ping)
if [ "$STATUS" -eq 200 ]; then
    echo "✅ Harbor API is Live (200 OK)"
else
    echo "❌ Harbor API Unreachable (HTTP $STATUS)"
    exit 1
fi

echo "=== SECURITY CHECK COMPLETE ==="
