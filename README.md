# Kubernetes Cluster on Raspberry Pi 4: Bare Metal GitOps Guide

## 1. Introduction and Scope
This project establishes a production-grade "Cloud Native" Kubernetes cluster on bare metal Raspberry Pi 4 hardware. The objective is to build a self-healing, observable, and secure platform managed entirely through **GitOps** principles.

This guide serves as the definitive roadmap for reproducing the cluster from scratch, ensuring that the infrastructure (Ansible) and the application state (ArgoCD) are version-controlled and automated.

## 2. Architecture Overview

### Hardware Topology
*   **Control Plane (rpi4-1):** 8GB RAM, 128GB SD, 1TB HDD.
    *   *Role:* Kubernetes API, Etcd, and **Primary Storage Node**.
    *   *Labels:* `ram=8gb`, `storage=hdd`, `unique-hdd=true`.
    *   *Taints:* Untainted to allow workloads, but reserved primarily for critical storage components.
*   **Worker Nodes (rpi4-2, 3, 4):** 4GB RAM, 64GB SD.
    *   *Role:* Stateless workload execution.
    *   *Protection:* Configured to block persistent storage writes to prevent SD card burnout.

### Software Stack & Justification

#### **A. Orchestration & Deployment**
*   **Kubernetes (Kubeadm):** The foundation. Installed via Ansible for a pure upstream experience.
*   **Helm:** The package manager used by ArgoCD to deploy applications.
*   **ArgoCD + Image Updater:** The GitOps engine. Monitors this repository and syncs changes to the cluster automatically. Image Updater automates container version bumps.
*   **JenkinsX:** The CI/CD automation platform. Handles complex pipelines (linting, building, releasing) and orchestrates the testing suites.

#### **B. Network Layer**
*   **Cilium:** The CNI plugin. Replaces `kube-proxy` with eBPF for superior performance and security. **Hubble:** Network observability tool (part of Cilium) to visualize communication maps. **Tetragon:** eBPF-based security observability and runtime enforcement.
*   **Traefik:** The Ingress Controller. Manages external access to services and handles LoadBalancing via Cilium L2 Announcements.

#### **C. Observability Stack**
*   **Prometheus Operator (Prometheus + Alertmanager):** The standard for metrics collection and alerting.
*   **Thanos:** Provides long-term storage for Prometheus metrics (deduplication and downsampling).
*   **Grafana:** Visual dashboarding for metrics and logs.
*   **Fluentd:** The log collector. Gathers logs from all nodes and processes them.
*   **Loki:** The log database. Stores logs indexed by labels.
*   **OpenTelemetry + Jaeger:** Distributed tracing. Tracks requests as they jump between microservices for latency debugging.
*   **SigNoz:** Full-stack APM (Application Performance Monitoring). Included for learning/redundancy to compare against the Prometheus/Loki stack.
*   **OpenCost:** Cloud cost allocation tool to estimate resource consumption costs.
*   **Kube-state-metrics:** Exposes raw Kubernetes object metrics.
*   **K8sGPT:** AI-powered diagnostics tool to explain cluster errors in plain English.
*   **Kubeshark:** API traffic analyzer (Wireshark for K8s).

#### **D. Security Layer**
*   **Cert-Manager:** Automates the issuance and renewal of TLS certificates.
*   **Harbor:** Private container registry to store built images locally. Scans images for vulnerabilities.
*   **OpenBao:** Secrets management (Vault fork) to securely store API keys and credentials.
*   **Trivy:** Vulnerability scanner integrated into the CI/CD pipeline to block insecure images.
*   **OWASP ZAP:** Dynamic Application Security Testing (DAST) tool integrated into JenkinsX for security testing.
*   **Falco:** Runtime threat detection. Alerts on suspicious system calls.
*   **Kyverno:** Policy engine. Enforces rules (e.g., "No root containers") at the API level.

#### **E. Cluster Management & Storage**
*   **Longhorn:** Distributed block storage. Configured to use the 1TB HDD on the control plane.
*   **MinIO:** Object storage. *Required Dependency* for Thanos, Loki, and Velero to function on bare metal.
*   **Velero:** Backup and disaster recovery. Backs up cluster state and volumes to MinIO.
*   **Portainer:** Visual web UI for quick container management.
*   **K9s:** Terminal-based UI for real-time cluster management (local tool).

---

## 3. Repository Directory Structure

This structure separates infrastructure provisioning from application deployment.

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
│   │   ├── metallb-config/          # (If needed, replaced by Cilium L2)
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
```

---


## 4. Deployment Roadmap

### Phase 1: Infrastructure (Ansible)
This phase makes the hardware "Kubernetes Ready."
1.  **OS Tuning:** Update Ubuntu, disable Swap, disable WiFi/BT (save power/interrupts), set GPU memory to minimum (16MB).
2.  **Kernel & Network:** Load `overlay` and `br_netfilter` modules. Enable IP forwarding and bridged traffic in `sysctl`.
3.  **Cgroups:** Append `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1` to `cmdline.txt` to enable resource limits.
4.  **Dependencies:** Install `containerd`, `open-iscsi`, `nfs-common`, `ipset`.
5.  **Binaries:** Install `kubeadm`, `kubelet`, `kubectl` (locked versions), `helm`, `etcdctl`, `cilium-cli`.

### Phase 2: Cluster Bootstrap
1.  **Init:** Run `kubeadm init` on `rpi4-1`.
2.  **Networking:** Install Cilium immediately to allow nodes to become Ready. Configure L2 Announcements for LoadBalancing.
3.  **Join:** Run `kubeadm join` on worker nodes.
4.  **Labeling:** Apply labels to distinguish the HDD node from the SD card nodes.

### Phase 3: Storage Foundation
1.  **HDD Setup:** Format and mount the 1TB drive to `/var/lib/longhorn` on `rpi4-1`.
2.  **Longhorn Install:** Deploy Longhorn. Configure it to strictly enforce data locality (replica count 1, data stored only on the HDD node).
3.  **MinIO Install:** Deploy MinIO on top of Longhorn. This creates the S3 bucket storage required for the next phase.

### Phase 4: GitOps & Observability
1.  **ArgoCD:** Deploy ArgoCD.
2.  **App of Apps:** Apply the root GitOps manifest. ArgoCD will then take over and install:
    *   **Observability:** Prometheus, Grafana, Thanos (connected to MinIO), Loki (connected to MinIO), Fluentd, OpenTelemetry/Jaeger, SigNoz.
    *   **Security:** Cert-Manager, Harbor, Kyverno, Falco, OpenBao.
    *   **Management:** Velero (connected to MinIO).

### Phase 5: CI/CD & DevEx
1.  **JenkinsX:** Deploy the JenkinsX platform for pipeline management.
2.  **Integration:** Configure JenkinsX to use Harbor for image pushing and OWASP ZAP/Trivy for security scanning steps.

## 5. Initial provisioning of Rasspberry Pis and Ansible Configuration

First thing to do is to write on each rpi sd card the OS. I used Raspberry Pi Imager and selected Ubuntu Server (25.10) as a smaller image to save resources. In configuration set a hostname (i have rpi4-1 ... rpi4-4), a username (user) and password, enable SSH and I added my key to authorized_keys.
From my home router I found the devices IPs. Still there you can configure Address reservation so every time they keep their IP. Did some Port forwarding too so I can access them from everywhere using DDNS from my ISP, as I don't have static IPv4. All of these settings are configured from you home router so Google how to if you're interested.
I added every PI to local machine C:\Windows\System32\drivers\etc\hosts file to be able to control them easier.
192.168.0.201 rpi4-1
192.168.0.202 rpi4-2
192.168.0.203 rpi4-3
192.168.0.204 rpi4-4


This is the required inventory file to map the architecture to the playbooks.

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
# Global Connection Variables
ansible_connection=ssh
ansible_user=user
ansible_ssh_private_key_file=/home/user/.ssh/rsa-4096/key-nopassphrase.pem
ansible_python_interpreter=/usr/bin/python3.13
```

---

after this part we should test connection with ansible -i ansible/hosts all -m ping.
