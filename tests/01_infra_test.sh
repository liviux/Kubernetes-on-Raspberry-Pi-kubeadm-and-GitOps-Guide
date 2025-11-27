#!/bin/bash
# =============================================================================
# Phase 1 Infrastructure Verification Script
# =============================================================================
# This script validates that all nodes are properly prepared for Kubernetes.
# Run from the repository root after executing the Phase 1 Ansible playbooks.
#
# Usage: bash tests/01_infra_test.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           PHASE 1: INFRASTRUCTURE VERIFICATION SUITE                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    local NAME=$1
    local CMD=$2
    if eval "$CMD" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $NAME: PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ $NAME: FAIL${NC}"
        ((FAIL++))
    fi
}

warn_check() {
    local NAME=$1
    local CMD=$2
    if eval "$CMD" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $NAME: PASS${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠️  $NAME: WARN (optional)${NC}"
        ((WARN++))
    fi
}

echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 1. CONNECTIVITY TESTS                                               │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "Ansible ping (all nodes)" "ansible -i ansible/hosts all -m ping"
check "SSH connection (control plane)" "ansible -i ansible/hosts big -m shell -a 'echo connected'"
check "SSH connection (workers)" "ansible -i ansible/hosts small -m shell -a 'echo connected'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 2. KUBERNETES BINARY TESTS                                          │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "kubeadm installed (all)" "ansible -i ansible/hosts all -m shell -a 'kubeadm version -o short'"
check "kubelet installed (all)" "ansible -i ansible/hosts all -m shell -a 'kubelet --version'"
check "kubectl installed (all)" "ansible -i ansible/hosts all -m shell -a 'kubectl version --client -o yaml'"
check "Kubernetes version 1.33" "ansible -i ansible/hosts all -m shell -a 'kubeadm version -o short | grep -q v1.33'"
check "Helm installed (CP)" "ansible -i ansible/hosts big -m shell -a 'helm version --short'"
check "Cilium CLI installed (CP)" "ansible -i ansible/hosts big -m shell -a 'cilium version --client'"
check "etcdctl installed (CP)" "ansible -i ansible/hosts big -m shell -a 'which etcdctl'"
warn_check "k9s installed (CP)" "ansible -i ansible/hosts big -m shell -a 'k9s version --short'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 3. OS CONFIGURATION TESTS                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Check swap is disabled
SWAP_OUTPUT=$(ansible -i ansible/hosts all -m shell -a "swapon --show" 2>/dev/null | grep -E "^[a-zA-Z]" | grep -v SUCCESS || true)
if [ -z "$SWAP_OUTPUT" ]; then
    echo -e "${GREEN}✅ Swap disabled (all nodes): PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Swap disabled (all nodes): FAIL - Swap still active${NC}"
    ((FAIL++))
fi

check "Cgroups memory enabled" "ansible -i ansible/hosts all -m shell -a 'grep -E \"^memory.*1$\" /proc/cgroups'"
check "Cgroups cpuset enabled" "ansible -i ansible/hosts all -m shell -a 'grep -E \"^cpuset.*1$\" /proc/cgroups'"
check "IP forwarding enabled" "ansible -i ansible/hosts all -m shell -a 'sysctl net.ipv4.ip_forward | grep -q \"= 1\"'"
check "Bridge netfilter iptables" "ansible -i ansible/hosts all -m shell -a 'sysctl net.bridge.bridge-nf-call-iptables | grep -q \"= 1\"'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 4. KERNEL MODULE TESTS                                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "Kernel module: overlay" "ansible -i ansible/hosts all -m shell -a 'lsmod | grep -q ^overlay'"
check "Kernel module: br_netfilter" "ansible -i ansible/hosts all -m shell -a 'lsmod | grep -q ^br_netfilter'"
check "Kernel module: iscsi_tcp" "ansible -i ansible/hosts all -m shell -a 'lsmod | grep -q ^iscsi_tcp'"
check "Kernel module: ip_vs" "ansible -i ansible/hosts all -m shell -a 'lsmod | grep -q ^ip_vs'"
check "Kernel module: nf_conntrack" "ansible -i ansible/hosts all -m shell -a 'lsmod | grep -q ^nf_conntrack'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 5. CONTAINER RUNTIME TESTS                                          │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "containerd running" "ansible -i ansible/hosts all -m shell -a 'systemctl is-active containerd | grep -q active'"
check "containerd enabled" "ansible -i ansible/hosts all -m shell -a 'systemctl is-enabled containerd | grep -q enabled'"
check "containerd SystemdCgroup" "ansible -i ansible/hosts all -m shell -a 'grep -q \"SystemdCgroup = true\" /etc/containerd/config.toml'"
check "containerd pause image" "ansible -i ansible/hosts all -m shell -a 'grep -q \"sandbox_image.*pause:3\" /etc/containerd/config.toml'"
check "iscsid service running" "ansible -i ansible/hosts all -m shell -a 'systemctl is-active iscsid | grep -q active'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 6. HARDWARE OPTIMIZATION TESTS (Raspberry Pi Specific)              │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "GPU memory limited" "ansible -i ansible/hosts all -m shell -a 'grep -q \"gpu_mem=16\" /boot/firmware/config.txt'"
check "WiFi disabled" "ansible -i ansible/hosts all -m shell -a 'grep -q \"disable-wifi\" /boot/firmware/config.txt'"
check "Bluetooth disabled" "ansible -i ansible/hosts all -m shell -a 'grep -q \"disable-bt\" /boot/firmware/config.txt'"
warn_check "Audio disabled" "ansible -i ansible/hosts all -m shell -a 'grep -q \"audio=off\" /boot/firmware/config.txt'"
warn_check "Watchdog enabled" "ansible -i ansible/hosts all -m shell -a 'grep -q \"watchdog=on\" /boot/firmware/config.txt'"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 7. PACKAGE TESTS                                                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"

check "open-iscsi installed" "ansible -i ansible/hosts all -m shell -a 'dpkg -l | grep -q open-iscsi'"
check "nfs-common installed" "ansible -i ansible/hosts all -m shell -a 'dpkg -l | grep -q nfs-common'"
check "ipset installed" "ansible -i ansible/hosts all -m shell -a 'dpkg -l | grep -q ipset'"
check "ipvsadm installed" "ansible -i ansible/hosts all -m shell -a 'dpkg -l | grep -q ipvsadm'"
check "conntrack installed" "ansible -i ansible/hosts all -m shell -a 'dpkg -l | grep -q conntrack'"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                          SUMMARY                                      ║"
echo "╠═══════════════════════════════════════════════════════════════════════╣"
printf "║  ${GREEN}Passed: %-3d${NC}  │  ${RED}Failed: %-3d${NC}  │  ${YELLOW}Warnings: %-3d${NC}               ║\n" $PASS $FAIL $WARN
echo "╚═══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "${RED}⚠️  Some tests failed. Review the output above and check node logs:${NC}"
    echo "   ansible -i ansible/hosts all -m shell -a 'journalctl -n 50'"
    echo ""
    echo "Common fixes:"
    echo "  • Swap still active: reboot nodes after playbook"
    echo "  • Missing modules: check /etc/modules-load.d/k8s.conf"
    echo "  • containerd issues: systemctl restart containerd"
    exit 1
fi

if [ $WARN -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}ℹ️  Some optional checks failed. This is non-blocking but review recommended.${NC}"
fi

echo ""
echo -e "${GREEN}🎉 PHASE 1 COMPLETE - All nodes are Kubernetes-ready!${NC}"
echo "   Proceed to Phase 2: Cluster Bootstrap"
echo ""
echo "   Next command:"
echo "   ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml"
