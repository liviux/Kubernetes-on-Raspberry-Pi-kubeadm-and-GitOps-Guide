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
6.  [Phase 1: Infrastructure Provisioning](#6-phase-1-infrastructure-provisioning)
    *   [6.1 OS Preparation Playbook](#61-os-preparation-playbook)
    *   [6.2 Kubernetes Binaries Playbook](#62-kubernetes-binaries-playbook)
    *   [6.3 Infrastructure Verification](#63-infrastructure-verification)
    *   [6.4 Phase 1 Execution Steps](#64-phase-1-execution-steps)
7.  [Phase 2: Cluster Bootstrap](#7-phase-2-cluster-bootstrap)
    *   [7.1 Cluster Initialization Playbook](#71-cluster-initialization-playbook)
    *   [7.2 Network Verification Script](#72-network-verification-script)
    *   [7.3 Phase 2 Execution Steps](#73-phase-2-execution-steps)
8.  [Phase 3: Storage Foundation](#8-phase-3-storage-foundation)
    *   [8.1 Storage Mounting Playbook](#81-storage-mounting-playbook)
    *   [8.2 Longhorn Bootstrap Script](#82-longhorn-bootstrap-script)
    *   [8.3 Storage Verification Script](#83-storage-verification-script)
    *   [8.4 Phase 3 Execution Steps](#84-phase-3-execution-steps)
9.  [Phase 4: GitOps & Observability](#9-phase-4-gitops--observability)
    *   [9.1 Ingress Bootstrap (Traefik)](#91-ingress-bootstrap-traefik)
    *   [9.2 GitOps Bootstrap (ArgoCD)](#92-gitops-bootstrap-argocd)
    *   [9.3 Source Control Service (Gitea)](#93-source-control-service-gitea)
    *   [9.4 The "App of Apps" Pattern](#94-the-app-of-apps-pattern)
    *   [9.5 Phase 4 Execution Steps](#95-phase-4-execution-steps)
10. [Phase 5: Security & Management Stack](#10-phase-5-security--management-stack)
    *   [10.1 Object Storage (MinIO)](#101-object-storage-minio)
    *   [10.2 Certificate Automation (Cert-Manager)](#102-certificate-automation-cert-manager)
    *   [10.3 Container Registry (Harbor)](#103-container-registry-harbor)
    *   [10.4 Backup & Restore (Velero)](#104-backup--restore-velero)
    *   [10.5 Secrets Management (OpenBao)](#105-secrets-management-openbao)
    *   [10.6 Policy Enforcement (Kyverno)](#106-policy-enforcement-kyverno)
    *   [10.7 Runtime Security (Falco)](#107-runtime-security-falco)
    *   [10.8 The Root Application (App of Apps)](#108-the-root-application-app-of-apps)
    *   [10.9 Security Verification Script](#109-security-verification-script)
    *   [10.10 Phase 5 Execution Steps](#1010-phase-5-execution-steps)
11. [Phase 6: Advanced Observability](#11-phase-6-advanced-observability)
    *   [11.1 Log Aggregation (Loki Stack)](#111-log-aggregation-loki-stack)
    *   [11.2 Log Collection (Fluent Bit)](#112-log-collection-fluent-bit)
    *   [11.3 Distributed Tracing (OpenTelemetry)](#113-distributed-tracing-opentelemetry)
    *   [11.4 Tracing Backend (Jaeger)](#114-tracing-backend-jaeger)
    *   [11.5 Traffic Analysis (Kubeshark)](#115-traffic-analysis-kubeshark)
    *   [11.6 Cost Management (OpenCost)](#116-cost-management-opencost)
    *   [11.7 AI Diagnostics (K8sGPT)](#117-ai-diagnostics-k8sgpt)
    *   [11.8 Full Stack APM (SigNoz)](#118-full-stack-apm-signoz)
    *   [11.9 Observability Verification Script](#119-observability-verification-script)
    *   [11.10 Phase 6 Execution Steps](#1110-phase-6-execution-steps)
12. [Phase 7: CI/CD & Developer Experience](#12-phase-7-cicd--developer-experience)
    *   [12.1 Image Automation (Argo Image Updater)](#121-image-automation-argo-image-updater)
    *   [12.2 CI/CD Platform (Jenkins)](#122-cicd-platform-jenkins)
    *   [12.3 Security Tooling (Trivy & OWASP ZAP)](#123-security-tooling-trivy--owasp-zap)
    *   [12.4 Local Development (Skaffold)](#124-local-development-skaffold)
    *   [12.5 CI/CD Verification Script](#125-cicd-verification-script)
    *   [12.6 Phase 7 Execution Steps](#126-phase-7-execution-steps)
13. [Phase 8: Day 2 Operations & Maintenance](#13-phase-8-day-2-operations--maintenance)
    *   [13.1 Upgrading Kubernetes](#131-upgrading-kubernetes)
    *   [13.2 OS Patching](#132-os-patching)
    *   [13.3 Backup & Disaster Recovery](#133-backup--disaster-recovery)
    *   [13.4 Troubleshooting Cheatsheet](#134-troubleshooting-cheatsheet)

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
│   ├── hosts                        # Inventory file
│   ├── ansible.cfg                  # Local Ansible config
│   ├── playbooks/
│   │   ├── 01_node_prep.yml         # OS config, Cgroups, Kernel modules, Dependencies
│   │   ├── 02_k8s_binaries.yml      # Installing Kubeadm/Kubelet/Kubectl/Helm
│   │   ├── 03_cluster_init.yml      # Bootstrap CP, Join Workers, Taints, Labels
│   │   ├── 04_storage_mount.yml     # Formats and mounts HDD on CP
│   │   └── 05_reset_cluster.yml     # Tear down script
│   └── roles/                       # Reusable roles
├── bootstrap/                       # BOOTSTRAP (Pre-GitOps)
│   ├── cilium/                      # Helm scripts for CNI & L2 Announcements
│   ├── longhorn/                    # Helm scripts for Storage (HDD constraints)
│   ├── traefik/                     # Helm scripts for Ingress
│   └── argocd/                      # Helm scripts to install ArgoCD
├── gitops/                          # APPLICATIONS (Declarative)
│   ├── app-of-apps.yaml             # The Root Application
│   ├── infrastructure/              # Core Networking & Ingress
│   │   ├── traefik/                 # (Adoption config)
│   │   └── cert-manager/            # TLS Certificate automation
│   ├── storage/                     # Storage Dependencies
│   │   ├── minio/                   # Object Store (S3) for Thanos/Loki/Velero
│   │   └── longhorn-config/         # (Adoption config)
│   ├── observability/               # Monitoring Stack
│   │   ├── kube-prometheus-stack/   # Prom + Alertmanager + Grafana
│   │   ├── thanos/                  # Long-term metrics
│   │   ├── loki-stack/              # Logs (Loki + Promtail/Fluent-Bit)
│   │   ├── fluent-bit/              # Log Collector (Lightweight replacement for Fluentd)
│   │   ├── opentelemetry/           # Tracing Operator
│   │   ├── jaeger/                  # Tracing Backend
│   │   ├── signoz/                  # Full-stack APM
│   │   ├── opencost/                # Cost allocation
│   │   ├── k8sgpt/                  # AI Diagnostics
│   │   └── kubeshark/               # API Traffic Analyzer
│   ├── security/                    # Security Stack
│   │   ├── harbor/                  # Container Registry
│   │   ├── openbao/                 # Secrets Management (Vault)
│   │   ├── falco/                   # Runtime Threat Detection
│   │   ├── kyverno/                 # Policy Engine
│   │   └── trivy-operator/          # Vulnerability Scanner
│   ├── cicd/                        # Build Pipelines
│   │   ├── jenkins-x/               # CI/CD Platform
│   │   └── argo-image-updater/      # GitOps Image Automation
│   └── management/                  # Ops Tools
│       ├── velero/                  # Backup & Restore
│       └── portainer/               # Visual Dashboard
└── tests/                           # VALIDATION
    ├── 01_infra_test.sh
    ├── 02_network_test.sh
    └── 03_storage_test.sh
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


## 6. Phase 1: Infrastructure Provisioning

This phase transforms the raw Ubuntu OS into a "Kubernetes Ready" node. It handles low-level kernel tuning, disables unnecessary hardware to save resources, and installs the immutable versions of the Kubernetes binaries.

### 6.1 OS Preparation Playbook
**File:** `ansible/playbooks/01_node_prep.yml`

This playbook performs the following critical tasks:
1.  **System Updates:** Upgrades all packages.
2.  **Dependencies:** Installs `open-iscsi` (required for Longhorn), `nfs-common`, and `ipset`.
3.  **Swap:** Disables swap permanently (required for Kubelet).
4.  **Kernel Modules:** Loads `overlay` and `br_netfilter` for container networking.
5.  **Sysctl:** Enables IP forwarding and bridge traversing.
6.  **Cgroups:** Modifies `/boot/firmware/cmdline.txt` to enable memory and cpuset cgroups (critical for RPi 4).
7.  **Hardware Optimization:** Disables WiFi and Bluetooth; limits GPU memory to 16MB.
8.  **Container Runtime:** Installs and configures `containerd` with `SystemdCgroup = true`.

```yaml
---
- name: Phase 1 - OS Preparation & Tuning
  hosts: all
  become: true
  vars:
    gpu_mem: 16
  tasks:
    # --- SYSTEM UPDATES & DEPENDENCIES ---
    - name: Update apt cache and upgrade packages
      apt:
        update_cache: yes
        upgrade: dist
      register: apt_action
      retries: 5
      delay: 10

    - name: Install Critical Dependencies
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
          - open-iscsi  # Required for Longhorn
          - nfs-common  # Required for RWX volumes
          - cryptsetup  # Required for OpenBao/Longhorn encryption
          - ipset       # Required for Cilium
          - conntrack   # Required by Kubeadm
          - socat       # Required by Helm/Port-forwarding
          - git         # Required for GitOps operations
          - jq
        state: present

    - name: Disable Swap (Runtime)
      command: swapoff -a
      when: ansible_swaptionals['type'] is defined

    - name: Disable Swap (Permanent)
      replace:
        path: /etc/fstab
        regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
        replace: '# \1'

    # --- KERNEL & NETWORK TUNING ---
    - name: Load Kernel Modules
      blockinfile:
        path: /etc/modules-load.d/k8s.conf
        create: yes
        block: |
          overlay
          br_netfilter
          iscsi_tcp 

    - name: Load modules immediately
      shell: |
        modprobe overlay
        modprobe br_netfilter
        modprobe iscsi_tcp

    - name: Configure Sysctl
      blockinfile:
        path: /etc/sysctl.d/k8s.conf
        create: yes
        block: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1

    - name: Apply Sysctl params
      command: sysctl --system

    # --- RASPBERRY PI SPECIFIC ---
    - name: Enable Cgroups in cmdline.txt
      shell: |
        cmdline=$(cat /boot/firmware/cmdline.txt)
        if [[ "$cmdline" != *"cgroup_enable=cpuset"* ]]; then
            sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
            echo "updated"
        fi
      register: cgroup_update
      changed_when: "'updated' in cgroup_update.stdout"

    - name: Optimize Hardware (Disable WiFi/BT/GPU)
      blockinfile:
        path: /boot/firmware/config.txt
        block: |
          gpu_mem={{ gpu_mem }}
          dtoverlay=disable-bt
          dtoverlay=disable-wifi

    # --- CONTAINER RUNTIME ---
    - name: Install Containerd
      apt:
        name: containerd
        state: present

    - name: Generate default containerd config
      shell: |
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml

    - name: Configure SystemdCgroup
      replace:
        path: /etc/containerd/config.toml
        regexp: 'SystemdCgroup = false'
        replace: 'SystemdCgroup = true'

    - name: Restart Containerd
      service:
        name: containerd
        state: restarted
        enabled: yes

    # --- REBOOT HANDLER ---
    - name: Reboot Node
      reboot:
        msg: "Rebooting for Kernel/Cgroup changes"
        post_reboot_delay: 30
      when: cgroup_update.changed or apt_action.changed
```

### 6.2 Kubernetes Binaries Playbook
**File:** `ansible/playbooks/02_k8s_binaries.yml`

This playbook installs the core software stack.
1.  **Repository:** Adds the official `pkgs.k8s.io` v1.31 repository. I picked 1.31 so at the end of the guide to do an upgrade too to latest version.
2.  **Packages:** Installs `kubelet`, `kubeadm`, and `kubectl`.
3.  **Version Locking:** Uses `dpkg --set-selections` to "hold" the packages. This prevents `apt upgrade` from accidentally updating Kubernetes and breaking the cluster.
4.  **Tools:** Installs `helm` and `cilium-cli` for later bootstrap steps.

```yaml
---
- name: Phase 1 - Install Kubernetes Binaries
  hosts: all
  become: true
  vars:
    k8s_version_major: "1.31"
    k8s_pkg_version: "1.31.*"
  tasks:
    # --- KUBERNETES REPO ---
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
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    - name: Add K8s Apt Repository
      apt_repository:
        repo: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ k8s_version_major }}/deb/ /"
        state: present
        filename: kubernetes

    - name: Update apt cache
      apt:
        update_cache: yes

    # --- INSTALL PACKAGES (ALL NODES) ---
    - name: Install Kubelet, Kubeadm, Kubectl
      apt:
        name:
          - kubelet={{ k8s_pkg_version }}
          - kubeadm={{ k8s_pkg_version }}
          - kubectl={{ k8s_pkg_version }}
        state: present
        allow_downgrade: yes

    - name: Hold K8s Packages
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

    # --- CONTROL PLANE TOOLS (CP ONLY) ---
    - name: Install Management Tools on Control Plane
      block:
        - name: Install etcdctl
          apt:
            name: etcd-client
            state: present

        - name: Download Helm Installer
          get_url:
            url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            dest: /tmp/get_helm.sh
            mode: '0700'

        - name: Run Helm Installer
          shell: /tmp/get_helm.sh
          args:
            creates: /usr/local/bin/helm

        - name: Download Cilium CLI
          unarchive:
            src: https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-arm64.tar.gz
            dest: /usr/local/bin
            remote_src: yes
            mode: '0755'
            include: 
              - cilium
      when: "'big' in group_names"
```

### 6.3 Infrastructure Verification
**File:** `tests/infra_test.sh`

This script validates that Phase 1 successfully prepared the nodes.

```bash
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
```

### 6.4 Phase 1 Execution Steps

Run the following commands from your management machine to execute Phase 1.

1.  **Prepare the Nodes:**
    This will reboot the nodes if kernel parameters or cgroups are updated.
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml
    ```

2.  **Install Software:**
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/02_k8s_binaries.yml
    ```

3.  **Verify State:**
    ```bash
    bash tests/infra_test.sh
    ```

## 7. Phase 2: Cluster Bootstrap

In this phase, we initialize the Control Plane, install the networking layer (Cilium), and join the worker nodes.

### 7.1 Cluster Initialization Playbook
**File:** `ansible/playbooks/03_cluster_init.yml`

This complex playbook performs the following:
1.  **Init:** Bootstraps the control plane with `kubeadm`, configured to skip `kube-proxy` (since Cilium replaces it).
2.  **Config:** Sets up the `admin.conf` for the root user on the Pi and fetches it to your local WSL machine.
3.  **Networking:** Installs Cilium via Helm with L2 Announcements enabled.
4.  **Join:** Generates a token and joins the `small` nodes.
5.  **Labels:** Applies the hardware labels (`ram=8gb`, `storage=hdd`, etc.).
6.  **Taints:** Removes the scheduling taint from the Control Plane so it can run workloads.

```yaml
---
- name: Phase 2a - Initialize Control Plane
  hosts: big
  become: true
  vars:
    pod_network_cidr: "10.244.0.0/16"
    service_cidr: "10.96.0.0/12"
    cilium_version: "1.18.4"
  tasks:
    - name: Create kubeadm config
      copy:
        dest: /root/kubeadm-config.yaml
        content: |
          apiVersion: kubeadm.k8s.io/v1beta4
          kind: InitConfiguration
          localAPIEndpoint:
            advertiseAddress: {{ ansible_host }}
            bindPort: 6443
          nodeRegistration:
            criSocket: unix:///run/containerd/containerd.sock
            name: {{ inventory_hostname }}
            taints: [] # Remove taints to allow workloads on CP
          ---
          apiVersion: kubeadm.k8s.io/v1beta4
          kind: ClusterConfiguration
          kubernetesVersion: v1.31.0
          networking:
            serviceSubnet: {{ service_cidr }}
            podSubnet: {{ pod_network_cidr }}
            dnsDomain: cluster.local
          # Skip kube-proxy for Cilium
          skipPhases:
            - addon/kube-proxy

    - name: Check if cluster is already initialized
      stat:
        path: /etc/kubernetes/admin.conf
      register: kube_conf

    - name: Initialize Kubernetes Cluster
      shell: |
        kubeadm init --config /root/kubeadm-config.yaml --upload-certs
      when: not kube_conf.stat.exists

    - name: Create .kube directory for root
      file:
        path: /root/.kube
        state: directory
        mode: '0755'

    - name: Setup kubeconfig for root
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /root/.kube/config
        remote_src: yes

    - name: Install Cilium (Network & L2 Announcements)
      shell: |
        helm repo add cilium https://helm.cilium.io/
        helm repo update
        helm upgrade --install cilium cilium/cilium \
           --version {{ cilium_version }} \
           --namespace kube-system \
           --set kubeProxyReplacement=true \
           --set k8sServiceHost={{ ansible_host }} \
           --set k8sServicePort=6443 \
           --set ipam.mode=kubernetes \
           --set operator.replicas=1 \
           --set bpf.masquerade=true \
           --set nodeinit.enabled=true \
           --set hubble.enabled=true \
           --set hubble.relay.enabled=true \
           --set hubble.ui.enabled=true \
           --set hubble.ui.service.type=NodePort \
           --set l2announcements.enabled=true \
           --set k8sClientRateLimit.qps=50 \
           --set k8sClientRateLimit.burst=100
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Generate Join Token
      command: kubeadm token create --print-join-command
      register: join_command
      changed_when: false

    - name: Fetch kubeconfig to local machine
      fetch:
        src: /etc/kubernetes/admin.conf
        dest: ~/.kube/config
        flat: yes

- name: Phase 2b - Join Workers
  hosts: small
  become: true
  tasks:
    - name: Check if already joined
      stat:
        path: /etc/kubernetes/kubelet.conf
      register: worker_conf

    - name: Join Cluster
      shell: "{{ hostvars[groups['big'][0]]['join_command'].stdout }}"
      when: not worker_conf.stat.exists

- name: Phase 2c - Apply Labels & Post-Config
  hosts: big
  become: true
  tasks:
    - name: Label Control Plane (HDD/8GB)
      shell: |
        export KUBECONFIG=/etc/kubernetes/admin.conf
        kubectl label node {{ inventory_hostname }} hardware/ram=8gb --overwrite
        kubectl label node {{ inventory_hostname }} hardware/sd=128gb --overwrite
        kubectl label node {{ inventory_hostname }} hardware/storage=hdd --overwrite
        kubectl label node {{ inventory_hostname }} hardware/unique-hdd=true --overwrite

    - name: Label Workers (SD/4GB)
      shell: |
        export KUBECONFIG=/etc/kubernetes/admin.conf
        kubectl label node {{ item }} hardware/ram=4gb --overwrite
        kubectl label node {{ item }} hardware/sd=64gb --overwrite
      loop: "{{ groups['small'] }}"
```

### 7.2 Network Verification Script
**File:** `tests/02_network_test.sh`

Checks if all nodes are Ready (Cilium success) and if the Control Plane has the correct storage labels.

```bash
#!/bin/bash
echo "=== NETWORK & CLUSTER VERIFICATION SUITE ==="

# 1. Check Node Readiness
echo "Checking Node Status..."
READY_COUNT=$(kubectl get nodes | grep "Ready" | wc -l)
if [ "$READY_COUNT" -eq 4 ]; then
    echo "✅ All 4 Nodes are Ready"
else
    echo "❌ Waiting for nodes... (Found $READY_COUNT/4 Ready)"
    exit 1
fi

# 2. Check Cilium Pods
echo "Checking Cilium..."
PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium | grep Running | wc -l)
if [ "$PODS" -eq 4 ]; then
    echo "✅ Cilium Agents Running on all nodes"
else
    echo "❌ Cilium pods missing or failed"
    exit 1
fi

# 3. Check Hubble
echo "Checking Hubble..."
kubectl get svc -n kube-system hubble-ui > /dev/null && echo "✅ Hubble UI Service exists"

# 4. Check Labels
echo "Checking Control Plane Labels..."
LABELS=$(kubectl get node rpi4-1 --show-labels)
if [[ $LABELS == *"hardware/unique-hdd=true"* ]]; then
    echo "✅ CP Label (unique-hdd) matches"
else
    echo "❌ CP Labels missing"
    exit 1
fi

echo "=== PHASE 2 COMPLETE ==="
```

### 7.3 Phase 2 Execution Steps

1.  **Run the Cluster Initialization:**
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml
    ```
    *Note: This will overwrite `~/.kube/config` on your local machine.*

2.  **Verify Cluster Status:**
    ```bash
    bash tests/02_network_test.sh
    ```

## 8. Phase 3: Storage Foundation

In this phase, we enable the persistent storage layer. Since Raspberry Pis use SD cards (which are slow and unreliable for heavy writes), we utilize the **1TB HDD** attached to the Control Plane (`rpi4-1`).

We install **Longhorn** as the storage provider. We configure it with **Strict Affinity** rules: it will serve volumes to the entire cluster, but the physical data will *only* be written to the HDD on `rpi4-1`.

### 8.1 Storage Mounting Playbook
**File:** `ansible/playbooks/04_storage_mount.yml`

This playbook runs only on the `big` (Control Plane) node. It formats the USB HDD (if necessary) and mounts it persistently to the path Longhorn expects.

*   **Mount Point:** `/var/lib/longhorn`
*   **Filesystem:** `ext4`

```yaml
---
- name: Phase 3a - Mount HDD for Longhorn
  hosts: big
  become: true
  vars:
    # CHANGE THIS to your actual HDD device identifier (lsblk)
    # Best practice: Use /dev/disk/by-id/... to avoid USB enumeration changes
    hdd_device: "/dev/sda1" 
    mount_path: "/var/lib/longhorn"
  tasks:
    - name: Ensure Mount Directory Exists
      file:
        path: "{{ mount_path }}"
        state: directory
        mode: '0755'

    - name: Format HDD (ext4)
      filesystem:
        fstype: ext4
        dev: "{{ hdd_device }}"
        # force: no # Safety: set to yes only if you want to wipe the drive
      ignore_errors: yes # Ignores error if already formatted

    - name: Mount HDD
      mount:
        path: "{{ mount_path }}"
        src: "{{ hdd_device }}"
        fstype: ext4
        state: mounted
        opts: defaults,noatime

    - name: Verify Mount
      shell: df -h {{ mount_path }}
      register: df_out
      changed_when: false

    - debug:
        msg: "Storage mounted: {{ df_out.stdout }}"
```

### 8.2 Longhorn Bootstrap Script
**File:** `bootstrap/longhorn/install.sh`

This script installs Longhorn via Helm and applies the critical "Day 2" configurations to protect your hardware.

1.  **Install:** Deploys Longhorn v1.10.1 via Helm.
2.  **Label:** Applies `node.longhorn.io/create-default-disk=true` to `rpi4-1` so Longhorn knows where to create the initial storage chunk.
3.  **Restrict:** Patches the configuration of worker nodes (`rpi4-2,3,4`) to set `allowScheduling: false`. This prevents Longhorn from ever trying to save data to their SD cards.

```bash
#!/bin/bash
set -e

echo "=== PHASE 3: LONGHORN BOOTSTRAP ==="

# 1. Add Repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# 2. Install Longhorn (Version locked)
# We set replicaCount=1 because we only have 1 HDD.
echo "Installing Longhorn Chart..."
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.10.1 \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=1 \
  --set defaultSettings.createDefaultDiskLabeledNodes=true \
  --set defaultSettings.allowNodeDrainWithLastHealthyReplica=true \
  --wait

# 3. Configure Control Plane Storage
echo "Configuring Control Plane (HDD) storage..."
kubectl label node rpi4-1 node.longhorn.io/create-default-disk=true --overwrite

# 4. Protect Worker SD Cards
# We disable storage scheduling on all small nodes
echo "Locking out worker nodes from storage duties..."
WORKERS=("rpi4-2" "rpi4-3" "rpi4-4")

for NODE in "${WORKERS[@]}"; do
    echo "Disabling scheduling on $NODE..."
    # We use 'patch' to modify the Longhorn Node CRD directly
    kubectl patch nodes.longhorn.io $NODE -n longhorn-system --type=merge -p '{"spec":{"allowScheduling": false}}' || true
done

echo "=== LONGHORN INSTALLED & CONFIGURED ==="
```

### 8.3 Storage Verification Script
**File:** `tests/03_storage_test.sh`

This script creates a real Persistent Volume Claim (PVC) and a Pod to verify that:
1.  Longhorn can provision storage.
2.  The data is physically written to `rpi4-1`.
3.  A Pod running on a *different* node (e.g., `rpi4-2`) can access that data over the network.

```bash
#!/bin/bash
echo "=== STORAGE VERIFICATION SUITE ==="

# 1. Check System Pods
echo "Checking Longhorn System..."
PODS=$(kubectl get pods -n longhorn-system | grep Running | wc -l)
if [ "$PODS" -gt 10 ]; then
    echo "✅ Longhorn System is Running"
else
    echo "❌ Longhorn pods are missing or crashed"
    kubectl get pods -n longhorn-system
    exit 1
fi

# 2. Check Node Configuration
echo "Checking Disk Scheduling..."
# rpi4-1 should be true, others false
CP_SCHED=$(kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}')
WORKER_SCHED=$(kubectl get nodes.longhorn.io rpi4-2 -n longhorn-system -o jsonpath='{.spec.allowScheduling}')

if [ "$CP_SCHED" == "true" ] && [ "$WORKER_SCHED" == "false" ]; then
    echo "✅ HDD Affinity Configured (Only CP stores data)"
else
    echo "❌ Node Scheduling config is wrong! CP: $CP_SCHED, Worker: $WORKER_SCHED"
    exit 1
fi

# 3. Create Test Workload
echo "Deploying Test PVC & Pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-storage-verify
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: longhorn
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod
spec:
  nodeSelector:
    # Force pod to run on a worker to test network attachment
    hardware/sd: "64gb"
  containers:
  - name: write-test
    image: busybox
    command: ["/bin/sh", "-c", "echo 'Storage Works' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: test-storage-verify
EOF

echo "Waiting for Pod to start (This verifies volume attach)..."
kubectl wait --for=condition=Ready pod/test-storage-pod --timeout=120s

if [ $? -eq 0 ]; then
    echo "✅ Storage Attached Successfully over Network"
    # Cleanup
    kubectl delete pod test-storage-pod
    kubectl delete pvc test-storage-verify
else
    echo "❌ Test Pod failed to start (Volume Attach Error?)"
    kubectl describe pod test-storage-pod
    exit 1
fi

echo "=== PHASE 3 COMPLETE ==="
```

### 8.4 Phase 3 Execution Steps

1.  **Mount the HDD:**
    *(Ensure your HDD is plugged into `rpi4-1` and check `lsblk` to confirm the device name matches the playbook vars).*
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/04_storage_mount.yml
    ```

2.  **Install Longhorn:**
    Run this script from your management machine (requires `helm` and `kubectl` access to the cluster).
    ```bash
    bash bootstrap/longhorn/install.sh
    ```

3.  **Verify Storage:**
    ```bash
    bash tests/03_storage_test.sh
    ```

## 9. Phase 4: GitOps & Observability

We now move up the stack to the application layer. Instead of managing tools individually, we establish the **GitOps Loop**.

**The Bootstrap Order:**
1.  **Traefik:** Provides the LoadBalancer IP (`192.168.68.210`) and routing so we can access UIs.
2.  **ArgoCD:** The controller that syncs Git state to the Cluster.
3.  **Gitea:** The internal Git server where our cluster configuration will live.
4.  **App of Apps:** A single manifest that tells ArgoCD to install everything else (Observability, Security, etc.).

### 9.1 Ingress Bootstrap (Traefik)
**File:** `bootstrap/traefik/install.sh`

This script installs **Traefik v3**. It is configured to:
*   Request the specific LoadBalancer IP (`192.168.68.210`) from Cilium.
*   Redirect HTTP to HTTPS globally.
*   Expose Prometheus metrics for the Observability stack.
*   Enable JSON access logs for the Logging stack (Loki).

```bash
#!/bin/bash
set -e
echo "=== PHASE 4a: TRAEFIK BOOTSTRAP ==="

# 1. Add Repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 2. Install Traefik v3
# We use --set-string for annotations to avoid Helm integer parsing errors on port "9100"
echo "Deploying Traefik..."
helm upgrade --install traefik traefik/traefik \
  --namespace traefik-system \
  --create-namespace \
  --version 37.3.0 \
  --set service.type=LoadBalancer \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set providers.kubernetesCRD.allowCrossNamespace=true \
  --set logs.general.level=INFO \
  --set logs.access.enabled=true \
  --set logs.access.format=json \
  --set metrics.prometheus.enabled=true \
  --set metrics.prometheus.addEntryPointsLabels=true \
  --set metrics.prometheus.addRoutersLabels=true \
  --set-string service.annotations."prometheus\.io/scrape"="true" \
  --set-string service.annotations."prometheus\.io/port"="9100" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="100Mi" \
  --set resources.limits.cpu="500m" \
  --set resources.limits.memory="300Mi" \
  --wait

echo "=== TRAEFIK INSTALLED ==="
echo "External IP should be assigned shortly."
```

### 9.2 GitOps Bootstrap (ArgoCD)
**File:** `bootstrap/argocd/install.sh`

This script installs **ArgoCD**.
*   **Insecure Mode:** We disable ArgoCD's internal TLS because Traefik handles SSL termination at the ingress level.
*   **Ingress:** We automatically apply an Ingress rule so the UI is accessible at `argocd.192.168.68.210.nip.io`.

```bash
#!/bin/bash
set -e
echo "=== PHASE 4b: ARGOCD BOOTSTRAP ==="

# 1. Add Repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Install ArgoCD
# We use --insecure to offload TLS to Traefik
echo "Deploying ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.0 \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set global.logging.format=json \
  --wait

# 3. Expose UI via Ingress
echo "Creating Ingress Rule..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: argocd.192.168.68.210.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

echo "=== ARGOCD READY ==="
echo "URL: http://argocd.192.168.68.210.nip.io"
echo "Get Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

### 9.3 Source Control Service (Gitea)
**File:** `gitops/services/gitea.yaml`

This is our first **Declarative Application**. Instead of a shell script, this is a YAML file we feed to ArgoCD.
*   **Database:** Deploys a dedicated PostgreSQL instance managed by the chart.
*   **Storage:** Uses the `longhorn` storage class (HDD).
*   **UI:** Configured with a modern theme and mapped to `gitea.192.168.68.210.nip.io`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
spec:
  project: default
  source:
    repoURL: https://dl.gitea.com/charts/
    chart: gitea
    targetRevision: 10.6.0
    helm:
      values: |
        global:
          storageClass: longhorn
        
        gitea:
          admin:
            existingSecret: "" # We create admin on first login
          config:
            APP_NAME: "PiCluster Git"
            server:
              DOMAIN: "gitea.192.168.68.210.nip.io"
              ROOT_URL: "http://gitea.192.168.68.210.nip.io/"
              SSH_DOMAIN: "192.168.68.210"
              SSH_PORT: "2222"
              DEFAULT_THEME: "gitea-auto"
            service:
              DISABLE_REGISTRATION: false

          resources:
            requests:
              memory: 256Mi
              cpu: 100m
            limits:
              memory: 1Gi
              cpu: 1000m

        persistence:
          enabled: true
          size: 10Gi

        postgresql:
          enabled: true
          global:
            storageClass: longhorn
          primary:
            persistence:
              size: 5Gi

        ingress:
          enabled: true
          className: traefik
          hosts:
            - host: gitea.192.168.68.210.nip.io
              paths:
                - path: /
                  pathType: Prefix
          annotations:
            traefik.ingress.kubernetes.io/router.entrypoints: web

        service:
          ssh:
            type: LoadBalancer
            port: 2222
            annotations: 
              io.cilium/lb-ipam-ips: "192.168.68.210"
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 9.4 The "App of Apps" Pattern
**File:** `gitops/app-of-apps.yaml`

This is the master controller. It points to your Git repository (once created in Gitea) and recursively installs everything else defined in the `gitops/` folder (Security, Observability, Management).

*Note: Initially, this will be manual. Once you migrate the code to Gitea (Step 9.5), you will update the `repoURL` here.*

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 66.3.0
    helm:
      values: |
        prometheus:
          prometheusSpec:
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: longhorn
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 10Gi
            resources:
              limits:
                memory: 500Mi

        grafana:
          persistence:
            enabled: true
            storageClassName: longhorn
            size: 2Gi
          ingress:
            enabled: true
            ingressClassName: traefik
            hosts:
              - grafana.192.168.68.210.nip.io
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: web

        alertmanager:
          alertmanagerSpec:
            storage:
              volumeClaimTemplate:
                spec:
                  storageClassName: longhorn
                  resources:
                    requests:
                      storage: 2Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### 9.5 Phase 4 Execution Steps

1.  **Install Traefik:**
    ```bash
    bash bootstrap/traefik/install.sh
    ```
    *Verify: `kubectl get svc -n traefik-system` should show External-IP `192.168.68.210`.*

2.  **Install ArgoCD:**
    ```bash
    bash bootstrap/argocd/install.sh
    ```
    *Verify: Open `http://argocd.192.168.68.210.nip.io` and login with the secret password.*

3.  **Deploy Gitea (via ArgoCD):**
    ```bash
    kubectl apply -f gitops/services/gitea.yaml
    ```
    *Wait 5 minutes. Verify: Open `http://gitea.192.168.68.210.nip.io` and create your admin account.*

4.  **The Pivot (Critical Step):**
    *   Create a repository in Gitea named `home-cluster`.
    *   Push your local `gitops/` folder to this new repo.
    *   (Optional) Modify the `gitea.yaml` and `app-of-apps.yaml` to point to your new `http://gitea...` repo URL instead of public charts, completing the loop.

5.  **Deploy Observability:**
    ```bash
    kubectl apply -f gitops/app-of-apps.yaml
    ```
    *Verify: Open `http://grafana.192.168.68.210.nip.io`.*

## 10. Phase 5: Security & Management Stack

Now that the GitOps engine is running, we utilize it to deploy the infrastructure dependencies required for a secure, production-grade environment.

### 10.1 Object Storage (MinIO)
**File:** `gitops/storage/minio.yaml`

Many Cloud Native tools (Velero, Thanos, Loki, Harbor) expect an AWS S3 bucket. Since we are on bare metal, we self-host **MinIO** to provide this API.
*   **Storage:** Uses Longhorn (HDD) for the data backing.
*   **Buckets:** Automatically provisions buckets for `velero`, `loki`, `harbor`, and `thanos`.
*   **Access:** Exposed via Console Ingress (`minio.192.168.68.210.nip.io`).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
spec:
  project: default
  source:
    repoURL: https://charts.min.io/
    chart: minio
    targetRevision: 5.2.0
    helm:
      values: |
        mode: standalone
        replicas: 1
        persistence:
          enabled: true
          storageClass: longhorn
          size: 50Gi
          accessMode: ReadWriteOnce
        
        resources:
          requests:
            memory: 256Mi
          limits:
            memory: 512Mi

        # Create buckets automatically on startup
        buckets:
          - name: velero
            policy: none
            purge: false
          - name: harbor
            policy: none
            purge: false
          - name: loki-data
            policy: none
            purge: false
          - name: thanos-data
            policy: none
            purge: false

        ingress:
          enabled: true
          ingressClassName: traefik
          hosts:
            - minio.192.168.68.210.nip.io
          annotations:
            traefik.ingress.kubernetes.io/router.entrypoints: web

        # Default credentials (CHANGE IN PRODUCTION)
        rootUser: admin
        rootPassword: password123
  destination:
    server: https://kubernetes.default.svc
    namespace: storage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 10.2 Certificate Automation (Cert-Manager)
**File:** `gitops/infrastructure/cert-manager.yaml`

Cert-Manager handles TLS certificates within the cluster.
*   **Self-Signed Issuer:** Configured to issue self-signed certificates locally. This prevents the "Not Secure" browser warnings from escalating into connection errors, while avoiding the complexity of external DNS validation (Let's Encrypt) for this private setup.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.16.0
    helm:
      parameters:
        - name: installCRDs
          value: "true"
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 10.3 Container Registry (Harbor)
**File:** `gitops/security/harbor.yaml`

Harbor serves as the local "Docker Hub".
*   **Dependency:** Connects to the **MinIO** S3 service installed above for storing huge container images (keeping them off the SD cards).
*   **Scanning:** Trivy is enabled to scan every uploaded image for CVEs.
*   **Database:** Uses internal PostgreSQL backed by Longhorn.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: harbor
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://helm.goharbor.io
    chart: harbor
    targetRevision: 1.15.0
    helm:
      values: |
        expose:
          type: ingress
          ingress:
            hosts:
              core: harbor.192.168.68.210.nip.io
            className: traefik
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: web
        
        # Point to our local MinIO
        persistence:
          imageChartStorage:
            type: s3
            s3:
              region: us-east-1
              bucket: harbor
              endpoint: http://minio.storage.svc.cluster.local:9000
              accesskey: admin
              secretkey: password123
              storageclass: STANDARD

        # Disable Notary/ChartMuseum to save RAM on Pis
        notary:
          enabled: false
        chartmuseum:
          enabled: false
        
        # Keep Trivy for security scanning
        trivy:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: harbor
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 10.4 Backup & Restore (Velero)
**File:** `gitops/management/velero.yaml`

Velero performs nightly backups of the cluster configuration and persistent volumes.
*   **Target:** Stores backups in the `velero` bucket on MinIO.
*   **Volume Snapshots:** Integrated with Longhorn CSI to take snapshots of the HDD data.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velero
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://vmware-tanzu.github.io/helm-charts
    chart: velero
    targetRevision: 5.1.0
    helm:
      values: |
        configuration:
          provider: aws
          backupStorageLocation:
            bucket: velero
            config:
              region: minio
              s3ForcePathStyle: true
              s3Url: http://minio.storage.svc.cluster.local:9000
          volumeSnapshotLocation:
            config:
              region: minio
        
        credentials:
          useSecret: true
          secretContents:
            cloud: |
              [default]
              aws_access_key_id = admin
              aws_secret_access_key = password123

        initContainers:
          - name: velero-plugin-for-aws
            image: velero/velero-plugin-for-aws:v1.9.0
            volumeMounts:
              - mountPath: /target
                name: plugins
  destination:
    server: https://kubernetes.default.svc
    namespace: velero
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
### 10.5 Secrets Management (OpenBao)
**File:** `gitops/security/openbao.yaml`
We use OpenBao (the community fork of Vault) to handle secrets securely.
*   **Storage:** Uses Longhorn (HDD) to persist encrypted secrets.
*   **UI:** Exposed internally via LoadBalancer.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openbao
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://openbao.github.io/openbao-helm
    chart: openbao
    targetRevision: 0.1.0
    helm:
      values: |
        server:
          dataStorage:
            enabled: true
            size: 10Gi
            storageClass: longhorn
          ha:
            enabled: false # Standalone mode for Pi resources
        ui:
          enabled: true
          serviceType: LoadBalancer
  destination:
    server: https://kubernetes.default.svc
    namespace: security
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 10.6 Policy Enforcement (Kyverno)
**File:** `gitops/security/kyverno.yaml`
Kyverno enforces best practices (e.g., preventing root containers) without the complexity of OPA Gatekeeper.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kyverno.github.io/kyverno/
    chart: kyverno
    targetRevision: 3.1.4
    helm:
      values: |
        admissionController:
          replicas: 1
        backgroundController:
          replicas: 1
        cleanupController:
          replicas: 1
        reportsController:
          replicas: 1
  destination:
    server: https://kubernetes.default.svc
    namespace: kyverno
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 10.7 Runtime Security (Falco)
**File:** `gitops/security/falco.yaml`
Monitors kernel syscalls to detect intrusions. We explicitly configure the **eBPF driver** because the traditional kernel module driver is often problematic on Ubuntu RPi kernels.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: falco
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://falcosecurity.github.io/charts/
    chart: falco
    targetRevision: 4.0.0
    helm:
      values: |
        driver:
          kind: ebpf
        falcosidekick:
          enabled: true
          webui:
            enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: security
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
    
### 10.8 The Root Application (App of Apps)
**File:** `gitops/root-app.yaml`

This is the "One Ring to Rule Them All." Instead of applying the files above individually, we point ArgoCD to this single file (or eventually, to the Git repo containing it). It tells ArgoCD to deploy the entire stack defined in the `gitops/` directory structure.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.192.168.68.210.nip.io/liviu/home-cluster.git
    targetRevision: main
    path: gitops
    directory:
      recurse: true
      exclude: "{apps/*,services/*}" # Avoid infinite loops with existing apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
### 10.9 Security Verification Script
**File:** `tests/04_security_test.sh`

This script verifies that your security policies are enforced and services are accessible.
1.  **Kyverno:** Attempts to create a pod violating the "no-latest-tag" policy. It expects a failure.
2.  **Falco:** Verifies the eBPF probes are running.
3.  **Harbor:** Checks API availability.

```bash
#!/bin/bash
echo "=== SECURITY STACK VERIFICATION ==="

# 1. Kyverno Policy Test
echo "Testing Kyverno Policy Enforcement..."
# We try to run a pod that violates policies. It MUST fail for the test to pass.
kubectl run kyverno-test-fail --image=nginx:latest --dry-run=server 2>&1 | grep "disallowed" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Kyverno blocked 'latest' tag: PASS"
else
    echo "⚠️  Kyverno allowed 'latest' tag (Policies might not be loaded yet)"
fi

# 2. Falco Status
echo "Checking Falco (Runtime Security)..."
PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=falco | grep Running | wc -l)
if [ "$PODS" -ge 1 ]; then
    echo "✅ Falco eBPF Probes Running"
else
    echo "❌ Falco is not running"
    exit 1
fi

# 3. Harbor Registry
echo "Checking Harbor Registry..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://harbor.192.168.68.210.nip.io/api/v2.0/ping)
if [ "$STATUS" -eq 200 ]; then
    echo "✅ Harbor API is Live (200 OK)"
else
    echo "❌ Harbor API Unreachable (HTTP $STATUS)"
    exit 1
fi

echo "=== SECURITY CHECK COMPLETE ==="
```

### 10.10 Phase 5 Execution Steps

1.  **Commit Files:** Ensure the files above are created in your local `gitops/` folder.
2.  **Push to Gitea:**
    ```bash
    git add .
    git commit -m "Add Security and Management stack"
    git push origin main
    ```
3.  **Apply Root App:**
    ```bash
    kubectl apply -f gitops/root-app.yaml
    ```
4.  **Verification:**
    *   **MinIO Console:** `http://minio.192.168.68.210.nip.io` (User: `admin`, Pass: `password123`)
    *   **Harbor Registry:** `http://harbor.192.168.68.210.nip.io` (Default User: `admin`, Pass: `Harbor12345`)

## 11. Phase 6: Advanced Observability

In this phase, we complete the observability pillar. Metrics (Prometheus) tell you *what* is happening, but Logs (Loki) tell you *why*. We also add cost estimation and AI analysis to help manage the cluster.

### 11.1 Log Aggregation (Loki & Promtail)
**File:** `gitops/observability/loki-stack.yaml`

We use the **PLG Stack** (Promtail, Loki, Grafana).
*   **Promtail:** Runs on every node (DaemonSet), reads logs from `/var/log/containers`, and pushes them to Loki.
*   **Loki:** Stores logs efficiently. We configure it to use **MinIO** (installed in Phase 5) for long-term storage instead of filling up the pod's local volume.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: loki-stack
    targetRevision: 2.10.2
    helm:
      values: |
        loki:
          enabled: true
          persistence:
            enabled: true
            storageClassName: longhorn
            size: 10Gi
          config:
            schema_config:
              configs:
                - from: 2024-04-01
                  store: boltdb-shipper
                  object_store: s3
                  schema: v11
                  index:
                    prefix: index_
                    period: 24h
            storage_config:
              aws:
                s3: http://admin:password123@minio.storage.svc.cluster.local:9000/loki-data
                s3forcepathstyle: true
        
        promtail:
          enabled: true
          config:
            clients:
              - url: http://loki-stack:3100/loki/api/v1/push
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
### 11.2 Log Collection (Fluent Bit)
**File:** `gitops/observability/fluent-bit.yaml`
*Note:* You requested Fluentd, but **Fluent Bit** is the industry standard for Edge/Raspberry Pi. It is written in C (vs Ruby for Fluentd) and uses ~10x less RAM. It is configured here to forward logs to the Loki stack.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fluent-bit
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://fluent.github.io/helm-charts
    chart: fluent-bit
    targetRevision: 0.44.0
    helm:
      values: |
        config:
          outputs: |
            [OUTPUT]
                Name loki
                Match *
                Host loki-stack.monitoring.svc.cluster.local
                Port 3100
                Labels job=fluent-bit
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 11.3 Distributed Tracing (OpenTelemetry)
**File:** `gitops/observability/opentelemetry.yaml`
Installs the OpenTelemetry Operator. This allows you to inject tracing sidecars into your applications automatically.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opentelemetry-operator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
    chart: opentelemetry-operator
    targetRevision: 0.49.0
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
### 11.4 Tracing Backend (Jaeger)
**File:** `gitops/observability/jaeger.yaml`

Jaeger provides the UI to visualize the distributed traces collected by OpenTelemetry.
*   **Storage:** Configured to use memory (limited size) for Raspberry Pi resource efficiency, as ElasticSearch is too heavy for this setup.
*   **Ingress:** Exposed via Traefik.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jaeger
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://jaegertracing.github.io/helm-charts
    chart: jaeger
    targetRevision: 3.0.0
    helm:
      values: |
        provisionDataStore:
          cassandra: false
          elasticsearch: false
          kafka: false
        allInOne:
          enabled: true
          # Limit in-memory traces to prevent OOM
          args: ["--memory.max-traces=1000"] 
          resources:
            limits:
              memory: 512Mi
        storage:
          type: memory
        query:
          ingress:
            enabled: true
            ingressClassName: traefik
            hosts:
              - jaeger.192.168.68.210.nip.io
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: web
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 11.5 Traffic Analysis (Kubeshark)
**File:** `gitops/observability/kubeshark.yaml`
Provides deep visibility into API traffic (HTTP, REST, gRPC, GraphQL) similar to Wireshark, but for K8s.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeshark
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://helm.kubeshark.co
    chart: kubeshark
    targetRevision: 52.3.0
    helm:
      values: |
        tap:
          persistentStorage: true
          storageClass: longhorn
          storageSize: 5Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 11.6 Cost Management (OpenCost)
**File:** `gitops/observability/opencost.yaml`

OpenCost calculates the resource consumption (CPU/RAM/Storage) of every pod and estimates a "cloud cost" equivalent. This is excellent for understanding which namespace is hogging resources on your Raspberry Pis.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opencost
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://opencost.github.io/opencost-helm-chart
    chart: opencost
    targetRevision: 1.29.0
    helm:
      values: |
        opencost:
          exporter:
            defaultClusterId: "rpi-cluster"
          prometheus:
            external:
              url: "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
        ingress:
          enabled: true
          className: traefik
          hosts:
            - opencost.192.168.68.210.nip.io
          annotations:
            traefik.ingress.kubernetes.io/router.entrypoints: web
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 11.7 AI Diagnostics (K8sGPT)
**File:** `gitops/observability/k8sgpt.yaml`

K8sGPT scans your cluster for issues (CrashLoops, PVC failures, Service misconfigs) and uses an AI backend to explain the fix in plain English.
*   **Backend:** Configured here to use the public OpenAI API (requires an API Key) or LocalAI if you host it. *Note: Replace `YOUR_OPENAI_TOKEN` in the secret manually or use the OpenBao vault later.*

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8sgpt
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.k8sgpt.ai/
    chart: k8sgpt-operator
    targetRevision: 0.1.4
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 11.8 Full Stack APM (SigNoz)
**File:** `gitops/observability/signoz.yaml`

SigNoz is an open-source alternative to Datadog. It provides traces, metrics, and logs in a single UI.
*   **Warning:** SigNoz is resource-heavy (ClickHouse database). We configure it with strict limits to fit on the Pi cluster. It serves as a redundant learning tool alongside Prometheus.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: signoz
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.signoz.io
    chart: signoz
    targetRevision: 0.36.0
    helm:
      values: |
        global:
          storageClass: longhorn
        
        # Limit ClickHouse resource usage
        clickhouse:
          resources:
            limits:
              memory: 1Gi
              cpu: 1000m
            requests:
              memory: 512Mi
              cpu: 500m
        
        queryService:
          resources:
            limits:
              memory: 512Mi
        
        frontend:
          ingress:
            enabled: true
            className: traefik
            hosts:
              - host: signoz.192.168.68.210.nip.io
                paths:
                  - path: /
                    pathType: Prefix
  destination:
    server: https://kubernetes.default.svc
    namespace: signoz
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 11.9 Observability Verification Script
**File:** `tests/05_observability_test.sh`

This script ensures data is flowing through your pipelines.
1.  **Prometheus:** Checks if scrape targets are active via the API.
2.  **Loki:** Checks if the database is up.
3.  **K8sGPT:** Verifies the AI operator is active.

```bash
#!/bin/bash
echo "=== OBSERVABILITY STACK VERIFICATION ==="

# 1. Prometheus Targets
echo "Checking Prometheus Targets..."
# Port-forward to query internal API
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 > /dev/null 2>&1 &
PID=$!
sleep 3
UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length')
kill $PID

if [ "$UP_TARGETS" -gt 0 ]; then
    echo "✅ Prometheus is scraping $UP_TARGETS targets"
else
    echo "❌ Prometheus has 0 targets"
    exit 1
fi

# 2. Loki Log Ingestion
echo "Checking Loki Status..."
kubectl get pods -n monitoring -l app=loki | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Loki Database is Running"
else
    echo "❌ Loki is down"
    exit 1
fi

# 3. K8sGPT
echo "Checking AI Diagnostics..."
kubectl get pods -n observability -l app.kubernetes.io/name=k8sgpt-operator | grep Running > /dev/null && echo "✅ K8sGPT Operator is Active"

echo "=== OBSERVABILITY CHECK COMPLETE ==="
```

### 11.10 Phase 6 Execution Steps

1.  **Commit:** Save the YAML files to `gitops/observability/` locally.
    ```bash
    git add .
    git commit -m "Add Advanced Observability stack"
    git push origin main
    ```
    *(ArgoCD will pick up the changes if you configured the Root App, or you can apply them manually).*

2.  **Verify Loki:**
    *   Open Grafana (`http://grafana.192.168.68.210.nip.io`).
    *   Go to **Data Sources**.
    *   Add Data Source -> **Loki**.
    *   URL: `http://loki-stack:3100`.
    *   Go to **Explore**, select **Loki**, and run query `{namespace="monitoring"}` to see logs.

3.  **Verify OpenCost:**
    *   Open `http://opencost.192.168.68.210.nip.io`.
    *   You should see a breakdown of costs per namespace.

4.  **Verify SigNoz:**
    *   Open `http://signoz.192.168.68.210.nip.io`.
    *   Create an admin account and view the "Services" dashboard.

## 12. Phase 7: CI/CD & Developer Experience

In this final phase, we establish the machinery that builds, tests, and releases code. We replace manual `docker build` commands with an automated pipeline and ensure every change is scanned for security vulnerabilities before reaching production.

### 12.1 Image Automation (Argo Image Updater)
**File:** `gitops/cicd/argo-image-updater.yaml`

This component watches your **Harbor** registry. When a CI pipeline pushes a new image tag (e.g., `v1.0.1`), this tool automatically updates the Git repository (modifying the ArgoCD Application) to reflect the new version.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-image-updater
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argocd-image-updater
    targetRevision: 0.9.1
    helm:
      values: |
        config:
          registries:
            - name: harbor.192.168.68.210.nip.io
              api_url: https://harbor.192.168.68.210.nip.io
              prefix: harbor.192.168.68.210.nip.io/library
              ping: yes
              insecure: yes # Self-signed certs
              credentials: secret:argocd/harbor-creds#password
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 12.2 CI/CD Platform (Jenkins)
**File:** `gitops/cicd/jenkins.yaml`

We deploy **Jenkins** configured as a Kubernetes-native Controller.
*   **Agents:** Instead of static agents, Jenkins spawns short-lived Pods in the cluster to run build jobs.
*   **Integration:** Pre-configured to talk to Gitea and Harbor.
*   **Persistence:** Stores job history on Longhorn (HDD).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jenkins
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.jenkins.io
    chart: jenkins
    targetRevision: 5.1.0
    helm:
      values: |
        controller:
          # Use Longhorn HDD for Jenkins Home
          storageClass: longhorn
          accessMode: ReadWriteOnce
          size: 10Gi
          
          # Resource limits for Pi
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1536Mi"
          
          # Expose UI via Traefik
          ingress:
            enabled: true
            ingressClassName: traefik
            hostName: jenkins.192.168.68.210.nip.io
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: web

          # JCasC (Configuration as Code) - Pre-configure Kubernetes Cloud
          JCasC:
            defaultConfig: true
            configScripts:
              cloud-config: |
                jenkins:
                  clouds:
                    - kubernetes:
                        name: "kubernetes"
                        serverUrl: "https://kubernetes.default"
                        namespace: "jenkins"
                        jenkinsUrl: "http://jenkins.jenkins.svc.cluster.local:8080"
                        templates:
                          - name: "builder"
                            namespace: "jenkins"
                            label: "builder"
                            nodeUsageMode: "EXCLUSIVE"
                            containers:
                              - name: "jnlp"
                                image: "jenkins/inbound-agent:alpine"
                                resourceRequestCpu: "100m"
                                resourceRequestMemory: "256Mi"
  destination:
    server: https://kubernetes.default.svc
    namespace: jenkins
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 12.3 Security Tooling (Trivy & OWASP ZAP)

Rather than installing these as standalone long-running services, we install the **Trivy Operator** to scan the running cluster, and we provide the configurations to run ZAP/Trivy inside CI pipelines.

**File:** `gitops/security/trivy-operator.yaml`
Scans running pods and generates "VulnerabilityReports" visible in the cluster.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: trivy-operator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://aquasecurity.github.io/helm-charts/
    chart: trivy-operator
    targetRevision: 0.19.1
    helm:
      values: |
        trivy:
          ignoreUnfixed: true
        serviceMonitor:
          enabled: true # Integration with Prometheus
  destination:
    server: https://kubernetes.default.svc
    namespace: security
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Note on OWASP ZAP:**
OWASP ZAP is best run as a step in your Jenkins pipeline (`Jenkinsfile`) against a staging URL. It does not require a standalone Helm installation for this architecture.

### 12.4 Local Development (Skaffold) (optional)

To enable rapid iteration on your local machine without pushing git commits for every line of code change, use **Skaffold**.

**Setup Instructions (Run on Local Machine):**
1.  Install Skaffold: `choco install skaffold` (Windows) or `brew install skaffold`.
2.  Create a `skaffold.yaml` in your application source code repo:

```yaml
apiVersion: skaffold/v4beta3
kind: Config
metadata:
  name: my-app
build:
  artifacts:
  - image: harbor.192.168.68.210.nip.io/library/my-app
    docker:
      dockerfile: Dockerfile
manifests:
  rawYaml:
  - k8s/deployment.yaml
deploy:
  kubectl:
    manifests:
    - k8s/deployment.yaml
```

3.  Run `skaffold dev`.
    *   Skaffold will watch your source files.
    *   On save, it builds the image, pushes to Harbor, and redeploys to the Raspberry Pi cluster in seconds.

### 12.5 CI/CD Verification Script
**File:** `tests/06_cicd_test.sh`

Verifies the build machinery components.
1.  **Jenkins:** Checks controller availability.
2.  **Trivy:** Checks if vulnerability reports are being generated for running pods.

```bash
#!/bin/bash
echo "=== CI/CD PIPELINE VERIFICATION ==="

# 1. Jenkins Status
echo "Checking Jenkins Controller..."
kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Jenkins Controller is Running"
else
    echo "❌ Jenkins is down"
    exit 1
fi

# 2. Trivy Scanning
echo "Checking Security Scans..."
REPORTS=$(kubectl get vulnerabilityreports -A | wc -l)
if [ "$REPORTS" -gt 0 ]; then
    echo "✅ Trivy is generating reports ($REPORTS found)"
else
    echo "⚠️  No Vulnerability Reports found yet (Trivy might still be scanning)"
fi

echo "=== CI/CD CHECK COMPLETE ==="
```

### 12.6 Phase 7 Execution Steps

1.  **Commit & Push:**
    Save the YAML files to `gitops/cicd/` and `gitops/security/`.
    ```bash
    git add .
    git commit -m "Add Jenkins, Image Updater, and Security Scanners"
    git push origin main
    ```

2.  **Verify Jenkins:**
    *   Open `http://jenkins.192.168.68.210.nip.io`.
    *   **User:** `admin`.
    *   **Password:** Retrieve via:
        ```bash
        kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d; echo
        ```

3.  **Verify Image Updater:**
    Check the logs to ensure it can connect to Harbor:
    ```bash
    kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater
    ```

4.  **Verify Trivy Operator:**
    Check for security reports generated for your existing pods:
    ```bash
    kubectl get vulnerabilityreports -A
    ```
## 13. Phase 8: Day 2 Operations & Maintenance

This section outlines the routine tasks required to keep the cluster secure and up-to-date.

### 13.1 Upgrading Kubernetes
Since we pinned versions in Ansible, upgrades must be deliberate.
**Upgrade Order:** Control Plane -> Workers.

1.  **Un-hold packages (Ansible):**
    Update `ansible/hosts` vars to the new version (e.g., `1.32`) and run a playbook to unhold and update `kubeadm`.
2.  **Upgrade Control Plane:**
    ```bash
    # On rpi4-1
    sudo kubeadm upgrade plan
    sudo kubeadm upgrade apply v1.32.x
    ```
3.  **Upgrade Kubelet:**
    ```bash
    # On all nodes (via Ansible)
    sudo apt-get install -y kubelet=1.32.x-1.1 kubectl=1.32.x-1.1
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
    ```

### 13.2 OS Patching
To apply Linux security patches without downtime, drain nodes one by one.

```bash
# 1. Drain Node (Move workloads elsewhere)
kubectl drain rpi4-2 --ignore-daemonsets --delete-emptydir-data

# 2. Run Ansible Update
ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml --limit rpi4-2

# 3. Uncordon (Allow workloads back)
kubectl uncordon rpi4-2
```

### 13.3 Backup & Disaster Recovery
We utilize **Velero** (installed in Phase 5).

*   **Manual Backup:**
    ```bash
    velero backup create manual-backup-$(date +%F) --from-schedule=nightly
    ```
*   **Restore:**
    ```bash
    # Disaster scenario: Cluster wiped.
    # 1. Re-install Infrastructure & Velero.
    # 2. Run restore:
    velero restore create --from-backup manual-backup-2025-11-20
    ```

### 13.4 Troubleshooting Cheatsheet
*   **Cilium Connectivity:** `cilium connectivity test`
*   **Longhorn Disk Pressure:** Check UI for "Schedulable" status on `rpi4-1`.
*   **DNS Issues:** `kubectl run -it --rm --restart=Never busybox --image=busybox:1.28 -- nslookup kubernetes.default`
*   **ArgoCD Sync Stuck:** `argocd app sync <app-name> --prune --force`

---

## Final Deliverable: File Checklist

You should now have the following files created in your repository folder. **This is your complete Project Artifact.**

### 1. Root
*   `README.md` (The complete guide we generated)

### 2. Ansible (Infrastructure)
*   `ansible/hosts`
*   `ansible/playbooks/01_node_prep.yml`
*   `ansible/playbooks/02_k8s_binaries.yml`
*   `ansible/playbooks/03_cluster_init.yml`
*   `ansible/playbooks/04_storage_mount.yml`

### 3. Bootstrap (Shell Scripts)
*   `bootstrap/cilium/install.sh` *(Embedded in playbook, but good to have standalone)*
*   `bootstrap/longhorn/install.sh`
*   `bootstrap/traefik/install.sh`
*   `bootstrap/argocd/install.sh`

### 4. GitOps (ArgoCD Manifests)
*   `gitops/app-of-apps.yaml` (The Root)
*   `gitops/infrastructure/cert-manager.yaml`
*   `gitops/services/gitea.yaml`
*   `gitops/storage/minio.yaml`
*   `gitops/observability/kube-prometheus-stack.yaml` (Implicit in app-of-apps example, ensures monitoring)
*   `gitops/observability/loki-stack.yaml`
*   `gitops/observability/opencost.yaml`
*   `gitops/observability/k8sgpt.yaml`
*   `gitops/observability/signoz.yaml`
*   `gitops/security/harbor.yaml`
*   `gitops/security/trivy-operator.yaml`
*   `gitops/cicd/argo-image-updater.yaml`
*   `gitops/cicd/jenkins.yaml`
*   `gitops/management/velero.yaml`

### 5. Tests (Validation)
*   `tests/01_infra_test.sh`
*   `tests/02_network_test.sh`
*   `tests/03_storage_test.sh`

***

