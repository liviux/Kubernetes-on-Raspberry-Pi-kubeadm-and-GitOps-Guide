#!/bin/bash
# =============================================================================
# PHASE 7: CI/CD PIPELINE COMPREHENSIVE VERIFICATION
# =============================================================================
# Verifies all CI/CD and developer experience components:
#   - Argo Workflows (CI engine)
#   - Argo Events (Event-driven triggers)
#   - Argo Image Updater (GitOps automation)
#   - Trivy Operator (Security scanning)
#
# Prerequisites:
#   - Phase 7 components deployed via ArgoCD
#   - kubectl configured for the cluster
#   - curl available for HTTP checks
#
# Usage: bash tests/06_cicd_test.sh
# =============================================================================

set -euo pipefail

# Configuration
CLUSTER_IP="${CLUSTER_IP:-192.168.68.210}"
WORKFLOWS_URL="http://workflows.${CLUSTER_IP}.nip.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          $1"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} Test $1: $2"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────┘${NC}"
}

pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((TESTS_WARNED++))
}

info() {
    echo -e "   ${BLUE}ℹ${NC}  $1"
}

# =============================================================================
print_header "PHASE 7: CI/CD PIPELINE VERIFICATION"
# =============================================================================

# -----------------------------------------------------------------------------
# Test 1: Argo Workflows Controller
# -----------------------------------------------------------------------------
print_test "1" "Argo Workflows Controller"

WF_CONTROLLER=$(kubectl get pods -n argo-workflows \
    -l app.kubernetes.io/name=argo-workflows-controller \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$WF_CONTROLLER" -ge 1 ]; then
    pass "Argo Workflows Controller is running"
    
    # Check controller version
    WF_VERSION=$(kubectl get deployment -n argo-workflows \
        argo-workflows-workflow-controller \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | \
        cut -d: -f2 || echo "unknown")
    info "Controller version: $WF_VERSION"
else
    fail "Argo Workflows Controller is not running"
fi

# -----------------------------------------------------------------------------
# Test 2: Argo Workflows Server
# -----------------------------------------------------------------------------
print_test "2" "Argo Workflows Server & UI"

WF_SERVER=$(kubectl get pods -n argo-workflows \
    -l app.kubernetes.io/name=argo-workflows-server \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$WF_SERVER" -ge 1 ]; then
    pass "Argo Workflows Server is running"
    
    # Check UI accessibility
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WORKFLOWS_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        pass "Workflows UI accessible at $WORKFLOWS_URL"
    else
        warn "Workflows UI not accessible (HTTP $HTTP_CODE)"
    fi
else
    fail "Argo Workflows Server is not running"
fi

# -----------------------------------------------------------------------------
# Test 3: Argo Workflows Artifact Repository
# -----------------------------------------------------------------------------
print_test "3" "Argo Workflows Artifact Repository (MinIO)"

# Check if artifact repository is configured
ARTIFACT_REPO=$(kubectl get configmap -n argo-workflows \
    workflow-controller-configmap \
    -o jsonpath='{.data.artifactRepository}' 2>/dev/null || echo "")

if [ -n "$ARTIFACT_REPO" ]; then
    pass "Artifact repository configured"
    
    # Check MinIO connectivity
    MINIO_SVC=$(kubectl get svc -n storage minio --no-headers 2>/dev/null || echo "")
    if [ -n "$MINIO_SVC" ]; then
        info "MinIO service found in storage namespace"
    else
        warn "MinIO service not found - artifacts may not persist"
    fi
else
    warn "Artifact repository not configured"
fi

# -----------------------------------------------------------------------------
# Test 4: Argo Events Controller
# -----------------------------------------------------------------------------
print_test "4" "Argo Events Controller"

AE_CONTROLLER=$(kubectl get pods -n argo-events \
    -l app.kubernetes.io/name=argo-events-controller \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$AE_CONTROLLER" -ge 1 ]; then
    pass "Argo Events Controller is running"
else
    fail "Argo Events Controller is not running"
fi

# -----------------------------------------------------------------------------
# Test 5: Argo Events EventBus
# -----------------------------------------------------------------------------
print_test "5" "Argo Events EventBus (Jetstream)"

EVENTBUS=$(kubectl get eventbus -n argo-events --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$EVENTBUS" -gt 0 ]; then
    pass "EventBus configured"
    
    # Check EventBus status
    EB_STATUS=$(kubectl get eventbus -n argo-events default \
        -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null || echo "")
    if [ "$EB_STATUS" = "True" ]; then
        info "EventBus status: Deployed"
        
        # Count NATS pods
        NATS_PODS=$(kubectl get pods -n argo-events \
            -l eventbus-name=default \
            --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        info "NATS replicas running: $NATS_PODS"
    else
        warn "EventBus not fully deployed"
    fi
else
    warn "No EventBus found - event-driven pipelines won't work"
fi

# -----------------------------------------------------------------------------
# Test 6: Argo Events EventSources
# -----------------------------------------------------------------------------
print_test "6" "Argo Events EventSources"

EVENT_SOURCES=$(kubectl get eventsources -A --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$EVENT_SOURCES" -gt 0 ]; then
    pass "Found $EVENT_SOURCES EventSource(s)"
    
    # List EventSources
    echo ""
    kubectl get eventsources -A --no-headers 2>/dev/null | \
        awk '{printf "   • %-25s %-20s %s\n", $1, $2, $4}'
else
    warn "No EventSources configured yet"
    info "Create EventSources to trigger workflows from external events"
fi

# -----------------------------------------------------------------------------
# Test 7: Argo Image Updater
# -----------------------------------------------------------------------------
print_test "7" "Argo Image Updater"

IMAGE_UPDATER=$(kubectl get pods -n argocd \
    -l app.kubernetes.io/name=argocd-image-updater \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$IMAGE_UPDATER" -ge 1 ]; then
    pass "Argo Image Updater is running"
    
    # Check recent logs for Harbor connectivity
    HARBOR_ERROR=$(kubectl logs -n argocd \
        -l app.kubernetes.io/name=argocd-image-updater \
        --tail=50 2>/dev/null | grep -i "error.*harbor" || echo "")
    
    if [ -z "$HARBOR_ERROR" ]; then
        info "No Harbor connectivity errors in recent logs"
    else
        warn "Harbor connectivity issues detected in logs"
    fi
    
    # List watched applications
    WATCHED_APPS=$(kubectl get applications -n argocd \
        -o jsonpath='{range .items[*]}{.metadata.annotations.argocd-image-updater\.argoproj\.io/image-list}{"\n"}{end}' 2>/dev/null | \
        grep -v "^$" | wc -l || echo "0")
    info "Applications with image update annotations: $WATCHED_APPS"
else
    fail "Argo Image Updater is not running"
fi

# -----------------------------------------------------------------------------
# Test 8: Trivy Operator
# -----------------------------------------------------------------------------
print_test "8" "Trivy Operator"

TRIVY_OPERATOR=$(kubectl get pods -n trivy-system \
    -l app.kubernetes.io/name=trivy-operator \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$TRIVY_OPERATOR" -ge 1 ]; then
    pass "Trivy Operator is running"
else
    # Try alternate namespace
    TRIVY_OPERATOR=$(kubectl get pods -n security \
        -l app.kubernetes.io/name=trivy-operator \
        --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$TRIVY_OPERATOR" -ge 1 ]; then
        pass "Trivy Operator is running (in security namespace)"
    else
        fail "Trivy Operator is not running"
    fi
fi

# -----------------------------------------------------------------------------
# Test 9: Trivy Vulnerability Reports
# -----------------------------------------------------------------------------
print_test "9" "Trivy Vulnerability Reports"

VULN_REPORTS=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$VULN_REPORTS" -gt 0 ]; then
    pass "Trivy is generating vulnerability reports ($VULN_REPORTS found)"
    
    # Count by severity
    CRITICAL=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | \
        jq '[.items[].report.summary.criticalCount // 0] | add' || echo "0")
    HIGH=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | \
        jq '[.items[].report.summary.highCount // 0] | add' || echo "0")
    
    info "Critical vulnerabilities: $CRITICAL"
    info "High vulnerabilities: $HIGH"
    
    if [ "$CRITICAL" -gt 0 ]; then
        warn "Critical vulnerabilities detected - review reports!"
    fi
else
    warn "No vulnerability reports yet (Trivy may still be scanning)"
    info "Reports will appear as pods are scanned"
fi

# -----------------------------------------------------------------------------
# Test 10: ArgoCD Application Health (CI/CD Apps)
# -----------------------------------------------------------------------------
print_test "10" "ArgoCD CI/CD Application Health"

CICD_APPS=("argo-workflows" "argo-events" "argo-image-updater" "trivy-operator")
HEALTHY_COUNT=0

for app in "${CICD_APPS[@]}"; do
    STATUS=$(kubectl get application -n argocd "$app" \
        -o jsonpath='{.status.health.status}' 2>/dev/null || echo "NotFound")
    SYNC=$(kubectl get application -n argocd "$app" \
        -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
    
    if [ "$STATUS" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
        info "✓ $app: Healthy/Synced"
        ((HEALTHY_COUNT++))
    elif [ "$STATUS" = "NotFound" ]; then
        info "○ $app: Not deployed"
    else
        warn "! $app: $STATUS/$SYNC"
    fi
done

if [ "$HEALTHY_COUNT" -ge 2 ]; then
    pass "Core CI/CD applications healthy ($HEALTHY_COUNT/${#CICD_APPS[@]})"
else
    warn "Some CI/CD applications not healthy"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                    VERIFICATION SUMMARY                                "
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "   Tests Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "   Warnings:      ${YELLOW}$TESTS_WARNED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "   ${GREEN}✅ All Phase 7 CI/CD tests passed!${NC}"
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                       ACCESS URLS                                     "
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "   • Argo Workflows:  $WORKFLOWS_URL"
    echo "   • ArgoCD:          http://argocd.${CLUSTER_IP}.nip.io"
    echo "   • Harbor:          https://harbor.${CLUSTER_IP}.nip.io"
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                       NEXT STEPS                                      "
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "   1. Create a WorkflowTemplate for your build pipeline"
    echo "   2. Configure Gitea webhook to trigger Argo Events"
    echo "   3. Annotate ArgoCD Applications for Image Updater"
    echo "   4. Review Trivy vulnerability reports"
    echo "   5. Set up Skaffold for local development"
    echo ""
    exit 0
else
    echo -e "   ${RED}❌ Some tests failed. Check component status above.${NC}"
    echo ""
    echo "   Troubleshooting:"
    echo "   • Check ArgoCD sync status: kubectl get applications -n argocd"
    echo "   • View pod logs: kubectl logs -n <namespace> -l app.kubernetes.io/name=<component>"
    echo "   • Verify secrets exist: kubectl get secrets -n argocd"
    echo ""
    exit 1
fi