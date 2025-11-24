# Kubernetes Cluster on Raspberry Pi 4: Bare Metal GitOps Guide

## Table of Contents
1.  [Introduction and Scope](#1-introduction-and-scope)
2.  [Architecture Overview](#2-architecture-overview)
    *   [Hardware Topology](#hardware-topology)
    *   [Software Stack & Justification](#software-stack--justification)
3.  [Repository Directory Structure](#3-repository-directory-structure)
4.  [Prerequisites & Initial Provisioning](#4-prerequisites--initial-provisioning)
    *   [OS & Network Setup](#os--network-setup)
    *   [Local Client Configuration](#local-client-configuration)
    *   [Ansible Configuration](#ansible-configuration)
5.  [Deployment Roadmap](#5-deployment-roadmap)

---

## 1. Introduction and Scope
This project documents the establishment of a production-grade "Cloud Native" Kubernetes cluster on bare metal Raspberry Pi 4 hardware. The objective is to build a self-healing, observable, and secure platform managed entirely through **GitOps** principles.

This guide serves as the definitive roadmap for reproducing the cluster from scratch. It ensures that the infrastructure provisioning (via Ansible) and the application state (via ArgoCD) are strictly version-controlled, automated, and reproducible.

---

## 2. Architecture Overview

### Hardware Topology
The cluster consists of four nodes, topologically separated into storage-heavy control roles and compute-heavy worker roles.

*   **Control Plane (`rpi4-1`):** 8GB RAM, 128GB SD, 1TB HDD.
    *   **Role:** Kubernetes API, Etcd, and **Primary Storage Node**.
    *   **Configuration:** Labeled with `storage=hdd` and `unique-hdd=true`.
    *   **Taints:** Untainted to allow workload scheduling, but functionally reserved for critical storage components (Longhorn/MinIO) to utilize the HDD.
*   **Worker Nodes (`rpi4-2`, `rpi4-3`, `rpi4-4`):** 4GB RAM, 64GB SD.
    *   **Role:** Stateless workload execution.
    *   **Protection:** Explicitly configured to block persistent storage writes, preventing SD card burnout.

### Software Stack & Justification

#### **A. Orchestration & Deployment**
*   **Kubernetes (Kubeadm):** The cluster foundation. Installed via Ansible (Phase 1) to ensure a pure upstream experience.
*   **Helm:** The package manager used by ArgoCD to deploy applications.
*   **ArgoCD + Image Updater:** The GitOps engine (Phase 4). Monitors this repository and automatically syncs changes to the cluster. The Image Updater automates container version bumps based on registry tags.
*   **JenkinsX:** The CI/CD automation platform (Phase 5). Orchestrates complex pipelines including linting, building, releasing, and testing suites.

#### **B. Network Layer**
*   **Cilium:** The CNI plugin (Phase 2). Replaces `kube-proxy` with eBPF for superior performance. Configured with L2 Announcements to turn the Raspberry Pis into a physical Load Balancer.
*   **Hubble:** Network observability tool (embedded in Cilium) for visualizing communication maps.
*   **Tetragon:** eBPF-based security observability and runtime enforcement.
*   **Traefik:** The Ingress Controller. Manages external access to services via LoadBalancer IPs requested from Cilium.

#### **C. Observability Stack** (Deployed via GitOps)
*   **Prometheus Operator:** The standard for metrics collection and alerting.
*   **Thanos:** Provides long-term storage for Prometheus metrics (deduplication and downsampling). *Depends on MinIO.*
*   **Grafana:** Visualization for metrics and logs.
*   **Fluentd:** Log collector. Gathers logs from all nodes.
*   **Loki:** Log database. Stores logs indexed by labels. *Depends on MinIO.*
*   **OpenTelemetry + Jaeger:** Distributed tracing. Tracks requests across microservices for latency debugging.
*   **SigNoz:** Full-stack APM (Application Performance Monitoring). Included for redundancy and deep-dive performance analysis.
*   **OpenCost:** Cloud cost allocation tool to estimate resource consumption.
*   **Kube-state-metrics:** Exposes raw Kubernetes object metrics.
*   **K8sGPT:** AI-powered diagnostics tool to explain cluster errors in plain English.
*   **Kubeshark:** API traffic analyzer (Wireshark for K8s).

#### **D. Security Layer** (Deployed via GitOps)
*   **Cert-Manager:** Automates the issuance and renewal of TLS certificates.
*   **Harbor:** Private container registry to store built images locally.
*   **OpenBao:** Secrets management (Community fork of Vault) to securely store API keys.
*   **Trivy:** Vulnerability scanner integrated into the CI/CD pipeline.
*   **OWASP ZAP:** Dynamic Application Security Testing (DAST) tool integrated into JenkinsX.
*   **Falco:** Runtime threat detection. Alerts on suspicious system calls.
*   **Kyverno:** Policy engine. Enforces rules (e.g., "No root containers") at the API level.

#### **E. Cluster Management & Storage**
*   **Longhorn:** Distributed block storage (Phase 3). Configured to strictly use the 1TB HDD on the control plane.
*   **MinIO:** Object storage. **Required Dependency** for Thanos, Loki, and Velero to function on bare metal.
*   **Velero:** Backup and disaster recovery. Backs up cluster state and volumes to MinIO.
*   **Portainer:** Visual web UI for simplified container management.
*   **K9s:** Terminal-based UI for real-time cluster interaction.

---

## 3. Repository Directory Structure

This structure separates infrastructure provisioning (Ansible), bootstrap scripts, and the declarative Application state (GitOps).

```text
.
├── README.md                        # This guide
├── ansible/                         # INFRASTRUCTURE (Imperative)
│   ├── hosts                        # Inventory file defined below
│   ├── playbooks/
│   │   ├── 01_node_prep.yml         # OS config, Cgroups, Kernel modules, Dependencies
│   │   ├── 02_k8s_binaries.yml      # Installing Kubeadm/Kubelet/Kubectl/Helm
│   │   ├── 03_cluster_init.yml      # Bootstrap CP, Join Workers, Taints, Labels
│   │   ├── 04_storage_mount.yml     # Formats and mounts HDD on CP
│   │   └── 05_reset_cluster.yml     # Tear down script (for reproducibility)
├── bootstrap/                       # BOOTSTRAP (Pre-GitOps)
│   ├── cilium/                      # Helm scripts for CNI & L2 Announcements
│   ├── longhorn/                    # Helm scripts for Storage (HDD constraints)
│   └── argocd/                      # Helm scripts to install ArgoCD
├── gitops/                          # APPLICATIONS (Declarative)
│   ├── app-of-apps.yaml             # The Root Application
│   ├── infrastructure/              # Core Networking & Ingress
│   │   ├── traefik/
│   │   └── cert-manager/
│   ├── storage/                     # Storage Dependencies
│   │   ├── longhorn-config/         # Post-install configuration
│   │   └── minio/                   # Object Store for Thanos/Loki/Velero
│   ├── observability/               # Monitoring Stack
│   │   ├── kube-prometheus-stack/   # Prom + Alertmanager + Grafana
│   │   ├── thanos/
│   │   ├── loki-distributed/
│   │   ├── fluentd/
│   │   ├── opentelemetry/
│   │   ├── jaeger/
│   │   ├── signoz/
│   │   ├── opencost/
│   │   ├── k8sgpt/
│   │   └── kubeshark/
│   ├── security/                    # Security Stack
│   │   ├── harbor/
│   │   ├── openbao/
│   │   ├── falco/
│   │   ├── kyverno/
│   │   └── trivy-operator/
│   ├── cicd/                        # Build Pipelines
│   │   ├── jenkins-x/
│   │   ├── owasp-zap/
│   │   └── argo-image-updater/
│   └── management/                  # Ops Tools
│       ├── velero/
│       └── portainer/
└── tests/                           # VALIDATION
    ├── infra_test.sh                # Verifies Nodes, RAM, HDD mounts
    ├── network_test.sh              # Verifies Cilium L2, DNS, Ingress
    └── storage_test.sh              # Verifies PVC creation on HDD
```

---

## 4. Prerequisites & Initial Provisioning

Before executing Ansible playbooks, the physical devices must be provisioned and network-accessible.

### OS & Network Setup
1.  **Flash OS:** Use **Raspberry Pi Imager** to flash **Ubuntu Server 25.10** to SD cards.
    *   *Why 25.10?* Selected for the latest kernel support optimized for RPi 4.
2.  **User Configuration:**
    *   Hostname: `rpi4-1` through `rpi4-4`.
    *   User: `user` (or your preferred username).
    *   SSH: Enabled with public key authentication. 
3.  **Network Configuration:**
    *   Identify IPs via your home router. 
    *   **Address Reservation:** Configure Static DHCP leases on the router to ensure IPs remain persistent (e.g., `192.168.0.201` - rpi4-1).
    *   **Port Forwarding/DDNS:** Configure DDNS and port forwarding if external access is required (optional). Unless you ave Static IPv4 and then you can have public access easier.

### Local Client Configuration
To simplify management, map the IPs to hostnames on your local management machine (Windows/Linux).

**Windows:** `C:\Windows\System32\drivers\etc\hosts`. I use WSL so I must edit the hosts file on Windows.
**Linux/Mac:** `/etc/hosts`

```text
192.168.0.201 rpi4-1
192.168.0.202 rpi4-2
192.168.0.203 rpi4-3
192.168.0.204 rpi4-4
```

### Ansible Configuration
We use Ansible to drive the infrastructure state.

**File:** `ansible/hosts`
```ini
[big]
# Control Plane (8GB RAM) - The Storage Node
rpi4-1

[small]
# Worker Nodes (4GB RAM) - Compute Only
rpi4-2
rpi4-3
rpi4-4

[all:vars]
# Connection Settings
ansible_connection=ssh
ansible_user=user
ansible_ssh_private_key_file=/home/user/.ssh/rsa-4096/key-nopassphrase.pem
ansible_python_interpreter=/usr/bin/python3.13

# Environment Variables
k8s_version=1.31
```

*Verification:*
Run the following to confirm connectivity before proceeding:
```bash
ansible -i ansible/hosts all -m ping
```

---

## 5. Deployment Roadmap

This roadmap outlines the specific order of operations required to bootstrap the cluster.

### Phase 1: Infrastructure (Ansible)
**Goal:** "Kubernetes Ready" hardware.
1.  **OS Tuning:** Update packages, disable Swap/WiFi/Bluetooth, set GPU memory to 16MB.
2.  **Kernel & Network:** Load `overlay`/`br_netfilter` modules; enable IP forwarding.
3.  **Cgroups:** Append `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1` to boot config.
4.  **Dependencies:** Install `containerd`, `open-iscsi`, `nfs-common`, `ipset`.
5.  **Binaries:** Install `kubeadm`, `kubelet`, `kubectl` (locked versions), `helm`, `etcdctl`, `cilium-cli`.

### Phase 2: Cluster Bootstrap
**Goal:** A running API server and networked nodes.
1.  **Init:** Run `kubeadm init` on `rpi4-1`.
2.  **Networking:** Install **Cilium** immediately to allow nodes to become Ready. Configure L2 Announcements.
3.  **Join:** Run `kubeadm join` on workers.
4.  **Labeling:** Apply labels (`hardware/storage=hdd`, `hardware/ram=8gb`) to distinguish the nodes.

### Phase 3: Storage Foundation
**Goal:** Persistent storage for the GitOps engine.
1.  **HDD Setup:** Format and mount the 1TB drive to `/var/lib/longhorn`.
2.  **Longhorn Install:** Deploy Longhorn with strict affinity settings (Replica Count: 1, Control Plane only).
3.  **MinIO Install:** Deploy MinIO on top of Longhorn to provide S3-compatible storage.

### Phase 4: GitOps & Observability
**Goal:** Automated application management.
1.  **ArgoCD:** Deploy ArgoCD.
2.  **App of Apps:** Apply the root manifest. ArgoCD takes over and installs the Observability, Security, and Management stacks defined in the `gitops/` directory.

### Phase 5: CI/CD & DevEx
**Goal:** Developer productivity.
1.  **JenkinsX:** Deploy the JenkinsX platform.
2.  **Integration:** Configure Harbor for image pushing and Security scanners.


We are now executing **Phase 1: Infrastructure**. You need to create the Ansible playbooks that will turn your fresh Ubuntu installation into a Kubernetes-ready node.

Create the following files in your repository.

---

### File: `ansible/playbooks/01_node_prep.yml`
**Purpose:** This playbook handles the low-level OS tuning. It disables unnecessary hardware (WiFi/BT/Swap), enables required Kernel modules for container networking, enforces memory limits via Cgroups, and installs storage dependencies (`open-iscsi`) required later by Longhorn.

```yaml
---
- name: Phase 1 - OS Preparation & Tuning
  hosts: all
  become: true
  vars:
    # Hardware tuning
    gpu_mem: 16
  tasks:
    # ---------------------------------------------------------
    # 1. SYSTEM UPDATES & BASICS
    # ---------------------------------------------------------
    - name: Update apt cache and upgrade packages
      apt:
        update_cache: yes
        upgrade: dist
      register: apt_action
      retries: 5
      delay: 10

    - name: Install Essential Dependencies
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
          - open-iscsi  # Required for Longhorn
          - nfs-common  # Required for RWX volumes
          - ipset       # Required for Cilium
          - jq          # Utility for parsing JSON
        state: present

    - name: Disable Swap (Runtime)
      command: swapoff -a
      when: ansible_swaptionals['type'] is defined

    - name: Disable Swap (Permanent)
      replace:
        path: /etc/fstab
        regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
        replace: '# \1'

    # ---------------------------------------------------------
    # 2. KERNEL & NETWORK TUNING
    # ---------------------------------------------------------
    - name: Load Kernel Modules (overlay, br_netfilter)
      blockinfile:
        path: /etc/modules-load.d/k8s.conf
        create: yes
        block: |
          overlay
          br_netfilter

    - name: Load modules immediately
      shell: |
        modprobe overlay
        modprobe br_netfilter

    - name: Configure Sysctl for Kubernetes Networking
      blockinfile:
        path: /etc/sysctl.d/k8s.conf
        create: yes
        block: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1

    - name: Apply Sysctl params
      command: sysctl --system

    # ---------------------------------------------------------
    # 3. RASPBERRY PI SPECIFIC (CGROUPS & HARDWARE)
    # ---------------------------------------------------------
    - name: Enable Cgroups (Memory & CPU) in cmdline.txt
      # We use a robust regex to ensure we don't duplicate flags
      shell: |
        cmdline=$(cat /boot/firmware/cmdline.txt)
        if [[ "$cmdline" != *"cgroup_enable=cpuset"* ]]; then
            sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
            echo "updated"
        fi
      register: cgroup_update
      changed_when: "'updated' in cgroup_update.stdout"

    - name: Optimize Hardware (Disable WiFi/BT, GPU Memory)
      blockinfile:
        path: /boot/firmware/config.txt
        block: |
          # K8s Optimization
          gpu_mem={{ gpu_mem }}
          dtoverlay=disable-bt
          dtoverlay=disable-wifi

    # ---------------------------------------------------------
    # 4. CONTAINER RUNTIME (CONTAINERD)
    # ---------------------------------------------------------
    - name: Install Containerd
      apt:
        name: containerd
        state: present

    - name: Generate default containerd config
      shell: |
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml

    - name: Configure SystemdCgroup = true
      replace:
        path: /etc/containerd/config.toml
        regexp: 'SystemdCgroup = false'
        replace: 'SystemdCgroup = true'

    - name: Restart Containerd
      service:
        name: containerd
        state: restarted
        enabled: yes

    # ---------------------------------------------------------
    # 5. REBOOT HANDLER
    # ---------------------------------------------------------
    - name: Reboot if critical changes occurred
      reboot:
        msg: "Rebooting for Kernel/Cgroup changes"
        post_reboot_delay: 30
      when: cgroup_update.changed or apt_action.changed
```

---

### File: `ansible/playbooks/02_k8s_binaries.yml`
**Purpose:** This playbook installs the specific versions of Kubernetes tools, Helm, and the Cilium CLI. It uses the modern `pkgs.k8s.io` repositories and locks the versions to prevent drift.

```yaml
---
- name: Phase 1 - Install Kubernetes Binaries
  hosts: all
  become: true
  vars:
    k8s_version_major: "1.31"
    # We define the specific package version format for apt
    k8s_pkg_version: "1.31.*" 
  tasks:
    # ---------------------------------------------------------
    # 1. KUBERNETES REPO SETUP
    # ---------------------------------------------------------
    - name: Create keyring directory
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Download K8s Signing Key
      get_url:
        url: "https://pkgs.k8s.io/core:/stable:/v{{ k8s_version_major }}/deb/Release.key"
        dest: /tmp/k8s-release.key

    - name: Dearmor K8s Key
      shell: |
        cat /tmp/k8s-release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes

    - name: Add K8s Apt Repository
      apt_repository:
        repo: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ k8s_version_major }}/deb/ /"
        state: present
        filename: kubernetes

    - name: Update apt cache
      apt:
        update_cache: yes

    # ---------------------------------------------------------
    # 2. INSTALL PACKAGES
    # ---------------------------------------------------------
    - name: Install Kubelet, Kubeadm, Kubectl
      apt:
        name:
          - kubelet={{ k8s_pkg_version }}
          - kubeadm={{ k8s_pkg_version }}
          - kubectl={{ k8s_pkg_version }}
        state: present
        allow_downgrade: yes

    - name: Hold K8s Packages (Prevent auto-upgrade)
      dpkg_selections:
        name: "{{ item }}"
        selection: hold
      loop:
        - kubelet
        - kubeadm
        - kubectl

    - name: Enable Kubelet Service
      service:
        name: kubelet
        enabled: yes
        # Note: It will loop/fail until kubeadm init is run, this is normal.

    # ---------------------------------------------------------
    # 3. HELM INSTALLATION
    # ---------------------------------------------------------
    - name: Download Helm Installer
      get_url:
        url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        dest: /tmp/get_helm.sh
        mode: '0700'

    - name: Run Helm Installer
      shell: /tmp/get_helm.sh
      args:
        creates: /usr/local/bin/helm

    # ---------------------------------------------------------
    # 4. CILIUM CLI INSTALLATION (For Debugging)
    # ---------------------------------------------------------
    - name: Download Cilium CLI
      unarchive:
        src: https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-arm64.tar.gz
        dest: /usr/local/bin
        remote_src: yes
        mode: '0755'
        include: 
          - cilium
```

---

### File: `tests/infra_test.sh`
**Purpose:** A script to verify that Phase 1 was successful. It checks if binaries exist, if swap is off, and if cgroups are active.

```bash
#!/bin/bash
echo "=== INFRASTRUCTURE VERIFICATION SUITE ==="

# Function to run a check
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

echo "Checking Local Connection..."
ansible -i ansible/hosts all -m ping > /dev/null && echo "✅ Ansible Connectivity: PASS" || exit 1

echo "Checking Binaries on Nodes..."
ansible -i ansible/hosts all -m shell -a "kubeadm version" > /dev/null && echo "✅ Kubeadm Installed: PASS"
ansible -i ansible/hosts all -m shell -a "helm version" > /dev/null && echo "✅ Helm Installed: PASS"

echo "Checking Swap Status (Should be empty)..."
ansible -i ansible/hosts all -m shell -a "swapon --show" | grep -v "rc=0" | grep -q "" 
if [ $? -eq 1 ]; then
    echo "✅ Swap Disabled: PASS"
else
    echo "❌ Swap is still active on some nodes!"
fi

echo "Checking Cgroups..."
ansible -i ansible/hosts all -m shell -a "cat /proc/cgroups | grep memory | grep 1" > /dev/null && echo "✅ Memory Cgroups Enabled: PASS"

echo "=== READY FOR PHASE 2 ==="
```

---

### Instructions for Phase 1

1.  **Create the files** above in your repository.
2.  **Run OS Prep:**
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml
    ```
    *(Expect reboots to happen automatically. Wait 1-2 minutes after it finishes)*
3.  **Run Binary Install:**
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/02_k8s_binaries.yml
    ```
4.  **Verify:**
    ```bash
    bash tests/infra_test.sh
    ```

**Let me know when the verification script passes, and we will proceed to Phase 2: Cluster Bootstrap.**