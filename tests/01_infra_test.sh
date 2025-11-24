#!/bin/bash
echo "=== INFRASTRUCTURE VERIFICATION SUITE ==="

check() {
    NAME=$1
    CMD=$2
    if eval $CMD; then
        echo "✅ $NAME: PASS"
    else
        echo "❌ $NAME: FAIL"
        exit 1
    fi
}

echo "1. Checking Ansible Connectivity..."
ansible -i ansible/hosts all -m ping > /dev/null && echo "✅ Ansible Ping: PASS" || exit 1

echo "2. Checking Kubernetes Binaries..."
ansible -i ansible/hosts all -m shell -a "kubeadm version" > /dev/null && echo "✅ Kubeadm: PASS"
ansible -i ansible/hosts all -m shell -a "helm version" > /dev/null && echo "✅ Helm: PASS"

echo "3. Checking Swap Status..."
# Returns 1 (PASS) if grep finds no swap entries
ansible -i ansible/hosts all -m shell -a "swapon --show" | grep -v "rc=0" | grep -q "" 
if [ $? -eq 1 ]; then
    echo "✅ Swap Disabled: PASS"
else
    echo "❌ Swap Active (FAIL)"
    exit 1
fi

echo "4. Checking Cgroups (Memory)..."
ansible -i ansible/hosts all -m shell -a "cat /proc/cgroups | grep memory | grep 1" > /dev/null && echo "✅ Cgroups: PASS"

echo "=== PHASE 1 COMPLETE ==="
