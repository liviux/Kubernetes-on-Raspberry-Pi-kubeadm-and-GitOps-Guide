#!/bin/bash
# =============================================================================
# Phase 6 Advanced Observability Verification Test
# =============================================================================
# Verifies all observability components deployed in Phase 6:
#   - Loki Stack (log aggregation)
#   - Fluent Bit (log collection)
#   - OpenTelemetry (trace collection)
#   - Jaeger (trace visualization)
#   - OpenCost (cost estimation)
#   - K8sGPT (AI diagnostics)
#   - Kubeshark (traffic analysis)
#
# Prerequisites:
#   - Phase 6 components deployed
#   - kubectl configured for the cluster
#
# Usage: bash tests/05_observability_test.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║       PHASE 6: ADVANCED OBSERVABILITY VERIFICATION                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
pass() {
    echo "✅ $1"
    ((TESTS_PASSED++))
}

fail() {
    echo "❌ $1"
    ((TESTS_FAILED++))
}

warn() {
    echo "⚠️  $1"
    ((TESTS_WARNED++))
}

# -----------------------------------------------------------------------------
# Test 1: Loki Log Aggregation
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 1: Loki Log Aggregation                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

LOKI_PODS=$(kubectl get pods -n monitoring -l app=loki --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$LOKI_PODS" -ge 1 ]; then
    pass "Loki is running ($LOKI_PODS pods)"
else
    fail "Loki not running"
fi

# -----------------------------------------------------------------------------
# Test 2: Promtail Log Collection
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 2: Promtail Log Collection                                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"

PROMTAIL_PODS=$(kubectl get pods -n monitoring -l app=promtail --no-headers 2>/dev/null | grep -c "Running" || echo "0")
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$PROMTAIL_PODS" -ge "$NODE_COUNT" ]; then
    pass "Promtail running on all nodes ($PROMTAIL_PODS/$NODE_COUNT)"
else
    warn "Promtail not on all nodes ($PROMTAIL_PODS/$NODE_COUNT)"
fi

# -----------------------------------------------------------------------------
# Test 3: Fluent Bit (Alternative Collector)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 3: Fluent Bit Log Collector                                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"

FLUENTBIT_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$FLUENTBIT_PODS" -ge 1 ]; then
    pass "Fluent Bit running ($FLUENTBIT_PODS pods)"
else
    warn "Fluent Bit not running (using Promtail instead)"
fi

# -----------------------------------------------------------------------------
# Test 4: OpenTelemetry Operator
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 4: OpenTelemetry Operator                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

OTEL_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$OTEL_PODS" -ge 1 ]; then
    pass "OpenTelemetry Operator running"
else
    fail "OpenTelemetry Operator not running"
fi

# -----------------------------------------------------------------------------
# Test 5: Jaeger Tracing Backend
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 5: Jaeger Tracing Backend                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

JAEGER_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$JAEGER_PODS" -ge 1 ]; then
    pass "Jaeger is running"
    
    # Check UI accessibility
    JAEGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://jaeger.192.168.0.210.nip.io 2>/dev/null || echo "000")
    if [ "$JAEGER_STATUS" == "200" ]; then
        echo "  ✅ Jaeger UI accessible"
    else
        echo "  ⚠️  Jaeger UI not accessible (HTTP $JAEGER_STATUS)"
    fi
else
    fail "Jaeger not running"
fi

# -----------------------------------------------------------------------------
# Test 6: OpenCost
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 6: OpenCost Cost Analysis                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

OPENCOST_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=opencost --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$OPENCOST_PODS" -ge 1 ]; then
    pass "OpenCost is running"
    
    # Check UI accessibility
    OPENCOST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://opencost.192.168.0.210.nip.io 2>/dev/null || echo "000")
    if [ "$OPENCOST_STATUS" == "200" ]; then
        echo "  ✅ OpenCost UI accessible"
    else
        echo "  ⚠️  OpenCost UI not accessible (HTTP $OPENCOST_STATUS)"
    fi
else
    fail "OpenCost not running"
fi

# -----------------------------------------------------------------------------
# Test 7: K8sGPT Operator
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 7: K8sGPT AI Diagnostics                                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"

K8SGPT_PODS=$(kubectl get pods -n observability -l app.kubernetes.io/name=k8sgpt-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$K8SGPT_PODS" -ge 1 ]; then
    pass "K8sGPT Operator running"
else
    warn "K8sGPT Operator not running"
fi

# -----------------------------------------------------------------------------
# Test 8: Kubeshark Traffic Analysis
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 8: Kubeshark Traffic Analysis                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

KUBESHARK_PODS=$(kubectl get pods -n observability -l app.kubernetes.io/name=kubeshark --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$KUBESHARK_PODS" -ge 1 ]; then
    pass "Kubeshark is running ($KUBESHARK_PODS pods)"
else
    warn "Kubeshark not running (optional - high memory usage)"
fi

# -----------------------------------------------------------------------------
# Test 9: Data Flow Verification
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 9: Data Flow Verification                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

echo "  Checking Prometheus scrape targets..."
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
PF_PID=$!
sleep 3
UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
kill $PF_PID 2>/dev/null || true

if [ "$UP_TARGETS" -gt 0 ]; then
    pass "Prometheus scraping $UP_TARGETS targets"
else
    warn "Could not verify Prometheus targets"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION SUMMARY                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Tests Passed:  $TESTS_PASSED"
echo "  Tests Failed:  $TESTS_FAILED"
echo "  Warnings:      $TESTS_WARNED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "  ✅ Phase 6 Advanced Observability verification complete!"
    echo ""
    echo "Access URLs:"
    echo "  • Grafana (Logs):  http://grafana.192.168.0.210.nip.io → Explore → Loki"
    echo "  • Jaeger (Traces): http://jaeger.192.168.0.210.nip.io"
    echo "  • OpenCost:        http://opencost.192.168.0.210.nip.io"
    echo ""
    echo "Port-forward for Kubeshark:"
    echo "  kubectl port-forward -n observability svc/kubeshark-hub 8899:80"
    exit 0
else
    echo "  ❌ Some tests failed. Check component status above."
    exit 1
fi