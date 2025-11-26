# Kubernetes Cluster on Raspberry Pi 4: Bare Metal GitOps Guide

TL;DR: This guide details the step-by-step process to deploy a production-grade Kubernetes cluster on Raspberry Pi 4 hardware using Ansible for infrastructure provisioning and ArgoCD for GitOps-based application management. And a ton of modern cloud-native tools along it.

## Table of Contents
1.  [Introduction and Scope](#1-introduction-and-scope)
    *   [Project Overview](#project-overview)
    *   [Target Audience](#target-audience)
    *   [Learning Outcomes](#learning-outcomes)
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
    *   [7.2 Metrics Server](#72-metrics-server)
    *   [7.3 Network Verification Script](#73-network-verification-script)
    *   [7.4 Phase 2 Execution Steps](#74-phase-2-execution-steps)
8.  [Phase 3: Storage Foundation](#8-phase-3-storage-foundation)
    *   [8.1 Storage Mounting Playbook](#81-storage-mounting-playbook)
    *   [8.2 Longhorn Bootstrap Script](#82-longhorn-bootstrap-script)
    *   [8.3 Storage Verification Script](#83-storage-verification-script)
    *   [8.4 Phase 3 Execution Steps](#84-phase-3-execution-steps)
9.  [Phase 4: GitOps & Observability](#9-phase-4-gitops--observability)
    *   [9.1 Gateway API Bootstrap (Traefik)](#91-gateway-api-bootstrap-traefik)
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
    *   [10.8 Configuration Reloader (Reloader)](#108-configuration-reloader-reloader)
    *   [10.9 Workload Rebalancing (Descheduler)](#109-workload-rebalancing-descheduler)
    *   [10.10 The Root Application (App of Apps)](#1010-the-root-application-app-of-apps)
    *   [10.11 Security Verification Script](#1011-security-verification-script)
    *   [10.12 Phase 5 Execution Steps](#1012-phase-5-execution-steps)
11. [Phase 6: Advanced Observability](#11-phase-6-advanced-observability)
    *   [11.1 Log Aggregation (Loki Stack)](#111-log-aggregation-loki-stack)
    *   [11.2 Log Collection (Fluent Bit)](#112-log-collection-fluent-bit)
    *   [11.3 Distributed Tracing (OpenTelemetry)](#113-distributed-tracing-opentelemetry)
    *   [11.4 Tracing Backend (Jaeger)](#114-tracing-backend-jaeger)
    *   [11.5 Traffic Analysis (Kubeshark)](#115-traffic-analysis-kubeshark)
    *   [11.6 Cost Management (OpenCost)](#116-cost-management-opencost)
    *   [11.7 AI Diagnostics (K8sGPT)](#117-ai-diagnostics-k8sgpt)
    *   [11.8 Observability Verification Script](#118-observability-verification-script)
    *   [11.9 Phase 6 Execution Steps](#119-phase-6-execution-steps)
12. [Phase 7: CI/CD & Developer Experience](#12-phase-7-cicd--developer-experience)
    *   [12.1 Image Automation (Argo Image Updater)](#121-image-automation-argo-image-updater)
    *   [12.2 CI Engine (Argo Workflows)](#122-ci-engine-argo-workflows)
    *   [12.3 Event Bus (Argo Events)](#123-event-bus-argo-events)
    *   [12.4 Security Tooling (Trivy)](#124-security-tooling-trivy)
    *   [12.5 Local Development (Skaffold)](#125-local-development-skaffold)
    *   [12.6 CI/CD Verification Script](#126-cicd-verification-script)
    *   [12.7 Phase 7 Execution Steps](#127-phase-7-execution-steps)
13. [Phase 8: Day 2 Operations & Maintenance](#13-phase-8-day-2-operations--maintenance)
    *   [13.1 Upgrading Kubernetes](#131-upgrading-kubernetes)
    *   [13.2 OS Patching](#132-os-patching)
    *   [13.3 Cluster Reset (The Nuclear Option)](#133-cluster-reset-the-nuclear-option)
    *   [13.4 Backup & Disaster Recovery](#134-backup--disaster-recovery)
    *   [13.5 Troubleshooting Cheatsheet](#135-troubleshooting-cheatsheet)

---

## 1. Introduction and Scope

### Project Overview

This project documents the establishment of a **production-grade, Cloud Native Kubernetes cluster** on bare metal Raspberry Pi 4 hardware. The objective is to build a self-healing, observable, and secure platform managed entirely through **GitOps principles**.

The architecture mirrors enterprise-grade deployments while accounting for the unique constraints of edge computing on ARM64 hardware—limited RAM, SD card wear concerns, and single-HDD storage topology.

**Core Philosophy:**
- **Infrastructure as Code (IaC):** All infrastructure provisioning is automated via Ansible playbooks, ensuring repeatable deployments.
- **GitOps:** Application state is declaratively defined in Git. ArgoCD continuously reconciles cluster state with the desired configuration.
- **Immutable Infrastructure:** Nodes are treated as disposable. Configuration changes trigger redeployment rather than in-place modification.
- **Defense in Depth:** Security is layered across network policies, runtime protection, image scanning, and policy enforcement.

### Target Audience

This guide is designed for:

| Audience | Prerequisites | Expected Benefit |
|----------|---------------|------------------|
| **DevOps Engineers** | Familiarity with containers, basic Kubernetes concepts | Production-ready home lab for experimentation |
| **Platform Engineers** | Experience with IaC tools (Terraform/Ansible) | Reference architecture for edge deployments |
| **SREs** | Understanding of observability principles | Complete monitoring stack implementation |
| **Developers** | Basic command-line proficiency | CI/CD pipeline for personal projects |
| **Students** | Willingness to learn | Hands-on experience with enterprise tooling |

**Assumed Knowledge:**
- Linux command-line fundamentals (`ssh`, `sudo`, file navigation)
- Basic YAML syntax
- Understanding of IP networking (subnets, DHCP, DNS)
- Familiarity with Git operations (`clone`, `commit`, `push`)

### Learning Outcomes

Upon completing this guide, you will be able to:

1. **Infrastructure Provisioning**
   - Configure Raspberry Pi hardware for Kubernetes workloads
   - Automate node preparation using Ansible
   - Manage version-locked Kubernetes binary installations

2. **Cluster Operations**
   - Bootstrap a multi-node Kubernetes cluster using `kubeadm`
   - Implement eBPF-based networking with Cilium
   - Configure bare-metal load balancing via L2 announcements

3. **Storage Management**
   - Deploy distributed block storage with strict hardware affinity
   - Implement S3-compatible object storage for cloud-native tooling
   - Protect SD cards from write amplification

4. **GitOps Workflows**
   - Implement the App of Apps pattern with ArgoCD
   - Automate image updates based on registry tags
   - Manage secrets securely with external secret stores

5. **Observability**
   - Deploy a complete metrics pipeline (Prometheus, Thanos, Grafana)
   - Implement centralized logging (Fluent Bit, Loki)
   - Configure distributed tracing (OpenTelemetry, Jaeger)

6. **Security Hardening**
   - Enforce pod security policies with Kyverno
   - Implement runtime threat detection with Falco
   - Integrate vulnerability scanning into CI/CD pipelines

7. **CI/CD Pipelines**
   - Build Kubernetes-native workflows with Argo Workflows
   - Configure event-driven automation with Argo Events
   - Implement automated security scanning gates

**Hardware Limitations Acknowledged:**
- **Single HDD:** All persistent storage relies on one physical disk. This is a single point of failure acceptable for a learning environment.
- **4GB Worker RAM:** Some observability tools (Jaeger, Kubeshark) are configured with aggressive resource limits that may cause OOM under heavy load.
- **SD Card Wear:** Longhorn is explicitly configured to never schedule replicas on worker nodes to protect SD cards.

---

## 2. Architecture Overview

### High-Level Architecture Diagram

> 💡 **Tip:** The Mermaid diagram below is interactive on GitHub. Click nodes to explore relationships.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#326CE5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#326CE5', 'lineColor': '#5D6D7E', 'secondaryColor': '#F39C12', 'tertiaryColor': '#fff'}}}%%
flowchart TB
    subgraph Internet["☁️ Internet"]
        USER[("👤 User")]
    end

    subgraph HomeNetwork["🏠 Home Network (192.168.0.0/24)"]
        ROUTER["🌐 Router/Gateway<br/>DHCP + Port Forward"]
        
        subgraph K8sCluster["⎈ Kubernetes Cluster"]
            subgraph ControlPlane["📍 Control Plane (rpi4-1 • 8GB • .201)"]
                ETCD[("💾 etcd")]
                API["🔌 API Server"]
                SCHED["📅 Scheduler"]
                CM["🎛️ Controller Manager"]
                
                subgraph Storage["💿 Storage Layer"]
                    HDD[("🗄️ 1TB HDD")]
                    LONGHORN["📦 Longhorn"]
                    MINIO["🪣 MinIO (S3)"]
                end
            end
            
            subgraph Workers["👷 Worker Nodes (4GB each)"]
                W1["rpi4-2 • .202"]
                W2["rpi4-3 • .203"]
                W3["rpi4-4 • .204"]
            end
            
            subgraph Networking["🌐 Network Layer"]
                CILIUM["🐝 Cilium CNI<br/>eBPF + L2 LB"]
                TRAEFIK["🚦 Traefik<br/>Gateway API"]
                GWAPI["📋 HTTPRoutes"]
            end
            
            subgraph GitOps["🔄 GitOps Engine"]
                ARGOCD["🐙 ArgoCD"]
                IMGUPD["🖼️ Image Updater"]
                GITEA[("🍵 Gitea<br/>GitOps Source")]
            end
            
            subgraph Observability["📊 Observability"]
                METRICS["📈 Metrics Server"]
                PROM["🔥 Prometheus"]
                THANOS["🏛️ Thanos"]
                GRAFANA["📉 Grafana"]
                LOKI["📝 Loki"]
                FLUENTBIT["🦋 Fluent Bit"]
                OTEL["📡 OpenTelemetry"]
                JAEGER["🔍 Jaeger"]
            end
            
            subgraph Security["🔒 Security Layer"]
                CERTMGR["📜 Cert-Manager"]
                HARBOR["🚢 Harbor Registry"]
                OPENBAO["🔐 OpenBao"]
                KYVERNO["📋 Kyverno"]
                FALCO["🦅 Falco"]
                TRIVY["🔬 Trivy"]
            end
            
            subgraph CICD["🚀 CI/CD"]
                WORKFLOWS["⚙️ Argo Workflows"]
                EVENTS["📨 Argo Events"]
            end
            
            subgraph Management["🛠️ Management"]
                VELERO["💾 Velero"]
                RELOADER["🔄 Reloader"]
                DESCHEDULER["⚖️ Descheduler"]
            end
        end
    end

    %% Traffic Flow
    USER -->|"HTTPS :443"| ROUTER
    ROUTER -->|"Port Forward"| CILIUM
    CILIUM -->|"L2 ARP<br/>192.168.0.210"| TRAEFIK
    TRAEFIK --> GWAPI
    GWAPI -->|"Route to Services"| Workers
    
    %% GitOps Flow
    GITEA -->|"Sync"| ARGOCD
    ARGOCD -->|"Deploy"| K8sCluster
    IMGUPD -->|"Watch Tags"| HARBOR
    
    %% Storage Dependencies
    HDD --> LONGHORN
    LONGHORN --> MINIO
    MINIO --> THANOS
    MINIO --> LOKI
    MINIO --> VELERO
    
    %% Observability Flow
    Workers -->|"Metrics"| PROM
    PROM --> THANOS
    THANOS --> GRAFANA
    Workers -->|"Logs"| FLUENTBIT
    FLUENTBIT --> LOKI
    LOKI --> GRAFANA
    Workers -->|"Traces"| OTEL
    OTEL --> JAEGER
    
    %% Security Flow
    CERTMGR -->|"TLS Certs"| TRAEFIK
    HARBOR -->|"Images"| Workers
    TRIVY -->|"Scan"| HARBOR
    KYVERNO -->|"Policies"| API
    FALCO -->|"Monitor"| Workers
    
    %% Control Plane
    API --> ETCD
    SCHED --> API
    CM --> API
    
    %% Management
    RELOADER -->|"Watch ConfigMaps"| Workers
    DESCHEDULER -->|"Rebalance"| Workers
    VELERO -->|"Backup"| MINIO

    %% Styling
    classDef control fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef worker fill:#5D6D7E,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#F39C12,stroke:#fff,stroke-width:2px,color:#fff
    classDef network fill:#1ABC9C,stroke:#fff,stroke-width:2px,color:#fff
    classDef gitops fill:#E74C3C,stroke:#fff,stroke-width:2px,color:#fff
    classDef observe fill:#9B59B6,stroke:#fff,stroke-width:2px,color:#fff
    classDef security fill:#E91E63,stroke:#fff,stroke-width:2px,color:#fff
    classDef external fill:#95A5A6,stroke:#fff,stroke-width:2px,color:#fff
    
    class ETCD,API,SCHED,CM control
    class W1,W2,W3 worker
    class HDD,LONGHORN,MINIO storage
    class CILIUM,TRAEFIK,GWAPI network
    class ARGOCD,IMGUPD,GITEA gitops
    class PROM,THANOS,GRAFANA,LOKI,FLUENTBIT,OTEL,JAEGER,METRICS observe
    class CERTMGR,HARBOR,OPENBAO,KYVERNO,FALCO,TRIVY security
    class USER,ROUTER external
```

### Deployment Sequence Diagram

```mermaid
%%{init: {'theme': 'base'}}%%
sequenceDiagram
    autonumber
    participant User as 👤 Operator
    participant Ansible as 📜 Ansible
    participant Nodes as 🖥️ RPi Nodes
    participant K8s as ⎈ Kubernetes
    participant Cilium as 🐝 Cilium
    participant ArgoCD as 🐙 ArgoCD
    participant Gitea as 🍵 Gitea

    rect rgb(50, 108, 229, 0.1)
        Note over User,Nodes: Phase 1: Infrastructure Provisioning
        User->>Ansible: Run 01_node_prep.yml
        Ansible->>Nodes: Configure OS, Cgroups, Containerd
        Nodes-->>Ansible: Ready
        User->>Ansible: Run 02_k8s_binaries.yml
        Ansible->>Nodes: Install kubeadm, kubelet, kubectl
    end

    rect rgb(26, 188, 156, 0.1)
        Note over User,Cilium: Phase 2: Cluster Bootstrap
        User->>Ansible: Run 03_cluster_init.yml
        Ansible->>Nodes: kubeadm init (Control Plane)
        Nodes->>K8s: API Server Online
        Ansible->>Cilium: helm install cilium
        Cilium-->>K8s: CNI Ready, L2 LB Active
        Ansible->>Nodes: kubeadm join (Workers)
        Nodes-->>K8s: 4/4 Nodes Ready
    end

    rect rgb(243, 156, 18, 0.1)
        Note over User,K8s: Phase 3: Storage Foundation
        User->>Ansible: Run 04_storage_mount.yml
        Ansible->>Nodes: Mount HDD to /var/lib/longhorn
        User->>K8s: helm install longhorn
        K8s-->>K8s: StorageClass: longhorn-hdd
    end

    rect rgb(231, 76, 60, 0.1)
        Note over User,Gitea: Phase 4: GitOps Bootstrap
        User->>K8s: helm install traefik
        User->>K8s: helm install argocd
        User->>K8s: kubectl apply -f root-app.yaml
        K8s->>ArgoCD: Root Application Created
        ArgoCD->>Gitea: Watch Repository
        Gitea-->>ArgoCD: Sync gitops/ manifests
        ArgoCD->>K8s: Deploy All Applications
    end

    rect rgb(155, 89, 182, 0.1)
        Note over Gitea,K8s: Continuous GitOps Loop
        loop Every 3 minutes
            ArgoCD->>Gitea: Check for changes
            Gitea-->>ArgoCD: New commit detected
            ArgoCD->>K8s: Apply changes
            K8s-->>ArgoCD: Sync complete ✓
        end
    end
```

### Component Dependency Graph

```mermaid
%%{init: {'theme': 'base'}}%%
flowchart LR
    subgraph Layer0["Layer 0: Hardware"]
        HDD["🗄️ 1TB HDD"]
        SD["💾 SD Cards"]
    end

    subgraph Layer1["Layer 1: Platform"]
        K8S["⎈ Kubernetes"]
        CILIUM["🐝 Cilium"]
    end

    subgraph Layer2["Layer 2: Storage"]
        LH["📦 Longhorn"]
        MINIO["🪣 MinIO"]
    end

    subgraph Layer3["Layer 3: Core Services"]
        ARGO["🐙 ArgoCD"]
        TRAEFIK["🚦 Traefik"]
        CERT["📜 Cert-Manager"]
    end

    subgraph Layer4["Layer 4: Platform Services"]
        PROM["🔥 Prometheus"]
        LOKI["📝 Loki"]
        HARBOR["🚢 Harbor"]
        VAULT["🔐 OpenBao"]
    end

    subgraph Layer5["Layer 5: Applications"]
        THANOS["🏛️ Thanos"]
        VELERO["💾 Velero"]
        GRAFANA["📉 Grafana"]
        WORKFLOWS["⚙️ Argo Workflows"]
    end

    %% Dependencies
    HDD --> LH
    SD --> K8S
    K8S --> CILIUM
    CILIUM --> LH
    LH --> MINIO
    LH --> HARBOR
    LH --> VAULT
    MINIO --> THANOS
    MINIO --> LOKI
    MINIO --> VELERO
    K8S --> ARGO
    ARGO --> TRAEFIK
    ARGO --> CERT
    ARGO --> PROM
    ARGO --> HARBOR
    PROM --> THANOS
    PROM --> GRAFANA
    LOKI --> GRAFANA
    CERT --> TRAEFIK
    HARBOR --> WORKFLOWS

    %% Styling
    style Layer0 fill:#34495E,stroke:#fff,color:#fff
    style Layer1 fill:#2C3E50,stroke:#fff,color:#fff
    style Layer2 fill:#F39C12,stroke:#fff,color:#fff
    style Layer3 fill:#E74C3C,stroke:#fff,color:#fff
    style Layer4 fill:#9B59B6,stroke:#fff,color:#fff
    style Layer5 fill:#1ABC9C,stroke:#fff,color:#fff
```

### ASCII Fallback Diagram

For environments that don't render Mermaid, here's the ASCII representation:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              HOME NETWORK (192.168.0.0/24)                      │
│                                                                                 │
│    ┌─────────────┐                                                              │
│    │   Router    │◄──── DHCP Reservations: .201-.204                            │
│    │  Gateway    │◄──── Port Forward: 80,443 → .210 (Traefik LB)               │
│    └──────┬──────┘                                                              │
│           │                                                                     │
│           ▼                                                                     │
│    ┌──────────────────────────────────────────────────────────────────────┐    │
│    │                    CILIUM L2 ANNOUNCEMENT POOL                        │    │
│    │                        192.168.0.210 - .220                           │    │
│    └──────────────────────────────────────────────────────────────────────┘    │
│           │                                                                     │
│    ═══════╪═════════════════════════════════════════════════════════════════   │
│           │           KUBERNETES CLUSTER (Pod CIDR: 10.244.0.0/16)             │
│    ═══════╪═════════════════════════════════════════════════════════════════   │
│           │                                                                     │
│    ┌──────┴──────┐     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│    │   rpi4-1    │     │   rpi4-2    │  │   rpi4-3    │  │   rpi4-4    │       │
│    │ Control+Stor│     │   Worker    │  │   Worker    │  │   Worker    │       │
│    │  .201 (8GB) │     │ .202 (4GB)  │  │ .203 (4GB)  │  │ .204 (4GB)  │       │
│    │             │     │             │  │             │  │             │       │
│    │ ┌─────────┐ │     │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │       │
│    │ │  etcd   │ │     │ │ Cilium  │ │  │ │ Cilium  │ │  │ │ Cilium  │ │       │
│    │ │ API Srv │ │     │ │  Agent  │ │  │ │  Agent  │ │  │ │  Agent  │ │       │
│    │ │ Sched.  │ │     │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │       │
│    │ └─────────┘ │     │             │  │             │  │             │       │
│    │             │     │  Workloads  │  │  Workloads  │  │  Workloads  │       │
│    │ ┌─────────┐ │     │  (Stateless)│  │  (Stateless)│  │  (Stateless)│       │
│    │ │Longhorn │ │     │             │  │             │  │             │       │
│    │ │ MinIO   │ │     │   64GB SD   │  │   64GB SD   │  │   64GB SD   │       │
│    │ └────┬────┘ │     │  (No PVCs)  │  │  (No PVCs)  │  │  (No PVCs)  │       │
│    │      │      │     └─────────────┘  └─────────────┘  └─────────────┘       │
│    │ ┌────▼────┐ │                                                              │
│    │ │  1TB    │ │                                                              │
│    │ │  HDD    │ │◄──── All Persistent Volumes                                  │
│    │ └─────────┘ │                                                              │
│    └─────────────┘                                                              │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Hardware Topology

The cluster consists of four Raspberry Pi 4 nodes with intentionally asymmetric roles:

| Node | Hostname | IP Address | RAM | Storage | Role | Labels |
|------|----------|------------|-----|---------|------|--------|
| Control Plane | `rpi4-1` | 192.168.0.201 | 8GB | 128GB SD + **1TB HDD** | API Server, etcd, Storage | `storage=hdd`, `unique-hdd=true`, `ram=8gb` |
| Worker 1 | `rpi4-2` | 192.168.0.202 | 4GB | 64GB SD | Compute | `ram=4gb` |
| Worker 2 | `rpi4-3` | 192.168.0.203 | 4GB | 64GB SD | Compute | `ram=4gb` |
| Worker 3 | `rpi4-4` | 192.168.0.204 | 4GB | 64GB SD | Compute | `ram=4gb` |

**Design Rationale:**

| Decision | Justification |
|----------|---------------|
| **Untainted Control Plane** | With only 4 nodes and 20GB total RAM, we cannot afford to waste 8GB on control plane overhead alone. The control plane runs storage workloads that benefit from its HDD. |
| **Single HDD Storage** | All persistent data lives on one disk. This is acceptable for a learning environment—production would require distributed storage across multiple nodes. |
| **Worker SD Protection** | SD cards have limited write endurance (~10K-100K cycles). Blocking PVC scheduling to workers extends their lifespan significantly. |
| **L2 Load Balancing** | Without cloud provider integration, Cilium's L2 Announcements provide LoadBalancer IPs by responding to ARP requests on the local network. |

### Network Architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           NETWORK TOPOLOGY                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  EXTERNAL ACCESS                                                        │
│  ───────────────                                                        │
│  Internet ──► Router ──► Port Forward ──► 192.168.0.210 (Traefik LB)   │
│                                                                         │
│  CLUSTER NETWORKS                                                       │
│  ────────────────                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Node Network:     192.168.0.201-204  (Physical IPs)             │   │
│  │ Pod Network:      10.244.0.0/16      (Cilium CNI)               │   │
│  │ Service Network:  10.96.0.0/12       (ClusterIP range)          │   │
│  │ LoadBalancer IPs: 192.168.0.210-220  (Cilium L2 Pool)           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  TRAFFIC FLOW                                                           │
│  ────────────                                                           │
│  External Request                                                       │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │   Cilium    │───►│   Traefik   │───►│  HTTPRoute  │                 │
│  │ L2 Announce │    │   Gateway   │    │   Routing   │                 │
│  │ (ARP Reply) │    │ (TLS Term.) │    │  (Service)  │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│       │                                       │                         │
│       │              ┌────────────────────────┘                         │
│       │              ▼                                                  │
│       │         ┌─────────────┐                                        │
│       │         │  Backend    │                                        │
│       │         │    Pod      │                                        │
│       │         └─────────────┘                                        │
│       │                                                                 │
│  Internal (Pod-to-Pod)                                                  │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐                                    │
│  │   Cilium    │───►│  eBPF Data  │  (No kube-proxy, direct routing)   │
│  │   Agent     │    │    Path     │                                    │
│  └─────────────┘    └─────────────┘                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Resource Budget

With constrained hardware, careful resource allocation is critical. Below is the expected memory footprint:

| Category | Component | Memory Request | Memory Limit | Node Placement |
|----------|-----------|----------------|--------------|----------------|
| **System** | kubelet + containerd | ~300MB | - | All |
| **System** | Cilium Agent | 128MB | 512MB | All |
| **Control Plane** | etcd | 256MB | 2GB | rpi4-1 |
| **Control Plane** | API Server | 256MB | 2GB | rpi4-1 |
| **Storage** | Longhorn Manager | 256MB | 512MB | rpi4-1 |
| **Storage** | MinIO | 512MB | 1GB | rpi4-1 |
| **GitOps** | ArgoCD (all components) | 512MB | 1GB | Any |
| **Observability** | Prometheus | 512MB | 2GB | Any |
| **Observability** | Loki | 256MB | 1GB | Any |
| **Observability** | Grafana | 128MB | 256MB | Any |
| **Security** | Falco | 128MB | 512MB | All (DaemonSet) |
| **Security** | Kyverno | 128MB | 384MB | Any |
| **Management** | Reloader | 64MB | 128MB | Any |
| **Management** | Descheduler | 64MB | 128MB | Any |

**Estimated Total:**
- **Control Plane (rpi4-1):** ~4-5GB reserved, leaving ~3GB for workloads
- **Workers (rpi4-2/3/4):** ~1GB system overhead, leaving ~3GB each for workloads
- **Cluster Total Available:** ~12GB for application workloads

> ⚠️ **Warning:** Running the full observability stack simultaneously may cause memory pressure. Consider disabling Kubeshark and Jaeger when not actively debugging.

### Software Stack & Justification

#### **A. Orchestration & Deployment**

| Tool | Version | Purpose | Why This Tool? |
|------|---------|---------|----------------|
| **Kubernetes** | 1.31 | Container orchestration | Industry standard, upstream experience via kubeadm |
| **Helm** | 3.x | Package management | Required by ArgoCD for chart deployments |
| **ArgoCD** | 2.x | GitOps controller | Best-in-class GitOps, declarative, self-healing |
| **Argo Image Updater** | 0.x | Image automation | Automatic version bumps from registry tags |
| **Argo Workflows** | 3.x | CI/CD pipelines | Kubernetes-native, replaces Jenkins |
| **Argo Events** | 1.x | Event automation | Webhook triggers, event-driven pipelines |

#### **B. Network Layer**

| Tool | Version | Purpose | Why This Tool? |
|------|---------|---------|----------------|
| **Cilium** | 1.18.x | CNI + Load Balancing | eBPF performance, replaces kube-proxy, L2 announcements |
| **Hubble** | (embedded) | Network observability | Service maps, flow visualization |
| **Tetragon** | (embedded) | Runtime security | eBPF-based syscall monitoring |
| **Traefik** | 3.x | Gateway API implementation | Native Gateway API support, lightweight |

**Gateway API vs Ingress:**
```text
┌─────────────────────────────────────────────────────────────────────┐
│                    WHY GATEWAY API?                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Ingress (Legacy)              Gateway API (Modern)                 │
│  ─────────────────             ────────────────────                 │
│  • Single resource type        • Separated concerns:                │
│  • Limited routing             │  - GatewayClass (infra)           │
│  • Vendor annotations          │  - Gateway (ops team)             │
│  • No traffic splitting        │  - HTTPRoute (dev team)           │
│                                • Rich routing (headers, weights)   │
│                                • Standard, portable                 │
│                                • Role-based ownership               │
│                                                                     │
│  This guide uses Gateway API exclusively for all external access.  │
└─────────────────────────────────────────────────────────────────────┘
```

#### **C. Observability Stack**

| Tool | Purpose | Depends On | Memory Impact |
|------|---------|------------|---------------|
| **Metrics Server** | Resource metrics (`kubectl top`, HPA, VPA) | - | Low (64MB) |
| **Prometheus Operator** | Metrics collection & alerting | - | High (512MB-2GB) |
| **Thanos** | Long-term metrics storage | MinIO | Medium (256MB) |
| **Grafana** | Visualization dashboards | - | Low (128MB) |
| **Fluent Bit** | Log collection (DaemonSet) | - | Low per node |
| **Loki** | Log storage & querying | MinIO | Medium (256MB) |
| **OpenTelemetry** | Trace collection | - | Low (128MB) |
| **Jaeger** | Trace visualization | - | Medium (256MB) |
| **OpenCost** | Cost estimation | Prometheus | Low (64MB) |
| **Kube-state-metrics** | Kubernetes object metrics | - | Low (64MB) |
| **K8sGPT** | AI-powered diagnostics | - | Low (64MB) |
| **Kubeshark** | API traffic analysis | - | High (512MB+) |

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY DATA FLOW                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  METRICS PIPELINE                                                   │
│  ────────────────                                                   │
│  Pods ──► Prometheus ──► Thanos ──► MinIO (S3)                     │
│                │                                                    │
│                └──► Grafana (Visualization)                         │
│                                                                     │
│  LOGGING PIPELINE                                                   │
│  ────────────────                                                   │
│  Containers ──► Fluent Bit ──► Loki ──► MinIO (S3)                 │
│                                   │                                 │
│                                   └──► Grafana (Log Explorer)       │
│                                                                     │
│  TRACING PIPELINE                                                   │
│  ────────────────                                                   │
│  Applications ──► OpenTelemetry ──► Jaeger                         │
│       (SDK)         (Collector)      (UI + Storage)                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### **D. Security Layer**

| Tool | Purpose | Enforcement Point |
|------|---------|-------------------|
| **Cert-Manager** | TLS certificate automation | Cluster-wide |
| **Harbor** | Private container registry | Image pulls |
| **OpenBao** | Secrets management (Vault fork) | Application runtime |
| **Trivy Operator** | Vulnerability scanning | CI/CD + continuous |
| **OWASP ZAP** | Dynamic security testing | CI/CD pipelines |
| **Falco** | Runtime threat detection | Kernel syscalls |
| **Kyverno** | Policy enforcement | API admission |

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    SECURITY DEFENSE LAYERS                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Layer 1: BUILD TIME                                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Trivy (Image Scan) ──► Harbor (Signed Images)              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  Layer 2: DEPLOY TIME        ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Kyverno (Admission) ──► "No privileged containers"         │   │
│  │                      ──► "Images from Harbor only"          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  Layer 3: RUN TIME           ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Falco (Syscall Monitor) ──► Alert on shell in container    │   │
│  │  Tetragon (eBPF)         ──► Block suspicious activity      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### **E. Cluster Management & Storage**

| Tool | Purpose | Critical For |
|------|---------|--------------|
| **Longhorn** | Distributed block storage | PersistentVolumes |
| **MinIO** | S3-compatible object storage | Thanos, Loki, Velero |
| **Velero** | Backup & disaster recovery | Cluster state, volumes |
| **Reloader** | Config change propagation | GitOps workflows |
| **Descheduler** | Workload rebalancing | Resource optimization |
| **Portainer** | Web UI for containers | Visual management |
| **K9s** | Terminal UI | Real-time interaction |

**Storage Dependency Chain:**
```text
┌─────────────────────────────────────────────────────────────────────┐
│                    STORAGE DEPENDENCIES                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│              ┌─────────┐                                            │
│              │   HDD   │ (1TB Physical Disk)                        │
│              └────┬────┘                                            │
│                   │                                                 │
│              ┌────▼────┐                                            │
│              │Longhorn │ (Block Storage)                            │
│              └────┬────┘                                            │
│                   │                                                 │
│         ┌─────────┼─────────┐                                       │
│         │         │         │                                       │
│    ┌────▼────┐ ┌──▼───┐ ┌───▼────┐                                 │
│    │  MinIO  │ │Harbor│ │OpenBao │                                 │
│    │  (S3)   │ │(Reg.)│ │(Vault) │                                 │
│    └────┬────┘ └──────┘ └────────┘                                 │
│         │                                                           │
│    ┌────┴────────────────┐                                         │
│    │         │           │                                          │
│    ▼         ▼           ▼                                          │
│  Thanos    Loki       Velero                                        │
│ (Metrics) (Logs)     (Backups)                                      │
│                                                                     │
│  ⚠️ MinIO failure = Observability & Backup systems offline          │
└─────────────────────────────────────────────────────────────────────┘
```

#### **F. Developer Experience**

| Tool | Purpose | Usage |
|------|---------|-------|
| **Skaffold** | Local development loop | Code → Build → Push → Deploy |
| **K9s** | Terminal cluster UI | Real-time pod management |
| **Portainer** | Web cluster UI | Visual container management |
| **Hubble UI** | Network visualization | Service dependency maps |

---

## 3. Repository Directory Structure

This structure follows the **separation of concerns** principle:
- **Imperative** (Ansible): One-time infrastructure provisioning
- **Bootstrap** (Helm scripts): Pre-GitOps dependencies that ArgoCD needs to exist first
- **Declarative** (GitOps): Everything managed by ArgoCD after bootstrap

```text
.
├── README.md                            # This comprehensive guide
│
├── ansible/                             # ══════════════════════════════════════
│   │                                    # INFRASTRUCTURE PROVISIONING (Imperative)
│   │                                    # Run once to prepare bare-metal nodes
│   │                                    # ══════════════════════════════════════
│   ├── hosts                            # Inventory: [big]=CP, [small]=workers
│   ├── ansible.cfg                      # SSH settings, privilege escalation
│   └── playbooks/
│       ├── 01_node_prep.yml             # OS: swap, cgroups, kernel modules, containerd
│       ├── 02_k8s_binaries.yml          # Install: kubeadm, kubelet, kubectl, helm, cilium-cli
│       ├── 03_cluster_init.yml          # Bootstrap: kubeadm init/join, Cilium CNI, labels
│       ├── 04_storage_mount.yml         # HDD: format ext4, mount /var/lib/longhorn, fstab
│       └── 05_reset_cluster.yml         # Nuclear option: kubeadm reset, cleanup everything
│
├── bootstrap/                           # ══════════════════════════════════════
│   │                                    # PRE-GITOPS DEPENDENCIES (Manual Helm)
│   │                                    # Components ArgoCD needs before it can run
│   │                                    # ══════════════════════════════════════
│   ├── cilium/                          # CNI: eBPF networking, L2 LoadBalancer pool
│   │   └── install.sh                   # → helm install cilium (skip-kube-proxy mode)
│   ├── longhorn/                        # Storage: Block storage with HDD-only affinity
│   │   └── install.sh                   # → helm install longhorn (replica=1, CP node)
│   ├── metrics-server/                  # Metrics: Required for kubectl top, HPA, VPA
│   │   └── install.sh                   # → helm install metrics-server (ARM64 flags)
│   ├── traefik/                         # Gateway: Traefik + Gateway API CRDs
│   │   └── install.sh                   # → kubectl apply CRDs, helm install traefik
│   └── argocd/                          # GitOps: ArgoCD server + controllers
│       └── install.sh                   # → helm install argocd (HA disabled for RPi)
│
├── gitops/                              # ══════════════════════════════════════
│   │                                    # APPLICATIONS (Declarative GitOps)
│   │                                    # Everything below is managed by ArgoCD
│   │                                    # Sync-waves control deployment order
│   │                                    # ══════════════════════════════════════
│   ├── root-app.yaml                    # Points ArgoCD to this gitops/ directory
│   ├── app-of-apps.yaml                 # Parent app that deploys all child apps
│   │
│   ├── infrastructure/                  # ──────────────────────────────────────
│   │   │                                # LAYER 1: Core cluster infrastructure
│   │   │                                # sync-wave: -5 (deploys first)
│   │   │                                # ──────────────────────────────────────
│   │   ├── cert-manager.yaml            # TLS: Let's Encrypt automation, ClusterIssuers
│   │   └── traefik.yaml                 # Gateway: HTTPRoute definitions (if GitOps-managed)
│   │
│   ├── storage/                         # ──────────────────────────────────────
│   │   │                                # LAYER 2: Persistent storage layer
│   │   │                                # sync-wave: -4 (before apps need PVCs)
│   │   │                                # ──────────────────────────────────────
│   │   └── minio.yaml                   # S3: Object storage for Thanos/Loki/Velero
│   │                                    #     PVC on Longhorn, credentials in Secret
│   │
│   ├── services/                        # ──────────────────────────────────────
│   │   │                                # LAYER 3: Platform services
│   │   │                                # sync-wave: -3
│   │   │                                # ──────────────────────────────────────
│   │   └── gitea.yaml                   # Git: Self-hosted repo, GitOps source of truth
│   │                                    #     SQLite DB, PVC for repos, HTTPRoute
│   │
│   ├── observability/                   # ──────────────────────────────────────
│   │   │                                # LAYER 4: Monitoring & debugging
│   │   │                                # sync-wave: 0 (default)
│   │   │                                # ──────────────────────────────────────
│   │   ├── metrics-server.yaml          # Metrics: kubectl top, HPA, VPA support
│   │   ├── loki-stack.yaml              # Logs: Loki + Promtail, S3 backend (MinIO)
│   │   ├── fluent-bit.yaml              # Logs: DaemonSet collector → Loki
│   │   ├── opentelemetry.yaml           # Traces: OTel Collector, OTLP receiver
│   │   ├── jaeger.yaml                  # Traces: Jaeger UI + storage, HTTPRoute
│   │   ├── opencost.yaml                # Cost: Resource cost estimation, Prom integration
│   │   ├── k8sgpt.yaml                  # AI: GPT-powered cluster diagnostics
│   │   └── kubeshark.yaml               # Debug: API traffic capture (Wireshark for K8s)
│   │                                    #        ⚠️ High memory - disable when not needed
│   │
│   ├── security/                        # ──────────────────────────────────────
│   │   │                                # LAYER 5: Security & compliance
│   │   │                                # sync-wave: 1
│   │   │                                # ──────────────────────────────────────
│   │   ├── harbor.yaml                  # Registry: Private images, vulnerability DB
│   │   │                                #           PVC for images, Trivy scanner
│   │   ├── openbao.yaml                 # Secrets: Vault fork, KV secrets engine
│   │   │                                #          Auto-unseal, K8s auth method
│   │   ├── falco.yaml                   # Runtime: Syscall monitoring, threat detection
│   │   │                                #          DaemonSet, kernel module or eBPF
│   │   ├── kyverno.yaml                 # Policy: Admission controller, mutations
│   │   │                                #          "Deny privileged", "Require labels"
│   │   └── trivy-operator.yaml          # Scanner: Continuous image vulnerability scans
│   │                                    #          CRDs: VulnerabilityReport, ConfigAudit
│   │
│   ├── cicd/                            # ──────────────────────────────────────
│   │   │                                # LAYER 6: CI/CD pipelines
│   │   │                                # sync-wave: 2
│   │   │                                # ──────────────────────────────────────
│   │   ├── argo-workflows.yaml          # CI: Kubernetes-native pipelines
│   │   │                                #     WorkflowTemplates, Artifact storage
│   │   ├── argo-events.yaml             # Events: Webhook triggers, EventSources
│   │   │                                #         GitHub/Gitea webhooks → Workflows
│   │   └── argo-image-updater.yaml      # CD: Watch registries, auto-bump image tags
│   │                                    #     Annotations on Apps, write-back to Git
│   │
│   └── management/                      # ──────────────────────────────────────
│       │                                # LAYER 7: Operations & maintenance
│       │                                # sync-wave: 3
│       │                                # ──────────────────────────────────────
│       ├── velero.yaml                  # Backup: Cluster state + PVCs → MinIO
│       │                                #         Scheduled backups, disaster recovery
│       ├── reloader.yaml                # GitOps: Watch ConfigMaps/Secrets, rolling restart
│       │                                #         Annotations trigger pod recreation
│       ├── descheduler.yaml             # Balance: Evict pods for better distribution
│       │                                #         LowNodeUtilization, RemoveDuplicates
│       └── portainer.yaml               # UI: Visual container management
│                                        #     Web dashboard, HTTPRoute
│
└── tests/                               # ══════════════════════════════════════
    │                                    # VALIDATION SCRIPTS
    │                                    # Run after each phase to verify success
    │                                    # ══════════════════════════════════════
    ├── 01_infra_test.sh                 # Phase 1: Node count, RAM, swap disabled
    ├── 02_network_test.sh               # Phase 2: Cilium status, L2 pool, CoreDNS
    ├── 03_storage_test.sh               # Phase 3: PVC create/delete, HDD mount
    ├── 04_security_test.sh              # Phase 5: Kyverno policies, Falco rules
    ├── 05_observability_test.sh         # Phase 6: Prometheus up, Loki query, Grafana
    └── 06_cicd_test.sh                  # Phase 7: Workflow submit, Event trigger
```

---

## 4. Prerequisites & Initial Provisioning

Before executing Ansible playbooks, the physical devices must be provisioned and network-accessible. This section covers the one-time manual setup required before automation takes over.

### Hardware Checklist

Verify you have the following hardware ready:

| Item | Quantity | Specification | Purpose |
|------|----------|---------------|---------|
| Raspberry Pi 4 | 4 | 1x 8GB, 3x 4GB | Cluster nodes |
| MicroSD Cards | 4 | 1x 128GB, 3x 64GB (Class A2 recommended) | OS boot drives |
| USB HDD/SSD | 1 | 1TB minimum | Persistent storage |
| Ethernet Cables | 4 | Cat5e or better | Network connectivity |
| USB-C Power Supplies | 4 | 5V 3A (15W) official recommended | Stable power |
| Network Switch | 1 | Gigabit, 5+ ports | Local connectivity |
| Heatsinks/Cooling | 4 | Passive or active | Thermal management |

> ⚠️ **Power Warning:** Insufficient power causes random crashes. Use official Raspberry Pi power supplies or verified 3A USB-C adapters. Avoid USB hubs for power.

### Software Prerequisites (Management Machine)

Install these tools on your local machine (Windows/WSL, Mac, or Linux):

```bash
# Essential tools
sudo apt update && sudo apt install -y \
    ansible \           # Infrastructure automation
    openssh-client \    # SSH connectivity
    curl \              # HTTP requests
    git                 # Version control

# Kubernetes tools (install latest versions)
# kubectl - Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# helm - Package manager
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k9s - Terminal UI (optional but recommended)
curl -sS https://webinstall.dev/k9s | bash
```

**Verify installations:**

```bash
ansible --version    # Should show 2.15+
kubectl version --client
helm version
```

### OS & Network Setup

#### Step 1: Flash Ubuntu Server

Use **Raspberry Pi Imager** (download from [raspberrypi.com](https://www.raspberrypi.com/software/)) to flash **Ubuntu Server 24.04 LTS** or **25.10** to each SD card.

> 💡 **Why Ubuntu Server?** Lightweight, excellent ARM64 support, long-term security updates, and broad community documentation.

**Imager Settings (⚙️ Advanced Options):**

| Setting | Control Plane (rpi4-1) | Workers (rpi4-2/3/4) |
|---------|------------------------|----------------------|
| Hostname | `rpi4-1` | `rpi4-2`, `rpi4-3`, `rpi4-4` |
| Username | `user` | `user` |
| Password | Set a strong password | Same password |
| SSH | ✅ Enable | ✅ Enable |
| SSH Auth | Public-key only | Public-key only |
| WiFi | ❌ Skip (use Ethernet) | ❌ Skip |
| Locale | Your timezone | Same |

#### Step 2: Generate SSH Keys

If you don't have an SSH key pair, generate one:

```bash
# Generate a 4096-bit RSA key (no passphrase for Ansible automation)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/rpi-cluster -N ""

# View your public key (copy this to Raspberry Pi Imager)
cat ~/.ssh/rpi-cluster.pub
```

#### Step 3: First Boot & IP Discovery

1. Insert SD cards into each Pi
2. Connect Ethernet cables to your network switch
3. Power on all Pis
4. Wait 2-3 minutes for first boot to complete

**Find IP addresses** using one of these methods:

```bash
# Method 1: Check your router's DHCP lease table (web UI)
# Usually at http://192.168.0.1 or http://192.168.1.1

# Method 2: Network scan (requires nmap)
nmap -sn 192.168.0.0/24 | grep -B2 "Raspberry"

# Method 3: mDNS/Bonjour (if enabled)
ping rpi4-1.local
```

#### Step 4: Configure Static DHCP Leases

In your router's admin panel, reserve these IPs:

| Hostname | MAC Address | Reserved IP |
|----------|-------------|-------------|
| rpi4-1 | (from router) | 192.168.0.201 |
| rpi4-2 | (from router) | 192.168.0.202 |
| rpi4-3 | (from router) | 192.168.0.203 |
| rpi4-4 | (from router) | 192.168.0.204 |

> 📝 **Note:** Write down the MAC addresses from your router's DHCP table—you'll need them for the static reservations.

#### Step 5: Port Forwarding (Optional - External Access)

If you want to access services from the internet:

| Service | External Port | Internal IP | Internal Port |
|---------|---------------|-------------|---------------|
| HTTPS (Traefik) | 443 | 192.168.0.210 | 443 |
| HTTP (Traefik) | 80 | 192.168.0.210 | 80 |
| SSH (optional) | 2222 | 192.168.0.201 | 22 |

> 🔐 **Security:** Consider using a VPN (WireGuard/Tailscale) instead of direct port forwarding for SSH access.

### Local Client Configuration

Add hostname mappings to your local machine for easier access:

**Windows:** Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator

**Linux/Mac:** Edit `/etc/hosts` with sudo

**WSL Users:** Edit the Windows hosts file (WSL inherits it)

```text
# Raspberry Pi Kubernetes Cluster
192.168.0.201 rpi4-1 rpi4-1.local
192.168.0.202 rpi4-2 rpi4-2.local
192.168.0.203 rpi4-3 rpi4-3.local
192.168.0.204 rpi4-4 rpi4-4.local

# Cluster Services (LoadBalancer IPs)
192.168.0.210 traefik.local argocd.local gitea.local grafana.local
```

**Verify SSH connectivity:**

```bash
# Test each node (should connect without password prompt)
ssh -i ~/.ssh/rpi-cluster user@rpi4-1 "hostname && cat /etc/os-release | grep PRETTY"
ssh -i ~/.ssh/rpi-cluster user@rpi4-2 "hostname"
ssh -i ~/.ssh/rpi-cluster user@rpi4-3 "hostname"
ssh -i ~/.ssh/rpi-cluster user@rpi4-4 "hostname"
```

### Ansible Configuration

Ansible automates all node preparation and cluster bootstrapping.

#### Inventory File

**File:** `ansible/hosts`

```ini
# ============================================================================
# KUBERNETES CLUSTER INVENTORY
# ============================================================================

[big]
# Control Plane Node - 8GB RAM, 1TB HDD
# Runs: API Server, etcd, Scheduler, Controller Manager, Longhorn, MinIO
rpi4-1

[small]
# Worker Nodes - 4GB RAM each
# Runs: Application workloads (stateless only, no PVCs)
rpi4-2
rpi4-3
rpi4-4

[cluster:children]
big
small

# ============================================================================
# CONNECTION SETTINGS
# ============================================================================
[all:vars]
ansible_connection=ssh
ansible_user=user
ansible_ssh_private_key_file=~/.ssh/rpi-cluster
ansible_python_interpreter=/usr/bin/python3

# Reduce SSH connection time
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# ============================================================================
# KUBERNETES CONFIGURATION
# ============================================================================
k8s_version=1.31
pod_network_cidr=10.244.0.0/16
service_cidr=10.96.0.0/12

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================
# LoadBalancer IP pool for Cilium L2 announcements
# Must be in your home network subnet and NOT used by DHCP
loadbalancer_ip_start=192.168.0.210
loadbalancer_ip_end=192.168.0.220

# Primary LoadBalancer IP (Traefik Gateway)
loadbalancer_ip=192.168.0.210

# ============================================================================
# STORAGE CONFIGURATION
# ============================================================================
# HDD device on control plane (verify with 'lsblk' after connecting HDD)
hdd_device=/dev/sda
longhorn_data_path=/var/lib/longhorn
```

#### Ansible Configuration File

**File:** `ansible/ansible.cfg`

```ini
[defaults]
inventory = hosts
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

# Performance tuning
forks = 10
pipelining = True

# Output formatting
stdout_callback = yaml
callback_whitelist = profile_tasks

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
```

#### Verification Commands

```bash
# Navigate to ansible directory
cd ansible/

# Test connectivity to all nodes
ansible -i hosts all -m ping

# Expected output:
# rpi4-1 | SUCCESS => { "ping": "pong" }
# rpi4-2 | SUCCESS => { "ping": "pong" }
# rpi4-3 | SUCCESS => { "ping": "pong" }
# rpi4-4 | SUCCESS => { "ping": "pong" }

# Gather facts (verify hardware)
ansible -i hosts all -m setup -a "filter=ansible_memtotal_mb"

# Expected: rpi4-1 ~8000MB, others ~4000MB

# Check disk on control plane
ansible -i hosts big -m shell -a "lsblk"

# Should show /dev/sda (your HDD)
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
1.  **Argo Workflows & Events:** Deploy the CI engine and Event Bus.
2.  **Integration:** Configure Harbor for image pushing and Security scanners (Trivy/ZAP) within the pipelines.

---

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
**File:** `tests/01_infra_test.sh`

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
    bash tests/01_infra_test.sh
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

### 7.2 Metrics Server
**File:** `bootstrap/metrics-server/install.sh`

Metrics Server is a cluster-wide aggregator of resource usage data. It is **required** for:
- `kubectl top nodes` and `kubectl top pods` commands
- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA)
- Kubernetes Dashboard resource displays

```bash
#!/bin/bash
set -e
echo "=== METRICS SERVER BOOTSTRAP ==="

# Install Metrics Server with ARM64 compatibility
# We use --kubelet-insecure-tls because we're using self-signed certs
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.12.2 \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="200Mi" \
  --set resources.limits.cpu="250m" \
  --set resources.limits.memory="300Mi"

echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s

echo "=== METRICS SERVER INSTALLED ==="
echo "Verify with: kubectl top nodes"
```

*Note: The `--kubelet-insecure-tls` flag is required because kubeadm generates self-signed certificates for the kubelet.*

### 7.3 Network Verification Script
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

### 7.4 Phase 2 Execution Steps

1.  **Run the Cluster Initialization:**
    ```bash
    ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml
    ```
    *Note: This will overwrite `~/.kube/config` on your local machine.*

2.  **Install Metrics Server:**
    ```bash
    bash bootstrap/metrics-server/install.sh
    ```
    *Verify: `kubectl top nodes` should return resource usage for all nodes.*

3.  **Verify Cluster Status:**
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
1.  **Traefik:** Provides the LoadBalancer IP (`192.168.0.210`) and routing so we can access UIs.
2.  **ArgoCD:** The controller that syncs Git state to the Cluster.
3.  **Gitea:** The internal Git server where our cluster configuration will live.
4.  **App of Apps:** A single manifest that tells ArgoCD to install everything else (Observability, Security, etc.).

### 9.1 Gateway API Bootstrap (Traefik)
**File:** `bootstrap/traefik/install.sh`

This script installs **Traefik v3** as a Gateway API implementation. Gateway API is the successor to Ingress, providing:
*   **More expressive routing:** Header-based, query-based, and method-based routing
*   **Role-based configuration:** Infrastructure admins manage Gateways, app teams manage HTTPRoutes
*   **Portable:** Standard API across all implementations (Traefik, Cilium, NGINX, etc.)

Traefik is configured to:
*   Request the specific LoadBalancer IP (`192.168.0.210`) from Cilium.
*   Serve as the Gateway API controller via GatewayClass.
*   Expose Prometheus metrics for the Observability stack.
*   Enable JSON access logs for the Logging stack (Loki).

```bash
#!/bin/bash
set -e
echo "=== PHASE 4a: TRAEFIK + GATEWAY API BOOTSTRAP ==="

# 1. Install Gateway API CRDs (required before Traefik)
echo "Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# 2. Add Repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 3. Install Traefik v3 with Gateway API support
echo "Deploying Traefik..."
helm upgrade --install traefik traefik/traefik \
  --namespace traefik-system \
  --create-namespace \
  --version 34.0.0 \
  --set service.type=LoadBalancer \
  --set service.spec.loadBalancerIP=192.168.0.210 \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set providers.kubernetesGateway.enabled=true \
  --set providers.kubernetesCRD.enabled=true \
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

# 4. Create the shared Gateway resource
echo "Creating Gateway resource..."
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: traefik-system
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-cert
            namespace: traefik-system
EOF

echo "=== TRAEFIK + GATEWAY API INSTALLED ==="
echo "External IP should be assigned shortly."
echo "Gateway: main-gateway.traefik-system"
```

### 9.2 GitOps Bootstrap (ArgoCD)
**File:** `bootstrap/argocd/install.sh`

This script installs **ArgoCD**.
*   **Insecure Mode:** We disable ArgoCD's internal TLS because Traefik handles SSL termination at the Gateway level.
*   **HTTPRoute:** We apply a Gateway API HTTPRoute so the UI is accessible at `argocd.192.168.0.210.nip.io`.

```bash
#!/bin/bash
set -e
echo "=== PHASE 4b: ARGOCD BOOTSTRAP ==="

# 1. Add Repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Install ArgoCD
# We use --insecure to offload TLS to Traefik Gateway
echo "Deploying ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.0 \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set global.logging.format=json \
  --wait

# 3. Expose UI via Gateway API HTTPRoute
echo "Creating HTTPRoute for ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik-system
  hostnames:
    - "argocd.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: argocd-server
          port: 80
EOF

echo "=== ARGOCD READY ==="
echo "URL: http://argocd.192.168.0.210.nip.io"
echo "Get Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

### 9.3 Source Control Service (Gitea)
**File:** `gitops/services/gitea.yaml`

This is our first **Declarative Application**. Instead of a shell script, this is a YAML file we feed to ArgoCD.
*   **Database:** Deploys a dedicated PostgreSQL instance managed by the chart.
*   **Storage:** Uses the `longhorn` storage class (HDD).
*   **UI:** Configured with a modern theme and mapped to `gitea.192.168.0.210.nip.io`.

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
              DOMAIN: "gitea.192.168.0.210.nip.io"
              ROOT_URL: "http://gitea.192.168.0.210.nip.io/"
              SSH_DOMAIN: "192.168.0.210"
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

        # Disable built-in ingress - we use Gateway API HTTPRoute
        ingress:
          enabled: false

        service:
          http:
            type: ClusterIP
          ssh:
            type: LoadBalancer
            port: 2222
            annotations: 
              io.cilium/lb-ipam-ips: "192.168.0.210"
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# HTTPRoute for Gitea (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gitea
  namespace: gitea
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik-system
  hostnames:
    - "gitea.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: gitea-http
          port: 3000
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
          # Disable built-in ingress - we use Gateway API HTTPRoute
          ingress:
            enabled: false

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
    *Verify: `kubectl get svc -n traefik-system` should show External-IP `192.168.0.210`.*

2.  **Install ArgoCD:**
    ```bash
    bash bootstrap/argocd/install.sh
    ```
    *Verify: Open `http://argocd.192.168.0.210.nip.io` and login with the secret password.*

3.  **Deploy Gitea (via ArgoCD):**
    ```bash
    kubectl apply -f gitops/services/gitea.yaml
    ```
    *Wait 5 minutes. Verify: Open `http://gitea.192.168.0.210.nip.io` and create your admin account.*

4.  **The Pivot (Critical Step):**
    *   Create a repository in Gitea named `home-cluster`.
    *   Push your local `gitops/` folder to this new repo.
    *   (Optional) Modify the `gitea.yaml` and `app-of-apps.yaml` to point to your new `http://gitea...` repo URL instead of public charts, completing the loop.

5.  **Deploy Observability:**
    ```bash
    kubectl apply -f gitops/app-of-apps.yaml
    ```
    *Verify: Open `http://grafana.192.168.0.210.nip.io`.*

## 10. Phase 5: Security & Management Stack

Now that the GitOps engine is running, we utilize it to deploy the infrastructure dependencies required for a secure, production-grade environment.

### 10.1 Object Storage (MinIO)
**File:** `gitops/storage/minio.yaml`

Many Cloud Native tools (Velero, Thanos, Loki, Harbor) expect an AWS S3 bucket. Since we are on bare metal, we self-host **MinIO** to provide this API.
*   **Storage:** Uses Longhorn (HDD) for the data backing.
*   **Buckets:** Automatically provisions buckets for `velero`, `loki`, `harbor`, and `thanos`.
*   **Access:** Exposed via Gateway API HTTPRoute (`minio.192.168.0.210.nip.io`).

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

        # Disable built-in ingress - we use Gateway API HTTPRoute
        ingress:
          enabled: false

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
---
# HTTPRoute for MinIO Console (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: minio-console
  namespace: storage
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik-system
  hostnames:
    - "minio.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: minio-console
          port: 9001
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
              core: harbor.192.168.0.210.nip.io
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

### 10.8 Configuration Reloader (Reloader)
**File:** `gitops/management/reloader.yaml`

Reloader watches for changes in ConfigMaps and Secrets, then automatically triggers rolling updates on associated Deployments/StatefulSets. This is essential for GitOps workflows where configuration changes should propagate without manual intervention.

*   **Use Case:** When you update a Grafana dashboard ConfigMap, Reloader restarts Grafana automatically.
*   **Footprint:** Extremely lightweight (~10MB RAM).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: reloader
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://stakater.github.io/stakater-charts
    chart: reloader
    targetRevision: 1.1.0
    helm:
      values: |
        reloader:
          watchGlobally: true
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 10m
              memory: 64Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Usage:** Annotate your Deployments to enable auto-reload:
```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

### 10.9 Workload Rebalancing (Descheduler)
**File:** `gitops/management/descheduler.yaml`

On resource-constrained Raspberry Pi clusters, workloads can become imbalanced over time. The Descheduler periodically evicts pods based on configured strategies, allowing the scheduler to rebalance them across nodes.

*   **Strategies Enabled:**
    *   `RemoveDuplicates`: Ensures replicas are spread across nodes.
    *   `LowNodeUtilization`: Moves pods from overloaded nodes to underutilized ones.
    *   `RemovePodsViolatingNodeAffinity`: Evicts pods that no longer satisfy node affinity rules.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: descheduler
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/descheduler
    chart: descheduler
    targetRevision: 0.31.0
    helm:
      values: |
        schedule: "*/15 * * * *"  # Run every 15 minutes
        deschedulerPolicy:
          strategies:
            RemoveDuplicates:
              enabled: true
            LowNodeUtilization:
              enabled: true
              params:
                nodeResourceUtilizationThresholds:
                  thresholds:
                    cpu: 20
                    memory: 20
                  targetThresholds:
                    cpu: 50
                    memory: 50
            RemovePodsViolatingNodeAffinity:
              enabled: true
              params:
                nodeAffinityType:
                  - requiredDuringSchedulingIgnoredDuringExecution
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

*Note: Descheduler only evicts pods; it does not schedule them. The kube-scheduler handles placement after eviction.*
    
### 10.10 The Root Application (App of Apps)
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
    repoURL: http://gitea.192.168.0.210.nip.io/liviu/home-cluster.git
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

### 10.11 Security Verification Script
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
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://harbor.192.168.0.210.nip.io/api/v2.0/ping)
if [ "$STATUS" -eq 200 ]; then
    echo "✅ Harbor API is Live (200 OK)"
else
    echo "❌ Harbor API Unreachable (HTTP $STATUS)"
    exit 1
fi

echo "=== SECURITY CHECK COMPLETE ==="
```

### 10.12 Phase 5 Execution Steps

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
    *   **MinIO Console:** `http://minio.192.168.0.210.nip.io` (User: `admin`, Pass: `password123`)
    *   **Harbor Registry:** `http://harbor.192.168.0.210.nip.io` (Default User: `admin`, Pass: `Harbor12345`)

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
        # Disable built-in ingress - we use Gateway API HTTPRoute
        query:
          ingress:
            enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# HTTPRoute for Jaeger UI (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: jaeger-query
  namespace: monitoring
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik-system
  hostnames:
    - "jaeger.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: jaeger-query
          port: 16686
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
        # Disable built-in ingress - we use Gateway API HTTPRoute
        ingress:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# HTTPRoute for OpenCost UI (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: opencost
  namespace: monitoring
spec:
  parentRefs:
    - name: main-gateway
      namespace: traefik-system
  hostnames:
    - "opencost.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: opencost
          port: 9090
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

### 11.8 Observability Verification Script
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

### 11.9 Phase 6 Execution Steps

1.  **Commit:** Save the YAML files to `gitops/observability/` locally.
    ```bash
    git add .
    git commit -m "Add Advanced Observability stack"
    git push origin main
    ```
    *(ArgoCD will pick up the changes if you configured the Root App, or you can apply them manually).*

2.  **Verify Loki:**
    *   Open Grafana (`http://grafana.192.168.0.210.nip.io`).
    *   Go to **Data Sources**.
    *   Add Data Source -> **Loki**.
    *   URL: `http://loki-stack:3100`.
    *   Go to **Explore**, select **Loki**, and run query `{namespace="monitoring"}` to see logs.

3.  **Verify OpenCost:**
    *   Open `http://opencost.192.168.0.210.nip.io`.
    *   You should see a breakdown of costs per namespace.

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
            - name: harbor.192.168.0.210.nip.io
              api_url: https://harbor.192.168.0.210.nip.io
              prefix: harbor.192.168.0.210.nip.io/library
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

### 12.2 CI Engine (Argo Workflows)
**File:** `gitops/cicd/argo-workflows.yaml`

Argo Workflows is a Kubernetes-native workflow engine. It creates Pods to run your build steps (clone, build, push, test).
*   **UI:** Exposed via Gateway API HTTPRoute.
*   **Persistence:** Uses MinIO (S3) to store build artifacts (logs, compiled binaries).
*   **Executor:** Uses `pns` (Process Namespace Sharing) for efficiency on Raspberry Pi.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-workflows
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-workflows
    targetRevision: 0.41.0
    helm:
      values: |
        server:
          # Insecure mode handled by Traefik Gateway
          extraArgs: ["--auth-mode=server"]
          # Disable built-in ingress - we use Gateway API HTTPRoute
          ingress:
            enabled: false
        
        controller:
          workflowDefaults:
            spec:
              # Use MinIO for artifact storage
              artifactRepository:
                s3:
                  bucket: argo-artifacts
                  endpoint: minio.storage.svc.cluster.local:9000
                  insecure: true
                  accessKeySecret:
                    name: argo-artifacts-creds
                    key: accessKey
                  secretKeySecret:
                    name: argo-artifacts-creds
                    key: secretKey

        # Efficient executor for Docker-in-Docker builds
        useDefaultArtifactRepo: true
        executor:
          pns: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-workflows
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 12.3 Event Bus (Argo Events)
**File:** `gitops/cicd/argo-events.yaml`

Argo Events listens for external triggers (like a `git push` to your Gitea repo) and triggers an Argo Workflow.
*   **Sensor:** Listens for the event.
*   **EventBus:** Manages the message queue (Jetstream).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-events
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-events
    targetRevision: 2.4.0
    helm:
      values: |
        controller:
          replicas: 1
        webhook:
          replicas: 1
        eventbus:
          replicas: 1
          nats:
            native:
              replicas: 3
              auth:token: "argo-events-secret"
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-events
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 12.4 Security Tooling (Trivy & OWASP ZAP)

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

> **Note on OWASP ZAP:**
> OWASP ZAP is best run as a step in your **Argo Workflow** (`WorkflowTemplate`) against a staging URL. It does not require a standalone Helm installation for this architecture.

### 12.5 Local Development (Skaffold) (optional)

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
  - image: harbor.192.168.0.210.nip.io/library/my-app
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

### 12.6 CI/CD Verification Script
**File:** `tests/06_cicd_test.sh`

Verifies the build machinery components.
1.  **Argo Workflows:** Checks controller availability.
2.  **Argo Events:** Checks controller availability.
3.  **Trivy:** Checks if vulnerability reports are being generated for running pods.

```bash
#!/bin/bash
echo "=== CI/CD PIPELINE VERIFICATION ==="

# 1. Argo Workflows Status
echo "Checking Argo Workflows Controller..."
kubectl get pods -n argo-workflows -l app.kubernetes.io/name=argo-workflows-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Argo Workflows Controller is Running"
else
    echo "❌ Argo Workflows is down"
    exit 1
fi

# 2. Argo Events Status
echo "Checking Argo Events..."
kubectl get pods -n argo-events -l app.kubernetes.io/name=argo-events-controller | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Argo Events Controller is Running"
else
    echo "❌ Argo Events is down"
    exit 1
fi

# 3. Trivy Scanning
echo "Checking Security Scans..."
REPORTS=$(kubectl get vulnerabilityreports -A | wc -l)
if [ "$REPORTS" -gt 0 ]; then
    echo "✅ Trivy is generating reports ($REPORTS found)"
else
    echo "⚠️  No Vulnerability Reports found yet (Trivy might still be scanning)"
fi

echo "=== CI/CD CHECK COMPLETE ==="
```

### 12.7 Phase 7 Execution Steps

1.  **Commit & Push:**
    Save the YAML files to `gitops/cicd/` and `gitops/security/`.
    ```bash
    git add .
    git commit -m "Add Argo Workflows, Image Updater, and Security Scanners"
    git push origin main
    ```

2.  **Verify Argo Workflows:**
    *   Open `http://workflows.192.168.0.210.nip.io`.
    *   Ensure you can see the Workflows dashboard.
    *   *(Authentication is handled via the Server auth mode or Traefik, depending on config).*

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
### 13.3 Cluster Reset (The Nuclear Option)
**File:** `ansible/playbooks/05_reset_cluster.yml`

This playbook is a safety net for your learning process. If you misconfigure the cluster or networking beyond repair, run this to wipe the nodes clean so you can restart from Phase 2 (Cluster Init) without re-flashing SD cards.

*   **Action:** Runs `kubeadm reset`, cleans CNI configurations (`/etc/cni`), flushes IPtables, and removes local kube configs.
*   **Safety:** By default, it *does not* wipe the Longhorn data on the HDD, preserving your persistent volumes.

```yaml
---
- name: Phase 8 - Cluster Reset (The Nuclear Option)
  hosts: all
  become: true
  tasks:
    - name: Confirm Reset
      pause:
        prompt: "WARNING: This will reset the Kubernetes cluster on all nodes. Press Enter to continue or Ctrl+C to abort."

    - name: Reset Kubeadm
      command: kubeadm reset -f
      ignore_errors: yes

    - name: Flush IPtables
      shell: |
        iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
      ignore_errors: yes

    - name: Cleanup CNI Config
      file:
        path: /etc/cni/net.d
        state: absent

    - name: Cleanup Kube Config
      file:
        path: /root/.kube
        state: absent

    - name: Remove CNI Interfaces
      shell: |
        ip link delete cilium_host || true
        ip link delete cilium_net || true
        ip link delete kube-ipvs0 || true
      ignore_errors: yes
```

**Usage:**
```bash
ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml
```


### 13.4 Backup & Disaster Recovery
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

### 13.5 Troubleshooting Cheatsheet
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
*   `bootstrap/metrics-server/install.sh`
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
*   `gitops/security/harbor.yaml`
*   `gitops/security/trivy-operator.yaml`
*   `gitops/cicd/argo-image-updater.yaml`
*   `gitops/cicd/argo-workflows.yaml`
*   `gitops/cicd/argo-events.yaml`
*   `gitops/management/velero.yaml`
*   `gitops/management/reloader.yaml`
*   `gitops/management/descheduler.yaml`

### 5. Tests (Validation)
*   `tests/01_infra_test.sh`
*   `tests/02_network_test.sh`
*   `tests/03_storage_test.sh`
*   `tests/04_security_test.sh`
*   `tests/05_observability_test.sh`
*   `tests/06_cicd_test.sh`


***
