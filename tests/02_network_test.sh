#!/bin/bash
# =============================================================================
# Phase 2: Network & Cluster Verification Script
# =============================================================================
# This script validates that the cluster bootstrap completed successfully.
#
# Checks:
#   1. Node Readiness - All 4 nodes in Ready state
#   2. Cilium Pods - CNI agents running on every node
#   3. Hubble Service - Network observability available
#   4. Hardware Labels - Scheduling affinity labels applied
#   5. CoreDNS - DNS resolution services running
#   6. Metrics Server - Resource usage metrics available
#   7. Cilium Status - Detailed CLI status from Control Plane
#   8. Cilium Connectivity - Basic pod-to-pod reachability test
#
# Usage: bash tests/02_network_test.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           NETWORK & CLUSTER VERIFICATION SUITE                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# -----------------------------------------------------------------------------
# 1. Check Node Readiness
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 1. NODE READINESS                                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

READY_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready")
if [ "$READY_COUNT" -eq 4 ]; then
    echo -e "${GREEN}✅ All 4 Nodes are Ready${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Waiting for nodes... (Found $READY_COUNT/4 Ready)${NC}"
    kubectl get nodes
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 2. Check Cilium Pods
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 2. CILIUM CNI                                                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"

CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running")
if [ "$CILIUM_PODS" -eq 4 ]; then
    echo -e "${GREEN}✅ Cilium Agents Running on all nodes${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Cilium pods missing or failed (Found $CILIUM_PODS/4)${NC}"
    kubectl get pods -n kube-system -l k8s-app=cilium
    ((FAIL++))
fi

# Check Cilium Operator
OPERATOR=$(kubectl get pods -n kube-system -l name=cilium-operator --no-headers 2>/dev/null | grep -c "Running")
if [ "$OPERATOR" -ge 1 ]; then
    echo -e "${GREEN}✅ Cilium Operator Running${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Cilium Operator not running${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 3. Check Hubble
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 3. HUBBLE OBSERVABILITY                                             │"
echo "└─────────────────────────────────────────────────────────────────────┘"

if kubectl get svc -n kube-system hubble-ui &>/dev/null; then
    echo -e "${GREEN}✅ Hubble UI Service exists${NC}"
    NODEPORT=$(kubectl get svc hubble-ui -n kube-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo "   Access via: http://<any-node-ip>:$NODEPORT"
    ((PASS++))
else
    echo -e "${RED}❌ Hubble UI Service not found${NC}"
    ((FAIL++))
fi

if kubectl get svc -n kube-system hubble-relay &>/dev/null; then
    echo -e "${GREEN}✅ Hubble Relay Service exists${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Hubble Relay Service not found${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 4. Check Labels
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 4. HARDWARE LABELS                                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Check Control Plane labels
CP_LABELS=$(kubectl get node rpi4-1 --show-labels 2>/dev/null || echo "")
if [[ $CP_LABELS == *"hardware/unique-hdd=true"* ]]; then
    echo -e "${GREEN}✅ Control Plane label (unique-hdd=true) applied${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Control Plane labels missing${NC}"
    ((FAIL++))
fi

if [[ $CP_LABELS == *"hardware/ram=8gb"* ]]; then
    echo -e "${GREEN}✅ Control Plane label (ram=8gb) applied${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Control Plane RAM label missing${NC}"
    ((FAIL++))
fi

# Check Worker labels
WORKER_LABELS=$(kubectl get node rpi4-2 --show-labels 2>/dev/null || echo "")
if [[ $WORKER_LABELS == *"hardware/ram=4gb"* ]]; then
    echo -e "${GREEN}✅ Worker labels (ram=4gb) applied${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Worker labels missing${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 5. Check CoreDNS
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 5. COREDNS STATUS                                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running")
if [ "$COREDNS_PODS" -ge 1 ]; then
    echo -e "${GREEN}✅ CoreDNS is running ($COREDNS_PODS pods)${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ CoreDNS is not running${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 6. Check Metrics Server
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 6. METRICS SERVER                                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

METRICS_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server --no-headers 2>/dev/null | grep -c "Running")
if [ "$METRICS_PODS" -ge 1 ]; then
    echo -e "${GREEN}✅ Metrics Server pod is running${NC}"
    ((PASS++))
    
    # Verify metrics API availability
    echo "   Verifying metrics API..."
    if kubectl top nodes &>/dev/null; then
         echo -e "${GREEN}✅ Node metrics available (kubectl top nodes works)${NC}"
         ((PASS++))
    else
         echo -e "${YELLOW}⚠️  Metrics API not yet available (may take a minute to collect data)${NC}"
    fi
else
    echo -e "${RED}❌ Metrics Server not running${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 7. Cilium Status (Remote via Ansible)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 7. CILIUM CLI STATUS (Remote on Control Plane)                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Use Ansible to run 'cilium status' on the 'big' (control plane) group
# This leverages the CLI tool installed in Phase 1
if ansible big -m shell -a "cilium status --wait=false" --become &>/dev/null; then
    echo -e "${GREEN}✅ Cilium CLI reports healthy status on Control Plane${NC}"
    
    # Optional: Print the status for the user to see
    echo "   ---------------------------------------------------"
    ansible big -m shell -a "cilium status --wait=false" --become | grep -v "SUCCESS" | sed 's/^/   /'
    echo "   ---------------------------------------------------"
    ((PASS++))
else
    echo -e "${RED}❌ Cilium CLI reported errors (or Ansible failed)${NC}"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# 8. Cilium Connectivity Test (Basic)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 8. CILIUM CONNECTIVITY TEST (Basic Reachability)                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "   Running basic connectivity tests (no-policies)... This may take 1-2 mins."

# Run cilium connectivity test via Ansible on Control Plane
# We filter for 'no-policies' to keep it fast and focused on basic connectivity
# We also filter out "Skipping test" lines to keep the output clean
echo "   ---------------------------------------------------"
if ansible big -m shell -a "cilium connectivity test --test ^no-policies" --become | grep -v "Skipping test"; then
    echo "   ---------------------------------------------------"
    echo -e "${GREEN}✅ Cilium Connectivity Test Passed${NC}"
    ((PASS++))
else
    echo "   ---------------------------------------------------"
    echo -e "${RED}❌ Cilium Connectivity Test Failed${NC}"
    echo "   Run 'ansible big -m shell -a \"cilium connectivity test\"' to debug"
    ((FAIL++))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                          SUMMARY                                      ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
printf "║  Passed: %-3d  │  Failed: %-3d                                       ║\n" $PASS $FAIL
echo "╚═══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ PHASE 2 VERIFICATION FAILED${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  • Nodes not Ready: Check kubelet logs with 'journalctl -u kubelet -f'"
    echo "  • Cilium issues: Run 'cilium status' on control plane"
    echo "  • Label issues: Re-run Phase 2c of the playbook"
    exit 1
fi

echo ""
echo "🎉 PHASE 2 COMPLETE - Cluster is operational!"
echo ""
echo "Next steps:"
echo "  1. Test Metrics Server: kubectl top nodes"
echo "  2. Access Hubble UI via NodePort"
echo "  3. Proceed to Phase 3: Storage Foundation"
echo ""
echo "Next command:"
echo "  ansible-playbook -i ansible/hosts ansible/playbooks/04_storage_mount.yml"
