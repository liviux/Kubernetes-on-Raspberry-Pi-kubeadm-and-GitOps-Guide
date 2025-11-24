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

