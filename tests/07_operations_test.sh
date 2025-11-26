#!/bin/bash
# ============================================================================
# KUBERNETES CLUSTER OPERATIONS & HEALTH CHECK
# ============================================================================
# Description: Comprehensive cluster health verification for Day 2 operations
# Usage:       ./tests/07_operations_test.sh
# Schedule:    Run daily via cron or after any cluster changes
#
# Exit Codes:
#   0 - All checks passed
#   1 - One or more checks failed
#   2 - Warnings detected (non-critical)
#
# Dependencies:
#   - kubectl configured and accessible
#   - cilium CLI (optional but recommended)
#   - argocd CLI (optional)
#   - velero CLI (optional)
#   - jq for JSON parsing
#
# Author: Kubernetes on Raspberry Pi Guide
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/operations_test_$(date +%Y%m%d_%H%M%S).log"

# Thresholds
CPU_WARN_THRESHOLD=80
MEMORY_WARN_THRESHOLD=85
DISK_WARN_THRESHOLD=80
BACKUP_MAX_AGE_HOURS=48

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0
SKIPPED=0
TOTAL=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

check_pass() {
    ((PASSED++))
    ((TOTAL++))
    log "${GREEN}✓ PASS${NC}: $1"
}

check_fail() {
    ((FAILED++))
    ((TOTAL++))
    log "${RED}✗ FAIL${NC}: $1"
}

check_warn() {
    ((WARNINGS++))
    ((TOTAL++))
    log "${YELLOW}⚠ WARN${NC}: $1"
}

check_skip() {
    ((SKIPPED++))
    ((TOTAL++))
    log "${BLUE}○ SKIP${NC}: $1"
}

section_header() {
    log ""
    log "${CYAN}[$1] $2${NC}"
    log "────────────────────────────────────────────────────────────────"
}

command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
preflight_checks() {
    log "╔══════════════════════════════════════════════════════════════════════╗"
    log "║           KUBERNETES CLUSTER OPERATIONS HEALTH CHECK                 ║"
    log "║                      $(date '+%Y-%m-%d %H:%M:%S')                              ║"
    log "╚══════════════════════════════════════════════════════════════════════╝"
    log ""
    log "Log file: $LOG_FILE"
    
    # Check kubectl
    if ! command_exists kubectl; then
        log "${RED}ERROR: kubectl not found. Cannot proceed.${NC}"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log "${RED}ERROR: Cannot connect to Kubernetes cluster.${NC}"
        exit 1
    fi
}

# ============================================================================
# TEST 1: NODE STATUS
# ============================================================================
test_node_status() {
    section_header "1/10" "NODE STATUS"
    
    local not_ready
    not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -cv " Ready" || echo "0")
    
    if [ "$not_ready" -eq 0 ]; then
        check_pass "All nodes are Ready"
        kubectl get nodes -o wide 2>/dev/null | head -10 | tee -a "$LOG_FILE"
    else
        check_fail "$not_ready node(s) not in Ready state"
        kubectl get nodes 2>/dev/null | grep -v " Ready" | tee -a "$LOG_FILE"
    fi
    
    # Check node ages
    log ""
    log "Node Ages:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null | tee -a "$LOG_FILE"
}

# ============================================================================
# TEST 2: SYSTEM PODS
# ============================================================================
test_system_pods() {
    section_header "2/10" "SYSTEM PODS (kube-system)"
    
    local failed_pods
    failed_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cvE "Running|Completed" || echo "0")
    
    if [ "$failed_pods" -eq 0 ]; then
        check_pass "All kube-system pods are healthy"
    else
        check_fail "$failed_pods kube-system pod(s) unhealthy"
        kubectl get pods -n kube-system 2>/dev/null | grep -vE "Running|Completed" | tee -a "$LOG_FILE"
    fi
    
    # Check for pod restarts
    local high_restarts
    high_restarts=$(kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null | awk '$2 > 10 {print}' | wc -l)
    
    if [ "$high_restarts" -gt 0 ]; then
        check_warn "$high_restarts pod(s) with high restart count (>10)"
    fi
}

# ============================================================================
# TEST 3: CILIUM CNI
# ============================================================================
test_cilium() {
    section_header "3/10" "CILIUM CNI STATUS"
    
    if ! command_exists cilium; then
        check_skip "Cilium CLI not installed"
        return
    fi
    
    if cilium status --wait=false 2>/dev/null | grep -q "OK"; then
        check_pass "Cilium is healthy"
    else
        check_fail "Cilium has issues"
        cilium status 2>/dev/null | head -20 | tee -a "$LOG_FILE"
    fi
    
    # Check Cilium agent pods
    local cilium_pods
    cilium_pods=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
    
    if [ "$cilium_pods" -eq 0 ]; then
        check_pass "All Cilium agent pods running"
    else
        check_warn "$cilium_pods Cilium agent pod(s) not running"
    fi
}

# ============================================================================
# TEST 4: STORAGE (LONGHORN)
# ============================================================================
test_storage() {
    section_header "4/10" "STORAGE (Longhorn)"
    
    # Check if Longhorn namespace exists
    if ! kubectl get namespace longhorn-system &> /dev/null; then
        check_skip "Longhorn namespace not found"
        return
    fi
    
    # Check Longhorn pods
    local lh_pods
    lh_pods=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -cvE "Running|Completed" || echo "0")
    
    if [ "$lh_pods" -eq 0 ]; then
        check_pass "All Longhorn pods are healthy"
    else
        check_warn "$lh_pods Longhorn pod(s) unhealthy"
        kubectl get pods -n longhorn-system 2>/dev/null | grep -vE "Running|Completed" | tee -a "$LOG_FILE"
    fi
    
    # Check PVC status
    local pending_pvc
    pending_pvc=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -ci "pending" || echo "0")
    
    if [ "$pending_pvc" -eq 0 ]; then
        check_pass "No pending PVCs"
    else
        check_warn "$pending_pvc PVC(s) in Pending state"
        kubectl get pvc -A 2>/dev/null | grep -i pending | tee -a "$LOG_FILE"
    fi
    
    # Check volume health
    local degraded_volumes
    degraded_volumes=$(kubectl get volumes.longhorn.io -n longhorn-system -o json 2>/dev/null | jq -r '.items[] | select(.status.state != "attached" and .status.state != "detached") | .metadata.name' | wc -l || echo "0")
    
    if [ "$degraded_volumes" -eq 0 ]; then
        check_pass "All Longhorn volumes healthy"
    else
        check_warn "$degraded_volumes volume(s) in degraded state"
    fi
}

# ============================================================================
# TEST 5: ARGOCD
# ============================================================================
test_argocd() {
    section_header "5/10" "ARGOCD STATUS"
    
    # Check if ArgoCD namespace exists
    if ! kubectl get namespace argocd &> /dev/null; then
        check_skip "ArgoCD namespace not found"
        return
    fi
    
    # Check ArgoCD pods
    local argo_pods
    argo_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
    
    if [ "$argo_pods" -eq 0 ]; then
        check_pass "All ArgoCD pods are healthy"
    else
        check_fail "$argo_pods ArgoCD pod(s) unhealthy"
        kubectl get pods -n argocd 2>/dev/null | grep -v "Running" | tee -a "$LOG_FILE"
    fi
    
    # Check app sync status (if argocd CLI available)
    if command_exists argocd; then
        local out_of_sync
        out_of_sync=$(argocd app list -o json 2>/dev/null | jq -r '.[] | select(.status.sync.status != "Synced") | .metadata.name' | wc -l || echo "0")
        
        if [ "$out_of_sync" -eq 0 ]; then
            check_pass "All ArgoCD applications are synced"
        else
            check_warn "$out_of_sync application(s) out of sync"
            argocd app list 2>/dev/null | grep -v "Synced" | tee -a "$LOG_FILE"
        fi
    else
        check_skip "ArgoCD CLI not installed - cannot check app sync status"
    fi
}

# ============================================================================
# TEST 6: CERTIFICATES
# ============================================================================
test_certificates() {
    section_header "6/10" "CERTIFICATES (cert-manager)"
    
    # Check if cert-manager exists
    if ! kubectl get namespace cert-manager &> /dev/null; then
        check_skip "cert-manager namespace not found"
        return
    fi
    
    # Check cert-manager pods
    local cm_pods
    cm_pods=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
    
    if [ "$cm_pods" -eq 0 ]; then
        check_pass "cert-manager pods are healthy"
    else
        check_warn "$cm_pods cert-manager pod(s) unhealthy"
    fi
    
    # Check certificate status
    local cert_issues
    cert_issues=$(kubectl get certificates -A -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True")) | .metadata.name' | wc -l || echo "0")
    
    if [ "$cert_issues" -eq 0 ]; then
        check_pass "All certificates are valid"
    else
        check_warn "$cert_issues certificate(s) have issues"
        kubectl get certificates -A 2>/dev/null | tee -a "$LOG_FILE"
    fi
    
    # Check for expiring certificates (within 7 days)
    log ""
    log "Certificate Expiry Status:"
    kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.notAfter}{"\n"}{end}' 2>/dev/null | tee -a "$LOG_FILE"
}

# ============================================================================
# TEST 7: RESOURCE UTILIZATION
# ============================================================================
test_resources() {
    section_header "7/10" "RESOURCE UTILIZATION"
    
    # Check if metrics-server is available
    if ! kubectl top nodes &> /dev/null; then
        check_skip "Metrics server not available"
        return
    fi
    
    log "Node Resources:"
    kubectl top nodes 2>/dev/null | tee -a "$LOG_FILE"
    
    # Check for high CPU usage
    local high_cpu
    high_cpu=$(kubectl top nodes --no-headers 2>/dev/null | awk '{gsub(/%/,"",$3); if($3 > '"$CPU_WARN_THRESHOLD"') print $1}' | wc -l)
    
    if [ "$high_cpu" -eq 0 ]; then
        check_pass "CPU utilization is normal (<${CPU_WARN_THRESHOLD}%)"
    else
        check_warn "$high_cpu node(s) with high CPU (>${CPU_WARN_THRESHOLD}%)"
    fi
    
    # Check for high memory usage
    local high_mem
    high_mem=$(kubectl top nodes --no-headers 2>/dev/null | awk '{gsub(/%/,"",$5); if($5 > '"$MEMORY_WARN_THRESHOLD"') print $1}' | wc -l)
    
    if [ "$high_mem" -eq 0 ]; then
        check_pass "Memory utilization is normal (<${MEMORY_WARN_THRESHOLD}%)"
    else
        check_warn "$high_mem node(s) with high memory (>${MEMORY_WARN_THRESHOLD}%)"
    fi
    
    # Top memory-consuming pods
    log ""
    log "Top 5 Memory-Consuming Pods:"
    kubectl top pods -A --sort-by=memory 2>/dev/null | head -6 | tee -a "$LOG_FILE"
}

# ============================================================================
# TEST 8: VELERO BACKUP
# ============================================================================
test_velero() {
    section_header "8/10" "VELERO BACKUP STATUS"
    
    # Check if Velero namespace exists
    if ! kubectl get namespace velero &> /dev/null; then
        check_skip "Velero namespace not found"
        return
    fi
    
    # Check Velero pods
    local velero_pods
    velero_pods=$(kubectl get pods -n velero --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$velero_pods" -gt 0 ]; then
        check_pass "Velero is running"
    else
        check_fail "Velero is not running"
        return
    fi
    
    if ! command_exists velero; then
        check_skip "Velero CLI not installed - cannot check backup status"
        return
    fi
    
    # Check for failed backups
    local failed_backups
    failed_backups=$(velero backup get -o json 2>/dev/null | jq -r '.items[] | select(.status.phase=="Failed") | .metadata.name' | wc -l || echo "0")
    
    if [ "$failed_backups" -eq 0 ]; then
        check_pass "No failed backups"
    else
        check_warn "$failed_backups backup(s) failed"
        velero backup get 2>/dev/null | grep Failed | tee -a "$LOG_FILE"
    fi
    
    # Check last successful backup age
    local last_backup_time
    last_backup_time=$(velero backup get -o json 2>/dev/null | jq -r '.items | map(select(.status.phase=="Completed")) | sort_by(.status.completionTimestamp) | last | .status.completionTimestamp // empty')
    
    if [ -n "$last_backup_time" ]; then
        local backup_age_hours
        backup_age_hours=$(( ($(date +%s) - $(date -d "$last_backup_time" +%s 2>/dev/null || echo $(date +%s))) / 3600 ))
        
        if [ "$backup_age_hours" -lt "$BACKUP_MAX_AGE_HOURS" ]; then
            check_pass "Last backup is recent (${backup_age_hours}h ago)"
        else
            check_warn "Last backup is old (${backup_age_hours}h ago, threshold: ${BACKUP_MAX_AGE_HOURS}h)"
        fi
    else
        check_warn "No completed backups found"
    fi
}

# ============================================================================
# TEST 9: SECURITY CHECKS
# ============================================================================
test_security() {
    section_header "9/10" "SECURITY STATUS"
    
    # Check for pods running as root
    local root_pods
    root_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0 or .spec.securityContext?.runAsUser == 0) | .metadata.namespace + "/" + .metadata.name' | wc -l || echo "0")
    
    if [ "$root_pods" -lt 5 ]; then
        check_pass "Few pods running as root ($root_pods system pods)"
    else
        check_warn "$root_pods pods running as root user"
    fi
    
    # Check for privileged containers
    local privileged
    privileged=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | .metadata.namespace + "/" + .metadata.name' | wc -l || echo "0")
    
    if [ "$privileged" -lt 10 ]; then
        check_pass "Limited privileged containers ($privileged)"
    else
        check_warn "$privileged privileged containers found"
    fi
    
    # Check Kyverno (if installed)
    if kubectl get namespace kyverno &> /dev/null; then
        local kyverno_pods
        kyverno_pods=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
        
        if [ "$kyverno_pods" -eq 0 ]; then
            check_pass "Kyverno policy engine is healthy"
        else
            check_warn "Kyverno has unhealthy pods"
        fi
    fi
    
    # Check Trivy (if installed)
    if kubectl get namespace trivy-system &> /dev/null; then
        local trivy_pods
        trivy_pods=$(kubectl get pods -n trivy-system --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
        
        if [ "$trivy_pods" -eq 0 ]; then
            check_pass "Trivy vulnerability scanner is healthy"
        else
            check_warn "Trivy has unhealthy pods"
        fi
    fi
}

# ============================================================================
# TEST 10: NETWORKING
# ============================================================================
test_networking() {
    section_header "10/10" "NETWORKING & DNS"
    
    # Check CoreDNS
    local coredns_pods
    coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
    
    if [ "$coredns_pods" -eq 0 ]; then
        check_pass "CoreDNS pods are healthy"
    else
        check_fail "CoreDNS has unhealthy pods"
    fi
    
    # Check Traefik (if installed)
    if kubectl get namespace traefik &> /dev/null; then
        local traefik_pods
        traefik_pods=$(kubectl get pods -n traefik --no-headers 2>/dev/null | grep -cv "Running" || echo "0")
        
        if [ "$traefik_pods" -eq 0 ]; then
            check_pass "Traefik ingress controller is healthy"
        else
            check_warn "Traefik has unhealthy pods"
        fi
    fi
    
    # Check for services without endpoints
    local no_endpoints
    no_endpoints=$(kubectl get endpoints -A -o json 2>/dev/null | jq -r '.items[] | select(.subsets == null or .subsets == []) | .metadata.namespace + "/" + .metadata.name' | grep -v "kubernetes" | wc -l || echo "0")
    
    if [ "$no_endpoints" -eq 0 ]; then
        check_pass "All services have endpoints"
    else
        check_warn "$no_endpoints service(s) without endpoints"
    fi
    
    # Check Gateway API (if installed)
    if kubectl get gateways.gateway.networking.k8s.io -A &> /dev/null 2>&1; then
        local gateways
        gateways=$(kubectl get gateways.gateway.networking.k8s.io -A --no-headers 2>/dev/null | wc -l || echo "0")
        check_pass "Gateway API configured ($gateways gateway(s))"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================
print_summary() {
    log ""
    log "╔══════════════════════════════════════════════════════════════════════╗"
    log "║                           SUMMARY                                    ║"
    log "╠══════════════════════════════════════════════════════════════════════╣"
    
    local status_color=$GREEN
    local status_text="HEALTHY"
    
    if [ "$FAILED" -gt 0 ]; then
        status_color=$RED
        status_text="UNHEALTHY"
    elif [ "$WARNINGS" -gt 0 ]; then
        status_color=$YELLOW
        status_text="DEGRADED"
    fi
    
    log "║                                                                      ║"
    log "║  Cluster Status: ${status_color}${status_text}${NC}                                          "
    log "║                                                                      ║"
    log "║  ┌────────────┬────────────┬────────────┬────────────┐              ║"
    log "║  │ ${GREEN}Passed: $(printf '%2d' $PASSED)${NC} │ ${YELLOW}Warns: $(printf '%3d' $WARNINGS)${NC} │ ${RED}Failed: $(printf '%2d' $FAILED)${NC} │ ${BLUE}Skip: $(printf '%4d' $SKIPPED)${NC} │              ║"
    log "║  └────────────┴────────────┴────────────┴────────────┘              ║"
    log "║                                                                      ║"
    log "║  Total Checks: $TOTAL                                                 "
    log "║  Log File: $LOG_FILE"
    log "║                                                                      ║"
    log "╚══════════════════════════════════════════════════════════════════════╝"
    
    # Return appropriate exit code
    if [ "$FAILED" -gt 0 ]; then
        return 1
    elif [ "$WARNINGS" -gt 0 ]; then
        return 2
    else
        return 0
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    preflight_checks
    
    test_node_status
    test_system_pods
    test_cilium
    test_storage
    test_argocd
    test_certificates
    test_resources
    test_velero
    test_security
    test_networking
    
    print_summary
    exit $?
}

# Run main function
main "$@"
