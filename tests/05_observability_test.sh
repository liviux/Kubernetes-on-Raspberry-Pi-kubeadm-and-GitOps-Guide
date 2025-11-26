#!/bin/bash
# =============================================================================
# Phase 4 Observability Stack Verification Test
# =============================================================================
# Verifies the observability components installed in Phase 4:
#   - Prometheus metrics collection
#   - Grafana dashboards
#   - Alertmanager
#   - Service accessibility
#
# Prerequisites:
#   - Phase 4 components deployed (Traefik, ArgoCD, Observability Stack)
#   - kubectl configured for the cluster
#
# Usage: bash tests/05_observability_test.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║          PHASE 4: OBSERVABILITY STACK VERIFICATION                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Test 1: Traefik Service
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 1: Traefik LoadBalancer Service                                │"
echo "└─────────────────────────────────────────────────────────────────────┘"

TRAEFIK_IP=$(kubectl get svc traefik -n traefik-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ "$TRAEFIK_IP" == "192.168.0.210" ]; then
    echo "✅ Traefik has correct LoadBalancer IP: $TRAEFIK_IP"
    ((TESTS_PASSED++))
else
    echo "❌ Traefik IP mismatch. Expected: 192.168.0.210, Got: $TRAEFIK_IP"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 2: ArgoCD Application Status
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 2: ArgoCD Application Health                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGOCD_PODS" -ge 3 ]; then
    echo "✅ ArgoCD has $ARGOCD_PODS running pods"
    ((TESTS_PASSED++))
else
    echo "❌ ArgoCD pods not healthy. Running: $ARGOCD_PODS (expected >= 3)"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 3: Prometheus Metrics Collection
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 3: Prometheus Metrics Collection                               │"
echo "└─────────────────────────────────────────────────────────────────────┘"

PROM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$PROM_PODS" -ge 1 ]; then
    echo "✅ Prometheus is running ($PROM_PODS pods)"
    ((TESTS_PASSED++))
    
    # Check targets via port-forward
    echo "  Checking scrape targets..."
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
    kill $PF_PID 2>/dev/null || true
    
    if [ "$UP_TARGETS" -gt 0 ]; then
        echo "  ✅ Prometheus scraping $UP_TARGETS targets"
    else
        echo "  ⚠️  Could not verify targets (port-forward may have failed)"
    fi
else
    echo "❌ Prometheus not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 4: Grafana Dashboards
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 4: Grafana Dashboard Service                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

GRAFANA_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$GRAFANA_PODS" -ge 1 ]; then
    echo "✅ Grafana is running"
    ((TESTS_PASSED++))
else
    echo "❌ Grafana not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 5: Alertmanager
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 5: Alertmanager Service                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

ALERTMGR_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ALERTMGR_PODS" -ge 1 ]; then
    echo "✅ Alertmanager is running"
    ((TESTS_PASSED++))
else
    echo "❌ Alertmanager not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 6: Service Endpoints Reachable
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 6: Service Endpoint Accessibility                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Test ArgoCD UI
ARGOCD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://argocd.192.168.0.210.nip.io 2>/dev/null || echo "000")
if [ "$ARGOCD_STATUS" == "200" ] || [ "$ARGOCD_STATUS" == "307" ]; then
    echo "✅ ArgoCD UI accessible (HTTP $ARGOCD_STATUS)"
    ((TESTS_PASSED++))
else
    echo "❌ ArgoCD UI not accessible (HTTP $ARGOCD_STATUS)"
    ((TESTS_FAILED++))
fi

# Test Grafana UI
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://grafana.192.168.0.210.nip.io 2>/dev/null || echo "000")
if [ "$GRAFANA_STATUS" == "200" ] || [ "$GRAFANA_STATUS" == "302" ]; then
    echo "✅ Grafana UI accessible (HTTP $GRAFANA_STATUS)"
    ((TESTS_PASSED++))
else
    echo "❌ Grafana UI not accessible (HTTP $GRAFANA_STATUS)"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION SUMMARY                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "  ✅ All Phase 4 observability tests passed!"
    echo ""
    echo "Access URLs:"
    echo "  • ArgoCD:  http://argocd.192.168.0.210.nip.io"
    echo "  • Grafana: http://grafana.192.168.0.210.nip.io"
    echo "  • Gitea:   http://gitea.192.168.0.210.nip.io"
    exit 0
else
    echo "  ❌ Some tests failed. Check component status above."
    exit 1
fi