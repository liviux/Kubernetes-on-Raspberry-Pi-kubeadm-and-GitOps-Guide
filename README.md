# Kubernetes-on-Raspberry-Pi-kubeadm-and-GitOps-Guide

## Introduction
This project documents the creation of a production-grade Kubernetes cluster running on bare metal Raspberry Pi 4 hardware. The goal is to build a fully automated, self-healing "Cloud Native" platform using industry-standard tools, adapted for the resource constraints of edge hardware (ARM64, SD Cards).

Unlike typical hobbyist setups, this cluster uses **GitOps** principles. The state of the cluster is defined in code (Infrastructure as Code), stored in a self-hosted Git server (Gitea), and reconciled automatically by ArgoCD.

## Architecture & Scope

### Hardware Layer
*   **Control Plane (rpi4-1):** 8GB RAM, 128GB SD Card. **Special Role:** Hosts the 1TB HDD for persistent cluster storage.
*   **Worker Nodes (rpi4-2, 3, 4):** 4GB RAM, 64GB SD Card. These are compute-only nodes protected from heavy write operations to preserve SD card life.

### Software Stack
*   **OS:** Ubuntu 25.10 (ARM64)
*   **Orchestration:** Kubernetes v1.31 (bootstrapped via `kubeadm`).
*   **Networking (CNI):** Cilium v1.18 (Strict Kube-Proxy Replacement, eBPF Masquerading, L2 Announcements for LoadBalancing).
*   **Security/Observability:** Tetragon (Runtime Enforcement) & Hubble (Network Observability).
*   **Storage:** Longhorn (Configured for single-replica HDD storage on the Control Plane).
*   **Ingress:** Traefik v3 (LoadBalancer mode with L2 Announcements).
*   **GitOps:** ArgoCD (App-of-Apps pattern).
*   **Source Control:** Gitea (Self-hosted, backed by Postgres).
*   **Monitoring:** Prometheus & Grafana (Kube-Prometheus-Stack).

## Repository Structure

This repository is organized to separate the bootstrap phase (imperative scripts) from the GitOps phase (declarative manifests).

```text
.
├── gitops/
│   ├── apps/                    # Application Definitions (The "App of Apps")
│   │   ├── security.yaml        # Points to security/ folder
│   │   ├── observability.yaml   # Points to observability/ folder
│   │   ├── cicd.yaml            # Points to cicd/ folder
│   │   └── management.yaml      # Points to management/ folder
│   │
│   ├── security/                # Security Layer
│   │   ├── cert-manager/        # Certificate Automation
│   │   ├── kyverno/             # Policy Enforcement
│   │   ├── falco/               # Runtime Threat Detection
│   │   ├── trivy/               # Vulnerability Scanner
│   │   └── openbao/             # Secrets Management (Vault fork)
│   │
│   ├── observability/           # Monitoring & Logging Layer
│   │   ├── loki/                # Log Aggregation
│   │   ├── promtail/            # Log Shipping Agent
│   │   ├── tempo/               # Distributed Tracing (Jaeger alternative)
│   │   ├── opencost/            # Cloud Cost estimation
│   │   ├── signoz/              # Full-stack APM
│   │   └── k8sgpt/              # AI Cluster Diagnostics
│   │
│   ├── cicd/                    # Build & Release Layer
│   │   ├── harbor/              # Container Registry
│   │   ├── gitea-runner/        # CI/CD Worker (Gitea Actions)
│   │   └── argo-image-updater/  # Automatic Git updates on image change
│   │
│   └── management/              # Cluster Operations
│       ├── minio/               # S3-compatible storage for Backups/Logs
│       ├── velero/              # Backup & Restore
│       └── portainer/           # Visual Dashboard (optional/local)
└── tests/                       # Verification Suites
    ├── 04_security_check.sh
    ├── 05_observability_check.sh
    └── 06_cicd_check.sh
```

---

## Part 1: Infrastructure Preparation (Ansible)

Before installing Kubernetes, the bare metal hardware must be tuned for container workloads. We use Ansible to ensure all nodes are configured identically.

### 1.1 Ansible Configuration
The inventory file is located at `ansible/hosts`. It groups the nodes into `big` (Control Plane) and `small` (Workers) to apply hardware-specific configurations. It uses SSH keys for passwordless access.

### 1.2 Operating System Tuning (`01_os_prep.yml`)
This playbook performs the following operations on all nodes:
*   **System Updates:** Upgrades all packages to the latest versions.
*   **Kernel Parameters:** Enables `overlay` and `br_netfilter` modules; configures `sysctl` to allow bridged traffic to pass through iptables.
*   **Cgroups Configuration:** Appends `cgroup_enable=cpuset` and `cgroup_enable=memory` to the boot configuration (critical for Kubernetes resource limits).
*   **Resource Optimization:** Disables Swap, GPU memory, WiFi, and Bluetooth to free up system resources.
*   **Dependencies:** Installs `open-iscsi` and `nfs-common` (Required for Longhorn).

### 1.3 Kubernetes Binaries (`02_k8s_install.yml`)
Installs `kubelet`, `kubeadm`, and `kubectl`.
*   **Version Locking:** Packages are pinned to version `1.31` to prevent accidental apt-get upgrades from breaking the cluster.
*   **Container Runtime:** Installs and configures `containerd` with the SystemdCgroup driver.

### 1.4 Storage Preparation (`04_storage_prep.yml`)
Targeting only the **Control Plane**, this playbook formats the attached 1TB HDD (ext4) and mounts it persistently to `/var/lib/longhorn`.

---

## Part 2: Cluster Initialization

We use `kubeadm` to bootstrap the control plane and join the workers.

### 2.1 Control Plane Init (`03_k8s_init.yml`)
*   Initializes the cluster without installing `kube-proxy` (skipping the phase), as Cilium will handle this role.
*   Configures the Pod CIDR.
*   **Node Taints:** Removes the default `NoSchedule` taint from the Control Plane so it can run workloads.
*   **Node Labeling:** Applies hardware labels (`ram=8gb`, `storage=hdd`) to the Control Plane and (`ram=4gb`, `sd=64gb`) to Workers for scheduling logic.

### 2.2 Verification
Run the script `tests/01_infra_check.sh` to confirm all nodes are in the cluster and hardware labels are applied correctly.

---

## Part 3: Critical Infrastructure Stack

Once the nodes are online, we install the foundational layers using Helm. These are installed imperatively first, then adopted by ArgoCD later.

### 3.1 Network Layer: Cilium
Located in `bootstrap/cilium/install.sh`.
*   **Kube-Proxy Replacement:** Enabled (Strict). Replaces iptables with eBPF for service handling.
*   **L2 Announcements:** Enabled. Allows the Raspberry Pis to answer ARP requests, functioning as a physical Load Balancer.
*   **Observability:** Hubble Relay and UI are enabled for visualizing network flows.
*   **Security:** Tetragon is deployed for runtime security enforcement.
*   **Metrics:** Prometheus metrics are exposed for scraping.

### 3.2 Storage Layer: Longhorn
Located in `bootstrap/longhorn/install.sh`.
*   **Replica Count:** Set to **1**. Data is not replicated to other nodes to save SD cards.
*   **Node Constraints:** A post-install script disables scheduling on all worker nodes, ensuring data only lands on the Control Plane's HDD.
*   **Driver:** Uses the pre-installed `open-iscsi` dependencies.

### 3.3 Ingress Layer: Traefik v3
Located in `bootstrap/traefik/install.sh`.
*   **Service Type:** `LoadBalancer`. It requests an IP from the Cilium L2 pool (e.g., `192.168.68.210`).
*   **Metrics:** Prometheus annotations are added for auto-discovery.
*   **Logs:** Access logs are enabled in JSON format for future parsing by Loki.

### 3.4 Verification
Run `tests/02_network_check.sh` to verify:
1.  Hubble UI is accessible.
2.  Traefik has an External IP.
3.  Longhorn UI loads and shows the HDD capacity.

---

## Part 4: GitOps Bootstrap

This phase transitions the cluster from "Manual Management" to "GitOps Management."

### 4.1 Install ArgoCD
Located in `bootstrap/argocd/install.sh`.
*   Installs ArgoCD in "Insecure Mode" (TLS offloaded to Traefik).
*   Configures an Ingress route for UI access (`argocd.192.168.68.210.nip.io`).

### 4.2 Install Gitea (Source Control)
Located in `gitops/services/gitea.yaml`.
*   Deploys Gitea using ArgoCD.
*   **Persistence:** Uses a Longhorn PVC backed by the HDD.
*   **Database:** Connects to a dedicated PostgreSQL pod.
*   **Look & Feel:** Configured with a modern theme and correct domain mapping.

### 4.3 The "Pivot"
1.  A repository named `home-cluster` is created in the new Gitea instance.
2.  The contents of the `gitops/` directory are pushed to this internal repo.
3.  ArgoCD applications are updated to pull configuration from the internal Gitea URL instead of the public internet.

---

## Part 5: Observability & Maintenance

### 5.1 Prometheus Stack
Managed via GitOps.
*   **Prometheus:** Scrapes metrics from Cilium, Traefik, and Nodes. Data is persisted to Longhorn.
*   **Grafana:** Dashboards are provisioned automatically.
*   **Alertmanager:** Configured for critical cluster alerts.

### 5.2 Routine Maintenance
*   **OS Updates:** Run `ansible-playbook ansible/playbooks/01_os_prep.yml`.
*   **App Updates:** Modify the `targetRevision` in the GitOps files in Gitea; ArgoCD auto-updates the cluster.


---

## Part 6: Security Layer (The "Day 2" Essentials)

Even in a home lab, security best practices apply. This layer ensures your cluster is trusted, policies are enforced, and intruders are detected.

### 6.1 Certificate Management (`security/cert-manager/`)
*   **Tool:** Cert-Manager.
*   **Function:** Automates the creation of SSL/TLS certificates.
*   **Configuration:** configured with a "SelfSigned" ClusterIssuer initially. This allows Traefik to serve HTTPS without you manually generating keys. It automates the "certificates" part you dislike.

### 6.2 Policy Enforcement (`security/kyverno/`)
*   **Tool:** Kyverno.
*   **Function:** A "Policy Engine" that acts as a bouncer for your API server.
*   **Policies:**
    *   *Disallow Latest Tag:* Prevents deployments using `:latest` images (unstable).
    *   *Require Labels:* Ensures every Pod has an `owner` label.
    *   *Restrict Root:* Prevents containers from running as root user (security best practice).

### 6.3 Runtime Security (`security/falco/`)
*   **Tool:** Falco.
*   **Function:** Monitors the Linux Kernel syscalls in real-time.
*   **Detection:** Alerts if a container tries to read sensitive files (like `/etc/shadow`), spawns an unexpected shell, or modifies binaries.

### 6.4 Vulnerability Scanning (`security/trivy/`)
*   **Tool:** Trivy Operator.
*   **Function:** Automatically scans running images for CVEs (Common Vulnerabilities and Exposures).
*   **Integration:** Results are written to Kubernetes CRDs so you can see security reports directly in ArgoCD or Grafana.

### 6.5 Secrets Management (`security/openbao/`)
*   **Tool:** OpenBao (Community fork of HashiCorp Vault).
*   **Function:** Stores sensitive data (API keys, database passwords) securely, rather than in plain text Kubernetes Secrets.
*   **Configuration:** Uses the Longhorn HDD for encrypted storage backend.

---

## Part 7: Advanced Observability

Beyond basic CPU/RAM metrics, we need logs, traces, and cost analysis.

### 7.1 Logging Stack (`observability/loki/` & `promtail/`)
*   **Tool:** Loki (Database) & Promtail (Agent).
*   **Function:** The "Prometheus for Logs."
*   **Why:** Storing logs in ElasticSearch is too heavy for Raspberry Pis. Loki uses the same label format as Prometheus.
*   **Storage:** Loki is configured to write chunks to MinIO (S3 compatible) running on the HDD.

### 7.2 Cost Analysis (`observability/opencost/`)
*   **Tool:** OpenCost.
*   **Function:** Measures the "cost" of your workloads based on CPU/RAM usage.
*   **Utility:** Even on bare metal, it helps you understand which namespaces are hogging resources.

### 7.3 AI Diagnostics (`observability/k8sgpt/`)
*   **Tool:** K8sGPT.
*   **Function:** Scans the cluster for errors (CrashLoopBackOff, FailedMounts) and sends the error logs to an AI backend (OpenAI or LocalAI) to give you a human-readable explanation and fix suggestion.

### 7.4 Full Stack Observability (`observability/signoz/`)
*   **Tool:** SigNoz.
*   **Function:** An all-in-one alternative to Datadog. It combines Metrics, Traces, and Logs.
*   **Note:** This is resource-intensive. We configure it with strict retention limits to prevent filling the HDD.

---

## Part 8: CI/CD & Developer Experience

We establish a pipeline where code commits automatically build images, scan them, and deploy them.

### 8.1 Container Registry (`cicd/harbor/`)
*   **Tool:** Harbor.
*   **Function:** Your local version of "Docker Hub."
*   **Storage:** Images are stored on the 1TB HDD via Longhorn.
*   **Security:** Integrated with Trivy to scan images *before* they are allowed to run in the cluster.

### 8.2 CI Pipelines (`cicd/gitea-runner/`)
*   **Tool:** Gitea Actions (Runner).
*   **Rationale:** Instead of installing the heavyweight JenkinsX (which often struggles on Pi), we use the native CI/CD built into Gitea. It is compatible with GitHub Actions syntax.
*   **Workflow:**
    1.  You push code to Gitea.
    2.  The Runner builds the Docker image.
    3.  The Runner pushes the image to Harbor.
    4.  The Runner updates the Helm chart version in the Git repo.

### 8.3 Continuous Deployment (`cicd/argo-image-updater/`)
*   **Tool:** ArgoCD Image Updater.
*   **Function:** Watches your Harbor registry. When a new image version appears, it automatically updates the ArgoCD application to use the new version and writes the change back to Git.

---

## Part 9: Cluster Management & Backup

How to manage the platform and save it from disaster.

### 9.1 Object Storage (`management/minio/`)
*   **Tool:** MinIO.
*   **Function:** Provides an S3-compatible API on top of your local HDD.
*   **Usage:** Used by Loki for storing logs and Velero for storing backups.

### 9.2 Backup & Restore (`management/velero/`)
*   **Tool:** Velero.
*   **Function:** Backs up all Kubernetes manifests and Persistent Volumes (Longhorn data) to MinIO.
*   **Schedule:** Configured to run nightly backups. allows you to restore the entire cluster state if you have to re-flash the SD cards.

### 9.3 Local Dashboard (`management/portainer/`)
*   **Tool:** Portainer.
*   **Function:** A simplified, visual dashboard for quick container management. Useful when you want a quick look at logs without writing PromQL queries.

---

## Initial Ansible Configuration

To reproduce this setup, you must start with the correct inventory.

### File: `ansible/hosts`
This file defines your topology and connection methods.

```ini
[big]
# The Control Plane Node (8GB RAM)
# This node will accept the "storage=hdd" label
rpi4-1  ansible_host=192.168.68.201

[small]
# Worker Nodes (4GB RAM)
# These nodes will be protected from storage writes
rpi4-2  ansible_host=192.168.68.202
rpi4-3  ansible_host=192.168.68.203
rpi4-4  ansible_host=192.168.68.204

[cluster:children]
big
small

[cluster:vars]
# SSH Configuration
ansible_connection=ssh
ansible_user=liviu
ansible_ssh_private_key_file=/home/liviu/.ssh/rsa-4096/key-nopassphrase.pem

# Python Interpreter (Ubuntu 25.10 specific)
ansible_python_interpreter=/usr/bin/python3.13

# Cluster Variables for Playbooks
k8s_version=1.31
cilium_version=1.18.4
longhorn_version=1.10.1
```

### Verification Suites

*   `tests/04_security_check.sh`: Tries to deploy a root container (should fail due to Kyverno). Checks Cert-Manager issuance.
*   `tests/05_observability_check.sh`: Queries Loki for logs and checks OpenCost for data.
*   `tests/06_cicd_check.sh`: Pushes a dummy image to Harbor and verifies ArgoCD detects it.

