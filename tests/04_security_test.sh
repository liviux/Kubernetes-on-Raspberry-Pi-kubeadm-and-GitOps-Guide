#!/bin/bash
# =============================================================================
# Security Stack Verification Test
# =============================================================================
# Tests the security and management components deployed in Phase 5:
#   - Kyverno (Policy Enforcement)
#   - Falco (Runtime Security)
#   - Harbor (Container Registry)
#   - MinIO (S3 Storage)
#   - Velero (Backup)
#   - Reloader (ConfigMap/Secret reload)
#   - Descheduler (Workload balancing)
#
# Prerequisites:
#   - Phase 5 applications synced and healthy
#   - kubectl configured for cluster access
#   - curl available for HTTP tests
#
# Usage:
#   chmod +x tests/04_security_test.sh
#   ./tests/04_security_test.sh
#
# Expected Output:
#   All checks should show ✅ for a healthy security stack
# =============================================================================

set -e  # Exit on first error (comment out for full report)

echo "=============================================="
echo "   SECURITY & MANAGEMENT STACK VERIFICATION"
echo "=============================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
pass() {
    echo "✅ $1"
    ((PASS_COUNT++))
}

fail() {
    echo "❌ $1"
    ((FAIL_COUNT++))
}

warn() {
    echo "⚠️  $1"
    ((WARN_COUNT++))
}

# -----------------------------------------------------------------------------
# 1. Kyverno Policy Enforcement
# -----------------------------------------------------------------------------
echo "📋 Testing Kyverno Policy Enforcement..."
echo "   Attempting to create pod with 'latest' tag (should be blocked)..."

# Try to run a pod with :latest tag - should be blocked by policy
KYVERNO_TEST=$(kubectl run kyverno-test-fail --image=nginx:latest --dry-run=server 2>&1 || true)
if echo "$KYVERNO_TEST" | grep -q "disallow\|blocked\|denied"; then
    pass "Kyverno blocked 'latest' tag policy violation"
else
    warn "Kyverno did not block 'latest' tag (policy may not be deployed yet)"
fi

# Check Kyverno admission controller is running
KYVERNO_PODS=$(kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$KYVERNO_PODS" -ge 1 ]; then
    pass "Kyverno admission controller running ($KYVERNO_PODS pods)"
else
    fail "Kyverno admission controller not running"
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Falco Runtime Security
# -----------------------------------------------------------------------------
echo "🛡️  Checking Falco Runtime Security..."

# Check Falco pods are running
FALCO_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=falco --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$FALCO_PODS" -ge 1 ]; then
    pass "Falco eBPF probes running ($FALCO_PODS pods)"
else
    fail "Falco pods not running"
fi

# Check Falcosidekick is running
SIDEKICK_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=falcosidekick --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$SIDEKICK_PODS" -ge 1 ]; then
    pass "Falcosidekick alert forwarder running"
else
    warn "Falcosidekick not running (alerts may not be forwarded)"
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Harbor Container Registry
# -----------------------------------------------------------------------------
echo "🐋 Checking Harbor Container Registry..."

# Check Harbor API endpoint
HARBOR_URL="http://harbor.192.168.0.210.nip.io"
HARBOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$HARBOR_URL/api/v2.0/ping" 2>/dev/null || echo 000)
if [ "$HARBOR_STATUS" -eq 200 ]; then
    pass "Harbor API responding (HTTP 200)"
else
    fail "Harbor API unreachable (HTTP $HARBOR_STATUS)"
fi

# Check Harbor core pods
HARBOR_PODS=$(kubectl get pods -n harbor -l app=harbor --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$HARBOR_PODS" -ge 1 ]; then
    pass "Harbor core components running ($HARBOR_PODS pods)"
else
    warn "Harbor pods not in Running state"
fi

echo ""

# -----------------------------------------------------------------------------
# 4. MinIO S3 Storage
# -----------------------------------------------------------------------------
echo "💾 Checking MinIO S3 Storage..."

# Check MinIO pod
MINIO_PODS=$(kubectl get pods -n storage -l app=minio --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$MINIO_PODS" -ge 1 ]; then
    pass "MinIO pod running"
else
    fail "MinIO pod not running"
fi

# Check MinIO console endpoint
MINIO_URL="http://minio-console.192.168.0.210.nip.io"
MINIO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$MINIO_URL" 2>/dev/null || echo 000)
if [ "$MINIO_STATUS" -eq 200 ] || [ "$MINIO_STATUS" -eq 302 ]; then
    pass "MinIO console accessible"
else
    warn "MinIO console unreachable (HTTP $MINIO_STATUS)"
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Velero Backup
# -----------------------------------------------------------------------------
echo "📦 Checking Velero Backup System..."

# Check Velero deployment
VELERO_PODS=$(kubectl get pods -n velero -l app.kubernetes.io/name=velero --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$VELERO_PODS" -ge 1 ]; then
    pass "Velero backup controller running"
else
    fail "Velero not running"
fi

# Check backup storage location status
BSL_STATUS=$(kubectl get backupstoragelocation -n velero -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
if [ "$BSL_STATUS" = "Available" ]; then
    pass "Velero backup storage location available"
else
    warn "Velero backup storage status: $BSL_STATUS"
fi

echo ""

# -----------------------------------------------------------------------------
# 6. Reloader
# -----------------------------------------------------------------------------
echo "🔄 Checking Reloader..."

RELOADER_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=reloader --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$RELOADER_PODS" -ge 1 ]; then
    pass "Reloader running (ConfigMap/Secret watch active)"
else
    fail "Reloader not running"
fi

echo ""

# -----------------------------------------------------------------------------
# 7. Descheduler
# -----------------------------------------------------------------------------
echo "⚖️  Checking Descheduler..."

# Check for descheduler CronJob
DESCHEDULER_CRONJOB=$(kubectl get cronjob -n kube-system descheduler --no-headers 2>/dev/null | wc -l || echo 0)
if [ "$DESCHEDULER_CRONJOB" -ge 1 ]; then
    pass "Descheduler CronJob configured"
else
    warn "Descheduler CronJob not found (may use different deployment method)"
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=============================================="
echo "   SECURITY STACK TEST SUMMARY"
echo "=============================================="
echo ""
echo "   ✅ Passed:   $PASS_COUNT"
echo "   ⚠️  Warnings: $WARN_COUNT"
echo "   ❌ Failed:   $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "❌ Some critical tests failed. Check the components above."
    exit 1
else
    echo "✅ Security stack verification complete!"
    exit 0
fi
