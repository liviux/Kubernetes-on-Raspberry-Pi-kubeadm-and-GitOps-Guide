#!/bin/bash
# =============================================================================
# Phase 4 GitOps & CI/CD Pipeline Verification Test
# =============================================================================
# Verifies the GitOps and CI/CD components:
#   - ArgoCD GitOps controller
#   - Gitea Git server
#   - ArgoCD Applications health
#   - Optional: Argo Workflows, Argo Events
#
# Prerequisites:
#   - Phase 4 components deployed
#   - kubectl configured for the cluster
#
# Usage: bash tests/06_cicd_test.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║          PHASE 4: GITOPS & CI/CD VERIFICATION                         ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Test 1: ArgoCD Server
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 1: ArgoCD Server Status                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

ARGOCD_SERVER=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGOCD_SERVER" -ge 1 ]; then
    echo "✅ ArgoCD Server is running"
    ((TESTS_PASSED++))
else
    echo "❌ ArgoCD Server is not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 2: ArgoCD Applications
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 2: ArgoCD Applications Health                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

TOTAL_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
HEALTHY_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Healthy" || echo "0")
SYNCED_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Synced" || echo "0")

echo "  Total Applications: $TOTAL_APPS"
echo "  Healthy: $HEALTHY_APPS"
echo "  Synced: $SYNCED_APPS"

if [ "$TOTAL_APPS" -gt 0 ]; then
    echo "✅ ArgoCD managing $TOTAL_APPS applications"
    ((TESTS_PASSED++))
    
    # List applications
    echo ""
    echo "  Applications:"
    kubectl get applications -n argocd --no-headers 2>/dev/null | awk '{printf "    • %-25s %s / %s\n", $1, $2, $3}'
else
    echo "⚠️  No ArgoCD applications deployed yet"
fi

# -----------------------------------------------------------------------------
# Test 3: Gitea Git Server
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 3: Gitea Git Server Status                                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"

GITEA_PODS=$(kubectl get pods -n gitea -l app.kubernetes.io/name=gitea --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$GITEA_PODS" -ge 1 ]; then
    echo "✅ Gitea is running"
    ((TESTS_PASSED++))
    
    # Check SSH service
    GITEA_SSH=$(kubectl get svc -n gitea gitea-ssh -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$GITEA_SSH" ]; then
        echo "  ✅ SSH LoadBalancer: $GITEA_SSH:2222"
    fi
else
    echo "❌ Gitea is not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 4: Gitea Database (PostgreSQL)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 4: Gitea PostgreSQL Database                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

POSTGRES_PODS=$(kubectl get pods -n gitea -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$POSTGRES_PODS" -ge 1 ]; then
    echo "✅ PostgreSQL database is running"
    ((TESTS_PASSED++))
else
    echo "❌ PostgreSQL is not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 5: Service Accessibility
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 5: Service Endpoint Accessibility                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Test Gitea HTTP
GITEA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://gitea.192.168.0.210.nip.io 2>/dev/null || echo "000")
if [ "$GITEA_STATUS" == "200" ] || [ "$GITEA_STATUS" == "302" ]; then
    echo "✅ Gitea UI accessible (HTTP $GITEA_STATUS)"
    ((TESTS_PASSED++))
else
    echo "❌ Gitea UI not accessible (HTTP $GITEA_STATUS)"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 6: Optional CI/CD Components (Argo Workflows)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 6: Optional CI/CD Components                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Argo Workflows (optional)
ARGO_WF=$(kubectl get pods -n argo-workflows -l app.kubernetes.io/name=argo-workflows-controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGO_WF" -ge 1 ]; then
    echo "✅ Argo Workflows Controller is running (optional)"
else
    echo "ℹ️  Argo Workflows not deployed (optional component)"
fi

# Argo Events (optional)
ARGO_EV=$(kubectl get pods -n argo-events -l app.kubernetes.io/name=argo-events-controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGO_EV" -ge 1 ]; then
    echo "✅ Argo Events Controller is running (optional)"
else
    echo "ℹ️  Argo Events not deployed (optional component)"
fi

# Trivy Operator (optional)
TRIVY=$(kubectl get pods -n trivy-system -l app.kubernetes.io/name=trivy-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$TRIVY" -ge 1 ]; then
    echo "✅ Trivy Operator is running (optional)"
    REPORTS=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l || echo "0")
    echo "  Security reports generated: $REPORTS"
else
    echo "ℹ️  Trivy Operator not deployed (optional component)"
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
    echo "  ✅ All Phase 4 GitOps/CI-CD tests passed!"
    echo ""
    echo "Access URLs:"
    echo "  • ArgoCD: http://argocd.192.168.0.210.nip.io"
    echo "  • Gitea:  http://gitea.192.168.0.210.nip.io"
    echo ""
    echo "Next Steps:"
    echo "  1. Create admin account in Gitea"
    echo "  2. Create 'home-cluster' repository"
    echo "  3. Push gitops/ folder to Gitea"
    exit 0
else
    echo "  ❌ Some tests failed. Check component status above."
    exit 1
fi