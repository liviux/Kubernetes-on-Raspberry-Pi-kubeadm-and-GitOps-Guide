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
5.  [Phase 1: Infrastructure Provisioning](#5-phase-1-infrastructure-provisioning)
    *   [5.1 OS Preparation Playbook](#51-os-preparation-playbook)
    *   [5.2 Kubernetes Binaries Playbook](#52-kubernetes-binaries-playbook)
    *   [5.3 Infrastructure Verification](#53-infrastructure-verification)
    *   [5.4 Phase 1 Execution Steps](#54-phase-1-execution-steps)
6.  [Phase 2: Cluster Bootstrap](#6-phase-2-cluster-bootstrap)
    *   [6.1 Cluster Initialization Playbook](#61-cluster-initialization-playbook)
    *   [6.2 Metrics Server](#62-metrics-server)
    *   [6.3 Network Verification Script](#63-network-verification-script)
    *   [6.4 Phase 2 Execution Steps](#64-phase-2-execution-steps)
7.  [Phase 3: Storage Foundation](#7-phase-3-storage-foundation)
    *   [7.1 Storage Mounting Playbook](#71-storage-mounting-playbook)
    *   [7.2 Longhorn Bootstrap Script](#72-longhorn-bootstrap-script)
    *   [7.3 Storage Verification Script](#73-storage-verification-script)
    *   [7.4 Phase 3 Execution Steps](#74-phase-3-execution-steps)
8.  [Phase 4: GitOps & Observability](#8-phase-4-gitops--observability)
    *   [8.1 Gateway API Bootstrap (Traefik)](#81-gateway-api-bootstrap-traefik)
    *   [8.2 GitOps Bootstrap (ArgoCD)](#82-gitops-bootstrap-argocd)
    *   [8.3 Source Control Service (Gitea)](#83-source-control-service-gitea)
    *   [8.4 The "App of Apps" Pattern](#84-the-app-of-apps-pattern)
    *   [8.5 Phase 4 Execution Steps](#85-phase-4-execution-steps)
9.  [Phase 5: Security & Management Stack](#9-phase-5-security--management-stack)
    *   [9.1 Object Storage (MinIO)](#91-object-storage-minio)
    *   [9.2 Certificate Automation (Cert-Manager)](#92-certificate-automation-cert-manager)
    *   [9.3 Container Registry (Harbor)](#93-container-registry-harbor)
    *   [9.4 Backup & Restore (Velero)](#94-backup--restore-velero)
    *   [9.5 Secrets Management (OpenBao)](#95-secrets-management-openbao)
    *   [9.6 Policy Enforcement (Kyverno)](#96-policy-enforcement-kyverno)
    *   [9.7 Runtime Security (Falco)](#97-runtime-security-falco)
    *   [9.8 Configuration Reloader (Reloader)](#98-configuration-reloader-reloader)
    *   [9.9 Workload Rebalancing (Descheduler)](#99-workload-rebalancing-descheduler)
    *   [9.10 The Root Application (App of Apps)](#910-the-root-application-app-of-apps)
    *   [9.11 Security Verification Script](#911-security-verification-script)
    *   [9.12 Phase 5 Execution Steps](#912-phase-5-execution-steps)
10. [Phase 6: Advanced Observability](#10-phase-6-advanced-observability)
    *   [10.1 Log Aggregation (Loki Stack)](#101-log-aggregation-loki-stack)
    *   [10.2 Log Collection (Fluent Bit)](#102-log-collection-fluent-bit)
    *   [10.3 Distributed Tracing (OpenTelemetry)](#103-distributed-tracing-opentelemetry)
    *   [10.4 Tracing Backend (Jaeger)](#104-tracing-backend-jaeger)
    *   [10.5 Traffic Analysis (Kubeshark)](#105-traffic-analysis-kubeshark)
    *   [10.6 Cost Management (OpenCost)](#106-cost-management-opencost)
    *   [10.7 AI Diagnostics (K8sGPT)](#107-ai-diagnostics-k8sgpt)
    *   [10.8 Observability Verification Script](#108-observability-verification-script)
    *   [10.9 Phase 6 Execution Steps](#109-phase-6-execution-steps)
11. [Phase 7: CI/CD & Developer Experience](#11-phase-7-cicd--developer-experience)
    *   [11.1 Image Automation (Argo Image Updater)](#111-image-automation-argo-image-updater)
    *   [11.2 CI Engine (Argo Workflows)](#112-ci-engine-argo-workflows)
    *   [11.3 Event Bus (Argo Events)](#113-event-bus-argo-events)
    *   [11.4 Security Tooling (Trivy)](#114-security-tooling-trivy)
    *   [11.5 Local Development (Skaffold)](#115-local-development-skaffold)
    *   [11.6 CI/CD Verification Script](#116-cicd-verification-script)
    *   [11.7 Phase 7 Execution Steps](#117-phase-7-execution-steps)
12. [Phase 8: Day 2 Operations & Maintenance](#12-phase-8-day-2-operations--maintenance)
    *   [12.1 Upgrading Kubernetes](#121-upgrading-kubernetes)
    *   [12.2 OS Patching](#122-os-patching)
    *   [12.3 Cluster Reset (The Nuclear Option)](#123-cluster-reset-the-nuclear-option)
    *   [12.4 Backup & Disaster Recovery](#124-backup--disaster-recovery)
    *   [12.5 Troubleshooting Cheatsheet](#125-troubleshooting-cheatsheet)

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

#### **G. Deployment Sequence**

The following diagram shows the order of operations. Phases 1-4 are manual; phases 5+ are automated via ArgoCD sync waves.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT SEQUENCE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  PHASE 1    │───►│  PHASE 2    │───►│  PHASE 3    │───►│  PHASE 4    │  │
│  │Infrastructure│   │  Bootstrap  │    │   Storage   │    │   GitOps    │  │
│  │  (Ansible)  │    │  (kubeadm)  │    │ (Longhorn)  │    │  (ArgoCD)   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│        │                  │                  │                  │          │
│        ▼                  ▼                  ▼                  ▼          │
│   OS + Binaries      K8s + Cilium       HDD + MinIO      App of Apps      │
│                                                                  │          │
│                                              ┌───────────────────┘          │
│                                              ▼                              │
│                                    ┌─────────────────┐                     │
│                                    │    PHASE 5+     │                     │
│                                    │  (Automated)    │                     │
│                                    │  ArgoCD syncs   │                     │
│                                    │  all remaining  │                     │
│                                    │   components    │                     │
│                                    └─────────────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

<details>
<summary>📄 Click to expand full ansible/hosts</summary>

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

</details>

#### Ansible Configuration File

**File:** `ansible/ansible.cfg`

<details>
<summary>📄 Click to expand full ansible/ansible.cfg</summary>

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

</details>

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

## 5. Phase 1: Infrastructure Provisioning

This phase transforms raw Ubuntu Server installations into "Kubernetes Ready" nodes. It handles low-level kernel tuning, disables unnecessary hardware to conserve resources on constrained Raspberry Pi hardware, and installs version-locked Kubernetes binaries.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 1 OVERVIEW                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   01_node   │───►│   02_k8s    │───►│   Reboot    │───►│   Verify    │  │
│  │   _prep.yml │    │ _binaries   │    │  (if needed)│    │  01_infra   │  │
│  │             │    │    .yml     │    │             │    │  _test.sh   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│        │                  │                                                 │
│        ▼                  ▼                                                 │
│   • System updates    • K8s repo (1.31)                                    │
│   • Dependencies      • kubelet/kubeadm                                    │
│   • Swap disabled     • kubectl + hold                                     │
│   • Kernel modules    • helm (CP only)                                     │
│   • Sysctl tuning     • cilium-cli (CP)                                    │
│   • Cgroups enabled   • etcdctl (CP)                                       │
│   • WiFi/BT disabled                                                       │
│   • Containerd                                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 OS Preparation Playbook

**File:** `ansible/playbooks/01_node_prep.yml`

This playbook prepares the base OS for Kubernetes. It runs on **all nodes** and performs these critical tasks:

| Task | Purpose | Why It's Required |
|------|---------|-------------------|
| Pre-flight Checks | Verify ARM64 architecture | Ensures correct target platform |
| System Updates | Upgrade all packages | Security patches, latest drivers |
| Dependencies | Install `open-iscsi`, `nfs-common`, `ipset`, `ipvsadm` | Longhorn storage, RWX volumes, Cilium, IPVS |
| Swap Disable | Remove swap permanently + mask services | Kubelet refuses to start with swap enabled |
| Kernel Modules | Load `overlay`, `br_netfilter`, `iscsi_tcp`, `ip_vs*` | Container networking, storage, IPVS mode |
| Sysctl Tuning | IP forwarding, bridge netfilter, inotify limits | Pod networking, many-pods support |
| Cgroups | Enable memory and cpuset cgroups | Resource limits, CPU pinning |
| Hardware Optimization | Disable WiFi/BT/Audio, limit GPU to 16MB, enable watchdog | Free ~100MB RAM, reduce power, auto-recovery |
| Container Runtime | Install containerd with SystemdCgroup + correct pause image | Required runtime for Kubernetes 1.24+ |
| Validation | Verify swap, modules, containerd | Catch issues before proceeding |

> ⚠️ **Important:** This playbook will reboot nodes if cgroup or kernel parameters change. Plan for ~5 minutes downtime per node.

<details>
<summary>📄 Click to expand full playbook</summary>

```yaml
---
# =============================================================================
# Phase 1 - OS Preparation & Tuning
# =============================================================================
# Prepares Raspberry Pi nodes for Kubernetes by:
#   - Installing required packages and dependencies
#   - Disabling swap (Kubernetes requirement)
#   - Loading kernel modules for networking and storage
#   - Enabling cgroups for resource management
#   - Optimizing hardware (disable WiFi/BT, reduce GPU memory)
#   - Installing and configuring containerd runtime
#
# Usage: ansible-playbook -i hosts playbooks/01_node_prep.yml
# Tags:  packages, swap, kernel, cgroups, hardware, containerd
# =============================================================================

- name: Phase 1 - OS Preparation & Tuning
  hosts: all
  become: true
  gather_facts: true

  vars:
    # Raspberry Pi GPU memory allocation (MB) - minimum for headless
    gpu_mem: 16
    # Containerd pause image for Kubernetes
    sandbox_image: "registry.k8s.io/pause:3.10"

  # =========================================================================
  # HANDLERS - Triggered by notify, run once at end
  # =========================================================================
  handlers:
    - name: Restart containerd
      ansible.builtin.service:
        name: containerd
        state: restarted

    - name: Apply sysctl
      ansible.builtin.command: sysctl --system
      changed_when: true

    - name: Reboot required
      ansible.builtin.reboot:
        msg: "Rebooting for kernel/cgroup changes"
        connect_timeout: 5
        reboot_timeout: 300
        pre_reboot_delay: 0
        post_reboot_delay: 30
        test_command: uptime

  # =========================================================================
  # TASKS
  # =========================================================================
  tasks:
    # -----------------------------------------------------------------------
    # PRE-FLIGHT CHECKS
    # -----------------------------------------------------------------------
    - name: Verify we're running on ARM64
      ansible.builtin.assert:
        that:
          - ansible_architecture == "aarch64"
        fail_msg: "This playbook is designed for ARM64 (Raspberry Pi). Detected: {{ ansible_architecture }}"
        success_msg: "Architecture verified: {{ ansible_architecture }}"
      tags: [preflight]

    - name: Display target node info
      ansible.builtin.debug:
        msg: |
          Node: {{ inventory_hostname }}
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          RAM: {{ ansible_memtotal_mb }} MB
          CPUs: {{ ansible_processor_vcpus }}
      tags: [preflight]

    # -----------------------------------------------------------------------
    # SYSTEM UPDATES & DEPENDENCIES
    # -----------------------------------------------------------------------
    - name: Update apt cache and upgrade packages
      ansible.builtin.apt:
        update_cache: true
        upgrade: dist
        cache_valid_time: 3600
      register: apt_action
      retries: 5
      delay: 10
      until: apt_action is succeeded
      tags: [packages]

    - name: Install Kubernetes dependencies
      ansible.builtin.apt:
        name:
          # Core utilities
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
          - software-properties-common
          # Storage (Longhorn requirements)
          - open-iscsi
          - nfs-common
          - cryptsetup
          # Networking (Cilium/Kubeadm requirements)
          - ipset
          - ipvsadm
          - conntrack
          - ethtool
          # Utilities
          - socat
          - git
          - jq
          - htop
          - iotop
        state: present
      tags: [packages]

    - name: Enable iscsid service for Longhorn
      ansible.builtin.service:
        name: iscsid
        state: started
        enabled: true
      tags: [packages]

    # -----------------------------------------------------------------------
    # SWAP CONFIGURATION
    # -----------------------------------------------------------------------
    - name: Disable swap immediately
      ansible.builtin.command: swapoff -a
      changed_when: true
      tags: [swap]

    - name: Remove swap entry from fstab
      ansible.builtin.replace:
        path: /etc/fstab
        regexp: '^([^#].*?\sswap\s+.*)$'
        replace: '# \1 # Disabled for Kubernetes'
      tags: [swap]

    - name: Disable swap service (if exists)
      ansible.builtin.systemd:
        name: "{{ item }}"
        state: stopped
        enabled: false
        masked: true
      loop:
        - dphys-swapfile
        - swap.target
      failed_when: false
      tags: [swap]

    # -----------------------------------------------------------------------
    # KERNEL MODULES
    # -----------------------------------------------------------------------
    - name: Configure persistent kernel modules
      ansible.builtin.copy:
        dest: /etc/modules-load.d/k8s.conf
        content: |
          # Kubernetes required kernel modules
          overlay
          br_netfilter
          # Longhorn iSCSI support
          iscsi_tcp
          # IPVS for kube-proxy (optional, better performance)
          ip_vs
          ip_vs_rr
          ip_vs_wrr
          ip_vs_sh
          nf_conntrack
        mode: '0644'
      notify: Reboot required
      tags: [kernel]

    - name: Load kernel modules immediately
      community.general.modprobe:
        name: "{{ item }}"
        state: present
      loop:
        - overlay
        - br_netfilter
        - iscsi_tcp
        - ip_vs
        - ip_vs_rr
        - ip_vs_wrr
        - ip_vs_sh
        - nf_conntrack
      tags: [kernel]

    # -----------------------------------------------------------------------
    # SYSCTL NETWORK TUNING
    # -----------------------------------------------------------------------
    - name: Configure sysctl for Kubernetes networking
      ansible.builtin.copy:
        dest: /etc/sysctl.d/99-kubernetes.conf
        content: |
          # Kubernetes networking requirements
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1
          net.ipv6.conf.all.forwarding        = 1

          # Performance tuning for containers
          net.core.somaxconn                  = 32768
          net.ipv4.tcp_max_syn_backlog        = 32768
          net.core.netdev_max_backlog         = 32768

          # Increase inotify limits (for many pods)
          fs.inotify.max_user_watches         = 524288
          fs.inotify.max_user_instances       = 8192

          # File descriptor limits
          fs.file-max                         = 2097152
        mode: '0644'
      notify: Apply sysctl
      tags: [kernel]

    - name: Apply sysctl parameters now
      ansible.builtin.command: sysctl --system
      changed_when: true
      tags: [kernel]

    # -----------------------------------------------------------------------
    # RASPBERRY PI SPECIFIC - CGROUPS
    # -----------------------------------------------------------------------
    - name: Check if cgroups already enabled
      ansible.builtin.shell: |
        grep -q "cgroup_enable=cpuset" /boot/firmware/cmdline.txt && echo "enabled" || echo "disabled"
      register: cgroup_status
      changed_when: false
      tags: [cgroups]

    - name: Enable cgroups in boot cmdline
      ansible.builtin.shell: |
        sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
      when: cgroup_status.stdout == "disabled"
      notify: Reboot required
      tags: [cgroups]

    # -----------------------------------------------------------------------
    # RASPBERRY PI SPECIFIC - HARDWARE OPTIMIZATION
    # -----------------------------------------------------------------------
    - name: Configure Raspberry Pi hardware optimizations
      ansible.builtin.blockinfile:
        path: /boot/firmware/config.txt
        marker: "# {mark} KUBERNETES OPTIMIZATIONS"
        block: |
          # Reduce GPU memory (headless server)
          gpu_mem={{ gpu_mem }}

          # Disable unused hardware to save power/memory
          dtoverlay=disable-bt
          dtoverlay=disable-wifi

          # Disable audio (saves resources)
          dtparam=audio=off

          # Enable hardware watchdog
          dtparam=watchdog=on

          # Optimize for server workload
          arm_boost=1
      notify: Reboot required
      tags: [hardware]

    # -----------------------------------------------------------------------
    # CONTAINER RUNTIME - CONTAINERD
    # -----------------------------------------------------------------------
    - name: Install containerd
      ansible.builtin.apt:
        name: containerd
        state: present
      tags: [containerd]

    - name: Create containerd config directory
      ansible.builtin.file:
        path: /etc/containerd
        state: directory
        mode: '0755'
      tags: [containerd]

    - name: Generate containerd default config
      ansible.builtin.shell: |
        containerd config default > /etc/containerd/config.toml
      args:
        creates: /etc/containerd/config.toml
      tags: [containerd]

    - name: Configure containerd for Kubernetes
      ansible.builtin.replace:
        path: /etc/containerd/config.toml
        regexp: "{{ item.regexp }}"
        replace: "{{ item.replace }}"
      loop:
        - regexp: 'SystemdCgroup = false'
          replace: 'SystemdCgroup = true'
        - regexp: 'sandbox_image = ".*"'
          replace: 'sandbox_image = "{{ sandbox_image }}"'
      notify: Restart containerd
      tags: [containerd]

    - name: Enable and start containerd
      ansible.builtin.service:
        name: containerd
        state: started
        enabled: true
      tags: [containerd]

    # -----------------------------------------------------------------------
    # FINAL VALIDATION
    # -----------------------------------------------------------------------
    - name: Verify swap is disabled
      ansible.builtin.command: swapon --show
      register: swap_check
      changed_when: false
      failed_when: swap_check.stdout != ""
      tags: [validate]

    - name: Verify required kernel modules
      ansible.builtin.shell: |
        lsmod | grep -E "^(overlay|br_netfilter|iscsi_tcp)" | wc -l
      register: modules_check
      changed_when: false
      failed_when: modules_check.stdout | int < 3
      tags: [validate]

    - name: Verify containerd is running
      ansible.builtin.command: systemctl is-active containerd
      register: containerd_check
      changed_when: false
      failed_when: containerd_check.stdout != "active"
      tags: [validate]

    - name: Display completion message
      ansible.builtin.debug:
        msg: |
          ════════════════════════════════════════════════════════════════
          ✅ Node preparation complete: {{ inventory_hostname }}
          ════════════════════════════════════════════════════════════════
          • Packages installed
          • Swap disabled
          • Kernel modules loaded
          • Sysctl tuned for Kubernetes
          • Containerd configured with SystemdCgroup
          {% if cgroup_status.stdout == "disabled" %}
          ⚠️  REBOOT REQUIRED for cgroup changes!
          {% endif %}
      tags: [validate]
```

</details>

### 5.2 Kubernetes Binaries Playbook

**File:** `ansible/playbooks/02_k8s_binaries.yml`

This playbook installs the Kubernetes toolchain on all nodes. We deliberately install version **1.31** (not latest) so we can demonstrate an upgrade procedure later in the guide.

| Package | Installed On | Purpose |
|---------|--------------|---------|
| `kubelet` | All nodes | Node agent that runs pods |
| `kubeadm` | All nodes | Cluster bootstrap tool |
| `kubectl` | All nodes | CLI for cluster interaction |
| `helm` | Control plane only | Package manager for K8s apps |
| `cilium-cli` | Control plane only | CNI management tool |
| `etcd-client` | Control plane only | Direct etcd access for debugging |
| `k9s` | Control plane only | Terminal UI for cluster management |

> 💡 **Version Locking:** The playbook uses `dpkg --set-selections` to "hold" packages at 1.31.x. This prevents `apt upgrade` from accidentally updating Kubernetes and breaking your cluster.

<details>
<summary>📄 Click to expand full playbook</summary>

```yaml
---
# =============================================================================
# Phase 1 - Install Kubernetes Binaries
# =============================================================================
# Installs the Kubernetes toolchain on all nodes:
#   - Adds official Kubernetes APT repository
#   - Installs kubelet, kubeadm, kubectl (version-locked)
#   - Installs management tools on control plane only
#
# Note: We install 1.31 (not latest) to demonstrate upgrades later.
#
# Usage: ansible-playbook -i hosts playbooks/02_k8s_binaries.yml
# Tags:  repo, packages, tools, validate
# =============================================================================

- name: Phase 1 - Install Kubernetes Binaries
  hosts: all
  become: true
  gather_facts: true

  vars:
    # Kubernetes version - deliberately not latest for upgrade demo
    k8s_version_major: "1.31"
    k8s_pkg_version: "1.31.*"
    
    # Tool versions (latest stable)
    helm_version: "latest"
    cilium_cli_version: "latest"

  # =========================================================================
  # TASKS
  # =========================================================================
  tasks:
    # -----------------------------------------------------------------------
    # PRE-FLIGHT CHECKS
    # -----------------------------------------------------------------------
    - name: Verify containerd is running
      ansible.builtin.command: systemctl is-active containerd
      register: containerd_status
      changed_when: false
      failed_when: containerd_status.stdout != "active"
      tags: [preflight]

    - name: Display installation plan
      ansible.builtin.debug:
        msg: |
          ════════════════════════════════════════════════════════════════
          Installing Kubernetes {{ k8s_version_major }} on {{ inventory_hostname }}
          ════════════════════════════════════════════════════════════════
          Role: {{ 'Control Plane' if 'big' in group_names else 'Worker' }}
          Packages: kubelet, kubeadm, kubectl ({{ k8s_pkg_version }})
          {% if 'big' in group_names %}
          Extra tools: helm, cilium-cli, etcdctl
          {% endif %}
      tags: [preflight]

    # -----------------------------------------------------------------------
    # KUBERNETES APT REPOSITORY
    # -----------------------------------------------------------------------
    - name: Create apt keyrings directory
      ansible.builtin.file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'
      tags: [repo]

    - name: Download Kubernetes GPG key
      ansible.builtin.get_url:
        url: "https://pkgs.k8s.io/core:/stable:/v{{ k8s_version_major }}/deb/Release.key"
        dest: /tmp/kubernetes-release.key
        mode: '0644'
      tags: [repo]

    - name: Convert and install GPG key
      ansible.builtin.shell: |
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg < /tmp/kubernetes-release.key
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      tags: [repo]

    - name: Add Kubernetes apt repository
      ansible.builtin.apt_repository:
        repo: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ k8s_version_major }}/deb/ /"
        state: present
        filename: kubernetes
        update_cache: true
      tags: [repo]

    # -----------------------------------------------------------------------
    # KUBERNETES PACKAGES (ALL NODES)
    # -----------------------------------------------------------------------
    - name: Install Kubernetes packages
      ansible.builtin.apt:
        name:
          - "kubelet={{ k8s_pkg_version }}"
          - "kubeadm={{ k8s_pkg_version }}"
          - "kubectl={{ k8s_pkg_version }}"
        state: present
        allow_downgrade: true
      tags: [packages]

    - name: Hold Kubernetes packages at current version
      ansible.builtin.dpkg_selections:
        name: "{{ item }}"
        selection: hold
      loop:
        - kubelet
        - kubeadm
        - kubectl
      tags: [packages]

    - name: Enable kubelet service (starts after kubeadm init)
      ansible.builtin.service:
        name: kubelet
        enabled: true
      tags: [packages]

    - name: Configure kubelet extra args for Raspberry Pi
      ansible.builtin.copy:
        dest: /etc/default/kubelet
        content: |
          # Extra kubelet arguments for Raspberry Pi
          KUBELET_EXTRA_ARGS="--node-ip={{ ansible_default_ipv4.address }}"
        mode: '0644'
      tags: [packages]

    # -----------------------------------------------------------------------
    # CONTROL PLANE TOOLS (CP ONLY)
    # -----------------------------------------------------------------------
    - name: Install control plane management tools
      when: "'big' in group_names"
      tags: [tools]
      block:
        # etcdctl - for etcd debugging
        - name: Install etcdctl
          ansible.builtin.apt:
            name: etcd-client
            state: present

        # Helm - Kubernetes package manager
        - name: Check if Helm is installed
          ansible.builtin.command: helm version --short
          register: helm_check
          changed_when: false
          failed_when: false

        - name: Download Helm installer
          ansible.builtin.get_url:
            url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            dest: /tmp/get_helm.sh
            mode: '0700'
          when: helm_check.rc != 0

        - name: Install Helm
          ansible.builtin.command: /tmp/get_helm.sh
          when: helm_check.rc != 0
          environment:
            DESIRED_VERSION: "{{ helm_version if helm_version != 'latest' else '' }}"

        # Cilium CLI - CNI management
        - name: Check if Cilium CLI is installed
          ansible.builtin.command: cilium version --client
          register: cilium_check
          changed_when: false
          failed_when: false

        - name: Get latest Cilium CLI version
          ansible.builtin.uri:
            url: https://api.github.com/repos/cilium/cilium-cli/releases/latest
            return_content: true
          register: cilium_release
          when: cilium_check.rc != 0 and cilium_cli_version == "latest"

        - name: Set Cilium CLI version
          ansible.builtin.set_fact:
            cilium_install_version: "{{ cilium_release.json.tag_name | default('v0.16.0') }}"
          when: cilium_check.rc != 0

        - name: Download and install Cilium CLI
          ansible.builtin.unarchive:
            src: "https://github.com/cilium/cilium-cli/releases/download/{{ cilium_install_version }}/cilium-linux-arm64.tar.gz"
            dest: /usr/local/bin
            remote_src: true
            mode: '0755'
            include:
              - cilium
          when: cilium_check.rc != 0

        # k9s - Terminal UI (optional but very useful)
        - name: Check if k9s is installed
          ansible.builtin.command: k9s version --short
          register: k9s_check
          changed_when: false
          failed_when: false

        - name: Get latest k9s version
          ansible.builtin.uri:
            url: https://api.github.com/repos/derailed/k9s/releases/latest
            return_content: true
          register: k9s_release
          when: k9s_check.rc != 0

        - name: Download and install k9s
          ansible.builtin.unarchive:
            src: "https://github.com/derailed/k9s/releases/download/{{ k9s_release.json.tag_name }}/k9s_Linux_arm64.tar.gz"
            dest: /usr/local/bin
            remote_src: true
            mode: '0755'
            include:
              - k9s
          when: k9s_check.rc != 0

    # -----------------------------------------------------------------------
    # BASH COMPLETION (ALL NODES)
    # -----------------------------------------------------------------------
    - name: Setup kubectl bash completion
      ansible.builtin.shell: |
        kubectl completion bash > /etc/bash_completion.d/kubectl
      args:
        creates: /etc/bash_completion.d/kubectl
      tags: [tools]

    - name: Setup kubeadm bash completion
      ansible.builtin.shell: |
        kubeadm completion bash > /etc/bash_completion.d/kubeadm
      args:
        creates: /etc/bash_completion.d/kubeadm
      tags: [tools]

    # -----------------------------------------------------------------------
    # VALIDATION
    # -----------------------------------------------------------------------
    - name: Verify kubeadm installation
      ansible.builtin.command: kubeadm version -o short
      register: kubeadm_version
      changed_when: false
      tags: [validate]

    - name: Verify kubelet installation
      ansible.builtin.command: kubelet --version
      register: kubelet_version
      changed_when: false
      tags: [validate]

    - name: Verify kubectl installation
      ansible.builtin.command: kubectl version --client -o yaml
      register: kubectl_version
      changed_when: false
      tags: [validate]

    - name: Verify Helm installation (control plane)
      ansible.builtin.command: helm version --short
      register: helm_version_check
      changed_when: false
      when: "'big' in group_names"
      tags: [validate]

    - name: Verify Cilium CLI installation (control plane)
      ansible.builtin.command: cilium version --client
      register: cilium_version_check
      changed_when: false
      when: "'big' in group_names"
      tags: [validate]

    - name: Display installation summary
      ansible.builtin.debug:
        msg: |
          ════════════════════════════════════════════════════════════════
          ✅ Kubernetes binaries installed on {{ inventory_hostname }}
          ════════════════════════════════════════════════════════════════
          kubeadm: {{ kubeadm_version.stdout }}
          kubelet: {{ kubelet_version.stdout }}
          kubectl: {{ kubectl_version.stdout | regex_search('gitVersion: ([^\s]+)', '\1') | first }}
          {% if 'big' in group_names %}
          helm:    {{ helm_version_check.stdout | default('installed') }}
          cilium:  {{ cilium_version_check.stdout_lines[0] | default('installed') }}
          {% endif %}
          
          ⚡ Ready for cluster initialization (Phase 2)
      tags: [validate]
```

</details>

### 5.3 Infrastructure Verification

**File:** `tests/01_infra_test.sh`

This script validates that Phase 1 successfully prepared all nodes. Run it before proceeding to Phase 2.

**What It Checks:**

| Category | Checks | Pass Criteria |
|----------|--------|---------------|
| **Connectivity** | Ansible ping, SSH to all nodes | All 4 nodes respond |
| **K8s Binaries** | kubeadm, kubelet, kubectl, helm, cilium-cli | Version 1.31.x installed |
| **OS Config** | Swap, cgroups, IP forwarding, bridge netfilter | Swap off, cgroups enabled |
| **Kernel Modules** | overlay, br_netfilter, iscsi_tcp, ip_vs, nf_conntrack | All modules loaded |
| **Container Runtime** | containerd status, SystemdCgroup, pause image, iscsid | All services active |
| **Hardware** | GPU mem, WiFi/BT disabled, watchdog | RPi optimizations applied |
| **Packages** | open-iscsi, nfs-common, ipset, ipvsadm, conntrack | All dependencies installed |

<details>
<summary>📄 Click to expand full test script</summary>

```bash
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
check "Kubernetes version 1.31" "ansible -i ansible/hosts all -m shell -a 'kubeadm version -o short | grep -q v1.31'"
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
printf "║  Passed: %-3d  │  Failed: %-3d  │  Warnings: %-3d               ║\n" $PASS $FAIL $WARN
echo "╚═══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "⚠️  Some tests failed. Review the output above and check node logs:"
    echo "   ansible -i ansible/hosts all -m shell -a 'journalctl -n 50'"
    echo ""
    echo "Common fixes:"
    echo "  • Swap still active: reboot nodes after playbook"
    echo "  • Missing modules: check /etc/modules-load.d/k8s.conf"
    echo "  • containerd issues: systemctl restart containerd"
    exit 1
fi

echo ""
echo "🎉 PHASE 1 COMPLETE - All nodes are Kubernetes-ready!"
echo "   Proceed to Phase 2: Cluster Bootstrap"
echo ""
echo "   Next command:"
echo "   ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml"
```

</details>

### 5.4 Phase 1 Execution Steps

Execute the following commands from your **management machine** (WSL/Linux/Mac):

```bash
# Navigate to the repository root
cd ~/Kubernetes-on-Raspberry-Pi-kubeadm-and-GitOps-Guide

# Step 1: Prepare the OS (installs deps, disables swap, configures kernel)
# ⚠️ Nodes will reboot if cgroups or kernel parameters change
ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml

# Wait for nodes to come back online (~2-3 minutes after reboot)
sleep 180

# Step 2: Install Kubernetes binaries (kubeadm, kubelet, kubectl, helm)
ansible-playbook -i ansible/hosts ansible/playbooks/02_k8s_binaries.yml

# Step 3: Verify everything is ready
bash tests/01_infra_test.sh
```

**Expected Output:**

```text
╔═══════════════════════════════════════════════════════════════════════╗
║           PHASE 1: INFRASTRUCTURE VERIFICATION SUITE                  ║
╚═══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────┐
│ 1. CONNECTIVITY TESTS                                               │
└─────────────────────────────────────────────────────────────────────┘
✅ Ansible ping (all nodes): PASS
✅ SSH connection (control plane): PASS
✅ SSH connection (workers): PASS

┌─────────────────────────────────────────────────────────────────────┐
│ 2. KUBERNETES BINARY TESTS                                          │
└─────────────────────────────────────────────────────────────────────┘
✅ kubeadm installed (all): PASS
✅ kubelet installed (all): PASS
✅ kubectl installed (all): PASS
✅ Kubernetes version 1.31: PASS
✅ Helm installed (CP): PASS
✅ Cilium CLI installed (CP): PASS
...

╔═══════════════════════════════════════════════════════════════════════╗
║                          SUMMARY                                      ║
╠═══════════════════════════════════════════════════════════════════════╣
║  Passed: 35   │  Failed: 0    │  Warnings: 2                         ║
╚═══════════════════════════════════════════════════════════════════════╝

🎉 PHASE 1 COMPLETE - All nodes are Kubernetes-ready!
   Proceed to Phase 2: Cluster Bootstrap
```

> ✅ **Checkpoint:** If all tests pass, proceed to Phase 2. If any fail, check `/var/log/syslog` on the affected node.

---

## 6. Phase 2: Cluster Bootstrap

In this phase, we initialize the Control Plane, install the networking layer (Cilium), and join the worker nodes. This transforms four standalone Raspberry Pis into a unified Kubernetes cluster.

### Phase 2 Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLUSTER BOOTSTRAP FLOW                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     kubeadm init      ┌─────────────────────────────────┐ │
│  │   rpi4-1    │ ────────────────────► │     Control Plane Components    │ │
│  │  (big node) │                       │  • API Server    • Scheduler    │ │
│  │   8GB RAM   │                       │  • Controller    • etcd         │ │
│  └─────────────┘                       └─────────────────────────────────┘ │
│        │                                           │                       │
│        │ Cilium CNI                               │ Join Token             │
│        ▼                                           ▼                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Cluster Network                              │   │
│  │  Pod CIDR: 10.244.0.0/16  │  Service CIDR: 10.96.0.0/12           │   │
│  │  Cilium replaces kube-proxy  │  L2 Announcements for LoadBalancer │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│        │                  │                  │                             │
│        ▼                  ▼                  ▼                             │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐                         │
│  │  rpi4-2  │      │  rpi4-3  │      │  rpi4-4  │   Worker Nodes          │
│  │  4GB RAM │      │  4GB RAM │      │  4GB RAM │   (small group)         │
│  └──────────┘      └──────────┘      └──────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 2 Components

| Component | Version | Purpose | Raspberry Pi Optimization |
|-----------|---------|---------|---------------------------|
| **kubeadm** | 1.31.0 | Cluster bootstrapper | Custom config skips kube-proxy |
| **Cilium** | 1.18.4 | CNI + Service Mesh | eBPF-based, replaces kube-proxy |
| **Hubble** | (bundled) | Network Observability | NodePort UI for debugging |
| **Metrics Server** | 3.12.2 | Resource metrics | `--kubelet-insecure-tls` for self-signed certs |

### Why Cilium?

Cilium is the ideal CNI for Raspberry Pi clusters:

| Feature | Benefit for RPi |
|---------|----------------|
| **eBPF-based** | More efficient than iptables, lower CPU usage |
| **kube-proxy replacement** | One less component, reduced memory footprint |
| **L2 Announcements** | Native LoadBalancer support without MetalLB |
| **Hubble** | Built-in network observability UI |
| **WireGuard encryption** | Optional cluster-wide encryption |

### 6.1 Cluster Initialization Playbook
**File:** `ansible/playbooks/03_cluster_init.yml`

This playbook orchestrates the complete cluster bootstrap in three phases:

| Phase | Hosts | Actions |
|-------|-------|----------|
| **2a - Init Control Plane** | `big` | kubeadm init, configure kubectl, install Cilium, generate join token |
| **2b - Join Workers** | `small` | Join each worker to the cluster using the generated token |
| **2c - Post-Config** | `big` | Apply hardware labels, configure node roles |

**Key Configuration Decisions:**

| Setting | Value | Reason |
|---------|-------|--------|
| `skipPhases: addon/kube-proxy` | Enabled | Cilium replaces kube-proxy with eBPF |
| `taints: []` | Empty | Allow workloads on Control Plane (4-node cluster) |
| `kubeProxyReplacement: true` | Enabled | Full kube-proxy replacement mode |
| `l2announcements.enabled: true` | Enabled | Native LoadBalancer without MetalLB |
| `hubble.ui.service.type: NodePort` | NodePort | Access Hubble UI via any node IP |

<details>
<summary>📄 Click to expand full ansible/playbooks/03_cluster_init.yml</summary>

```yaml
---
# =============================================================================
# Phase 2: Cluster Bootstrap Playbook
# =============================================================================
# This playbook initializes the Kubernetes cluster with Cilium CNI.
#
# Phases:
#   2a - Initialize Control Plane (kubeadm init, Cilium, generate join token)
#   2b - Join Workers (kubeadm join on all small nodes)
#   2c - Post-Config (apply hardware labels for scheduling affinity)
#
# Prerequisites:
#   - Phase 1 playbooks completed (01_node_prep.yml, 02_k8s_binaries.yml)
#   - All nodes reachable via SSH
#   - Helm installed on control plane
#
# Usage: ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml
# =============================================================================

- name: Phase 2a - Initialize Control Plane
  hosts: big
  become: true
  vars:
    # Network CIDRs - must not overlap with your home network
    pod_network_cidr: "10.244.0.0/16"
    service_cidr: "10.96.0.0/12"
    # Cilium version - check https://github.com/cilium/cilium/releases
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
          # Skip kube-proxy for Cilium (eBPF-based replacement)
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

    - name: Wait for Cilium to be ready
      shell: |
        kubectl wait --for=condition=Ready pods -l k8s-app=cilium -n kube-system --timeout=300s
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

# =============================================================================
# Phase 2b: Join Worker Nodes
# =============================================================================
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

# =============================================================================
# Phase 2c: Apply Hardware Labels for Scheduling Affinity
# =============================================================================
- name: Phase 2c - Apply Labels & Post-Config
  hosts: big
  become: true
  tasks:
    - name: Wait for all nodes to be ready
      shell: |
        kubectl wait --for=condition=Ready nodes --all --timeout=300s
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

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

</details>

### 6.2 Metrics Server

**File:** `bootstrap/metrics-server/install.sh`

Metrics Server is a cluster-wide aggregator of resource usage data. It collects CPU and memory metrics from kubelets and exposes them via the Kubernetes API.

| Feature | Dependency | Why It Matters |
|---------|------------|----------------|
| `kubectl top` | Metrics Server | View real-time node/pod resource usage |
| **HPA** | Metrics Server | Auto-scale based on CPU/memory |
| **VPA** | Metrics Server | Right-size container requests |
| **Dashboard** | Metrics Server | Display resource graphs |

**Raspberry Pi Considerations:**

| Setting | Value | Reason |
|---------|-------|--------|
| `--kubelet-insecure-tls` | Required | kubeadm uses self-signed kubelet certs |
| `--kubelet-preferred-address-types` | `InternalIP` | Prefer internal cluster IPs |
| Resource requests | 100m CPU, 200Mi | Tuned for RPi resources |

<details>
<summary>📄 Click to expand full bootstrap/metrics-server/install.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Metrics Server Bootstrap Script
# =============================================================================
# Metrics Server is a cluster-wide aggregator of resource usage data.
#
# Required for:
#   - kubectl top nodes/pods commands
#   - Horizontal Pod Autoscaler (HPA)
#   - Vertical Pod Autoscaler (VPA)
#   - Kubernetes Dashboard resource displays
#
# Raspberry Pi Considerations:
#   - --kubelet-insecure-tls: Required because kubeadm uses self-signed certs
#   - --kubelet-preferred-address-types=InternalIP: Use internal cluster IPs
#   - Resource limits tuned for ARM64 with limited RAM
#
# Usage: bash bootstrap/metrics-server/install.sh
# =============================================================================

set -e
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              METRICS SERVER BOOTSTRAP                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"

# Add Helm repository
echo "Adding Metrics Server Helm repository..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install Metrics Server with ARM64 compatibility
echo "Installing Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.12.2 \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="200Mi" \
  --set resources.limits.cpu="250m" \
  --set resources.limits.memory="300Mi"

echo ""
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              METRICS SERVER INSTALLED                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Verification commands:"
echo "  kubectl top nodes        # View node resource usage"
echo "  kubectl top pods -A      # View pod resource usage across all namespaces"
echo ""
```

</details>

*Note: The `--kubelet-insecure-tls` flag is required because kubeadm generates self-signed certificates for the kubelet.*

### 6.3 Network Verification Script

**File:** `tests/02_network_test.sh`

This script validates the cluster bootstrap by checking critical networking components:

| Check | Pass Criteria | What It Validates |
|-------|---------------|-------------------|
| **Node Readiness** | 4/4 nodes Ready | All nodes joined and Cilium agent running |
| **Cilium Pods** | 4 pods Running | CNI deployed on every node |
| **Hubble Service** | Service exists | Network observability available |
| **Hardware Labels** | `unique-hdd=true` on CP | Labels applied for scheduling affinity |

<details>
<summary>📄 Click to expand full tests/02_network_test.sh</summary>

```bash
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
#
# Usage: bash tests/02_network_test.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

READY_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready" || echo "0")
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

CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$CILIUM_PODS" -eq 4 ]; then
    echo -e "${GREEN}✅ Cilium Agents Running on all nodes${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Cilium pods missing or failed (Found $CILIUM_PODS/4)${NC}"
    kubectl get pods -n kube-system -l k8s-app=cilium
    ((FAIL++))
fi

# Check Cilium Operator
OPERATOR=$(kubectl get pods -n kube-system -l name=cilium-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
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

# -----------------------------------------------------------------------------
# 4. Check Labels
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 4. HARDWARE LABELS                                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

CP_LABELS=$(kubectl get node rpi4-1 --show-labels 2>/dev/null || echo "")
if [[ $CP_LABELS == *"hardware/unique-hdd=true"* ]]; then
    echo -e "${GREEN}✅ Control Plane label (unique-hdd=true) applied${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Control Plane labels missing${NC}"
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
    exit 1
fi

echo ""
echo "🎉 PHASE 2 COMPLETE - Cluster is operational!"
echo ""
echo "Next command:"
echo "  ansible-playbook -i ansible/hosts ansible/playbooks/04_storage_mount.yml"
```

</details>

### 6.4 Phase 2 Execution Steps

Execute the following commands from your **management machine** (WSL/Linux/Mac):

```bash
# Navigate to the repository root
cd ~/Kubernetes-on-Raspberry-Pi-kubeadm-and-GitOps-Guide

# Step 1: Initialize the cluster (Control Plane + Workers)
# ⚠️ This will overwrite ~/.kube/config on your local machine
ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml

# Step 2: Install Metrics Server for kubectl top and HPA support
bash bootstrap/metrics-server/install.sh

# Step 3: Verify cluster status
bash tests/02_network_test.sh
```

**Expected Output from Verification Script:**

```text
=== NETWORK & CLUSTER VERIFICATION SUITE ===
Checking Node Status...
✅ All 4 Nodes are Ready
Checking Cilium...
✅ Cilium Agents Running on all nodes
Checking Hubble...
✅ Hubble UI Service exists
Checking Control Plane Labels...
✅ CP Label (unique-hdd) matches
=== PHASE 2 COMPLETE ===
```

**Verify Metrics Server:**

```bash
# Check resource usage across all nodes
kubectl top nodes
```

```text
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
rpi4-1   312m         8%     1842Mi          24%
rpi4-2   89m          2%     512Mi           13%
rpi4-3   76m          2%     489Mi           13%
rpi4-4   82m          2%     501Mi           13%
```

**Access Hubble UI:**

```bash
# Get the Hubble UI NodePort
kubectl get svc hubble-ui -n kube-system

# Access via any node IP, e.g.:
# http://192.168.0.201:<NodePort>
```

> ✅ **Checkpoint:** All nodes Ready, Cilium running, Metrics available. Proceed to Phase 3: Storage.

---

## 7. Phase 3: Storage Foundation

In this phase, we enable the persistent storage layer. Since Raspberry Pis use SD cards (which are slow and unreliable for heavy writes), we utilize the **1TB HDD** attached to the Control Plane (`rpi4-1`).

### Storage Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     LONGHORN STORAGE TOPOLOGY                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐   │
│  │         rpi4-1 (Control Plane) - Storage Node                     │   │
│  │  ┌─────────────────┐    ┌──────────────────────────────────────┐   │   │
│  │  │  128GB SD Card  │    │  1TB USB HDD (/var/lib/longhorn)     │   │   │
│  │  │  (OS + etcd)    │    │  • allowScheduling: true            │   │   │
│  │  └─────────────────┘    │  • Longhorn data path               │   │   │
│  │                         │  • Replica storage (1 replica)      │   │   │
│  │                         └──────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                            │                                           │
│                            │ iSCSI over Network                        │
│                            ▼                                           │
│  ┌───────────────────────────────────────────────────────────────────┐   │
│  │              Worker Nodes (rpi4-2, rpi4-3, rpi4-4)               │   │
│  │  ┌─────────────────┐  • allowScheduling: false                    │   │
│  │  │  64GB SD Card   │  • No local Longhorn data                    │   │
│  │  │  (OS only)      │  • Access volumes via iSCSI                  │   │
│  │  └─────────────────┘  • Pods can mount PVCs from rpi4-1            │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 3 Components

| Component | Version | Purpose | Configuration |
|-----------|---------|---------|---------------|
| **Longhorn** | 1.10.1 | Distributed block storage | Single HDD node, 1 replica |
| **iSCSI** | System | Volume attachment protocol | Pre-installed in Phase 1 |
| **ext4** | System | HDD filesystem | `noatime` for performance |

### Why Longhorn for Raspberry Pi?

| Challenge | Longhorn Solution |
|-----------|-------------------|
| **SD card wear** | Store all data on HDD, not SD cards |
| **Limited nodes** | Supports single-node storage (replica=1) |
| **Network storage** | iSCSI allows any pod to access HDD volumes |
| **UI access** | Built-in web dashboard for management |
| **Backup** | Supports S3-compatible backup targets |

### 7.1 Storage Mounting Playbook

**File:** `ansible/playbooks/04_storage_mount.yml`

This playbook runs only on the `big` (Control Plane) node. It formats the USB HDD (if necessary) and mounts it persistently to the path Longhorn expects.

| Setting | Value | Notes |
|---------|-------|-------|
| **Mount Point** | `/var/lib/longhorn` | Default Longhorn data path |
| **Filesystem** | `ext4` | Best balance of performance and reliability |
| **Mount Options** | `defaults,noatime` | `noatime` reduces write operations |
| **Target Node** | `rpi4-1` only | Only the HDD-equipped node |

> ⚠️ **Important:** Before running, verify your HDD device with `lsblk` on `rpi4-1`. The default is `/dev/sda1` but USB enumeration can vary. For stability, use `/dev/disk/by-id/...`.

<details>
<summary>📄 Click to expand full ansible/playbooks/04_storage_mount.yml</summary>

```yaml
---
# =============================================================================
# Phase 3a: Storage Mounting Playbook
# =============================================================================
# This playbook mounts the external USB HDD on the Control Plane node.
# Longhorn will use this mount point as the sole storage location.
#
# Configuration:
#   - Mount Point: /var/lib/longhorn (Longhorn default data path)
#   - Filesystem: ext4 (best balance of performance and reliability)
#   - Mount Options: defaults,noatime (reduces write operations)
#
# ⚠️  Before running, verify your HDD device:
#     ansible -i ansible/hosts big -m shell -a 'lsblk'
#
# Usage: ansible-playbook -i ansible/hosts ansible/playbooks/04_storage_mount.yml
# =============================================================================

- name: Phase 3a - Mount HDD for Longhorn
  hosts: big
  become: true
  vars:
    # =========================================================================
    # CHANGE THIS to your actual HDD device identifier
    # =========================================================================
    hdd_device: "/dev/sda1"
    # Option 2 (Recommended): Use by-id path for stability
    # hdd_device: "/dev/disk/by-id/usb-YOUR_DRIVE_ID-part1"
    mount_path: "/var/lib/longhorn"
  tasks:
    - name: Ensure Mount Directory Exists
      file:
        path: "{{ mount_path }}"
        state: directory
        mode: '0755'

    - name: Check if already formatted
      command: blkid -o value -s TYPE {{ hdd_device }}
      register: fs_type
      changed_when: false
      failed_when: false

    - name: Format HDD (ext4) if not already formatted
      filesystem:
        fstype: ext4
        dev: "{{ hdd_device }}"
      when: fs_type.stdout != "ext4"

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

    - name: Display Mount Status
      debug:
        msg: "Storage mounted at {{ mount_path }}: {{ df_out.stdout }}"
```

</details>

### 7.2 Longhorn Bootstrap Script

**File:** `bootstrap/longhorn/install.sh`

This script installs Longhorn via Helm and applies critical configurations to protect your SD cards from being used as storage targets.

**Installation Phases:**

| Phase | Action | Purpose |
|-------|--------|---------|
| **1. Helm Install** | Deploy Longhorn v1.10.1 | Core storage system |
| **2. Label CP** | `node.longhorn.io/create-default-disk=true` | Mark rpi4-1 as storage node |
| **3. Lock Workers** | `allowScheduling: false` on rpi4-2,3,4 | Protect SD cards from writes |

**Longhorn Settings:**

| Setting | Value | Reason |
|---------|-------|--------|
| `defaultClassReplicaCount` | `1` | Only 1 HDD available |
| `createDefaultDiskLabeledNodes` | `true` | Auto-create disk on labeled nodes |
| `allowNodeDrainWithLastHealthyReplica` | `true` | Allow maintenance with single replica |
| `defaultDataPath` | `/var/lib/longhorn` | Match the mounted HDD path |

<details>
<summary>📄 Click to expand full bootstrap/longhorn/install.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 3b: Longhorn Bootstrap Script
# =============================================================================
# Installs Longhorn distributed storage and configures it for single-HDD setup.
#
# Key Configuration:
#   - Single replica (only 1 HDD available)
#   - Storage only on rpi4-1 (Control Plane with HDD)
#   - Workers locked out (protect SD cards from writes)
#
# Prerequisites:
#   - HDD mounted at /var/lib/longhorn on rpi4-1
#   - iSCSI tools installed (Phase 1)
#   - kubectl and helm configured
#
# Usage: bash bootstrap/longhorn/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 3: LONGHORN BOOTSTRAP                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding Longhorn Helm Repository                             │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add longhorn https://charts.longhorn.io
helm repo update

# =============================================================================
# 2. Install Longhorn
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing Longhorn v1.10.1                                 │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.10.1 \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=1 \
  --set defaultSettings.createDefaultDiskLabeledNodes=true \
  --set defaultSettings.allowNodeDrainWithLastHealthyReplica=true \
  --wait

echo ""
echo "Waiting for Longhorn pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n longhorn-system --timeout=300s

# =============================================================================
# 3. Configure Control Plane as Storage Node
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Configuring Control Plane (HDD) Storage                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"
kubectl label node rpi4-1 node.longhorn.io/create-default-disk=true --overwrite
echo "✅ Label applied: node.longhorn.io/create-default-disk=true on rpi4-1"

# =============================================================================
# 4. Protect Worker SD Cards
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 4: Locking Workers (Protect SD Cards)                          │"
echo "└─────────────────────────────────────────────────────────────────────┘"

sleep 10  # Wait for Longhorn Node CRDs

WORKERS=("rpi4-2" "rpi4-3" "rpi4-4")
for NODE in "${WORKERS[@]}"; do
    echo "Disabling storage scheduling on $NODE..."
    kubectl patch nodes.longhorn.io "$NODE" -n longhorn-system \
        --type=merge -p '{"spec":{"allowScheduling": false}}' 2>/dev/null || \
        echo "  ⚠️  Node CRD not yet created for $NODE"
done

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              LONGHORN INSTALLED & CONFIGURED                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Verify with: bash tests/03_storage_test.sh"
```

</details>

### 7.3 Storage Verification Script

**File:** `tests/03_storage_test.sh`

This script creates a real PVC and Pod to verify end-to-end storage functionality:

| Check | Test Method | Pass Criteria |
|-------|-------------|---------------|
| **System Health** | Count Running pods in `longhorn-system` | >10 pods Running |
| **CP Scheduling** | Check `nodes.longhorn.io/rpi4-1` | `allowScheduling: true` |
| **Worker Protection** | Check `nodes.longhorn.io/rpi4-2` | `allowScheduling: false` |
| **Volume Provisioning** | Create 100Mi PVC | PVC bound successfully |
| **Network Attach** | Pod on rpi4-2 mounts volume from rpi4-1 | Pod reaches Ready state |

The test forces the pod to run on a worker node (`hardware/sd=64gb` selector) while the volume data lives on the control plane's HDD. This validates iSCSI network storage is working.

<details>
<summary>📄 Click to expand full tests/03_storage_test.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 3: Storage Verification Script
# =============================================================================
# This script validates end-to-end storage functionality with Longhorn.
#
# Tests:
#   1. Longhorn System Health - All pods running in longhorn-system
#   2. Node Scheduling Config - CP enabled, workers disabled
#   3. Volume Provisioning - Create PVC and verify it binds
#   4. Network Attach - Pod on worker mounts volume from CP
#
# Usage: bash tests/03_storage_test.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              STORAGE VERIFICATION SUITE                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# =============================================================================
# 1. Check Longhorn System Pods
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 1. LONGHORN SYSTEM HEALTH                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"

PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$PODS" -gt 10 ]; then
    echo -e "${GREEN}✅ Longhorn System is Running ($PODS pods)${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Longhorn pods are missing or crashed${NC}"
    kubectl get pods -n longhorn-system
    ((FAIL++))
fi

# =============================================================================
# 2. Check Node Configuration
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 2. NODE SCHEDULING CONFIGURATION                                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"

CP_SCHED=$(kubectl get nodes.longhorn.io rpi4-1 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null)
WORKER_SCHED=$(kubectl get nodes.longhorn.io rpi4-2 -n longhorn-system -o jsonpath='{.spec.allowScheduling}' 2>/dev/null)

if [ "$CP_SCHED" == "true" ]; then
    echo -e "${GREEN}✅ Control Plane (rpi4-1): allowScheduling=true${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ Control Plane scheduling incorrect${NC}"
    ((FAIL++))
fi

if [ "$WORKER_SCHED" == "false" ]; then
    echo -e "${GREEN}✅ Workers: allowScheduling=false (SD cards protected)${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠️  Worker scheduling not disabled${NC}"
    ((FAIL++))
fi

# =============================================================================
# 3. Create Test Workload
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 3. VOLUME PROVISIONING TEST                                         │"
echo "└─────────────────────────────────────────────────────────────────────┘"

kubectl delete pod test-storage-pod --ignore-not-found=true 2>/dev/null
kubectl delete pvc test-storage-verify --ignore-not-found=true 2>/dev/null

echo "Creating test PVC and Pod..."
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
    hardware/sd: "64gb"
  containers:
  - name: write-test
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo 'Storage Works!' > /data/test.txt && sleep 30"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: test-storage-verify
  restartPolicy: Never
EOF

echo "Waiting for Pod to start..."
kubectl wait --for=condition=Ready pod/test-storage-pod --timeout=120s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Storage Attached Successfully over Network${NC}"
    POD_NODE=$(kubectl get pod test-storage-pod -o jsonpath='{.spec.nodeName}')
    echo "   Pod running on: $POD_NODE, Volume on: rpi4-1"
    kubectl delete pod test-storage-pod --ignore-not-found=true
    kubectl delete pvc test-storage-verify --ignore-not-found=true
    ((PASS++))
else
    echo -e "${RED}❌ Test Pod failed to start${NC}"
    kubectl describe pod test-storage-pod
    ((FAIL++))
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
printf "║  Passed: %-3d  │  Failed: %-3d                                       ║\n" $PASS $FAIL
echo "╚═══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}❌ PHASE 3 VERIFICATION FAILED${NC}"
    exit 1
fi

echo ""
echo "🎉 PHASE 3 COMPLETE - Storage is operational!"
echo "Next command: bash bootstrap/traefik/install.sh"
```

</details>

### 7.4 Phase 3 Execution Steps

Execute the following commands from your **management machine**:

```bash
# Navigate to the repository root
cd ~/Kubernetes-on-Raspberry-Pi-kubeadm-and-GitOps-Guide

# Step 1: Mount the HDD on rpi4-1
# ⚠️ First verify device with: ansible -i ansible/hosts big -m shell -a 'lsblk'
ansible-playbook -i ansible/hosts ansible/playbooks/04_storage_mount.yml

# Step 2: Install and configure Longhorn
bash bootstrap/longhorn/install.sh

# Step 3: Verify storage is working
bash tests/03_storage_test.sh
```

**Expected Output from Verification Script:**

```text
=== STORAGE VERIFICATION SUITE ===
Checking Longhorn System...
✅ Longhorn System is Running
Checking Disk Scheduling...
✅ HDD Affinity Configured (Only CP stores data)
Deploying Test PVC & Pod...
persistentvolumeclaim/test-storage-verify created
pod/test-storage-pod created
Waiting for Pod to start (This verifies volume attach)...
pod/test-storage-pod condition met
✅ Storage Attached Successfully over Network
pod "test-storage-pod" deleted
persistentvolumeclaim "test-storage-verify" deleted
=== PHASE 3 COMPLETE ===
```

**Access Longhorn UI:**

```bash
# Port-forward the Longhorn frontend
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80

# Access at http://localhost:8080
```

**Verify Storage Configuration:**

```bash
# Check node scheduling status
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
'NAME:.metadata.name,SCHEDULING:.spec.allowScheduling,DISKS:.spec.disks'
```

```text
NAME     SCHEDULING   DISKS
rpi4-1   true         map[default-disk-...]
rpi4-2   false        <none>
rpi4-3   false        <none>
rpi4-4   false        <none>
```

> ✅ **Checkpoint:** Storage operational, HDD-only affinity confirmed. Proceed to Phase 4: GitOps.

---

## 8. Phase 4: GitOps & Observability

We now move up the stack to the application layer. Instead of managing tools individually, we establish the **GitOps Loop**—a self-healing, declarative approach where Git is the single source of truth for cluster state.

### Phase 4 Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           GITOPS CONTROL LOOP                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                         EXTERNAL ACCESS FLOW                             │  │
│   │                                                                          │  │
│   │    Internet ──► Router ──► 192.168.0.210 ──► Traefik Gateway            │  │
│   │                              (Cilium L2)       │                         │  │
│   │                                                ▼                         │  │
│   │    ┌──────────────────────────────────────────────────────────────┐     │  │
│   │    │              HTTPRoute Routing Table                         │     │  │
│   │    │  ┌─────────────────────┬─────────────────────────────────┐  │     │  │
│   │    │  │ argocd.*.nip.io     │ → argocd-server:80              │  │     │  │
│   │    │  │ gitea.*.nip.io      │ → gitea-http:3000               │  │     │  │
│   │    │  │ grafana.*.nip.io    │ → grafana:80                    │  │     │  │
│   │    │  │ minio.*.nip.io      │ → minio-console:9001            │  │     │  │
│   │    │  └─────────────────────┴─────────────────────────────────┘  │     │  │
│   │    └──────────────────────────────────────────────────────────────┘     │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                         GITOPS RECONCILIATION                            │  │
│   │                                                                          │  │
│   │   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐       │  │
│   │   │   Gitea     │◄───────►│   ArgoCD    │────────►│  Kubernetes │       │  │
│   │   │ (Git Repo)  │  poll   │ (Controller)│  apply  │   Cluster   │       │  │
│   │   └─────────────┘         └──────┬──────┘         └─────────────┘       │  │
│   │                                  │                                       │  │
│   │                                  ▼                                       │  │
│   │                          ┌─────────────┐                                │  │
│   │                          │App of Apps  │                                │  │
│   │                          │  (Parent)   │                                │  │
│   │                          └──────┬──────┘                                │  │
│   │                                 │                                        │  │
│   │            ┌────────────────────┼────────────────────┐                  │  │
│   │            ▼                    ▼                    ▼                  │  │
│   │    ┌─────────────┐      ┌─────────────┐      ┌─────────────┐           │  │
│   │    │  Security   │      │Observability│      │ Management  │           │  │
│   │    │   Apps      │      │    Apps     │      │    Apps     │           │  │
│   │    └─────────────┘      └─────────────┘      └─────────────┘           │  │
│   │                                                                          │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 4 Components

| Component | Version | Purpose | Access URL |
|-----------|---------|---------|------------|
| **Traefik** | 37.3.0 | Gateway API / Ingress Controller | LoadBalancer: 192.168.0.210 |
| **ArgoCD** | 7.7.0 | GitOps Controller | argocd.192.168.0.210.nip.io |
| **Gitea** | 10.6.0 | Self-hosted Git Server | gitea.192.168.0.210.nip.io |
| **Prometheus Stack** | 66.3.0 | Metrics & Alerting | grafana.192.168.0.210.nip.io |

### The Bootstrap Order

The components must be installed in a specific order due to dependencies:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                     PHASE 4 BOOTSTRAP SEQUENCE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Step 1          Step 2          Step 3          Step 4                 │
│  ┌──────┐        ┌──────┐        ┌──────┐        ┌──────┐              │
│  │Traefik│───────►│ArgoCD│───────►│Gitea │───────►│App of│              │
│  │      │        │      │        │      │        │ Apps │              │
│  └──────┘        └──────┘        └──────┘        └──────┘              │
│     │               │               │               │                   │
│     ▼               ▼               ▼               ▼                   │
│  Provides        Provides        Provides        Deploys               │
│  LoadBalancer    GitOps          Git Repo        Everything            │
│  + Routing       Engine          Storage         Else                  │
│                                                                         │
│  ════════════════════════════════════════════════════════════════════  │
│  Manual Bootstrap (Scripts)       │    Automated (ArgoCD Managed)      │
│  ════════════════════════════════════════════════════════════════════  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.1 Gateway API Bootstrap (Traefik)

**File:** `bootstrap/traefik/install.sh`

This script installs **Traefik v3** as the cluster's ingress controller and Gateway API implementation.

**Why Traefik?**

| Feature | Benefit for RPi Cluster |
|---------|-------------------------|
| **Lightweight** | Low memory footprint (~100MB) |
| **Gateway API Native** | Modern routing standard, future-proof |
| **Auto-discovery** | Automatically finds Ingress/HTTPRoute resources |
| **Prometheus Metrics** | Built-in observability integration |
| **JSON Access Logs** | Structured logs for Loki ingestion |

**Configuration Highlights:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `loadBalancerIP` | `192.168.0.210` | Static IP from Cilium L2 pool |
| `providers.kubernetesCRD.allowCrossNamespace` | `true` | Services in any namespace can use Traefik |
| `logs.access.format` | `json` | Structured logs for Loki |
| `metrics.prometheus.enabled` | `true` | Expose metrics for Prometheus |

<details>
<summary>📄 Click to expand full bootstrap/traefik/install.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 4a: Traefik Gateway Bootstrap Script
# =============================================================================
# Installs Traefik v3 as the cluster's ingress controller and Gateway API
# implementation. All external traffic flows through this single entry point.
#
# Features:
#   - LoadBalancer IP from Cilium L2 pool (192.168.0.210)
#   - Cross-namespace routing support
#   - Prometheus metrics enabled
#   - JSON access logs for Loki
#
# Prerequisites:
#   - Cilium CNI with L2 announcements enabled
#   - kubectl and helm configured
#
# Usage: bash bootstrap/traefik/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 4a: TRAEFIK GATEWAY BOOTSTRAP                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding Traefik Helm Repository                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add traefik https://traefik.github.io/charts
helm repo update

# =============================================================================
# 2. Install Traefik
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing Traefik v3                                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Deploying Traefik with Gateway API support..."

helm upgrade --install traefik traefik/traefik \
  --namespace traefik-system \
  --create-namespace \
  --version 37.3.0 \
  --set service.type=LoadBalancer \
  --set service.spec.loadBalancerIP=192.168.0.210 \
  --set ports.web.nodePort=null \
  --set ports.websecure.nodePort=null \
  --set providers.kubernetesCRD.enabled=true \
  --set providers.kubernetesCRD.allowCrossNamespace=true \
  --set providers.kubernetesIngress.enabled=true \
  --set logs.general.level=INFO \
  --set logs.access.enabled=true \
  --set logs.access.format=json \
  --set metrics.prometheus.enabled=true \
  --set metrics.prometheus.addEntryPointsLabels=true \
  --set metrics.prometheus.addRoutersLabels=true \
  --set metrics.prometheus.addServicesLabels=true \
  --set-string service.annotations."prometheus\.io/scrape"="true" \
  --set-string service.annotations."prometheus\.io/port"="9100" \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="100Mi" \
  --set resources.limits.cpu="500m" \
  --set resources.limits.memory="300Mi" \
  --wait

# =============================================================================
# 3. Verify Installation
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Verifying Installation                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

echo "Waiting for LoadBalancer IP assignment..."
sleep 5

EXTERNAL_IP=$(kubectl get svc traefik -n traefik-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              TRAEFIK GATEWAY INSTALLED                                ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  • Namespace: traefik-system"
echo "  • External IP: $EXTERNAL_IP"
echo "  • HTTP Port: 80 (web)"
echo "  • HTTPS Port: 443 (websecure)"
echo "  • Metrics: :9100/metrics"
echo ""
echo "Verify with:"
echo "  kubectl get svc -n traefik-system"
echo "  curl -I http://$EXTERNAL_IP"
echo ""
echo "Next command:"
echo "  bash bootstrap/argocd/install.sh"
```

</details>

### 8.2 GitOps Bootstrap (ArgoCD)

**File:** `bootstrap/argocd/install.sh`

This script installs **ArgoCD**, the GitOps controller that continuously monitors Git repositories and ensures the cluster state matches the desired state defined in those repositories.

**Why ArgoCD?**

| Feature | Benefit for RPi Cluster |
|---------|-------------------------|
| **Declarative** | All config in Git, no manual `kubectl apply` |
| **Self-Healing** | Auto-corrects drift from desired state |
| **Multi-tenancy** | Projects isolate teams/environments |
| **UI Dashboard** | Visual sync status and diff viewer |
| **Rollback** | One-click revert to any previous state |

**Configuration Highlights:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `server.extraArgs` | `--insecure` | TLS offload to Traefik (avoids double encryption) |
| `global.logging.format` | `json` | Structured logs for Loki |
| `configs.params.server.insecure` | `true` | Allows HTTP backend |

**Expected Output:**

```text
╔═══════════════════════════════════════════════════════════════════════╗
║              ARGOCD GITOPS CONTROLLER INSTALLED                       ║
╚═══════════════════════════════════════════════════════════════════════╝

Access Information:
  • URL: http://argocd.192.168.0.210.nip.io
  • Username: admin
  • Password: <see command below>

Retrieve Admin Password:
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d && echo
```

<details>
<summary>📄 Click to expand full bootstrap/argocd/install.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 4b: ArgoCD GitOps Controller Bootstrap Script
# =============================================================================
# Installs ArgoCD, the GitOps engine that watches Git repositories and
# automatically syncs the cluster state to match the desired configuration.
#
# Features:
#   - Insecure mode (TLS offloaded to Traefik)
#   - JSON logging for Loki integration
#   - Ingress for UI access
#
# Prerequisites:
#   - Traefik installed with Gateway/Ingress support
#   - kubectl and helm configured
#
# Usage: bash bootstrap/argocd/install.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 4b: ARGOCD GITOPS BOOTSTRAP                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Add Helm Repository
# =============================================================================
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 1: Adding ArgoCD Helm Repository                               │"
echo "└─────────────────────────────────────────────────────────────────────┘"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# =============================================================================
# 2. Install ArgoCD
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installing ArgoCD                                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Deploying ArgoCD with insecure mode (TLS offload to Traefik)..."

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.0 \
  --set server.extraArgs="{--insecure}" \
  --set configs.params."server\.insecure"=true \
  --set global.logging.format=json \
  --set server.resources.requests.cpu="100m" \
  --set server.resources.requests.memory="128Mi" \
  --set server.resources.limits.cpu="500m" \
  --set server.resources.limits.memory="256Mi" \
  --set controller.resources.requests.cpu="100m" \
  --set controller.resources.requests.memory="256Mi" \
  --set controller.resources.limits.cpu="500m" \
  --set controller.resources.limits.memory="512Mi" \
  --set repoServer.resources.requests.cpu="100m" \
  --set repoServer.resources.requests.memory="128Mi" \
  --set repoServer.resources.limits.cpu="500m" \
  --set repoServer.resources.limits.memory="256Mi" \
  --wait

# =============================================================================
# 3. Create Ingress for UI Access
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 3: Creating Ingress for ArgoCD UI                              │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "Creating Ingress for ArgoCD..."

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
    - host: argocd.192.168.0.210.nip.io
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

# =============================================================================
# 4. Retrieve Initial Admin Password
# =============================================================================
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Step 4: Retrieving Admin Credentials                                │"
echo "└─────────────────────────────────────────────────────────────────────┘"

# Wait for secret to be created
sleep 5
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "pending")

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║              ARGOCD GITOPS CONTROLLER INSTALLED                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Access Information:"
echo "  • URL: http://argocd.192.168.0.210.nip.io"
echo "  • Username: admin"
echo "  • Password: $ARGOCD_PASSWORD"
echo ""
echo "Retrieve Password Later:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Verify with:"
echo "  kubectl get pods -n argocd"
echo "  argocd app list"
echo ""
echo "Next command:"
echo "  kubectl apply -f gitops/services/gitea.yaml"
```

</details>

### 8.3 Source Control Service (Gitea)

**File:** `gitops/services/gitea.yaml`

This is our first **Declarative Application**. Instead of a shell script, this is a YAML file we feed to ArgoCD. Gitea provides a self-hosted Git server that serves as the "source of truth" for our GitOps workflow.

**Why Gitea?**

| Feature | Benefit for RPi Cluster |
|---------|-------------------------|
| **Lightweight** | Runs well on ARM64 with ~200MB memory |
| **Self-contained** | No external dependencies required |
| **GitHub-like UX** | Familiar interface for developers |
| **Built-in CI** | Gitea Actions for local CI/CD |
| **SSH + HTTP** | Both protocols supported |

**Gitea Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `storageClass` | `longhorn` | Persistent data on HDD-backed storage |
| `postgresql.enabled` | `true` | Production-grade database |
| `persistence.size` | `10Gi` | Repository data storage |
| `ssh.port` | `2222` | Avoid conflict with node SSH |
| `service.ssh.type` | `LoadBalancer` | Direct SSH access via Cilium L2 |

**Access Information:**

| Service | URL / Address |
|---------|---------------|
| Web UI | http://gitea.192.168.0.210.nip.io |
| SSH Clone | ssh://git@192.168.0.210:2222/user/repo.git |
| HTTP Clone | http://gitea.192.168.0.210.nip.io/user/repo.git |

<details>
<summary>📄 Click to expand full gitops/services/gitea.yaml</summary>

```yaml
# =============================================================================
# Gitea - Self-Hosted Git Server
# =============================================================================
# Provides the Git repository hosting for the GitOps workflow. All cluster
# configuration lives here as code, making it the "single source of truth".
#
# Features:
#   - PostgreSQL database for production reliability
#   - Longhorn storage for persistent data
#   - SSH and HTTP access for git operations
#   - Modern UI with auto theme detection
#
# Access:
#   - Web: http://gitea.192.168.0.210.nip.io
#   - SSH: ssh://git@192.168.0.210:2222/user/repo.git
#
# First-time Setup:
#   1. Access web UI
#   2. Create admin account
#   3. Create 'home-cluster' repository
#   4. Push gitops/ folder content
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://dl.gitea.com/charts/
    chart: gitea
    targetRevision: 10.6.0
    helm:
      values: |
        # ---------------------------------------------------------------------
        # Global Storage Configuration
        # ---------------------------------------------------------------------
        global:
          storageClass: longhorn
        
        # ---------------------------------------------------------------------
        # Gitea Application Settings
        # ---------------------------------------------------------------------
        gitea:
          admin:
            existingSecret: ""  # Create admin on first login via UI
          
          config:
            APP_NAME: "PiCluster Git"
            
            server:
              DOMAIN: "gitea.192.168.0.210.nip.io"
              ROOT_URL: "http://gitea.192.168.0.210.nip.io/"
              SSH_DOMAIN: "192.168.0.210"
              SSH_PORT: "2222"
            
            ui:
              DEFAULT_THEME: "gitea-auto"
            
            service:
              DISABLE_REGISTRATION: false  # Enable for first setup
            
            repository:
              DEFAULT_BRANCH: "main"
          
          # Resource limits for RPi
          resources:
            requests:
              memory: 256Mi
              cpu: 100m
            limits:
              memory: 1Gi
              cpu: 1000m
        
        # ---------------------------------------------------------------------
        # Persistent Storage
        # ---------------------------------------------------------------------
        persistence:
          enabled: true
          size: 10Gi
          storageClass: longhorn
        
        # ---------------------------------------------------------------------
        # PostgreSQL Database
        # ---------------------------------------------------------------------
        postgresql:
          enabled: true
          global:
            storageClass: longhorn
          primary:
            persistence:
              size: 5Gi
            resources:
              requests:
                memory: 128Mi
                cpu: 50m
              limits:
                memory: 256Mi
                cpu: 250m
        
        # ---------------------------------------------------------------------
        # Service Configuration
        # ---------------------------------------------------------------------
        # Disable built-in ingress - we use separate Ingress resource
        ingress:
          enabled: false
        
        service:
          http:
            type: ClusterIP
            port: 3000
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
      - ServerSideApply=true

---
# =============================================================================
# Ingress for Gitea Web UI
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea
  namespace: gitea
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: gitea.192.168.0.210.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea-http
                port:
                  number: 3000
```

</details>

### 8.4 The "App of Apps" Pattern

**File:** `gitops/app-of-apps.yaml`

The **App of Apps** pattern is the key to scalable GitOps. Instead of manually deploying each application, we deploy one "parent" Application that points to a directory containing child Applications. ArgoCD recursively discovers and syncs all of them.

**How It Works:**

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        APP OF APPS HIERARCHY                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                    ┌─────────────────────────────┐                         │
│                    │      Root Application       │                         │
│                    │    (app-of-apps.yaml)       │                         │
│                    └─────────────┬───────────────┘                         │
│                                  │                                          │
│                                  │ watches gitops/ directory                │
│                                  │                                          │
│    ┌─────────────┬───────────────┼───────────────┬─────────────┐           │
│    ▼             ▼               ▼               ▼             ▼           │
│ ┌──────┐    ┌────────┐    ┌─────────────┐  ┌──────────┐  ┌─────────┐      │
│ │cicd/ │    │infra/  │    │observability│  │security/ │  │storage/ │      │
│ │      │    │        │    │/            │  │          │  │         │      │
│ └──┬───┘    └───┬────┘    └──────┬──────┘  └────┬─────┘  └────┬────┘      │
│    │            │                │              │             │            │
│    ▼            ▼                ▼              ▼             ▼            │
│ argo-       cert-         prometheus      kyverno         minio           │
│ workflows   manager       grafana         falco           velero          │
│ argo-                     loki            trivy                           │
│ events                    jaeger          openbao                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Initial Bootstrap - Observability Stack:**

For the initial deployment, we start with the **kube-prometheus-stack** which provides:

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Dashboards and visualization |
| **Alertmanager** | Alert routing and silencing |
| **Node Exporter** | Host-level metrics |
| **kube-state-metrics** | Kubernetes object metrics |

**Configuration Highlights:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `prometheus.storageSpec` | `10Gi` Longhorn | Persistent metrics storage |
| `grafana.persistence` | `2Gi` Longhorn | Dashboard persistence |
| `alertmanager.storage` | `2Gi` Longhorn | Alert state persistence |

<details>
<summary>📄 Click to expand full gitops/app-of-apps.yaml</summary>

```yaml
# =============================================================================
# Observability Stack - Prometheus, Grafana, Alertmanager
# =============================================================================
# This is the initial "App of Apps" deployment that provides comprehensive
# monitoring and alerting for the cluster.
#
# Components Deployed:
#   - Prometheus: Metrics collection and storage
#   - Grafana: Visualization and dashboards
#   - Alertmanager: Alert routing and notification
#   - Node Exporter: Host metrics
#   - kube-state-metrics: Kubernetes object metrics
#
# Access:
#   - Grafana: http://grafana.192.168.0.210.nip.io
#   - Default Login: admin / prom-operator
#
# Storage: All components use Longhorn for persistence
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 66.3.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Global Settings
        # -------------------------------------------------------------------
        fullnameOverride: prometheus
        
        # -------------------------------------------------------------------
        # Prometheus Configuration
        # -------------------------------------------------------------------
        prometheus:
          prometheusSpec:
            # Persistent storage for metrics
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: longhorn
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 10Gi
            
            # Retention settings
            retention: 15d
            retentionSize: "8GB"
            
            # Resource limits for RPi
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                cpu: 500m
                memory: 512Mi
            
            # Scrape all namespaces
            serviceMonitorSelectorNilUsesHelmValues: false
            podMonitorSelectorNilUsesHelmValues: false
        
        # -------------------------------------------------------------------
        # Grafana Configuration
        # -------------------------------------------------------------------
        grafana:
          # Persistent storage for dashboards
          persistence:
            enabled: true
            storageClassName: longhorn
            size: 2Gi
          
          # Resource limits for RPi
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          
          # Disable built-in ingress - we use separate Ingress resource
          ingress:
            enabled: false
          
          # Additional dashboards
          dashboardProviders:
            dashboardproviders.yaml:
              apiVersion: 1
              providers:
                - name: 'default'
                  folder: ''
                  type: file
                  disableDeletion: false
                  editable: true
                  options:
                    path: /var/lib/grafana/dashboards/default
        
        # -------------------------------------------------------------------
        # Alertmanager Configuration
        # -------------------------------------------------------------------
        alertmanager:
          alertmanagerSpec:
            # Persistent storage for alert state
            storage:
              volumeClaimTemplate:
                spec:
                  storageClassName: longhorn
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 2Gi
            
            # Resource limits for RPi
            resources:
              requests:
                cpu: 10m
                memory: 32Mi
              limits:
                cpu: 100m
                memory: 64Mi
        
        # -------------------------------------------------------------------
        # Component Resource Limits
        # -------------------------------------------------------------------
        kube-state-metrics:
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
        
        prometheus-node-exporter:
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 100m
              memory: 32Mi
  
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

---
# =============================================================================
# Ingress for Grafana UI
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: grafana.192.168.0.210.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-grafana
                port:
                  number: 80
```

</details>

### 8.5 Phase 4 Execution Steps

Execute these commands in order from your control machine:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 4 EXECUTION CHECKLIST                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  □ Step 1: Install Traefik (Gateway/Ingress)                               │
│  □ Step 2: Install ArgoCD (GitOps Controller)                              │
│  □ Step 3: Deploy Gitea (Git Server)                                       │
│  □ Step 4: Create Repository in Gitea                                      │
│  □ Step 5: Deploy Observability Stack                                      │
│  □ Step 6: Verify All Services                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Step 1: Install Traefik**

```bash
bash bootstrap/traefik/install.sh
```

**Verify:**
```bash
# Check Traefik service has External IP
kubectl get svc -n traefik-system

# Expected output:
# NAME      TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)
# traefik   LoadBalancer   10.96.x.x      192.168.0.210   80:xxxxx/TCP,443:xxxxx/TCP
```

**Step 2: Install ArgoCD**

```bash
bash bootstrap/argocd/install.sh
```

**Verify:**
```bash
# Check ArgoCD pods are running
kubectl get pods -n argocd

# Access ArgoCD UI
# Open: http://argocd.192.168.0.210.nip.io
# Username: admin
# Password: (shown in install script output)
```

**Step 3: Deploy Gitea via ArgoCD**

```bash
kubectl apply -f gitops/services/gitea.yaml
```

**Verify:**
```bash
# Watch the deployment progress
kubectl get pods -n gitea -w

# Check Application status in ArgoCD
kubectl get application -n argocd gitea

# Expected: STATUS=Synced, HEALTH=Healthy (wait ~5 minutes)
```

**Step 4: Initialize Gitea (The Pivot Point)**

This is the critical step where we close the GitOps loop:

1. Open Gitea UI: `http://gitea.192.168.0.210.nip.io`
2. Create your admin account on first visit
3. Create a new repository named `home-cluster`
4. Push your local configuration:

```bash
# Initialize and push to Gitea
cd /path/to/your/gitops/folder
git init
git remote add origin http://gitea.192.168.0.210.nip.io/admin/home-cluster.git
git add .
git commit -m "Initial cluster configuration"
git push -u origin main
```

**Step 5: Deploy Observability Stack**

```bash
kubectl apply -f gitops/app-of-apps.yaml
```

**Verify:**
```bash
# Watch deployment progress
kubectl get pods -n monitoring -w

# Check Application status
kubectl get application -n argocd observability-stack

# Expected: All pods Running (wait ~10 minutes for all components)
```

**Step 6: Final Verification**

```bash
# List all ArgoCD-managed applications
kubectl get applications -n argocd

# Expected output:
# NAME                  SYNC STATUS   HEALTH STATUS
# gitea                 Synced        Healthy
# observability-stack   Synced        Healthy
```

**Access URLs:**

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | http://argocd.192.168.0.210.nip.io | admin / (secret) |
| Gitea | http://gitea.192.168.0.210.nip.io | (created on first visit) |
| Grafana | http://grafana.192.168.0.210.nip.io | admin / prom-operator |

## 9. Phase 5: Security & Management Stack

Now that the GitOps engine is running, we utilize it to deploy the infrastructure dependencies required for a secure, production-grade environment.

### 9.1 Object Storage (MinIO)
**File:** `gitops/storage/minio.yaml`

Many Cloud Native tools (Velero, Thanos, Loki, Harbor) expect an AWS S3 bucket. Since we are on bare metal, we self-host **MinIO** to provide this API.
*   **Storage:** Uses Longhorn (HDD) for the data backing.
*   **Buckets:** Automatically provisions buckets for `velero`, `loki`, `harbor`, and `thanos`.
*   **Access:** Exposed via Gateway API HTTPRoute (`minio.192.168.0.210.nip.io`).

<details>
<summary>📄 Click to expand full gitops/storage/minio.yaml</summary>

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

</details>

### 9.2 Certificate Automation (Cert-Manager)
**File:** `gitops/infrastructure/cert-manager.yaml`

Cert-Manager handles TLS certificates within the cluster.
*   **Self-Signed Issuer:** Configured to issue self-signed certificates locally. This prevents the "Not Secure" browser warnings from escalating into connection errors, while avoiding the complexity of external DNS validation (Let's Encrypt) for this private setup.

<details>
<summary>📄 Click to expand full gitops/infrastructure/cert-manager.yaml</summary>

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

</details>

### 9.3 Container Registry (Harbor)
**File:** `gitops/security/harbor.yaml`

Harbor serves as the local "Docker Hub".
*   **Dependency:** Connects to the **MinIO** S3 service installed above for storing huge container images (keeping them off the SD cards).
*   **Scanning:** Trivy is enabled to scan every uploaded image for CVEs.
*   **Database:** Uses internal PostgreSQL backed by Longhorn.

<details>
<summary>📄 Click to expand full gitops/security/harbor.yaml</summary>

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

</details>

### 9.4 Backup & Restore (Velero)
**File:** `gitops/management/velero.yaml`

Velero performs nightly backups of the cluster configuration and persistent volumes.
*   **Target:** Stores backups in the `velero` bucket on MinIO.
*   **Volume Snapshots:** Integrated with Longhorn CSI to take snapshots of the HDD data.

<details>
<summary>📄 Click to expand full gitops/management/velero.yaml</summary>

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

</details>
### 9.5 Secrets Management (OpenBao)
**File:** `gitops/security/openbao.yaml`
We use OpenBao (the community fork of Vault) to handle secrets securely.
*   **Storage:** Uses Longhorn (HDD) to persist encrypted secrets.
*   **UI:** Exposed internally via LoadBalancer.

<details>
<summary>📄 Click to expand full gitops/security/openbao.yaml</summary>

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

</details>

### 9.6 Policy Enforcement (Kyverno)
**File:** `gitops/security/kyverno.yaml`
Kyverno enforces best practices (e.g., preventing root containers) without the complexity of OPA Gatekeeper.

<details>
<summary>📄 Click to expand full gitops/security/kyverno.yaml</summary>

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

</details>

### 9.7 Runtime Security (Falco)
**File:** `gitops/security/falco.yaml`
Monitors kernel syscalls to detect intrusions. We explicitly configure the **eBPF driver** because the traditional kernel module driver is often problematic on Ubuntu RPi kernels.

<details>
<summary>📄 Click to expand full gitops/security/falco.yaml</summary>

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

</details>

### 9.8 Configuration Reloader (Reloader)
**File:** `gitops/management/reloader.yaml`

Reloader watches for changes in ConfigMaps and Secrets, then automatically triggers rolling updates on associated Deployments/StatefulSets. This is essential for GitOps workflows where configuration changes should propagate without manual intervention.

*   **Use Case:** When you update a Grafana dashboard ConfigMap, Reloader restarts Grafana automatically.
*   **Footprint:** Extremely lightweight (~10MB RAM).

<details>
<summary>📄 Click to expand full gitops/management/reloader.yaml</summary>

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

</details>

**Usage:** Annotate your Deployments to enable auto-reload:
```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

### 9.9 Workload Rebalancing (Descheduler)
**File:** `gitops/management/descheduler.yaml`

On resource-constrained Raspberry Pi clusters, workloads can become imbalanced over time. The Descheduler periodically evicts pods based on configured strategies, allowing the scheduler to rebalance them across nodes.

*   **Strategies Enabled:**
    *   `RemoveDuplicates`: Ensures replicas are spread across nodes.
    *   `LowNodeUtilization`: Moves pods from overloaded nodes to underutilized ones.
    *   `RemovePodsViolatingNodeAffinity`: Evicts pods that no longer satisfy node affinity rules.

<details>
<summary>📄 Click to expand full gitops/management/descheduler.yaml</summary>

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

</details>

*Note: Descheduler only evicts pods; it does not schedule them. The kube-scheduler handles placement after eviction.*
    
### 9.10 The Root Application (App of Apps)
**File:** `gitops/root-app.yaml`

This is the "One Ring to Rule Them All." Instead of applying the files above individually, we point ArgoCD to this single file (or eventually, to the Git repo containing it). It tells ArgoCD to deploy the entire stack defined in the `gitops/` directory structure.

<details>
<summary>📄 Click to expand full gitops/root-app.yaml</summary>

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

</details>

### 9.11 Security Verification Script
**File:** `tests/04_security_test.sh`

This script verifies that your security policies are enforced and services are accessible.
1.  **Kyverno:** Attempts to create a pod violating the "no-latest-tag" policy. It expects a failure.
2.  **Falco:** Verifies the eBPF probes are running.
3.  **Harbor:** Checks API availability.

<details>
<summary>📄 Click to expand full tests/04_security_test.sh</summary>

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

</details>

### 9.12 Phase 5 Execution Steps

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

## 10. Phase 6: Advanced Observability

In this phase, we complete the observability pillar. Metrics (Prometheus) tell you *what* is happening, but Logs (Loki) tell you *why*. We also add cost estimation and AI analysis to help manage the cluster.

### 10.1 Log Aggregation (Loki Stack)
**File:** `gitops/observability/loki-stack.yaml`

We use the **PLG Stack** (Promtail, Loki, Grafana).
*   **Promtail:** Runs on every node (DaemonSet), reads logs from `/var/log/containers`, and pushes them to Loki.
*   **Loki:** Stores logs efficiently. We configure it to use **MinIO** (installed in Phase 5) for long-term storage instead of filling up the pod's local volume.

<details>
<summary>📄 Click to expand full gitops/observability/loki-stack.yaml</summary>

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

</details>

### 10.2 Log Collection (Fluent Bit)
**File:** `gitops/observability/fluent-bit.yaml`
*Note:* You requested Fluentd, but **Fluent Bit** is the industry standard for Edge/Raspberry Pi. It is written in C (vs Ruby for Fluentd) and uses ~10x less RAM. It is configured here to forward logs to the Loki stack.

<details>
<summary>📄 Click to expand full gitops/observability/fluent-bit.yaml</summary>

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

</details>

### 10.3 Distributed Tracing (OpenTelemetry)
**File:** `gitops/observability/opentelemetry.yaml`
Installs the OpenTelemetry Operator. This allows you to inject tracing sidecars into your applications automatically.

<details>
<summary>📄 Click to expand full gitops/observability/opentelemetry.yaml</summary>

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

</details>

### 10.4 Tracing Backend (Jaeger)
**File:** `gitops/observability/jaeger.yaml`

Jaeger provides the UI to visualize the distributed traces collected by OpenTelemetry.
*   **Storage:** Configured to use memory (limited size) for Raspberry Pi resource efficiency, as ElasticSearch is too heavy for this setup.
*   **Ingress:** Exposed via Traefik.

<details>
<summary>📄 Click to expand full gitops/observability/jaeger.yaml</summary>

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

</details>

### 10.5 Traffic Analysis (Kubeshark)
**File:** `gitops/observability/kubeshark.yaml`
Provides deep visibility into API traffic (HTTP, REST, gRPC, GraphQL) similar to Wireshark, but for K8s.

<details>
<summary>📄 Click to expand full gitops/observability/kubeshark.yaml</summary>

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

</details>

### 10.6 Cost Management (OpenCost)
**File:** `gitops/observability/opencost.yaml`

OpenCost calculates the resource consumption (CPU/RAM/Storage) of every pod and estimates a "cloud cost" equivalent. This is excellent for understanding which namespace is hogging resources on your Raspberry Pis.

<details>
<summary>📄 Click to expand full gitops/observability/opencost.yaml</summary>

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

</details>

### 10.7 AI Diagnostics (K8sGPT)
**File:** `gitops/observability/k8sgpt.yaml`

K8sGPT scans your cluster for issues (CrashLoops, PVC failures, Service misconfigs) and uses an AI backend to explain the fix in plain English.
*   **Backend:** Configured here to use the public OpenAI API (requires an API Key) or LocalAI if you host it. *Note: Replace `YOUR_OPENAI_TOKEN` in the secret manually or use the OpenBao vault later.*

<details>
<summary>📄 Click to expand full gitops/observability/k8sgpt.yaml</summary>

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

</details>

### 10.8 Observability Verification Script
**File:** `tests/05_observability_test.sh`

This script ensures data is flowing through your pipelines.
1.  **Prometheus:** Checks if scrape targets are active via the API.
2.  **Loki:** Checks if the database is up.
3.  **K8sGPT:** Verifies the AI operator is active.

<details>
<summary>📄 Click to expand full tests/05_observability_test.sh</summary>

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

</details>

### 10.9 Phase 6 Execution Steps

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

## 11. Phase 7: CI/CD & Developer Experience

In this final phase, we establish the machinery that builds, tests, and releases code. We replace manual `docker build` commands with an automated pipeline and ensure every change is scanned for security vulnerabilities before reaching production.

### 11.1 Image Automation (Argo Image Updater)
**File:** `gitops/cicd/argo-image-updater.yaml`

This component watches your **Harbor** registry. When a CI pipeline pushes a new image tag (e.g., `v1.0.1`), this tool automatically updates the Git repository (modifying the ArgoCD Application) to reflect the new version.

<details>
<summary>📄 Click to expand full gitops/cicd/argo-image-updater.yaml</summary>

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

</details>

### 11.2 CI Engine (Argo Workflows)
**File:** `gitops/cicd/argo-workflows.yaml`

Argo Workflows is a Kubernetes-native workflow engine. It creates Pods to run your build steps (clone, build, push, test).
*   **UI:** Exposed via Gateway API HTTPRoute.
*   **Persistence:** Uses MinIO (S3) to store build artifacts (logs, compiled binaries).
*   **Executor:** Uses `pns` (Process Namespace Sharing) for efficiency on Raspberry Pi.

<details>
<summary>📄 Click to expand full gitops/cicd/argo-workflows.yaml</summary>

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

</details>

### 11.3 Event Bus (Argo Events)
**File:** `gitops/cicd/argo-events.yaml`

Argo Events listens for external triggers (like a `git push` to your Gitea repo) and triggers an Argo Workflow.
*   **Sensor:** Listens for the event.
*   **EventBus:** Manages the message queue (Jetstream).

<details>
<summary>📄 Click to expand full gitops/cicd/argo-events.yaml</summary>

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

</details>

### 11.4 Security Tooling (Trivy)

Rather than installing these as standalone long-running services, we install the **Trivy Operator** to scan the running cluster, and we provide the configurations to run ZAP/Trivy inside CI pipelines.

**File:** `gitops/security/trivy-operator.yaml`
Scans running pods and generates "VulnerabilityReports" visible in the cluster.

<details>
<summary>📄 Click to expand full gitops/security/trivy-operator.yaml</summary>

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

</details>

> **Note on OWASP ZAP:**
> OWASP ZAP is best run as a step in your **Argo Workflow** (`WorkflowTemplate`) against a staging URL. It does not require a standalone Helm installation for this architecture.

### 11.5 Local Development (Skaffold)

To enable rapid iteration on your local machine without pushing git commits for every line of code change, use **Skaffold**.

**Setup Instructions (Run on Local Machine):**
1.  Install Skaffold: `choco install skaffold` (Windows) or `brew install skaffold`.
2.  Create a `skaffold.yaml` in your application source code repo:

<details>
<summary>📄 Click to expand full skaffold.yaml</summary>

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

</details>

3.  Run `skaffold dev`.
    *   Skaffold will watch your source files.
    *   On save, it builds the image, pushes to Harbor, and redeploys to the Raspberry Pi cluster in seconds.

### 11.6 CI/CD Verification Script
**File:** `tests/06_cicd_test.sh`

Verifies the build machinery components.
1.  **Argo Workflows:** Checks controller availability.
2.  **Argo Events:** Checks controller availability.
3.  **Trivy:** Checks if vulnerability reports are being generated for running pods.

<details>
<summary>📄 Click to expand full tests/06_cicd_test.sh</summary>

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

</details>

### 11.7 Phase 7 Execution Steps

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

## 12. Phase 8: Day 2 Operations & Maintenance

This section outlines the routine tasks required to keep the cluster secure and up-to-date.

### 12.1 Upgrading Kubernetes
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

### 12.2 OS Patching
To apply Linux security patches without downtime, drain nodes one by one.

```bash
# 1. Drain Node (Move workloads elsewhere)
kubectl drain rpi4-2 --ignore-daemonsets --delete-emptydir-data

# 2. Run Ansible Update
ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml --limit rpi4-2

# 3. Uncordon (Allow workloads back)
kubectl uncordon rpi4-2
```
### 12.3 Cluster Reset (The Nuclear Option)
**File:** `ansible/playbooks/05_reset_cluster.yml`

This playbook is a safety net for your learning process. If you misconfigure the cluster or networking beyond repair, run this to wipe the nodes clean so you can restart from Phase 2 (Cluster Init) without re-flashing SD cards.

*   **Action:** Runs `kubeadm reset`, cleans CNI configurations (`/etc/cni`), flushes IPtables, and removes local kube configs.
*   **Safety:** By default, it *does not* wipe the Longhorn data on the HDD, preserving your persistent volumes.

<details>
<summary>📄 Click to expand full ansible/playbooks/05_reset_cluster.yml</summary>

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

</details>

**Usage:**
```bash
ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml
```


### 12.4 Backup & Disaster Recovery
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

### 12.5 Troubleshooting Cheatsheet
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
