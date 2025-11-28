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
    *   [7.3 Local Path Provisioner (Optional)](#73-local-path-provisioner-optional)
    *   [7.4 Storage Verification Script](#74-storage-verification-script)
    *   [7.5 Phase 3 Execution Steps](#75-phase-3-execution-steps)
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
    *   [9.10 Cluster Dashboard (Headlamp)](#910-cluster-dashboard-headlamp)
    *   [9.11 The Root Application (App of Apps)](#911-the-root-application-app-of-apps)
    *   [9.12 Security Verification Script](#912-security-verification-script)
    *   [9.13 Phase 5 Execution Steps](#913-phase-5-execution-steps)
10. [Phase 6: Advanced Observability](#10-phase-6-advanced-observability)
    *   [10.1 On-Demand Observability Tools](#101-on-demand-observability-tools)
    *   [10.2 Log Aggregation (Loki Stack)](#102-log-aggregation-loki-stack)
    *   [10.3 Log Collection (Fluent Bit)](#103-log-collection-fluent-bit)
    *   [10.4 Distributed Tracing (OpenTelemetry)](#104-distributed-tracing-opentelemetry)
    *   [10.5 Tracing Backend (Jaeger)](#105-tracing-backend-jaeger)
    *   [10.6 Traffic Analysis (Kubeshark)](#106-traffic-analysis-kubeshark)
    *   [10.7 Cost Management (OpenCost)](#107-cost-management-opencost)
    *   [10.8 AI Diagnostics (K8sGPT)](#108-ai-diagnostics-k8sgpt)
    *   [10.9 Observability Verification Script](#109-observability-verification-script)
    *   [10.10 Phase 6 Execution Steps](#1010-phase-6-execution-steps)
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
    *   [12.2 Rolling OS Upgrade Playbook](#122-rolling-os-upgrade-playbook)
    *   [12.3 Manual OS Patching](#123-manual-os-patching)
    *   [12.4 Cluster Reset (The Nuclear Option)](#124-cluster-reset-the-nuclear-option)
    *   [12.5 Backup & Disaster Recovery](#125-backup--disaster-recovery)
    *   [12.6 Troubleshooting Cheatsheet](#126-troubleshooting-cheatsheet)
    *   [12.7 Operational Runbooks](#127-operational-runbooks)
    *   [12.8 Health Check Script](#128-health-check-script)
    *   [12.9 Secrets Migration to OpenBao](#129-secrets-migration-to-openbao)
    *   [12.10 Component Cleanup Commands](#1210-component-cleanup-commands)

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
| **Management** | Headlamp | 64MB | 192MB | Any |

**Estimated Total:**
- **Control Plane (rpi4-1):** ~4-5GB reserved, leaving ~3GB for workloads
- **Workers (rpi4-2/3/4):** ~1GB system overhead, leaving ~3GB each for workloads
- **Cluster Total Available:** ~12GB for application workloads

> ⚠️ **Warning:** Running the full observability stack simultaneously may cause memory pressure. Consider disabling Kubeshark and Jaeger when not actively debugging.

### Software Stack & Justification

#### **A. Orchestration & Deployment**

| Tool | Version | Purpose | Why This Tool? |
|------|---------|---------|----------------|
| **Kubernetes** | 1.33 | Container orchestration | Industry standard, upstream experience via kubeadm |
| **Helm** | 4.x | Package management | Required by ArgoCD for chart deployments |
| **ArgoCD** | 2.x | GitOps controller | Best-in-class GitOps, declarative, self-healing |
| **Argo Image Updater** | 0.x | Image automation | Automatic version bumps from registry tags |
| **Argo Workflows** | 3.x | CI/CD pipelines | Kubernetes-native, replaces Jenkins |
| **Argo Events** | 1.x | Event automation | Webhook triggers, event-driven pipelines |

#### **B. Network Layer**

| Tool | Version | Purpose | Why This Tool? |
|------|---------|---------|----------------|
| **Cilium** | 1.18.x | CNI + Load Balancing | eBPF performance, replaces kube-proxy, L2 announcements |
| **Hubble** | (embedded) | Network observability | Service maps, flow visualization |
| **Tetragon** | (embedded) | eBPF runtime security | Kernel-level process & network monitoring |
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

> **📦 kube-prometheus-stack Bundle:** Prometheus Operator, Grafana, kube-state-metrics, and AlertManager are deployed together via the `kube-prometheus-stack` Helm chart. Thanos is included but disabled by default.

| Tool | Purpose | Depends On | Memory Impact |
|------|---------|------------|---------------|
| **Metrics Server** | K8s API metrics (`kubectl top`, HPA, VPA) | - | Low (64MB) |
| **Prometheus Operator** ¹ | Metrics collection & alerting | - | High (512MB-2GB) |
| **Thanos** ² | Long-term metrics storage | MinIO | Medium (256MB) |
| **Grafana** ¹ | Visualization dashboards | - | Low (128MB) |
| **Fluent Bit** | Log collection (DaemonSet) | - | Low per node |
| **Loki** | Log storage & querying | MinIO | Medium (256MB) |
| **OpenTelemetry** | Trace collection | - | Low (128MB) |
| **Jaeger** | Trace visualization | - | Medium (256MB) |
| **OpenCost** | Cost estimation | Prometheus | Low (64MB) |
| **Kube-state-metrics** ¹ ³ | Kubernetes object metrics | - | Low (64MB) |
| **K8sGPT** | AI-powered diagnostics | - | Low (64MB) |
| **Kubeshark** | API traffic analysis | - | High (512MB+) |

> **Notes:**
> - ¹ Bundled in `kube-prometheus-stack` Helm chart
> - ² Disabled by default for RPi resource constraints; enable if you need long-term metrics retention
> - ³ **kube-state-metrics** exposes Kubernetes object states (deployments, pods, nodes) as Prometheus metrics. **Metrics Server** provides real-time resource usage (CPU/memory) for `kubectl top` and autoscaling. They serve different purposes and are both needed.

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
| **OWASP ZAP** ⁴ | Dynamic security testing | CI/CD pipelines |
| **Tetragon** | eBPF runtime security | Kernel syscalls (process, network, file) |
| **Falco** | Runtime threat detection | Kernel syscalls |
| **Kyverno** | Policy enforcement | API admission |

> **Note:** ⁴ OWASP ZAP is run as an **Argo Workflow step** during CI/CD pipelines, not as a persistent deployment. It scans deployed applications for vulnerabilities (SQL injection, XSS, etc.) before promoting to production.

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
│  │  Tetragon (eBPF Security) ──► Process/file/network tracing  │   │
│  │  Falco (Syscall Monitor)  ──► Alert on shell in container   │   │
│  │  Cilium Network Policies  ──► Block unauthorized traffic    │   │
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
| **K9s** | Terminal UI | Real-time cluster interaction |

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
| **Headlamp** | Cluster dashboard | Full K8s UI, resource management, pod exec |
| **Skaffold** | Local development loop | Code → Build → Push → Deploy |
| **K9s** | Terminal cluster UI | Real-time pod management |
| **Hubble UI** | Network visualization | Service dependency maps |
| **ArgoCD UI** | GitOps management | Application sync & status |
| **Grafana** | Metrics & logs | Dashboards & log exploration |
| **Longhorn UI** | Storage management | Volume health & snapshots |

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
│       ├── 05_reset_cluster.yml         # Nuclear option: kubeadm reset, cleanup everything
│       └── 06_rolling_upgrade.yml       # Day 2: Rolling OS upgrades with drain/uncordon
│
├── bootstrap/                           # ══════════════════════════════════════
│   │                                    # PRE-GITOPS DEPENDENCIES (Manual Helm)
│   │                                    # Components ArgoCD needs before it can run
│   │                                    # ══════════════════════════════════════
│   ├── argocd/                          # GitOps: ArgoCD server + controllers
│   │   └── install.sh                   # → helm install argocd (HA disabled for RPi)
│   ├── longhorn/                        # Storage: Block storage with HDD-only affinity
│   │   └── install.sh                   # → helm install longhorn (replica=1, CP node)
│   ├── metrics-server/                  # Metrics: Required for kubectl top, HPA, VPA
│   │   └── install.sh                   # → helm install metrics-server (ARM64 flags)
│   └── traefik/                         # Gateway: Traefik + Gateway API CRDs
│       └── install.sh                   # → kubectl apply CRDs, helm install traefik
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
│   │   └── cert-manager.yaml            # TLS: Let's Encrypt automation, ClusterIssuers
│   │
│   ├── storage/                         # ──────────────────────────────────────
│   │   │                                # LAYER 2: Persistent storage layer
│   │   │                                # sync-wave: -4 (before apps need PVCs)
│   │   │                                # ──────────────────────────────────────
│   │   ├── minio.yaml                   # S3: Object storage for Thanos/Loki/Velero
│   │   │                                #     PVC on Longhorn, credentials in Secret
│   │   └── local-path-provisioner.yaml  # Local: Optional direct-to-disk storage
│   │                                    #     For caches, ephemeral data (SD card)
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
│       ├── descheduler.yaml             # Balance: Evict pods for better distribution
│       │                                #         LowNodeUtilization, RemoveDuplicates
│       ├── headlamp.yaml                # Dashboard: Modern K8s UI with plugin support
│       │                                #            Resource management, pod exec, logs
│       ├── reloader.yaml                # GitOps: Watch ConfigMaps/Secrets, rolling restart
│       │                                #         Annotations trigger pod recreation
│       └── velero.yaml                  # Backup: Cluster state + PVCs → MinIO
│                                        #         Scheduled backups, disaster recovery
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
    ├── 06_cicd_test.sh                  # Phase 7: Workflow submit, Event trigger
    └── 07_operations_test.sh            # Phase 8: Cluster health, backups, Day 2 ops
```

### Test Script Quick Reference

| Phase | Section | Test Script | What It Validates |
|-------|---------|-------------|-------------------|
| **Phase 1** | [§5 Infrastructure](#5-phase-1-infrastructure-provisioning) | `tests/01_infra_test.sh` | Node count, RAM, swap off, kernel modules |
| **Phase 2** | [§6 Cluster Bootstrap](#6-phase-2-cluster-bootstrap) | `tests/02_network_test.sh` | Cilium, L2 announcements, CoreDNS, Hubble |
| **Phase 3** | [§7 Storage](#7-phase-3-storage-foundation) | `tests/03_storage_test.sh` | Longhorn, PVC lifecycle, HDD mount |
| **Phase 4** | [§8 GitOps](#8-phase-4-gitops--observability) | - | Manual: Verify ArgoCD UI, app sync |
| **Phase 5** | [§9 Security](#9-phase-5-security--management-stack) | `tests/04_security_test.sh` | Kyverno policies, Falco, Trivy, Harbor |
| **Phase 6** | [§10 Observability](#10-phase-6-advanced-observability) | `tests/05_observability_test.sh` | Prometheus, Loki, Grafana, OpenTelemetry |
| **Phase 7** | [§11 CI/CD](#11-phase-7-cicd--developer-experience) | `tests/06_cicd_test.sh` | Argo Workflows, Events, Image Updater |
| **Phase 8** | [§12 Day 2 Ops](#12-phase-8-day-2-operations--maintenance) | `tests/07_operations_test.sh` | Health checks, Velero, Descheduler |

> **💡 Usage:** Run the corresponding test script after completing each phase:
> ```bash
> chmod +x tests/*.sh
> ./tests/01_infra_test.sh    # After completing Phase 1
> ```

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
sudo apt update && sudo apt install -y ansible openssh-client curl git               

# Kubernetes tools (install latest versions)
# kubectl - Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# helm - Package manager
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# k9s - Terminal UI (optional but recommended)
curl -sS https://webinstall.dev/k9s | bash
```

> Note: **Helm v4 is a client-only tool (no server/Tiller).** Installing Helm on
your management machine is sufficient to manage charts remotely. If you
prefer running `helm` from the cluster, the Ansible playbook
`ansible/playbooks/02_k8s_binaries.yml` installs Helm on the control-plane
node (the host in the `big` group, e.g. `rpi4-1`) for convenience when
executing bootstrap or maintenance commands directly from the control plane.

**Verify installations:**

```bash
ansible --version    # Should show 2.19+
kubectl version --client # Should show 1.34+
helm version         # Should show 4.x
```

### OS & Network Setup

#### Step 1: Flash Ubuntu Server

Use **Raspberry Pi Imager** (download from [raspberrypi.com](https://www.raspberrypi.com/software/)) to flash **Ubuntu Server 24.04 LTS** or **25.10** (my pick) to each SD card.

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
# Usually at http://192.168.0.1 or http://192.168.1.1 or http://192.168.68.1

# Method 2: Network scan (requires nmap)
nmap -sn 192.168.68.0/24 | grep -B2 "rpi"

# Method 3: mDNS/Bonjour (if enabled)
ping rpi4-1
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
ssh -i ~/.ssh/rpi-cluster user@rpi4-2 "hostname && cat /etc/os-release | grep PRETTY"
ssh -i ~/.ssh/rpi-cluster user@rpi4-3 "hostname && cat /etc/os-release | grep PRETTY"
ssh -i ~/.ssh/rpi-cluster user@rpi4-4 "hostname && cat /etc/os-release | grep PRETTY"
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
k8s_version=1.33
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
# =============================================================================
# Ansible Configuration for Raspberry Pi Kubernetes Cluster
# =============================================================================
# Place this file in the ansible/ directory alongside the hosts inventory.
# Ansible automatically discovers ansible.cfg in the current working directory.
#
# Usage: Run playbooks from the ansible/ directory:
#   cd ansible/
#   ansible-playbook playbooks/01_node_prep.yml
# =============================================================================

[defaults]
# -----------------------------------------------------------------------------
# INVENTORY SETTINGS
# -----------------------------------------------------------------------------
# Path to the inventory file containing host definitions
inventory = ./hosts

# Default remote user (matches the user created during Pi Imager setup)
remote_user = user

# Disable host key checking for initial setup
# Enable this in production for security
host_key_checking = False

# Path to store temporary files on managed nodes
remote_tmp = /tmp/ansible-${USER}

# Path for local temporary files
local_tmp = /tmp/ansible-local-${USER}

# Number of parallel processes (4 = all Pi nodes simultaneously)
forks = 4

# Default timeout for SSH connections (seconds)
timeout = 30

# Suppress deprecation warnings (optional, disable in CI)
deprecation_warnings = False

# Display task path on failure for debugging
display_failed_stderr = True

# Retry failed hosts automatically
retry_files_enabled = True
retry_files_save_path = ./playbooks/.retry

# Colorized output
force_color = True

# -----------------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------------
# Uncomment to enable logging (useful for debugging)
# log_path = ./ansible.log

# -----------------------------------------------------------------------------
# PERFORMANCE OPTIMIZATIONS
# -----------------------------------------------------------------------------
# Use pipelining to reduce SSH operations (requires requiretty disabled)
pipelining = True

# Gather only necessary facts (speeds up playbook execution)
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible-facts-cache
fact_caching_timeout = 3600

# -----------------------------------------------------------------------------
# STDOUT CALLBACK
# -----------------------------------------------------------------------------
# Use YAML callback for better readability
stdout_callback = yaml
callback_whitelist = profile_tasks

[privilege_escalation]
# -----------------------------------------------------------------------------
# PRIVILEGE ESCALATION (sudo)
# -----------------------------------------------------------------------------
# Enable sudo for all tasks by default
become = True

# Method for privilege escalation
become_method = sudo

# Target user after escalation
become_user = root

# Ask for sudo password (disable if using NOPASSWD in sudoers)
become_ask_pass = False

[ssh_connection]
# -----------------------------------------------------------------------------
# SSH CONNECTION SETTINGS
# -----------------------------------------------------------------------------
# SSH arguments for multiplexing (reuse connections)
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

# Use SCP for file transfers (more compatible than SFTP)
scp_if_ssh = smart

# Transfer method (prefer sftp, fallback to scp)
transfer_method = smart

# Private key file for SSH authentication
# Uncomment and update path if not using default key location
# private_key_file = ~/.ssh/rpi-cluster

[colors]
# -----------------------------------------------------------------------------
# OUTPUT COLORS
# -----------------------------------------------------------------------------
changed = yellow
debug = dark gray
deprecate = purple
diff_add = green
diff_lines = cyan
diff_remove = red
error = red
highlight = white
ok = green
skip = cyan
unreachable = bright red
verbose = blue
warn = bright purple```

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
</details>


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
│   • System updates    • K8s repo (1.33)                                    │
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

          # Disable IPv6 if not needed (saves memory)
          # net.ipv6.conf.all.disable_ipv6    = 1
          # net.ipv6.conf.default.disable_ipv6 = 1
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

This playbook installs the Kubernetes toolchain on all nodes. We deliberately install version **1.33** (not latest) so we can demonstrate an upgrade procedure later in the guide.

| Package | Installed On | Purpose |
|---------|--------------|---------|
| `kubelet` | All nodes | Node agent that runs pods |
| `kubeadm` | All nodes | Cluster bootstrap tool |
| `kubectl` | All nodes | CLI for cluster interaction |
| `helm` | Control plane only | Package manager for K8s apps |
| `cilium-cli` | Control plane only | CNI management tool |
| `tetra` | Control plane only | Tetragon CLI for eBPF runtime security |
| `etcd-client` | Control plane only | Direct etcd access for debugging |
| `k9s` | Control plane only | Terminal UI for cluster management |

> 💡 **Version Locking:** The playbook uses `dpkg --set-selections` to "hold" packages at 1.33.x. This prevents `apt upgrade` from accidentally updating Kubernetes and breaking your cluster.

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
# Note: We install 1.33 (not latest) to demonstrate upgrades later.
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
    k8s_version_major: "1.33"
    k8s_pkg_version: "1.33.*"
    
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
            url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
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

        # Tetragon CLI - eBPF runtime security management
        - name: Check if Tetragon CLI is installed
          ansible.builtin.command: tetra version
          register: tetra_check
          changed_when: false
          failed_when: false

        - name: Get latest Tetragon CLI version
          ansible.builtin.uri:
            url: https://api.github.com/repos/cilium/tetragon/releases/latest
            return_content: true
          register: tetragon_release
          when: tetra_check.rc != 0

        - name: Download and install Tetragon CLI
          ansible.builtin.unarchive:
            src: "https://github.com/cilium/tetragon/releases/download/{{ tetragon_release.json.tag_name }}/tetra-linux-arm64.tar.gz"
            dest: /usr/local/bin
            remote_src: true
            mode: '0755'
            include:
              - tetra
          when: tetra_check.rc != 0

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

    - name: Verify Tetragon CLI installation (control plane)
      ansible.builtin.command: tetra version
      register: tetra_version_check
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
          tetra:   {{ tetra_version_check.stdout | default('installed') }}
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
| **K8s Binaries** | kubeadm, kubelet, kubectl, helm, cilium-cli | Version 1.33.x installed |
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
✅ Kubernetes version 1.33: PASS
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
| **kubeadm** | 1.33.0 | Cluster bootstrapper | Custom config skips kube-proxy |
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
          kubernetesVersion: v1.33.0
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

    - name: Install Cilium (Network, L2 Announcements & Tetragon)
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
           --set tetragon.enabled=true \
           --set tetragon.serviceAccount.create=true \
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

Hubble UI provides a graphical visualization of your cluster's network flows and service dependencies.

```bash
# Get the Hubble UI NodePort
kubectl get svc hubble-ui -n kube-system

# The output will show the NodePort (e.g., 80:31234/TCP)
# Access via any node IP: http://<NODE_IP>:<NodePort>
# Example: http://192.168.0.201:31234

# Alternative: Port-forward for local access
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Then access: http://localhost:12000
```

> **💡 Tip:** Hubble UI shows real-time network flows, service maps, and policy enforcement. It's invaluable for debugging network connectivity issues.

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

### 7.3 Local Path Provisioner (Optional)

**File:** `gitops/storage/local-path-provisioner.yaml`

The Local Path Provisioner creates PersistentVolumes directly on node-local storage (SD cards). This is useful for workloads that:

- Handle their own data replication (Redis Cluster, distributed caches)
- Need maximum I/O performance (local disk bypasses network)
- Store ephemeral/temporary data that can be regenerated

> ⚠️ **Critical Warnings:**
> - **No Replication:** Data lives on a single node. If that node fails, data is **LOST**.
> - **Node Affinity:** Pods using local-path PVCs are bound to the node where the PV was created.
> - **Not Backed Up:** Velero does not back up local-path volumes (use Longhorn for critical data).
> - **SD Card Wear:** Only use for low-write workloads to protect SD card lifespan.

**Storage Classes Comparison:**

| StorageClass | Data Location | Replication | Network Latency | Use Case |
|--------------|---------------|-------------|-----------------|----------|
| `longhorn` (default) | HDD on rpi4-1 | Optional | Yes (iSCSI) | Databases, persistent apps |
| `local-path` | SD card on pod's node | None | None | Caches, temp data, self-replicating apps |

**When to Use Local Path:**

| ✅ Good Use Cases | ❌ Bad Use Cases |
|-------------------|------------------|
| Redis/Valkey cache | Databases without replication |
| Build caches (npm, pip, maven) | Application state |
| Temporary processing directories | User uploads |
| Applications with built-in replication | Anything you can't afford to lose |

**Usage Example:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-cache-pvc
spec:
  storageClassName: local-path    # Use local storage instead of Longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

<details>
<summary>📄 Click to expand full gitops/storage/local-path-provisioner.yaml</summary>

```yaml
# =============================================================================
# Local Path Provisioner - Direct Node Storage (OPTIONAL)
# =============================================================================
# Provides a lightweight StorageClass for applications that:
#   - Handle their own data replication (Redis Cluster, etc.)
#   - Need maximum I/O performance (local disk vs network)
#   - Store ephemeral/cacheable data that can be regenerated
#
# ⚠️ IMPORTANT WARNINGS:
#   - Data is NOT replicated - if the node dies, data is LOST
#   - Pods using local-path PVCs are bound to a specific node
#   - NOT backed up by Velero (use Longhorn for critical data)
#   - SD card wear: Only use for low-write workloads on workers
#
# Use Cases:
#   ✅ Redis/Valkey cache (data can be regenerated)
#   ✅ Build caches (npm, pip, maven)
#   ✅ Temporary processing directories
#   ✅ Applications with built-in replication
#   ❌ Databases without replication
#   ❌ Critical application data
#   ❌ Anything you can't afford to lose
#
# Storage Location:
#   - Worker nodes: /opt/local-path-provisioner (on SD card)
#   - Control plane: /opt/local-path-provisioner (on SD card, NOT HDD)
#
# Usage Example:
#   apiVersion: v1
#   kind: PersistentVolumeClaim
#   metadata:
#     name: my-cache-pvc
#   spec:
#     storageClassName: local-path    # <-- Use this StorageClass
#     accessModes: [ReadWriteOnce]
#     resources:
#       requests:
#         storage: 1Gi
#
# Dependencies: None (self-contained)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: local-path-provisioner
  namespace: argocd
  annotations:
    # Deploy early - storage classes should be available before apps
    argocd.argoproj.io/sync-wave: "-4"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/rancher/local-path-provisioner.git
    path: deploy/chart/local-path-provisioner
    targetRevision: v0.0.30
    helm:
      values: |
        # -------------------------------------------------------------------
        # Storage Configuration
        # -------------------------------------------------------------------
        storageClass:
          # Not the default - Longhorn remains default for safety
          defaultClass: false
          name: local-path
          reclaimPolicy: Delete
        
        # Path where PVs will be created on each node
        # Using /opt to avoid filling up /var (systemd journals, etc.)
        nodePathMap:
          - node: DEFAULT_PATH_FOR_NON_LISTED_NODES
            paths:
              - /opt/local-path-provisioner
        
        # -------------------------------------------------------------------
        # Resource Limits (lightweight provisioner)
        # -------------------------------------------------------------------
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 128Mi
        
        # -------------------------------------------------------------------
        # Helper Pod Configuration
        # -------------------------------------------------------------------
        # The helper pod creates/deletes directories on nodes
        helperImage:
          repository: busybox
          tag: stable
        
        # -------------------------------------------------------------------
        # Security Context
        # -------------------------------------------------------------------
        # Helper pods need root to create directories
        helperPod:
          securityContext:
            runAsUser: 0
            runAsGroup: 0
  
  destination:
    server: https://kubernetes.default.svc
    namespace: local-path-storage
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

</details>

### 7.4 Storage Verification Script

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

### 7.5 Phase 3 Execution Steps

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

### Understanding nip.io (Wildcard DNS)

Throughout this guide, you'll see URLs like `argocd.192.168.0.210.nip.io`. This uses **nip.io**, a free wildcard DNS service that eliminates the need for custom DNS configuration.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                         HOW nip.io WORKS                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Your Browser               nip.io DNS                 Your Cluster        │
│  ───────────────            ──────────                 ─────────────       │
│                                                                            │
│  argocd.192.168.0.210.nip.io                                               │
│       │                                                                    │
│       └──► DNS Query ──► nip.io extracts IP ──► Returns 192.168.0.210     │
│                          from hostname                                     │
│       ◄── Connect to 192.168.0.210 ──────────────────────────────────────► │
│                                                                            │
│  The pattern: <anything>.<IP-with-dots>.nip.io → resolves to <IP>          │
│                                                                            │
│  Examples:                                                                 │
│  ├── argocd.192.168.0.210.nip.io     → 192.168.0.210                      │
│  ├── grafana.192.168.0.210.nip.io    → 192.168.0.210                      │
│  └── my-app.10.0.0.5.nip.io          → 10.0.0.5                           │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Why use nip.io?**

| Benefit | Description |
|---------|-------------|
| **No DNS server needed** | Works out of the box, no `/etc/hosts` editing |
| **Host-based routing** | Traefik routes requests based on hostname (argocd vs grafana) |
| **TLS certificates** | Cert-manager can request certs for these hostnames |
| **Works anywhere** | Any machine on the network can access services by hostname |

> **💡 Alternative:** If you have a real domain, replace `192.168.0.210.nip.io` with your domain and configure DNS A records pointing to `192.168.0.210`.

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

The components must be installed in a specific order due to dependencies. This includes prerequisites from Phase 3:

```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE BOOTSTRAP SEQUENCE                                │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ══════════════════════════════════════════════════════════════════════════════  │
│  PHASE 3 PREREQUISITES (Must be completed before Phase 4)                        │
│  ══════════════════════════════════════════════════════════════════════════════  │
│                                                                                   │
│  Step 0a         Step 0b                                                          │
│  ┌──────────┐    ┌──────────────┐                                                │
│  │ Longhorn │────│Metrics Server│                                                │
│  │(Storage) │    │   (API)      │                                                │
│  └──────────┘    └──────────────┘                                                │
│       │                │                                                          │
│       ▼                ▼                                                          │
│  PVCs for         kubectl top                                                     │
│  ArgoCD/Gitea     HPA scaling                                                     │
│                                                                                   │
│  ══════════════════════════════════════════════════════════════════════════════  │
│  PHASE 4 BOOTSTRAP (Run scripts in order)                                        │
│  ══════════════════════════════════════════════════════════════════════════════  │
│                                                                                   │
│  Step 1          Step 2          Step 3          Step 4                           │
│  ┌──────┐        ┌──────┐        ┌──────┐        ┌──────┐                        │
│  │Traefik│───────►│ArgoCD│───────►│Gitea │───────►│App of│                        │
│  │      │        │      │        │      │        │ Apps │                        │
│  └──────┘        └──────┘        └──────┘        └──────┘                        │
│     │               │               │               │                             │
│     ▼               ▼               ▼               ▼                             │
│  Provides        Provides        Provides        Deploys                         │
│  LoadBalancer    GitOps          Git Repo        Everything                      │
│  + Routing       Engine          Storage         Else                            │
│                                                                                   │
│  ══════════════════════════════════════════════════════════════════════════════  │
│  Manual Bootstrap (Scripts)           │    Automated (ArgoCD Managed)            │
│  ══════════════════════════════════════════════════════════════════════════════  │
└───────────────────────────────────────────────────────────────────────────────────┘
```

> **📌 Summary:** `Longhorn` → `Metrics Server` → `Traefik` → `ArgoCD` → `Gitea` → `App of Apps`

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

Now that the GitOps engine is running, we utilize it to deploy the infrastructure dependencies required for a secure, production-grade environment. This phase establishes the **Defense in Depth** layers and **Day 2 Operations** tooling.

### Phase 5 Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      SECURITY & MANAGEMENT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                      STORAGE FOUNDATION LAYER                            │  │
│   │                                                                          │  │
│   │    ┌─────────────┐                                                       │  │
│   │    │   MinIO     │◄─── S3-Compatible Object Storage                      │  │
│   │    │   (S3 API)  │                                                       │  │
│   │    └──────┬──────┘                                                       │  │
│   │           │                                                              │  │
│   │    ┌──────┴──────────────────────────────────┐                          │  │
│   │    │              │              │           │                          │  │
│   │    ▼              ▼              ▼           ▼                          │  │
│   │ ┌──────┐    ┌──────────┐   ┌──────┐   ┌──────────┐                     │  │
│   │ │Velero│    │  Harbor  │   │ Loki │   │  Thanos  │                     │  │
│   │ │Backup│    │ Registry │   │ Logs │   │ Metrics  │                     │  │
│   │ └──────┘    └──────────┘   └──────┘   └──────────┘                     │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                      SECURITY DEFENSE LAYERS                             │  │
│   │                                                                          │  │
│   │   BUILD TIME          DEPLOY TIME           RUN TIME                     │  │
│   │   ──────────          ───────────           ────────                     │  │
│   │   ┌─────────┐         ┌─────────┐          ┌─────────┐                  │  │
│   │   │  Trivy  │────────►│ Kyverno │─────────►│  Falco  │                  │  │
│   │   │  Scan   │         │ Policies│          │  eBPF   │                  │  │
│   │   └─────────┘         └─────────┘          └─────────┘                  │  │
│   │        │                   │                    │                        │  │
│   │        ▼                   ▼                    ▼                        │  │
│   │   Block vulnerable    Reject non-          Alert on                     │  │
│   │   images at push      compliant pods       suspicious                   │  │
│   │                                            syscalls                      │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                      MANAGEMENT AUTOMATION                               │  │
│   │                                                                          │  │
│   │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │  │
│   │   │  Reloader   │    │Descheduler  │    │   OpenBao   │                 │  │
│   │   │             │    │             │    │   (Vault)   │                 │  │
│   │   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                 │  │
│   │          │                  │                  │                         │  │
│   │          ▼                  ▼                  ▼                         │  │
│   │   Auto-restart         Rebalance           Secrets                      │  │
│   │   on ConfigMap         workloads           injection                    │  │
│   │   changes              across nodes                                      │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 5 Components

| Component | Version | Category | Purpose | Depends On |
|-----------|---------|----------|---------|------------|
| **MinIO** | 5.2.0 | Storage | S3-compatible object storage | Longhorn |
| **Cert-Manager** | 1.16.0 | Security | TLS certificate automation | - |
| **Harbor** | 1.15.0 | Security | Private container registry | MinIO |
| **Velero** | 5.1.0 | Management | Backup & disaster recovery | MinIO |
| **OpenBao** | 0.1.0 | Security | Secrets management (Vault fork) | Longhorn |
| **Kyverno** | 3.1.4 | Security | Policy enforcement | - |
| **Falco** | 4.0.0 | Security | Runtime threat detection | - |
| **Reloader** | 1.1.0 | Management | ConfigMap/Secret reload | - |
| **Descheduler** | 0.31.0 | Management | Workload rebalancing | - |

### Deployment Order (Sync Waves)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 5 SYNC WAVE ORDER                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Wave -2        Wave -1        Wave 0         Wave 1         Wave 2        │
│  ────────       ────────       ──────         ──────         ──────        │
│                                                                             │
│  ┌──────┐      ┌────────┐     ┌───────┐     ┌───────┐     ┌──────────┐    │
│  │MinIO │─────►│Cert-Mgr│────►│Kyverno│────►│ Falco │────►│  Harbor  │    │
│  │      │      │Reloader│     │OpenBao│     │       │     │  Velero  │    │
│  └──────┘      └────────┘     └───────┘     └───────┘     └──────────┘    │
│     │              │              │             │              │           │
│     ▼              ▼              ▼             ▼              ▼           │
│  S3 buckets    TLS certs      Admission     Runtime       Dependent       │
│  available     automation     webhooks      monitoring    services        │
│                                ready                                       │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│  Dependencies flow left to right. Later waves depend on earlier ones.      │
│  ═══════════════════════════════════════════════════════════════════════   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.1 Object Storage (MinIO)

**File:** `gitops/storage/minio.yaml`

Many Cloud Native tools (Velero, Thanos, Loki, Harbor) expect an AWS S3 bucket. Since we are on bare metal, we self-host **MinIO** to provide this API.

**Why MinIO?**

| Feature | Benefit for RPi Cluster |
|---------|-------------------------|
| **S3 Compatible** | Works with any tool expecting AWS S3 |
| **Lightweight** | Single binary, ~256MB memory |
| **Auto-bucket** | Creates required buckets on startup |
| **Web Console** | Easy management UI |

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `mode` | `standalone` | Single instance (no distributed mode on RPi) |
| `persistence.size` | `50Gi` | Storage for all S3 data |
| `persistence.storageClass` | `longhorn` | HDD-backed storage |
| `buckets` | velero, harbor, loki-data, thanos-data | Pre-created buckets |

**Access:**

| Service | URL | Credentials |
|---------|-----|-------------|
| Console | http://minio.192.168.0.210.nip.io | admin / password123 |
| API | http://minio.storage.svc:9000 | (internal) |

> ⚠️ **Security Warning:** Change the default credentials (`admin`/`password123`) in production!

<details>
<summary>📄 Click to expand full gitops/storage/minio.yaml</summary>

```yaml
# =============================================================================
# MinIO - S3-Compatible Object Storage
# =============================================================================
# Provides S3 API for Cloud Native tools that expect object storage.
# This is the foundation for backup, logging, and metrics storage.
#
# Buckets Created:
#   - velero: Cluster backups
#   - harbor: Container image layers
#   - loki-data: Log storage
#   - thanos-data: Long-term metrics
#
# Access:
#   - Console: http://minio.192.168.0.210.nip.io
#   - API: http://minio.storage.svc.cluster.local:9000
#   - Credentials: admin / password123 (CHANGE IN PRODUCTION!)
#
# Dependencies: Longhorn storage class
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
    argocd.argoproj.io/sync-options: ServerSideApply=true
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.min.io/
    chart: minio
    targetRevision: 5.2.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Deployment Mode
        # -------------------------------------------------------------------
        mode: standalone
        replicas: 1
        
        # -------------------------------------------------------------------
        # Storage Configuration
        # -------------------------------------------------------------------
        persistence:
          enabled: true
          storageClass: longhorn
          size: 50Gi
          accessMode: ReadWriteOnce
        
        # -------------------------------------------------------------------
        # Resource Limits (RPi optimized)
        # -------------------------------------------------------------------
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        # -------------------------------------------------------------------
        # Auto-Create Buckets
        # -------------------------------------------------------------------
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
        
        # -------------------------------------------------------------------
        # Ingress Configuration
        # -------------------------------------------------------------------
        ingress:
          enabled: true
          ingressClassName: traefik
          hosts:
            - minio.192.168.0.210.nip.io
          annotations:
            traefik.ingress.kubernetes.io/router.entrypoints: web
        
        consoleIngress:
          enabled: true
          ingressClassName: traefik
          hosts:
            - minio-console.192.168.0.210.nip.io
          annotations:
            traefik.ingress.kubernetes.io/router.entrypoints: web
        
        # -------------------------------------------------------------------
        # Credentials (CHANGE IN PRODUCTION!)
        # -------------------------------------------------------------------
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
      - ServerSideApply=true
```

</details>

### 9.2 Certificate Automation (Cert-Manager)

**File:** `gitops/infrastructure/cert-manager.yaml`

Cert-Manager automates TLS certificate management within the cluster.

**Why Cert-Manager?**

| Feature | Benefit |
|---------|---------|
| **Automatic Renewal** | Certificates auto-renew before expiry |
| **Multiple Issuers** | Self-signed, Let's Encrypt, CA, Vault |
| **Native Integration** | Works with Ingress and Gateway API |
| **Lightweight** | ~100MB memory footprint |

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `installCRDs` | `true` | Install Certificate, Issuer CRDs |
| `namespace` | `cert-manager` | Standard namespace location |

> 💡 **Note:** This setup uses self-signed certificates. For production with public DNS, configure Let's Encrypt issuers.

<details>
<summary>📄 Click to expand full gitops/infrastructure/cert-manager.yaml</summary>

```yaml
# =============================================================================
# Cert-Manager - TLS Certificate Automation
# =============================================================================
# Handles automatic provisioning and renewal of TLS certificates.
# Currently configured for self-signed certificates (internal use).
#
# For Let's Encrypt (production):
#   1. Configure DNS provider credentials
#   2. Create ClusterIssuer with ACME solver
#   3. Update Ingress annotations
#
# Usage:
#   Add to Ingress: cert-manager.io/cluster-issuer: "self-signed"
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
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
      values: |
        # Resource limits for RPi
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        
        webhook:
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 50m
              memory: 64Mi
        
        cainjector:
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
  
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

Harbor serves as the local "Docker Hub" - a private container registry with built-in security scanning.

**Why Harbor?**

| Feature | Benefit |
|---------|---------|
| **Private Registry** | Keep images off public Docker Hub |
| **Trivy Integration** | Scan images for CVEs on push |
| **S3 Backend** | Store image layers in MinIO (not on SD cards) |
| **RBAC** | Project-based access control |

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `expose.type` | `ingress` | Access via Traefik |
| `persistence.type` | `s3` | Store images in MinIO |
| `trivy.enabled` | `true` | Vulnerability scanning |
| `notary.enabled` | `false` | Save RAM (image signing disabled) |

**Access:**

| Service | URL | Credentials |
|---------|-----|-------------|
| Web UI | http://harbor.192.168.0.210.nip.io | admin / Harbor12345 |
| Docker | docker login harbor.192.168.0.210.nip.io | (same) |

<details>
<summary>📄 Click to expand full gitops/security/harbor.yaml</summary>

```yaml
# =============================================================================
# Harbor - Private Container Registry
# =============================================================================
# Enterprise-grade container registry with vulnerability scanning.
# Images are stored in MinIO S3 to avoid filling SD cards.
#
# Features:
#   - Trivy vulnerability scanning on push
#   - S3 backend storage (MinIO)
#   - Project-based access control
#
# Access:
#   - Web: http://harbor.192.168.0.210.nip.io
#   - Docker: docker login harbor.192.168.0.210.nip.io
#   - Default: admin / Harbor12345
#
# Dependencies: MinIO (storage), Longhorn (database)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: harbor
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://helm.goharbor.io
    chart: harbor
    targetRevision: 1.15.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Ingress Configuration
        # -------------------------------------------------------------------
        expose:
          type: ingress
          ingress:
            hosts:
              core: harbor.192.168.0.210.nip.io
            className: traefik
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: web
        
        # External URL for Docker client
        externalURL: http://harbor.192.168.0.210.nip.io
        
        # -------------------------------------------------------------------
        # S3 Storage Backend (MinIO)
        # -------------------------------------------------------------------
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
        
        # -------------------------------------------------------------------
        # Components (RPi optimized)
        # -------------------------------------------------------------------
        # Disable heavy components to save RAM
        notary:
          enabled: false
        chartmuseum:
          enabled: false
        
        # Enable security scanning
        trivy:
          enabled: true
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
        
        # -------------------------------------------------------------------
        # Core Components Resources
        # -------------------------------------------------------------------
        core:
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
        
        portal:
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
        
        registry:
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
  
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

Velero performs scheduled backups of cluster resources and persistent volumes, enabling disaster recovery.

**Why Velero?**

| Feature | Benefit |
|---------|---------|
| **Cluster Backups** | Back up Kubernetes resources (YAML) |
| **Volume Snapshots** | PV data via CSI snapshots |
| **Scheduled** | Automated daily/weekly backups |
| **Restore** | One-command cluster restore |

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `provider` | `aws` | S3-compatible (MinIO) |
| `bucket` | `velero` | Pre-created MinIO bucket |
| `s3Url` | MinIO internal service | Backup destination |

**Backup Commands:**

```bash
# Create manual backup
velero backup create manual-backup --include-namespaces default

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup manual-backup
```

<details>
<summary>📄 Click to expand full gitops/management/velero.yaml</summary>

```yaml
# =============================================================================
# Velero - Backup & Disaster Recovery
# =============================================================================
# Provides scheduled backups of Kubernetes resources and persistent volumes.
# Stores backups in MinIO S3 bucket for off-cluster durability.
#
# Features:
#   - Scheduled cluster state backups
#   - PersistentVolume snapshots via Longhorn CSI
#   - Point-in-time recovery
#
# Commands:
#   velero backup create <name>
#   velero backup get
#   velero restore create --from-backup <name>
#
# Dependencies: MinIO (velero bucket)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velero
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://vmware-tanzu.github.io/helm-charts
    chart: velero
    targetRevision: 5.1.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Backup Configuration
        # -------------------------------------------------------------------
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
        
        # -------------------------------------------------------------------
        # MinIO Credentials
        # -------------------------------------------------------------------
        credentials:
          useSecret: true
          secretContents:
            cloud: |
              [default]
              aws_access_key_id = admin
              aws_secret_access_key = password123
        
        # -------------------------------------------------------------------
        # AWS Plugin for S3
        # -------------------------------------------------------------------
        initContainers:
          - name: velero-plugin-for-aws
            image: velero/velero-plugin-for-aws:v1.9.0
            volumeMounts:
              - mountPath: /target
                name: plugins
        
        # -------------------------------------------------------------------
        # Scheduled Backups
        # -------------------------------------------------------------------
        schedules:
          daily-backup:
            schedule: "0 2 * * *"  # 2 AM daily
            template:
              ttl: "168h"  # Keep for 7 days
              includedNamespaces:
                - "*"
              excludedNamespaces:
                - kube-system
        
        # -------------------------------------------------------------------
        # Resource Limits (RPi optimized)
        # -------------------------------------------------------------------
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
  
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

OpenBao (community fork of HashiCorp Vault) provides secure secrets management with encryption at rest.

**Why OpenBao?**

| Feature | Benefit |
|---------|---------|
| **Open Source** | Community-maintained Vault fork |
| **Encryption** | Secrets encrypted at rest |
| **Dynamic Secrets** | Generate credentials on-demand |
| **Audit Logging** | Track secret access |

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `ha.enabled` | `false` | Single instance for RPi |
| `dataStorage.size` | `10Gi` | Secret storage volume |
| `ui.enabled` | `true` | Web management interface |

<details>
<summary>📄 Click to expand full gitops/security/openbao.yaml</summary>

```yaml
# =============================================================================
# OpenBao - Secrets Management
# =============================================================================
# Secure secrets management (HashiCorp Vault community fork).
# Provides encrypted storage, dynamic secrets, and audit logging.
#
# Features:
#   - Encryption at rest
#   - Dynamic credential generation
#   - Kubernetes auth integration
#   - Audit logging
#
# First-time Setup:
#   1. Port-forward: kubectl port-forward svc/openbao 8200:8200 -n security
#   2. Initialize: bao operator init
#   3. Unseal: bao operator unseal (use 3 of 5 keys)
#
# Dependencies: Longhorn storage
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openbao
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://openbao.github.io/openbao-helm
    chart: openbao
    targetRevision: 0.1.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Server Configuration
        # -------------------------------------------------------------------
        server:
          # Standalone mode (no HA for RPi resources)
          ha:
            enabled: false
          
          # Persistent storage
          dataStorage:
            enabled: true
            size: 10Gi
            storageClass: longhorn
          
          # Resource limits (RPi optimized)
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
        
        # -------------------------------------------------------------------
        # UI Configuration
        # -------------------------------------------------------------------
        ui:
          enabled: true
          serviceType: ClusterIP
        
        # -------------------------------------------------------------------
        # Injector (sidecar for secret injection)
        # -------------------------------------------------------------------
        injector:
          enabled: true
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
  
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

Kyverno enforces security best practices through admission control policies—no OPA Gatekeeper complexity required.

**Why Kyverno?**

| Feature | Benefit |
|---------|---------|
| **Native YAML** | Policies written in Kubernetes YAML (no Rego) |
| **Validate/Mutate/Generate** | Block, modify, or create resources |
| **Audit Mode** | Test policies before enforcing |
| **Lightweight** | ~128MB memory per controller |

**Example Policies:**

| Policy | Action |
|--------|--------|
| No `:latest` tags | Block pods using `image:latest` |
| No privileged containers | Reject `securityContext.privileged: true` |
| Require resource limits | Block pods without CPU/memory limits |
| Required labels | Ensure all pods have `app` label |

<details>
<summary>📄 Click to expand full gitops/security/kyverno.yaml</summary>

```yaml
# =============================================================================
# Kyverno - Policy Enforcement Engine
# =============================================================================
# Kubernetes-native policy engine using admission webhooks.
# Enforces security best practices without OPA/Rego complexity.
#
# Features:
#   - Validate: Block non-compliant resources
#   - Mutate: Auto-fix resources on creation
#   - Generate: Create companion resources
#
# Example Policy (add separately):
#   Disallow :latest image tags
#   Require resource limits
#   Block privileged containers
#
# Test policies:
#   kubectl run test --image=nginx:latest --dry-run=server
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://kyverno.github.io/kyverno/
    chart: kyverno
    targetRevision: 3.1.4
    helm:
      values: |
        # -------------------------------------------------------------------
        # Controller Replicas (single for RPi)
        # -------------------------------------------------------------------
        admissionController:
          replicas: 1
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
        
        backgroundController:
          replicas: 1
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
        
        cleanupController:
          replicas: 1
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 50m
              memory: 64Mi
        
        reportsController:
          replicas: 1
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
  
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

Falco monitors kernel syscalls to detect intrusions and suspicious behavior at runtime.

**Why Falco?**

| Feature | Benefit |
|---------|---------|
| **Kernel Monitoring** | Sees all syscalls, not just API calls |
| **eBPF Driver** | Modern, no kernel module compilation |
| **Rule-Based** | Customizable detection rules |
| **Sidekick UI** | Web dashboard for alerts |

**Detection Examples:**

| Event | Alert |
|-------|-------|
| Shell in container | "Terminal shell opened in container" |
| File system changes | "Write to /etc inside container" |
| Network anomalies | "Unexpected outbound connection" |
| Privilege escalation | "Setuid binary executed" |

> ⚠️ **RPi Note:** We explicitly use the `ebpf` driver because the kernel module driver often fails on Ubuntu RPi kernels.

<details>
<summary>📄 Click to expand full gitops/security/falco.yaml</summary>

```yaml
# =============================================================================
# Falco - Runtime Security Monitoring
# =============================================================================
# Kernel-level syscall monitoring for threat detection.
# Uses eBPF driver (not kernel module) for RPi compatibility.
#
# Features:
#   - Syscall monitoring via eBPF
#   - Real-time alerting
#   - Falcosidekick UI for visualization
#
# Example Detections:
#   - Shell opened in container
#   - File write in /etc
#   - Unexpected network connections
#   - Privilege escalation attempts
#
# View alerts:
#   kubectl logs -n security -l app.kubernetes.io/name=falco
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: falco
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://falcosecurity.github.io/charts/
    chart: falco
    targetRevision: 4.0.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Driver Configuration (eBPF for RPi)
        # -------------------------------------------------------------------
        driver:
          kind: ebpf  # Not kernel_module - avoids RPi kernel issues
        
        # -------------------------------------------------------------------
        # Falcosidekick (Alert Forwarding + UI)
        # -------------------------------------------------------------------
        falcosidekick:
          enabled: true
          webui:
            enabled: true
            resources:
              requests:
                cpu: 10m
                memory: 32Mi
              limits:
                cpu: 50m
                memory: 64Mi
        
        # -------------------------------------------------------------------
        # Resource Limits (DaemonSet on all nodes)
        # -------------------------------------------------------------------
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        
        # -------------------------------------------------------------------
        # Custom Rules (optional)
        # -------------------------------------------------------------------
        customRules:
          custom-rules.yaml: |
            # Alert on shell in any container
            - rule: Shell in container
              desc: Detect shell inside container
              condition: >
                spawned_process and container and
                (proc.name = bash or proc.name = sh)
              output: >
                Shell opened (user=%user.name container=%container.name
                image=%container.image.repository)
              priority: WARNING
  
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

Reloader watches for changes in ConfigMaps and Secrets, then automatically triggers rolling updates on associated Deployments/StatefulSets.

**Why Reloader?**

| Feature | Benefit |
|---------|---------|
| **Auto-Restart** | No manual `kubectl rollout restart` |
| **GitOps Friendly** | Config changes propagate automatically |
| **Lightweight** | ~10MB RAM footprint |
| **Selective** | Only restarts annotated workloads |

**Usage:**

Add this annotation to enable auto-reload:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

Or specify exact ConfigMaps/Secrets:

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "my-configmap"
    secret.reloader.stakater.com/reload: "my-secret"
```

<details>
<summary>📄 Click to expand full gitops/management/reloader.yaml</summary>

```yaml
# =============================================================================
# Reloader - ConfigMap/Secret Change Propagation
# =============================================================================
# Watches ConfigMaps and Secrets for changes, then triggers rolling
# restarts on Deployments/StatefulSets that reference them.
#
# Essential for GitOps: when you update a ConfigMap in Git, the
# corresponding pods automatically restart to pick up changes.
#
# Usage - Add annotation to Deployment:
#   reloader.stakater.com/auto: "true"
#
# Or specify specific ConfigMaps:
#   configmap.reloader.stakater.com/reload: "app-config"
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: reloader
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://stakater.github.io/stakater-charts
    chart: reloader
    targetRevision: 1.1.0
    helm:
      values: |
        reloader:
          # Watch all namespaces
          watchGlobally: true
          
          # Resource limits (very lightweight)
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 128Mi
          
          # Logging
          logFormat: json
  
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

</details>

### 9.9 Workload Rebalancing (Descheduler)

**File:** `gitops/management/descheduler.yaml`

On resource-constrained Raspberry Pi clusters, workloads can become imbalanced over time. The Descheduler periodically evicts pods based on configured strategies, allowing the scheduler to rebalance them.

**Why Descheduler?**

| Feature | Benefit |
|---------|---------|
| **Auto-Rebalance** | Even distribution across nodes |
| **Node Affinity Fix** | Evict pods violating affinity rules |
| **Duplicate Removal** | Spread replicas across nodes |
| **Scheduled** | Runs on cron (every 15 min) |

**Strategies Enabled:**

| Strategy | Action |
|----------|--------|
| `RemoveDuplicates` | Spread replicas across different nodes |
| `LowNodeUtilization` | Move pods from overloaded to underutilized nodes |
| `RemovePodsViolatingNodeAffinity` | Evict pods not matching node affinity |

> 💡 **Note:** Descheduler only evicts pods; the kube-scheduler handles new placement.

<details>
<summary>📄 Click to expand full gitops/management/descheduler.yaml</summary>

```yaml
# =============================================================================
# Descheduler - Workload Rebalancing
# =============================================================================
# Periodically evicts pods to enable the scheduler to rebalance workloads
# across nodes. Essential for resource-constrained RPi clusters.
#
# Strategies:
#   - RemoveDuplicates: Spread replicas across nodes
#   - LowNodeUtilization: Balance CPU/memory across nodes
#   - RemovePodsViolatingNodeAffinity: Fix affinity violations
#
# Schedule: Runs every 15 minutes
#
# Note: Descheduler evicts pods; kube-scheduler places them
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: descheduler
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/descheduler
    chart: descheduler
    targetRevision: 0.31.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Schedule (cron expression)
        # -------------------------------------------------------------------
        schedule: "*/15 * * * *"  # Every 15 minutes
        
        # -------------------------------------------------------------------
        # Descheduling Strategies
        # -------------------------------------------------------------------
        deschedulerPolicy:
          strategies:
            # Ensure pod replicas are spread across nodes
            RemoveDuplicates:
              enabled: true
            
            # Move pods from overloaded to underutilized nodes
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
            
            # Evict pods that no longer satisfy node affinity
            RemovePodsViolatingNodeAffinity:
              enabled: true
              params:
                nodeAffinityType:
                  - requiredDuringSchedulingIgnoredDuringExecution
        
        # -------------------------------------------------------------------
        # Resource Limits
        # -------------------------------------------------------------------
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
    
### 9.10 Cluster Dashboard (Headlamp)

**File:** `gitops/management/headlamp.yaml`

Headlamp is a **modern, lightweight Kubernetes dashboard** that provides a graphical interface for cluster management. Unlike the traditional Kubernetes Dashboard, Headlamp features a plugin architecture and a more intuitive React-based UI.

**Why Headlamp over Kubernetes Dashboard?**

| Feature | Kubernetes Dashboard | Headlamp |
|---------|---------------------|----------|
| **Memory Usage** | ~200MB | ~100MB |
| **UI Framework** | Angular | React (modern) |
| **Plugin System** | ❌ | ✅ Extensible |
| **Multi-cluster** | Limited | ✅ Native |
| **Active Development** | Moderate | Very Active |
| **OIDC Ready** | Manual config | Built-in |

**Access Configuration:**

| Setting | Value |
|---------|-------|
| **URL** | `http://headlamp.192.168.0.210.nip.io` |
| **Authentication** | Service Account Token |
| **Namespace** | `headlamp` |
| **Memory Limit** | 192Mi |

**Getting the Authentication Token:**

```bash
# Get the token for Headlamp login
kubectl get secret headlamp-token -n headlamp -o jsonpath='{.data.token}' | base64 -d
```

**Key Features:**

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HEADLAMP CAPABILITIES                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  RESOURCE MANAGEMENT                   DEBUGGING TOOLS                      │
│  ───────────────────                   ───────────────                      │
│  • View all K8s resources              • Pod logs (real-time)               │
│  • Create/Edit/Delete via YAML         • Exec into containers               │
│  • Scale deployments                   • Resource events                    │
│  • Manage ConfigMaps/Secrets           • Node conditions                    │
│                                                                             │
│  VISUALIZATION                         CLUSTER OVERVIEW                     │
│  ─────────────                         ────────────────                     │
│  • Workload status                     • Node status & resources            │
│  • Pod relationships                   • Namespace summary                  │
│  • Storage volumes                     • RBAC visualization                 │
│  • Network resources                   • CRD browser                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

<details>
<summary>📄 Click to expand full gitops/management/headlamp.yaml</summary>

```yaml
# =============================================================================
# Headlamp - Modern Kubernetes Dashboard
# =============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: headlamp
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://headlamp-k8s.github.io/headlamp
    chart: headlamp
    targetRevision: 0.25.0
    helm:
      releaseName: headlamp
      values: |
        replicaCount: 1
        
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 192Mi
        
        service:
          type: ClusterIP
          port: 80
        
        serviceAccount:
          create: true
          name: headlamp
        
        clusterRoleBinding:
          create: true
          clusterRoleName: cluster-admin
        
  destination:
    server: https://kubernetes.default.svc
    namespace: headlamp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
---
# HTTPRoute for Gateway API access
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: headlamp
  namespace: headlamp
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "headlamp.192.168.0.210.nip.io"
  rules:
    - backendRefs:
        - name: headlamp
          port: 80
---
# Service Account Token for authentication
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-token
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp
type: kubernetes.io/service-account-token
```

</details>

### 9.11 The Root Application (App of Apps)

**File:** `gitops/root-app.yaml`

This is the **"One Ring to Rule Them All"**—the master Application that points ArgoCD at the entire `gitops/` directory, enabling recursive discovery of all child Applications.

**How It Works:**

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ROOT APP HIERARCHY                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         ┌─────────────────┐                                │
│                         │    root-app     │                                │
│                         │   (This file)   │                                │
│                         └────────┬────────┘                                │
│                                  │                                          │
│                         watches: gitops/                                    │
│                                  │                                          │
│         ┌────────────────────────┼────────────────────────┐                │
│         ▼                        ▼                        ▼                │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐          │
│  │infrastructure│        │  security/  │         │ management/ │          │
│  │/             │         │             │         │             │          │
│  └──────┬──────┘         └──────┬──────┘         └──────┬──────┘          │
│         │                       │                       │                   │
│         ▼                       ▼                       ▼                   │
│    cert-manager            kyverno                 reloader                │
│                            falco                   descheduler             │
│                            harbor                  velero                  │
│                            openbao                 headlamp                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `repoURL` | Gitea repo URL | Source of truth for config |
| `path` | `gitops` | Directory containing Applications |
| `directory.recurse` | `true` | Find nested Application YAMLs |

<details>
<summary>📄 Click to expand full gitops/root-app.yaml</summary>

```yaml
# =============================================================================
# Root Application - App of Apps Pattern
# =============================================================================
# The master controller that points ArgoCD at the gitops/ directory.
# ArgoCD recursively discovers and syncs all Application manifests.
#
# This is the ONLY manifest you need to apply manually. After this,
# ArgoCD manages everything through Git reconciliation.
#
# Usage:
#   1. Push gitops/ folder to Gitea repository
#   2. Update repoURL below to your Gitea repo
#   3. kubectl apply -f gitops/root-app.yaml
#   4. Watch ArgoCD deploy everything automatically
#
# Excluded Paths:
#   - apps/*: User applications (deploy separately)
#   - services/*: Avoid recursive loops
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    # Update this to your Gitea repository URL
    repoURL: http://gitea.192.168.0.210.nip.io/liviu/home-cluster.git
    targetRevision: main
    path: gitops
    directory:
      recurse: true
      # Exclude to avoid infinite loops
      exclude: "{apps/*,services/*}"
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

</details>

### 9.12 Security Verification Script

**File:** `tests/04_security_test.sh`

This script verifies that all security components are functioning correctly.

**Test Coverage:**

| Test | Component | Expected Result |
|------|-----------|-----------------|
| Policy Enforcement | Kyverno | Block pods with `:latest` tag |
| Runtime Monitoring | Falco | eBPF probes running |
| Registry Access | Harbor | API returns HTTP 200 |
| Secrets Management | OpenBao | Service responding |
| Backup System | Velero | Server pod running |

<details>
<summary>📄 Click to expand full tests/04_security_test.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 5 Security Stack Verification Test
# =============================================================================
# Verifies all security and management components:
#   - Kyverno policy enforcement
#   - Falco runtime security
#   - Harbor container registry
#   - OpenBao secrets management
#   - Velero backup system
#   - MinIO object storage
#
# Prerequisites:
#   - Phase 5 components deployed
#   - kubectl configured for the cluster
#
# Usage: bash tests/04_security_test.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║          PHASE 5: SECURITY & MANAGEMENT VERIFICATION                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Test 1: MinIO Object Storage
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 1: MinIO Object Storage                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

MINIO_PODS=$(kubectl get pods -n storage -l app=minio --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$MINIO_PODS" -ge 1 ]; then
    echo "✅ MinIO is running"
    ((TESTS_PASSED++))
    
    # Check API endpoint
    MINIO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://minio.192.168.0.210.nip.io/minio/health/live 2>/dev/null || echo "000")
    if [ "$MINIO_STATUS" == "200" ]; then
        echo "  ✅ MinIO API accessible"
    fi
else
    echo "❌ MinIO not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 2: Kyverno Policy Enforcement
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 2: Kyverno Policy Enforcement                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$KYVERNO_PODS" -ge 1 ]; then
    echo "✅ Kyverno is running ($KYVERNO_PODS pods)"
    ((TESTS_PASSED++))
    
    # Test policy enforcement (should fail)
    echo "  Testing policy enforcement..."
    if kubectl run kyverno-test --image=nginx:latest --dry-run=server 2>&1 | grep -q "blocked\|denied\|disallowed"; then
        echo "  ✅ Policy blocked :latest tag"
    else
        echo "  ⚠️  Policy not enforcing (may not be configured yet)"
    fi
else
    echo "❌ Kyverno not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 3: Falco Runtime Security
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 3: Falco Runtime Security                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

FALCO_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=falco --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$FALCO_PODS" -ge 1 ]; then
    echo "✅ Falco eBPF probes running ($FALCO_PODS pods)"
    ((TESTS_PASSED++))
else
    echo "❌ Falco not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 4: Harbor Container Registry
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 4: Harbor Container Registry                                   │"
echo "└─────────────────────────────────────────────────────────────────────┘"

HARBOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://harbor.192.168.0.210.nip.io/api/v2.0/ping 2>/dev/null || echo "000")
if [ "$HARBOR_STATUS" == "200" ]; then
    echo "✅ Harbor API accessible (HTTP 200)"
    ((TESTS_PASSED++))
else
    echo "❌ Harbor API not accessible (HTTP $HARBOR_STATUS)"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 5: Velero Backup System
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 5: Velero Backup System                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

VELERO_PODS=$(kubectl get pods -n velero -l app.kubernetes.io/name=velero --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$VELERO_PODS" -ge 1 ]; then
    echo "✅ Velero server is running"
    ((TESTS_PASSED++))
    
    # Check backup location
    BSL_STATUS=$(kubectl get backupstoragelocation -n velero default -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "  Backup Storage Location: $BSL_STATUS"
else
    echo "❌ Velero not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Test 6: OpenBao Secrets Management
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 6: OpenBao Secrets Management                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

OPENBAO_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=openbao --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$OPENBAO_PODS" -ge 1 ]; then
    echo "✅ OpenBao is running"
    ((TESTS_PASSED++))
else
    echo "⚠️  OpenBao not running (may need initialization)"
fi

# -----------------------------------------------------------------------------
# Test 7: Reloader
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 7: Reloader ConfigMap Watcher                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

RELOADER_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=reloader --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$RELOADER_PODS" -ge 1 ]; then
    echo "✅ Reloader is running"
    ((TESTS_PASSED++))
else
    echo "❌ Reloader not running"
    ((TESTS_FAILED++))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION SUMMARY                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "  ✅ All Phase 5 security tests passed!"
    echo ""
    echo "Access URLs:"
    echo "  • MinIO:  http://minio.192.168.0.210.nip.io (admin/password123)"
    echo "  • Harbor: http://harbor.192.168.0.210.nip.io (admin/Harbor12345)"
    exit 0
else
    echo "  ❌ Some tests failed. Check component status above."
    exit 1
fi
```

</details>

### 9.13 Phase 5 Execution Steps

Execute these commands after Phase 4 (GitOps) is complete:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 5 EXECUTION CHECKLIST                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  □ Step 1: Verify gitops/ files exist locally                              │
│  □ Step 2: Push to Gitea repository                                        │
│  □ Step 3: Apply root-app.yaml                                             │
│  □ Step 4: Monitor ArgoCD sync progress                                    │
│  □ Step 5: Run verification script                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Step 1: Verify Local Files**

Ensure all gitops/ files are created:

```bash
ls -la gitops/storage/
ls -la gitops/security/
ls -la gitops/management/
ls -la gitops/infrastructure/
```

**Step 2: Push to Gitea**

```bash
cd /path/to/your/repo
git add .
git commit -m "Add Phase 5: Security and Management stack"
git push origin main
```

**Step 3: Apply Root Application**

```bash
kubectl apply -f gitops/root-app.yaml
```

**Step 4: Monitor Sync Progress**

```bash
# Watch ArgoCD applications
kubectl get applications -n argocd -w

# Check specific application status
kubectl get application -n argocd minio -o yaml | grep -A5 status:
```

**Step 5: Run Verification**

```bash
bash tests/04_security_test.sh
```

**Access Credentials:**

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| MinIO Console | http://minio.192.168.0.210.nip.io | admin | password123 |
| Harbor Registry | http://harbor.192.168.0.210.nip.io | admin | Harbor12345 |
| Headlamp Dashboard | http://headlamp.192.168.0.210.nip.io | - | Service Account Token ⁵ |

> **⁵ Headlamp Token:** Get the authentication token with:
> ```bash
> kubectl get secret headlamp-token -n headlamp -o jsonpath='{.data.token}' | base64 -d
> ```

> ⚠️ **Security Reminder:** Change all default passwords before exposing services externally!

## 10. Phase 6: Advanced Observability

In this phase, we complete the observability pillar. Metrics (Prometheus) tell you *what* is happening, but Logs (Loki) tell you *why*. We also add cost estimation and AI analysis to help manage the cluster.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ADVANCED OBSERVABILITY ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         DATA SOURCES                                 │   │
│  │    Pods          Nodes          Services          Kernel             │   │
│  └──────┬─────────────┬───────────────┬───────────────┬────────────────┘   │
│         │             │               │               │                     │
│         ▼             ▼               ▼               ▼                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      COLLECTION LAYER                                │   │
│  │  ┌───────────┐  ┌───────────┐  ┌────────────┐  ┌───────────────┐    │   │
│  │  │Fluent Bit │  │ Promtail  │  │OpenTelemetry│ │kube-state-    │    │   │
│  │  │(alt logs) │  │  (logs)   │  │ (traces)   │  │metrics        │    │   │
│  │  └─────┬─────┘  └─────┬─────┘  └──────┬─────┘  └───────┬───────┘    │   │
│  └────────┼──────────────┼───────────────┼────────────────┼────────────┘   │
│           │              │               │                │                 │
│           ▼              ▼               ▼                ▼                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       STORAGE LAYER                                  │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐    │   │
│  │  │     Loki      │  │  Prometheus   │  │      Jaeger           │    │   │
│  │  │   (logs)      │  │   (metrics)   │  │     (traces)          │    │   │
│  │  │       │       │  │       │       │  │                       │    │   │
│  │  │       ▼       │  │       ▼       │  │    (in-memory for     │    │   │
│  │  │   MinIO S3    │  │   Thanos      │  │     RPi resources)    │    │   │
│  │  │               │  │       │       │  │                       │    │   │
│  │  │               │  │       ▼       │  │                       │    │   │
│  │  │               │  │   MinIO S3    │  │                       │    │   │
│  │  └───────────────┘  └───────────────┘  └───────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│           │                    │                    │                       │
│           └────────────────────┼────────────────────┘                       │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    VISUALIZATION LAYER                               │   │
│  │      ┌─────────────────────────────────────────────────────────┐    │   │
│  │      │                     GRAFANA                             │    │   │
│  │      │    ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │    │   │
│  │      │    │Dashboards│ │Log      │  │Trace    │  │ Alerts  │  │    │   │
│  │      │    │(metrics)│  │Explorer │  │Explorer │  │         │  │    │   │
│  │      │    └─────────┘  └─────────┘  └─────────┘  └─────────┘  │    │   │
│  │      └─────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      ANALYSIS LAYER                                  │   │
│  │    ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │   │
│  │    │   OpenCost   │  │   K8sGPT     │  │     Kubeshark        │     │   │
│  │    │ (cost est.)  │  │ (AI diag.)   │  │  (API analysis)      │     │   │
│  │    └──────────────┘  └──────────────┘  └──────────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Phase 6 Components:**

| Component | Version | Purpose | Memory | Depends On |
|-----------|---------|---------|--------|------------|
| Loki Stack | 2.10.2 | Log aggregation + storage | 256MB | MinIO |
| Fluent Bit | 0.44.0 | Lightweight log forwarding | 64MB | Loki |
| OpenTelemetry | 0.49.0 | Distributed trace collection | 128MB | - |
| Jaeger | 3.0.0 | Trace visualization | 512MB | - |
| Kubeshark | 52.3.0 | API traffic analysis | 512MB | Longhorn |
| OpenCost | 1.29.0 | Cost estimation | 64MB | Prometheus |
| K8sGPT | 0.1.4 | AI-powered diagnostics | 64MB | - |

### 10.1 On-Demand Observability Tools

Some observability tools are resource-intensive and only needed during active debugging. To optimize memory usage on resource-constrained Raspberry Pi nodes, **Jaeger** and **Kubeshark** are deployed with **0 replicas by default**.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ON-DEMAND OBSERVABILITY PATTERN                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ALWAYS-ON (Essential for operations)                                       │
│  ─────────────────────────────────────                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Prometheus  │  │    Loki     │  │  Grafana    │  │ Fluent Bit  │        │
│  │  (metrics)  │  │   (logs)    │  │  (viz)      │  │  (collect)  │        │
│  │   ~512MB    │  │   ~256MB    │  │   ~128MB    │  │   ~64MB     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                             │
│  ON-DEMAND (Scale up only when debugging)                                   │
│  ─────────────────────────────────────────                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐          │
│  │         Jaeger              │  │        Kubeshark            │          │
│  │   (distributed tracing)     │  │    (API traffic capture)    │          │
│  │      replicas: 0            │  │       replicas: 0           │          │
│  │      ~512MB when active     │  │       ~512MB when active    │          │
│  └─────────────────────────────┘  └─────────────────────────────┘          │
│                                                                             │
│  Memory Savings: ~1GB freed when not actively debugging                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Enable/Disable Commands:**

```bash
# ============================================================================
# JAEGER - Distributed Tracing UI
# ============================================================================
# Enable (when debugging trace issues):
kubectl scale deployment jaeger-all-in-one -n monitoring --replicas=1

# Wait for it to be ready:
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=jaeger -n monitoring --timeout=120s

# Access Jaeger UI:
# http://jaeger.192.168.0.210.nip.io

# Disable (when done debugging):
kubectl scale deployment jaeger-all-in-one -n monitoring --replicas=0

# ============================================================================
# KUBESHARK - API Traffic Analyzer
# ============================================================================
# Enable (when debugging API traffic):
kubectl scale deployment kubeshark-hub -n observability --replicas=1

# Access Kubeshark UI:
kubectl port-forward -n observability svc/kubeshark-hub 8899:80
# Open: http://localhost:8899

# Disable (when done debugging):
kubectl scale deployment kubeshark-hub -n observability --replicas=0
```

**Workflow Integration:**

You can create shell aliases or a Makefile for convenience:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias jaeger-on='kubectl scale deployment jaeger-all-in-one -n monitoring --replicas=1'
alias jaeger-off='kubectl scale deployment jaeger-all-in-one -n monitoring --replicas=0'
alias kubeshark-on='kubectl scale deployment kubeshark-hub -n observability --replicas=1'
alias kubeshark-off='kubectl scale deployment kubeshark-hub -n observability --replicas=0'
```

> 💡 **Tip:** When OpenTelemetry is sending traces but Jaeger is scaled to 0, traces are simply dropped. No data is lost because traces are inherently ephemeral—they're only useful during active debugging sessions.

### 10.2 Log Aggregation (Loki Stack)

**File:** `gitops/observability/loki-stack.yaml`

We use the **PLG Stack** (Promtail, Loki, Grafana) for centralized logging.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LOKI LOGGING PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐     │
│  │   rpi4-1    │   │   rpi4-2    │   │   rpi4-3    │   │   rpi4-4    │     │
│  │  ┌───────┐  │   │  ┌───────┐  │   │  ┌───────┐  │   │  ┌───────┐  │     │
│  │  │Promtail│  │   │  │Promtail│  │   │  │Promtail│  │   │  │Promtail│  │     │
│  │  └───┬───┘  │   │  └───┬───┘  │   │  └───┬───┘  │   │  └───┬───┘  │     │
│  │      │      │   │      │      │   │      │      │   │      │      │     │
│  │ /var/log/   │   │ /var/log/   │   │ /var/log/   │   │ /var/log/   │     │
│  │ containers │   │ containers │   │ containers │   │ containers │     │
│  └──────┼──────┘   └──────┼──────┘   └──────┼──────┘   └──────┼──────┘     │
│         │                 │                 │                 │             │
│         └─────────────────┴─────────────────┴─────────────────┘             │
│                                   │                                         │
│                                   ▼                                         │
│                          ┌───────────────┐                                 │
│                          │     LOKI      │                                 │
│                          │   (Index +    │                                 │
│                          │    Query)     │                                 │
│                          └───────┬───────┘                                 │
│                                  │                                          │
│                                  ▼                                          │
│                          ┌───────────────┐                                 │
│                          │   MinIO S3    │                                 │
│                          │  loki-data    │   Long-term                     │
│                          │    bucket     │   storage                       │
│                          └───────────────┘                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why Loki vs Elasticsearch?**

| Feature | Loki | Elasticsearch |
|---------|------|---------------|
| **RAM Usage** | ~256MB | 2GB+ minimum |
| **Index Strategy** | Labels only (not full-text) | Full-text indexing |
| **Query Language** | LogQL (Prometheus-like) | Lucene/KQL |
| **RPi Suitability** | ✅ Excellent | ❌ Too heavy |
| **Grafana Integration** | Native | Plugin required |

**Storage Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `object_store` | s3 | Use MinIO for log chunks |
| `boltdb-shipper` | Index store | Local + S3 sync |
| `period` | 24h | New index table daily |
| `s3forcepathstyle` | true | Required for MinIO |

<details>
<summary>📄 Click to expand full gitops/observability/loki-stack.yaml</summary>

```yaml
# =============================================================================
# Loki Stack - Log Aggregation Pipeline
# =============================================================================
# Centralized logging using Promtail (collector) + Loki (storage/query).
# Integrated with Grafana for visualization via Log Explorer.
#
# Components:
#   - Loki: Log storage and query engine
#   - Promtail: DaemonSet log collector on all nodes
#
# Storage:
#   - Index: BoltDB Shipper (local + S3 sync)
#   - Chunks: MinIO S3 (loki-data bucket)
#
# Query Examples:
#   - All logs: {job="fluent-bit"}
#   - By namespace: {namespace="argocd"}
#   - By pod: {pod=~"prometheus.*"}
#   - With filter: {namespace="monitoring"} |= "error"
#
# Access:
#   - Grafana → Explore → Loki data source
#
# Dependencies: MinIO (storage/minio), Grafana (Phase 4)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki-stack
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: loki-stack
    targetRevision: 2.10.2
    helm:
      values: |
        # -------------------------------------------------------------------
        # Loki Server Configuration
        # -------------------------------------------------------------------
        loki:
          enabled: true
          
          # Persistent storage for index
          persistence:
            enabled: true
            storageClassName: longhorn
            size: 10Gi
          
          # Resource limits (RPi optimized)
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          
          # Storage configuration
          config:
            # Schema versioning
            schema_config:
              configs:
                - from: 2024-04-01
                  store: boltdb-shipper
                  object_store: s3
                  schema: v11
                  index:
                    prefix: index_
                    period: 24h
            
            # S3 storage backend (MinIO)
            storage_config:
              aws:
                s3: http://admin:password123@minio.storage.svc.cluster.local:9000/loki-data
                s3forcepathstyle: true
              boltdb_shipper:
                active_index_directory: /data/loki/boltdb-shipper-active
                cache_location: /data/loki/boltdb-shipper-cache
                shared_store: s3
            
            # Limits to prevent OOM on RPi
            limits_config:
              enforce_metric_name: false
              reject_old_samples: true
              reject_old_samples_max_age: 168h  # 7 days
              ingestion_rate_mb: 4
              ingestion_burst_size_mb: 6
        
        # -------------------------------------------------------------------
        # Promtail Log Collector (DaemonSet)
        # -------------------------------------------------------------------
        promtail:
          enabled: true
          
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          
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
    syncOptions:
      - CreateNamespace=true
```

</details>

### 10.3 Log Collection (Fluent Bit)

**File:** `gitops/observability/fluent-bit.yaml`

> 💡 **Why Fluent Bit over Fluentd?** Fluent Bit is written in C (vs Ruby for Fluentd) and uses ~10x less RAM—critical for Raspberry Pi.

**Comparison:**

| Feature | Fluent Bit | Fluentd |
|---------|------------|---------|
| **Language** | C | Ruby |
| **Memory** | ~10MB | ~100MB |
| **CPU** | Minimal | Moderate |
| **Plugins** | 70+ built-in | 1000+ plugins |
| **Use Case** | Edge/IoT | Enterprise |
| **RPi Suitability** | ✅ Excellent | ⚠️ Heavy |

**Pipeline Configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `OUTPUT.Name` | loki | Send logs to Loki |
| `OUTPUT.Host` | loki-stack.monitoring.svc | Internal service DNS |
| `OUTPUT.Labels` | job=fluent-bit | Label for Loki queries |

<details>
<summary>📄 Click to expand full gitops/observability/fluent-bit.yaml</summary>

```yaml
# =============================================================================
# Fluent Bit - Lightweight Log Collector
# =============================================================================
# Alternative to Promtail with lower memory footprint.
# Written in C, uses ~10MB RAM (vs 100MB for Fluentd).
#
# Features:
#   - Stream Processing: Filter, parse, enrich logs in-flight
#   - Multiple Outputs: Loki, Elasticsearch, S3, stdout
#   - Kubernetes Enrichment: Adds pod, namespace, node labels
#
# Input (automatic):
#   - /var/log/containers/*.log (all container logs)
#   - Kubernetes metadata injection
#
# Output:
#   - Loki via HTTP API
#
# Query in Grafana:
#   {job="fluent-bit"} |= "error"
#
# Dependencies: Loki (observability/loki-stack)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fluent-bit
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://fluent.github.io/helm-charts
    chart: fluent-bit
    targetRevision: 0.44.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Resource Limits (very lightweight)
        # -------------------------------------------------------------------
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 64Mi
        
        # -------------------------------------------------------------------
        # Pipeline Configuration
        # -------------------------------------------------------------------
        config:
          # Service settings
          service: |
            [SERVICE]
                Flush         5
                Log_Level     info
                Daemon        off
                Parsers_File  parsers.conf
                HTTP_Server   On
                HTTP_Listen   0.0.0.0
                HTTP_Port     2020
          
          # Input: Container logs
          inputs: |
            [INPUT]
                Name              tail
                Path              /var/log/containers/*.log
                Parser            cri
                Tag               kube.*
                Refresh_Interval  10
                Mem_Buf_Limit     5MB
                Skip_Long_Lines   On
          
          # Filter: Add Kubernetes metadata
          filters: |
            [FILTER]
                Name                kubernetes
                Match               kube.*
                Kube_URL            https://kubernetes.default.svc:443
                Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
                Merge_Log           On
                K8S-Logging.Parser  On
                K8S-Logging.Exclude On
          
          # Output: Send to Loki
          outputs: |
            [OUTPUT]
                Name   loki
                Match  *
                Host   loki-stack.monitoring.svc.cluster.local
                Port   3100
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

### 10.4 Distributed Tracing (OpenTelemetry)

**File:** `gitops/observability/opentelemetry.yaml`

OpenTelemetry is the **CNCF standard** for observability instrumentation. The Operator enables automatic trace injection into applications.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPENTELEMETRY TRACING FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                        APPLICATION POD                                │ │
│  │  ┌─────────────────┐     ┌─────────────────────────────────────────┐ │ │
│  │  │   Your App      │────►│  OTel Sidecar (auto-injected)           │ │ │
│  │  │  (instrumented) │     │  - Collects spans                       │ │ │
│  │  │                 │     │  - Batches traces                       │ │ │
│  │  └─────────────────┘     │  - Exports to collector                 │ │ │
│  │                          └────────────────────┬────────────────────┘ │ │
│  └───────────────────────────────────────────────┼───────────────────────┘ │
│                                                  │                          │
│                                                  ▼                          │
│                          ┌───────────────────────────────────────────┐     │
│                          │      OpenTelemetry Collector              │     │
│                          │  - Receives traces from all apps          │     │
│                          │  - Processes and transforms               │     │
│                          │  - Exports to Jaeger                      │     │
│                          └───────────────────────┬───────────────────┘     │
│                                                  │                          │
│                                                  ▼                          │
│                          ┌───────────────────────────────────────────┐     │
│                          │           Jaeger Backend                  │     │
│                          │      (Storage + Query + UI)               │     │
│                          └───────────────────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why OpenTelemetry?**

| Feature | Benefit |
|---------|---------|
| **Vendor Neutral** | Export to Jaeger, Zipkin, Datadog, etc. |
| **Auto-Instrumentation** | No code changes for many languages |
| **CNCF Standard** | Industry-wide adoption |
| **Unified** | Traces + Metrics + Logs in one SDK |

<details>
<summary>📄 Click to expand full gitops/observability/opentelemetry.yaml</summary>

```yaml
# =============================================================================
# OpenTelemetry Operator - Distributed Tracing Infrastructure
# =============================================================================
# Installs the OpenTelemetry Operator which enables:
#   - Automatic sidecar injection for trace collection
#   - OpenTelemetryCollector CRD for deploying collectors
#   - Instrumentation CRD for auto-instrumentation
#
# Auto-Instrumentation Languages:
#   - Java, Python, Node.js, .NET, Go
#
# Usage:
#   1. Create an Instrumentation resource
#   2. Add annotation to pods: instrumentation.opentelemetry.io/inject-java: "true"
#   3. Traces automatically sent to Jaeger
#
# Dependencies: Jaeger (for trace storage/visualization)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opentelemetry-operator
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
    chart: opentelemetry-operator
    targetRevision: 0.49.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Manager (Operator) Resources
        # -------------------------------------------------------------------
        manager:
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 50m
              memory: 64Mi
        
        # -------------------------------------------------------------------
        # Admission Webhooks
        # -------------------------------------------------------------------
        admissionWebhooks:
          certManager:
            enabled: false  # We use self-signed certs
          autoGenerateCert:
            enabled: true
  
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

</details>

### 10.5 Tracing Backend (Jaeger)

**File:** `gitops/observability/jaeger.yaml`

Jaeger provides the UI to visualize distributed traces collected by OpenTelemetry.

> ⚠️ **RPi Optimization:** We use in-memory storage instead of Elasticsearch/Cassandra to conserve resources. Traces are limited to 1000 to prevent OOM.

**Storage Options:**

| Backend | Memory | RPi Suitable | Persistence |
|---------|--------|--------------|-------------|
| **Memory** | 512MB | ✅ Yes | ❌ No |
| Elasticsearch | 2GB+ | ❌ No | ✅ Yes |
| Cassandra | 4GB+ | ❌ No | ✅ Yes |
| Badger (local) | 256MB | ⚠️ Limited | ✅ Yes |

**Access:**

| Endpoint | URL |
|----------|-----|
| Jaeger UI | http://jaeger.192.168.0.210.nip.io |
| Query API | http://jaeger.192.168.0.210.nip.io/api |

<details>
<summary>📄 Click to expand full gitops/observability/jaeger.yaml</summary>

```yaml
# =============================================================================
# Jaeger - Distributed Tracing Backend
# =============================================================================
# Provides trace storage, query engine, and web UI for visualizing
# request flows across microservices.
#
# Configuration (RPi optimized):
#   - All-in-One deployment (collector + query + agent in one pod)
#   - In-memory storage (no external DB required)
#   - Max 1000 traces to prevent OOM
#
# Features:
#   - Service dependency graph
#   - Trace comparison
#   - Latency histograms
#   - Error tracking
#
# Access: http://jaeger.192.168.0.210.nip.io
#
# Dependencies: OpenTelemetry Operator (for auto-instrumentation)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jaeger
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://jaegertracing.github.io/helm-charts
    chart: jaeger
    targetRevision: 3.0.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Disable External Data Stores (use in-memory)
        # -------------------------------------------------------------------
        provisionDataStore:
          cassandra: false
          elasticsearch: false
          kafka: false
        
        # -------------------------------------------------------------------
        # All-in-One Deployment
        # -------------------------------------------------------------------
        allInOne:
          enabled: true
          # Limit in-memory traces to prevent OOM
          args:
            - "--memory.max-traces=1000"
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
        
        # -------------------------------------------------------------------
        # Storage Configuration
        # -------------------------------------------------------------------
        storage:
          type: memory
        
        # -------------------------------------------------------------------
        # Disable Legacy Ingress (we use Gateway API HTTPRoute)
        # -------------------------------------------------------------------
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
# =============================================================================
# HTTPRoute for Jaeger UI (Gateway API)
# =============================================================================
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

### 10.6 Traffic Analysis (Kubeshark)

**File:** `gitops/observability/kubeshark.yaml`

Kubeshark provides **real-time API traffic analysis**—like Wireshark but for Kubernetes. It captures and decodes HTTP, gRPC, GraphQL, and other protocols.

> ⚠️ **Resource Warning:** Kubeshark can consume significant memory when capturing traffic. Disable when not actively debugging.

**Capabilities:**

| Feature | Description |
|---------|-------------|
| **Protocol Decoding** | HTTP/1.1, HTTP/2, gRPC, GraphQL, Kafka, Redis |
| **Real-time Capture** | Live traffic view with filters |
| **Service Map** | Visual service dependency graph |
| **Traffic Replay** | Re-send captured requests |
| **Query Language** | Filter by pod, namespace, method, status |

**Query Examples:**

```text
# All traffic to a specific service
request.namespace == "default" and request.name == "my-service"

# All 5xx errors
response.status >= 500

# Slow requests (>1s)
response.latency > 1000
```

<details>
<summary>📄 Click to expand full gitops/observability/kubeshark.yaml</summary>

```yaml
# =============================================================================
# Kubeshark - API Traffic Analyzer
# =============================================================================
# Real-time visibility into Kubernetes API traffic.
# Like Wireshark, but for microservices communication.
#
# Features:
#   - Protocol decoding (HTTP, gRPC, GraphQL, Kafka, Redis)
#   - Real-time traffic capture
#   - Service dependency visualization
#   - Traffic replay for debugging
#
# Access: Port-forward to Kubeshark UI
#   kubectl port-forward -n observability svc/kubeshark-hub 8899:80
#   Open: http://localhost:8899
#
# WARNING: High memory usage during capture. Disable when not debugging.
#
# Dependencies: Longhorn (for persistent storage)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeshark
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://helm.kubeshark.co
    chart: kubeshark
    targetRevision: 52.3.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # Traffic Capture Settings
        # -------------------------------------------------------------------
        tap:
          # Persistent storage for captured traffic
          persistentStorage: true
          storageClass: longhorn
          storageSize: 5Gi
          
          # Resource limits (RPi optimized)
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
        
        # -------------------------------------------------------------------
        # Hub (UI Server)
        # -------------------------------------------------------------------
        hub:
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
  
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

### 10.7 Cost Management (OpenCost)

**File:** `gitops/observability/opencost.yaml`

OpenCost calculates resource consumption (CPU/RAM/Storage) per namespace/pod and estimates equivalent cloud costs. Essential for understanding which workloads are consuming your Raspberry Pi resources.

**Cost Model:**

| Resource | Default Rate | Customizable |
|----------|--------------|--------------|
| CPU | $0.031/hour | Yes |
| Memory | $0.004/GB/hour | Yes |
| Storage | $0.0425/GB/month | Yes |
| Network | $0.00/GB | Yes |

**Insights Provided:**

| View | Purpose |
|------|---------|
| **Namespace** | Cost breakdown by namespace |
| **Deployment** | Per-deployment resource usage |
| **Pod** | Individual pod costs |
| **Efficiency** | Idle vs utilized resources |

**Access:** http://opencost.192.168.0.210.nip.io

<details>
<summary>📄 Click to expand full gitops/observability/opencost.yaml</summary>

```yaml
# =============================================================================
# OpenCost - Resource Cost Estimation
# =============================================================================
# Calculates resource consumption and estimates cloud-equivalent costs.
# Useful for understanding which namespaces/pods consume the most resources.
#
# Features:
#   - Per-namespace cost breakdown
#   - Per-pod resource consumption
#   - Efficiency metrics (idle vs used)
#   - Prometheus integration
#
# Access: http://opencost.192.168.0.210.nip.io
#
# Cost Model (customizable):
#   - CPU: $0.031/hour
#   - Memory: $0.004/GB/hour
#   - Storage: $0.0425/GB/month
#
# Dependencies: Prometheus (observability/kube-prometheus-stack)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opencost
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://opencost.github.io/opencost-helm-chart
    chart: opencost
    targetRevision: 1.29.0
    helm:
      values: |
        # -------------------------------------------------------------------
        # OpenCost Configuration
        # -------------------------------------------------------------------
        opencost:
          exporter:
            # Cluster identifier
            defaultClusterId: "rpi-cluster"
            
            # Resource limits
            resources:
              requests:
                cpu: 10m
                memory: 32Mi
              limits:
                cpu: 100m
                memory: 64Mi
          
          # Prometheus data source
          prometheus:
            external:
              url: "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
          
          # UI resources
          ui:
            resources:
              requests:
                cpu: 10m
                memory: 32Mi
              limits:
                cpu: 100m
                memory: 64Mi
        
        # -------------------------------------------------------------------
        # Disable Legacy Ingress (we use Gateway API HTTPRoute)
        # -------------------------------------------------------------------
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
# =============================================================================
# HTTPRoute for OpenCost UI (Gateway API)
# =============================================================================
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

### 10.8 AI Diagnostics (K8sGPT)

**File:** `gitops/observability/k8sgpt.yaml`

K8sGPT scans your cluster for issues (CrashLoops, PVC failures, Service misconfigs) and uses AI to explain fixes in plain English.

**Analyzers:**

| Analyzer | Detects |
|----------|---------|
| **Pod** | CrashLoopBackOff, OOMKilled, ImagePullErrors |
| **Service** | Missing endpoints, selector mismatches |
| **PVC** | Pending claims, storage class issues |
| **Ingress** | Missing backends, invalid paths |
| **NetworkPolicy** | Blocked traffic patterns |
| **HPA** | Scaling issues, metric unavailability |

**AI Backend Options:**

| Provider | Free | Notes |
|----------|------|-------|
| **OpenAI** | No | Requires API key, best quality |
| **LocalAI** | Yes | Self-hosted, requires more resources |
| **Ollama** | Yes | Run models locally |
| **AzureOpenAI** | No | Enterprise option |

> 💡 **Note:** Replace `YOUR_OPENAI_TOKEN` with your actual API key, or use OpenBao for secrets management.

<details>
<summary>📄 Click to expand full gitops/observability/k8sgpt.yaml</summary>

```yaml
# =============================================================================
# K8sGPT - AI-Powered Kubernetes Diagnostics
# =============================================================================
# Scans cluster for issues and provides AI-generated explanations and fixes.
#
# Analyzers:
#   - Pod: CrashLoopBackOff, OOMKilled, ImagePullErrors
#   - Service: Missing endpoints, selector mismatches
#   - PVC: Pending claims, storage class issues
#   - Ingress: Missing backends, invalid paths
#   - NetworkPolicy: Blocked traffic patterns
#
# Usage (CLI):
#   kubectl get results -n observability    # View scan results
#   k8sgpt analyze                          # Run manual scan
#
# AI Backend Configuration:
#   Create secret with OpenAI key or configure LocalAI
#   kubectl create secret generic k8sgpt-secret \
#     --from-literal=openai-api-key=YOUR_KEY -n observability
#
# Dependencies: None (but AI features need backend configuration)
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8sgpt
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.k8sgpt.ai/
    chart: k8sgpt-operator
    targetRevision: 0.1.4
    helm:
      values: |
        # -------------------------------------------------------------------
        # Operator Configuration
        # -------------------------------------------------------------------
        controllerManager:
          manager:
            resources:
              limits:
                cpu: 200m
                memory: 128Mi
              requests:
                cpu: 10m
                memory: 64Mi
  
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

### 10.9 Observability Verification Script

**File:** `tests/05_observability_test.sh`

This script verifies data flows through all observability pipelines.

**Test Coverage:**

| Test | Component | Verification |
|------|-----------|--------------|
| Loki | Log Storage | Pod running, can query logs |
| Fluent Bit | Log Collection | DaemonSet running on all nodes |
| Jaeger | Tracing | UI accessible |
| OpenCost | Cost Analysis | UI accessible, data from Prometheus |
| K8sGPT | AI Diagnostics | Operator running |
| Kubeshark | Traffic Analysis | Hub pod running |

<details>
<summary>📄 Click to expand full tests/05_observability_test.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# Phase 6 Advanced Observability Verification Test
# =============================================================================
# Verifies all observability components deployed in Phase 6:
#   - Loki Stack (log aggregation)
#   - Fluent Bit (log collection)
#   - OpenTelemetry (trace collection)
#   - Jaeger (trace visualization)
#   - OpenCost (cost estimation)
#   - K8sGPT (AI diagnostics)
#   - Kubeshark (traffic analysis)
#
# Prerequisites:
#   - Phase 6 components deployed
#   - kubectl configured for the cluster
#
# Usage: bash tests/05_observability_test.sh
# =============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║       PHASE 6: ADVANCED OBSERVABILITY VERIFICATION                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
pass() {
    echo "✅ $1"
    ((TESTS_PASSED++))
}

fail() {
    echo "❌ $1"
    ((TESTS_FAILED++))
}

warn() {
    echo "⚠️  $1"
    ((TESTS_WARNED++))
}

# -----------------------------------------------------------------------------
# Test 1: Loki Log Aggregation
# -----------------------------------------------------------------------------
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 1: Loki Log Aggregation                                        │"
echo "└─────────────────────────────────────────────────────────────────────┘"

LOKI_PODS=$(kubectl get pods -n monitoring -l app=loki --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$LOKI_PODS" -ge 1 ]; then
    pass "Loki is running ($LOKI_PODS pods)"
else
    fail "Loki not running"
fi

# -----------------------------------------------------------------------------
# Test 2: Promtail Log Collection
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 2: Promtail Log Collection                                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"

PROMTAIL_PODS=$(kubectl get pods -n monitoring -l app=promtail --no-headers 2>/dev/null | grep -c "Running" || echo "0")
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$PROMTAIL_PODS" -ge "$NODE_COUNT" ]; then
    pass "Promtail running on all nodes ($PROMTAIL_PODS/$NODE_COUNT)"
else
    warn "Promtail not on all nodes ($PROMTAIL_PODS/$NODE_COUNT)"
fi

# -----------------------------------------------------------------------------
# Test 3: Fluent Bit (Alternative Collector)
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 3: Fluent Bit Log Collector                                    │"
echo "└─────────────────────────────────────────────────────────────────────┘"

FLUENTBIT_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$FLUENTBIT_PODS" -ge 1 ]; then
    pass "Fluent Bit running ($FLUENTBIT_PODS pods)"
else
    warn "Fluent Bit not running (using Promtail instead)"
fi

# -----------------------------------------------------------------------------
# Test 4: OpenTelemetry Operator
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 4: OpenTelemetry Operator                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

OTEL_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$OTEL_PODS" -ge 1 ]; then
    pass "OpenTelemetry Operator running"
else
    fail "OpenTelemetry Operator not running"
fi

# -----------------------------------------------------------------------------
# Test 5: Jaeger Tracing Backend
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 5: Jaeger Tracing Backend                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

JAEGER_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$JAEGER_PODS" -ge 1 ]; then
    pass "Jaeger is running"
    
    # Check UI accessibility
    JAEGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://jaeger.192.168.0.210.nip.io 2>/dev/null || echo "000")
    if [ "$JAEGER_STATUS" == "200" ]; then
        echo "  ✅ Jaeger UI accessible"
    else
        echo "  ⚠️  Jaeger UI not accessible (HTTP $JAEGER_STATUS)"
    fi
else
    fail "Jaeger not running"
fi

# -----------------------------------------------------------------------------
# Test 6: OpenCost
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 6: OpenCost Cost Analysis                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

OPENCOST_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=opencost --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$OPENCOST_PODS" -ge 1 ]; then
    pass "OpenCost is running"
    
    # Check UI accessibility
    OPENCOST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://opencost.192.168.0.210.nip.io 2>/dev/null || echo "000")
    if [ "$OPENCOST_STATUS" == "200" ]; then
        echo "  ✅ OpenCost UI accessible"
    else
        echo "  ⚠️  OpenCost UI not accessible (HTTP $OPENCOST_STATUS)"
    fi
else
    fail "OpenCost not running"
fi

# -----------------------------------------------------------------------------
# Test 7: K8sGPT Operator
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 7: K8sGPT AI Diagnostics                                       │"
echo "└─────────────────────────────────────────────────────────────────────┘"

K8SGPT_PODS=$(kubectl get pods -n observability -l app.kubernetes.io/name=k8sgpt-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$K8SGPT_PODS" -ge 1 ]; then
    pass "K8sGPT Operator running"
else
    warn "K8sGPT Operator not running"
fi

# -----------------------------------------------------------------------------
# Test 8: Kubeshark Traffic Analysis
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 8: Kubeshark Traffic Analysis                                  │"
echo "└─────────────────────────────────────────────────────────────────────┘"

KUBESHARK_PODS=$(kubectl get pods -n observability -l app.kubernetes.io/name=kubeshark --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$KUBESHARK_PODS" -ge 1 ]; then
    pass "Kubeshark is running ($KUBESHARK_PODS pods)"
else
    warn "Kubeshark not running (optional - high memory usage)"
fi

# -----------------------------------------------------------------------------
# Test 9: Data Flow Verification
# -----------------------------------------------------------------------------
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ Test 9: Data Flow Verification                                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"

echo "  Checking Prometheus scrape targets..."
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
PF_PID=$!
sleep 3
UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
kill $PF_PID 2>/dev/null || true

if [ "$UP_TARGETS" -gt 0 ]; then
    pass "Prometheus scraping $UP_TARGETS targets"
else
    warn "Could not verify Prometheus targets"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION SUMMARY                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Tests Passed:  $TESTS_PASSED"
echo "  Tests Failed:  $TESTS_FAILED"
echo "  Warnings:      $TESTS_WARNED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "  ✅ Phase 6 Advanced Observability verification complete!"
    echo ""
    echo "Access URLs:"
    echo "  • Grafana (Logs):  http://grafana.192.168.0.210.nip.io → Explore → Loki"
    echo "  • Jaeger (Traces): http://jaeger.192.168.0.210.nip.io"
    echo "  • OpenCost:        http://opencost.192.168.0.210.nip.io"
    echo ""
    echo "Port-forward for Kubeshark:"
    echo "  kubectl port-forward -n observability svc/kubeshark-hub 8899:80"
    exit 0
else
    echo "  ❌ Some tests failed. Check component status above."
    exit 1
fi
```

</details>

### 10.10 Phase 6 Execution Steps

Execute these steps after Phase 5 (Security & Management) is complete.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 6 EXECUTION CHECKLIST                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  □ Step 1: Verify Phase 5 MinIO is running (required for Loki storage)     │
│  □ Step 2: Commit observability files to Git                               │
│  □ Step 3: Wait for ArgoCD to sync applications                            │
│  □ Step 4: Configure Grafana data sources                                  │
│  □ Step 5: Run verification script                                         │
│  □ Step 6: (Optional) Configure K8sGPT AI backend                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Step 1: Verify Prerequisites**

```bash
# Ensure MinIO is running (Loki needs S3 storage)
kubectl get pods -n storage -l app=minio
# Expected: minio pod Running

# Ensure Prometheus is running (OpenCost needs metrics)
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
# Expected: prometheus pods Running
```

**Step 2: Commit and Push**

```bash
cd /path/to/your/repo
git add gitops/observability/
git commit -m "Add Phase 6: Advanced Observability stack"
git push origin main
```

**Step 3: Monitor ArgoCD Sync**

```bash
# Watch all applications sync
kubectl get applications -n argocd -w

# Check specific application
kubectl describe application -n argocd loki-stack
```

**Step 4: Configure Grafana Data Sources**

After Loki is running, add it as a data source in Grafana:

1. Open Grafana: http://grafana.192.168.0.210.nip.io
2. Navigate to: **Configuration → Data Sources → Add data source**
3. Select: **Loki**
4. Configure:
   - URL: `http://loki-stack:3100`
   - Click **Save & Test**

**Step 5: Run Verification Script**

```bash
bash tests/05_observability_test.sh
```

**Step 6: (Optional) Configure K8sGPT**

To enable AI-powered diagnostics, create an OpenAI API key secret:

```bash
kubectl create secret generic k8sgpt-secret \
  --from-literal=openai-api-key=sk-your-actual-key-here \
  -n observability
```

**Phase 6 Access URLs:**

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana (Logs) | http://grafana.192.168.0.210.nip.io | Log Explorer with Loki |
| Jaeger | http://jaeger.192.168.0.210.nip.io | Distributed tracing UI |
| OpenCost | http://opencost.192.168.0.210.nip.io | Cost estimation dashboard |

**Port-Forward Commands:**

```bash
# Kubeshark (traffic analysis)
kubectl port-forward -n observability svc/kubeshark-hub 8899:80
# Open: http://localhost:8899

# K8sGPT Results (if using CLI)
kubectl get results -n observability
```

**Sample LogQL Queries for Grafana:**

| Query | Purpose |
|-------|---------|
| `{namespace="argocd"}` | All ArgoCD logs |
| `{pod=~"prometheus.*"}` | Prometheus pod logs |
| `{namespace="monitoring"} \|= "error"` | Errors in monitoring |
| `{namespace="security"} \| json` | Parsed JSON logs from security namespace |

**Troubleshooting:**

| Issue | Solution |
|-------|----------|
| Loki not receiving logs | Check Promtail pods: `kubectl logs -n monitoring -l app=promtail` |
| OpenCost shows no data | Verify Prometheus is accessible from OpenCost namespace |
| Jaeger empty | Applications need OpenTelemetry instrumentation |
| K8sGPT no results | Configure AI backend secret |

## 11. Phase 7: CI/CD & Developer Experience

In this final phase, we establish the machinery that builds, tests, and releases code. We replace manual `docker build` commands with an automated pipeline and ensure every change is scanned for security vulnerabilities before reaching production.

### CI/CD Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                          COMPLETE CI/CD PIPELINE FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  DEVELOPER                    EVENT-DRIVEN PIPELINE                    GITOPS DEPLOY   │
│  ─────────                    ─────────────────────                    ────────────────│
│                                                                                         │
│  ┌─────────┐    git push    ┌─────────────┐                                            │
│  │ Skaffold│───────────────▶│   Gitea     │                                            │
│  │ (local) │                │ Git Server  │                                            │
│  └─────────┘                └──────┬──────┘                                            │
│       │                           │                                                    │
│       │ dev mode                  │ webhook                                            │
│       │ (hot reload)              ▼                                                    │
│       │                    ┌─────────────┐     ┌──────────────┐                        │
│       │                    │Argo Events  │────▶│ EventBus     │                        │
│       │                    │  (Webhook)  │     │ (Jetstream)  │                        │
│       │                    └─────────────┘     └──────┬───────┘                        │
│       │                                               │                                │
│       │                                               │ trigger                        │
│       │                                               ▼                                │
│       │                                        ┌─────────────┐                         │
│       │                                        │Argo Events  │                         │
│       │                                        │  (Sensor)   │                         │
│       │                                        └──────┬──────┘                         │
│       │                                               │                                │
│       │                                               │ create workflow                │
│       │                                               ▼                                │
│  ┌────┴────────────────────────────────────────────────────────────────────────┐       │
│  │                         ARGO WORKFLOWS PIPELINE                             │       │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │       │
│  │  │  Clone   │──▶│  Build   │──▶│  Test    │──▶│  Scan    │──▶│  Push    │  │       │
│  │  │   Repo   │   │  Image   │   │  (Unit)  │   │ (Trivy)  │   │ (Harbor) │  │       │
│  │  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘  │       │
│  │       │                                              │             │        │       │
│  │       ▼                                              ▼             ▼        │       │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │       │
│  │  │                      MinIO (Artifact Storage)                        │  │       │
│  │  │    Logs • Build Cache • Test Results • Security Reports • Binaries   │  │       │
│  │  └──────────────────────────────────────────────────────────────────────┘  │       │
│  └─────────────────────────────────────────────────────────────────────────────┘       │
│                                               │                                        │
│                                               │ new image tag                          │
│                                               ▼                                        │
│                                        ┌─────────────┐                                 │
│                                        │   Harbor    │                                 │
│                                        │  Registry   │                                 │
│                                        └──────┬──────┘                                 │
│                                               │                                        │
│                                               │ watches registry                       │
│                                               ▼                                        │
│                                    ┌───────────────────┐                               │
│                                    │ Argo Image        │                               │
│                                    │ Updater           │                               │
│                                    └─────────┬─────────┘                               │
│                                              │                                         │
│                                              │ updates git                             │
│                                              ▼                                         │
│                                        ┌─────────────┐                                 │
│                                        │   Gitea     │◀───────────────────────┐        │
│                                        │ (GitOps)    │                        │        │
│                                        └──────┬──────┘                        │        │
│                                               │                               │        │
│                                               │ sync                          │        │
│                                               ▼                               │        │
│                                        ┌─────────────┐   manifest changes     │        │
│                                        │   ArgoCD    │────────────────────────┘        │
│                                        │             │                                 │
│                                        └──────┬──────┘                                 │
│                                               │                                        │
│                                               │ deploy                                 │
│                                               ▼                                        │
│                                  ┌─────────────────────────┐                           │
│                                  │     Kubernetes          │                           │
│                                  │   (Production Pods)     │                           │
│                                  └─────────────────────────┘                           │
│                                                                                        │
│  SECURITY LAYER (Continuous Scanning)                                                  │
│  ─────────────────────────────────────                                                 │
│  ┌────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         TRIVY OPERATOR                                         │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                 │   │
│  │  │ VulnerabilityRpt│  │ ConfigAuditRpt  │  │ ExposedSecretRpt│                 │   │
│  │  │  (Image CVEs)   │  │ (Misconfig)     │  │ (Leaked Secrets)│                 │   │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                 │   │
│  │           │                    │                    │                          │   │
│  │           └────────────────────┼────────────────────┘                          │   │
│  │                                ▼                                               │   │
│  │                    ┌─────────────────────┐                                     │   │
│  │                    │   Prometheus        │──▶ Grafana Dashboards               │   │
│  │                    │   (Metrics)         │──▶ Alert Manager                    │   │
│  │                    └─────────────────────┘                                     │   │
│  └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### CI/CD Component Stack

| Component | Version | Purpose | Memory | ARM64 |
|-----------|---------|---------|--------|-------|
| **Argo Workflows** | 0.41.0 | Kubernetes-native CI engine | ~150MB | ✅ |
| **Argo Events** | 2.4.0 | Event-driven workflow triggers | ~100MB | ✅ |
| **Argo Image Updater** | 0.9.1 | Automatic image tag updates | ~50MB | ✅ |
| **Trivy Operator** | 0.19.1 | Runtime security scanning | ~100MB | ✅ |
| **Skaffold** | Latest | Local development workflow | Local | ✅ |

### Why This CI/CD Stack?

| Alternative | Why We Chose Argo |
|------------|-------------------|
| **Jenkins** | Heavy JVM footprint (~1GB+), complex plugin management, not cloud-native |
| **GitLab CI** | Requires GitLab server, heavy resource usage |
| **GitHub Actions** | Cloud-based, not self-hosted on Pi (unless using runners) |
| **Tekton** | More complex CRD model, steeper learning curve |
| **Drone CI** | Good alternative, but Argo has better ecosystem integration |

**Argo Benefits:**
- Native Kubernetes integration (Workflows run as Pods)
- DAG-based pipeline definitions
- Shared ecosystem with ArgoCD
- Excellent UI for workflow visualization
- MinIO integration for artifact storage

---

### 11.1 Image Automation (Argo Image Updater)
**File:** `gitops/cicd/argo-image-updater.yaml`

This component watches your **Harbor** registry. When a CI pipeline pushes a new image tag (e.g., `v1.0.1`), this tool automatically updates the Git repository (modifying the ArgoCD Application) to reflect the new version—completing the **GitOps loop**.

#### How Image Updater Works

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     IMAGE UPDATER AUTOMATION FLOW                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                      HARBOR REGISTRY                                   │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │  │
│  │  │ my-app:v1.0 │ │ my-app:v1.1 │ │ my-app:v1.2 │ │ my-app:v1.3 │      │  │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └──────┬──────┘      │  │
│  └────────────────────────────────────────────────────────│──────────────┘  │
│                                                           │ NEW TAG!        │
│                                                           ▼                 │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                     ARGO IMAGE UPDATER                                 │  │
│  │                                                                        │  │
│  │  1. Poll Harbor every 2 minutes                                        │  │
│  │  2. Detect new tag v1.3 (semver strategy)                             │  │
│  │  3. Update Git repository with new image tag                          │  │
│  │  4. Commit: "chore: update my-app to v1.3"                            │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────┬───────────────┘  │
│                                                           │                 │
│                                                           │ git commit      │
│                                                           ▼                 │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                         GITEA REPOSITORY                               │  │
│  │                                                                        │  │
│  │  gitops/apps/my-app.yaml:                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────┐     │  │
│  │  │  spec:                                                        │     │  │
│  │  │    source:                                                    │     │  │
│  │  │      helm:                                                    │     │  │
│  │  │        parameters:                                            │     │  │
│  │  │        - name: image.tag                                      │     │  │
│  │  │          value: "v1.3"  ◀── UPDATED AUTOMATICALLY             │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────┬───────────────┘  │
│                                                           │                 │
│                                                           │ sync            │
│                                                           ▼                 │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                           ARGOCD                                       │  │
│  │                                                                        │  │
│  │  Detects drift → Syncs → Deploys new version                          │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### Image Update Strategies

| Strategy | Example | Use Case |
|----------|---------|----------|
| **semver** | `~1.0` matches 1.0.x | Production releases |
| **latest** | Always newest | Dev environments |
| **digest** | SHA-based | Immutable deployments |
| **name** | Alphabetical sort | Custom naming schemes |

<details>
<summary>📄 Click to expand full gitops/cicd/argo-image-updater.yaml</summary>

```yaml
# ============================================================================
# ARGO IMAGE UPDATER - Automated Image Tag Management
# ============================================================================
# Component: Argo Image Updater v0.9.1
# Purpose: Watches Harbor registry for new image tags and automatically
#          updates Git repository to trigger GitOps deployments
# Dependencies: ArgoCD, Harbor registry, Git repository access
# ============================================================================
#
# ARCHITECTURE:
#   Harbor Registry ──▶ Image Updater ──▶ Git Commit ──▶ ArgoCD Sync
#
# UPDATE STRATEGIES:
#   - semver: Semantic versioning (recommended for production)
#   - latest: Always use the newest tag
#   - digest: Update based on SHA digest changes
#   - name: Alphabetical sorting
#
# RESOURCE USAGE (ARM64):
#   - Memory: ~50MB
#   - CPU: Minimal (polling-based)
#
# ============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-image-updater
  namespace: argocd
  labels:
    app.kubernetes.io/component: image-automation
    app.kubernetes.io/part-of: cicd-pipeline
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argocd-image-updater
    targetRevision: 0.9.1
    helm:
      values: |
        # ──────────────────────────────────────────────────────────────────────
        # REGISTRY CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        config:
          registries:
            # Harbor private registry
            - name: harbor.192.168.0.210.nip.io
              api_url: https://harbor.192.168.0.210.nip.io
              prefix: harbor.192.168.0.210.nip.io/library
              ping: yes
              # Allow self-signed certificates (home lab)
              insecure: yes
              # Credentials stored in argocd namespace
              # Create: kubectl create secret generic harbor-creds \
              #         --from-literal=username=admin \
              #         --from-literal=password=<harbor-password> \
              #         -n argocd
              credentials: secret:argocd/harbor-creds#password
          
          # Application configuration (annotations on ArgoCD Applications)
          # Example annotations for your app:
          #   argocd-image-updater.argoproj.io/image-list: myapp=harbor.192.168.0.210.nip.io/library/myapp
          #   argocd-image-updater.argoproj.io/myapp.update-strategy: semver
          #   argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
          #   argocd-image-updater.argoproj.io/write-back-method: git

        # ──────────────────────────────────────────────────────────────────────
        # RESOURCE LIMITS (ARM64 Optimized)
        # ──────────────────────────────────────────────────────────────────────
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "128Mi"
            cpu: "100m"

        # ──────────────────────────────────────────────────────────────────────
        # POLLING CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        # Check for new images every 2 minutes
        # Adjust based on CI frequency and Harbor load
        extraArgs:
          - --interval=2m
          - --loglevel=info

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

* **UI:** Exposed via Gateway API HTTPRoute
* **Persistence:** Uses MinIO (S3) to store build artifacts (logs, compiled binaries)
* **Executor:** Uses `pns` (Process Namespace Sharing) for efficiency on Raspberry Pi

#### Workflow Execution Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                        ARGO WORKFLOWS INTERNALS                                │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  USER/TRIGGER                                                                  │
│       │                                                                        │
│       │ submit workflow                                                        │
│       ▼                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    WORKFLOW CONTROLLER                                   │  │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │  │
│  │  │ Workflow CRD  │  │  DAG Engine   │  │ Pod Scheduler │               │  │
│  │  │   Parser      │  │  (Steps/DAG)  │  │               │               │  │
│  │  └───────────────┘  └───────────────┘  └───────────────┘               │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│                                      │ creates pods                           │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    WORKFLOW EXECUTION (DAG)                              │  │
│  │                                                                          │  │
│  │    ┌─────────┐                                                          │  │
│  │    │  Clone  │─────────────────────────────────────────┐                │  │
│  │    │  Repo   │                                         │                │  │
│  │    └────┬────┘                                         │                │  │
│  │         │                                              │                │  │
│  │         ▼                                              ▼                │  │
│  │    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐           │  │
│  │    │  Lint   │    │  Build  │    │ Security│    │  Test   │           │  │
│  │    │  Code   │    │  Image  │    │  Scan   │    │  Unit   │           │  │
│  │    └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘           │  │
│  │         │              │              │              │                │  │
│  │         └──────────────┴──────────────┴──────────────┘                │  │
│  │                                       │                                │  │
│  │                                       ▼                                │  │
│  │                              ┌─────────────┐                           │  │
│  │                              │    Push     │                           │  │
│  │                              │   Harbor    │                           │  │
│  │                              └─────────────┘                           │  │
│  │                                                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│                                      │ store artifacts                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                          MinIO S3 STORAGE                                │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │  │
│  │  │ Build Logs   │ │ Test Results │ │ Scan Reports │ │   Binaries   │   │  │
│  │  │   /logs/     │ │   /tests/    │ │ /security/   │ │  /outputs/   │   │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  UI ACCESS (workflows.192.168.0.210.nip.io)                                    │
│  ─────────────────────────────────────────                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│  │  │  Workflow   │  │    Live     │  │  Artifact   │  │    Logs     │    │  │
│  │  │   List      │  │  DAG View   │  │   Browser   │  │   Stream    │    │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

#### Executor Comparison

| Executor | Pros | Cons | Use Case |
|----------|------|------|----------|
| **pns** ✅ | Low overhead, no Docker needed | Limited capabilities | Best for Raspberry Pi |
| **emissary** | Feature-rich, no Docker daemon | Higher memory | Cloud environments |
| **docker** | Full Docker support | Requires DinD, security concerns | Legacy workflows |
| **k8sapi** | API-based, works anywhere | Slower artifact handling | Air-gapped clusters |

#### Sample Build Workflow

```yaml
# Example WorkflowTemplate for building a Go application
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: build-go-app
  namespace: argo-workflows
spec:
  entrypoint: build-and-push
  arguments:
    parameters:
    - name: repo
      value: "https://gitea.192.168.0.210.nip.io/home/my-app.git"
    - name: image
      value: "harbor.192.168.0.210.nip.io/library/my-app"
    - name: tag
      value: "latest"

  templates:
  - name: build-and-push
    dag:
      tasks:
      - name: clone
        template: git-clone
      - name: build
        template: docker-build
        dependencies: [clone]
      - name: scan
        template: trivy-scan
        dependencies: [build]
      - name: push
        template: harbor-push
        dependencies: [scan]

  - name: git-clone
    container:
      image: alpine/git:latest
      command: [git, clone, "{{workflow.parameters.repo}}", /workspace]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: docker-build
    container:
      image: gcr.io/kaniko-project/executor:latest
      args:
      - --context=/workspace
      - --destination={{workflow.parameters.image}}:{{workflow.parameters.tag}}
      - --no-push
      - --tarPath=/workspace/image.tar
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: trivy-scan
    container:
      image: aquasec/trivy:latest
      args: ["image", "--input", "/workspace/image.tar", "--severity", "HIGH,CRITICAL"]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: harbor-push
    container:
      image: gcr.io/go-containerregistry/crane:latest
      command: [crane, push, /workspace/image.tar, "{{workflow.parameters.image}}:{{workflow.parameters.tag}}"]
      volumeMounts:
      - name: workspace
        mountPath: /workspace
```

<details>
<summary>📄 Click to expand full gitops/cicd/argo-workflows.yaml</summary>

```yaml
# ============================================================================
# ARGO WORKFLOWS - Kubernetes-Native CI/CD Engine
# ============================================================================
# Component: Argo Workflows v0.41.0
# Purpose: Container-native workflow engine for CI/CD pipelines
# Dependencies: MinIO (artifact storage), Harbor (image registry)
# ============================================================================
#
# ARCHITECTURE:
#   Trigger ──▶ Workflow Controller ──▶ Pods ──▶ Artifacts (MinIO)
#
# COMPONENTS:
#   - Controller: Orchestrates workflow execution
#   - Server: Web UI and API
#   - Executor: Runs workflow steps (pns mode for ARM64)
#
# EXECUTOR MODES:
#   - pns (Process Namespace Sharing): Best for ARM64, low overhead
#   - emissary: Feature-rich, higher memory
#   - docker: Requires DinD, security concerns
#
# RESOURCE USAGE (ARM64):
#   - Controller: ~100MB
#   - Server: ~50MB
#   - Per Workflow Pod: Varies by step
#
# ============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-workflows
  namespace: argocd
  labels:
    app.kubernetes.io/component: ci-engine
    app.kubernetes.io/part-of: cicd-pipeline
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-workflows
    targetRevision: 0.41.0
    helm:
      values: |
        # ──────────────────────────────────────────────────────────────────────
        # SERVER CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        server:
          # Authentication handled by Gateway/Traefik
          # Options: server, client, sso
          extraArgs: ["--auth-mode=server"]
          
          # Disable built-in ingress - we use Gateway API HTTPRoute
          ingress:
            enabled: false
          
          # Resource limits for server component
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
            limits:
              memory: "256Mi"
              cpu: "200m"

        # ──────────────────────────────────────────────────────────────────────
        # CONTROLLER CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        controller:
          # Resource limits for controller
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
            limits:
              memory: "256Mi"
              cpu: "200m"
          
          # Default workflow settings
          workflowDefaults:
            spec:
              # TTL for completed workflows (cleanup after 1 hour)
              ttlStrategy:
                secondsAfterCompletion: 3600
                secondsAfterSuccess: 3600
                secondsAfterFailure: 86400  # Keep failed for 24h
              
              # Pod garbage collection
              podGC:
                strategy: OnPodCompletion
              
              # ────────────────────────────────────────────────────────────────
              # ARTIFACT REPOSITORY (MinIO S3)
              # ────────────────────────────────────────────────────────────────
              # All workflows use MinIO for artifact storage
              # Create bucket: mc mb minio/argo-artifacts
              artifactRepository:
                archiveLogs: true
                s3:
                  bucket: argo-artifacts
                  endpoint: minio.storage.svc.cluster.local:9000
                  insecure: true  # Internal cluster traffic
                  # Create secret:
                  # kubectl create secret generic argo-artifacts-creds \
                  #   --from-literal=accessKey=minioadmin \
                  #   --from-literal=secretKey=<minio-password> \
                  #   -n argo-workflows
                  accessKeySecret:
                    name: argo-artifacts-creds
                    key: accessKey
                  secretKeySecret:
                    name: argo-artifacts-creds
                    key: secretKey

        # ──────────────────────────────────────────────────────────────────────
        # EXECUTOR CONFIGURATION (ARM64 Optimized)
        # ──────────────────────────────────────────────────────────────────────
        # PNS executor is optimal for Raspberry Pi:
        # - No Docker daemon required
        # - Lower memory overhead
        # - Better process isolation
        useDefaultArtifactRepo: true
        executor:
          resources:
            requests:
              memory: "32Mi"
              cpu: "10m"
            limits:
              memory: "128Mi"
              cpu: "100m"

        # ──────────────────────────────────────────────────────────────────────
        # WORKFLOW ARCHIVE (Optional PostgreSQL)
        # ──────────────────────────────────────────────────────────────────────
        # Enable for workflow history persistence
        # Requires PostgreSQL database
        # artifactRepository:
        #   archiveLogs: true
        # persistence:
        #   archive: true
        #   postgresql:
        #     host: postgresql.database.svc
        #     port: 5432
        #     database: argo_workflows
        #     tableName: argo_workflows

  destination:
    server: https://kubernetes.default.svc
    namespace: argo-workflows
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# ============================================================================
# GATEWAY API HTTPROUTE - Argo Workflows UI Access
# ============================================================================
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argo-workflows-route
  namespace: argo-workflows
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "workflows.192.168.0.210.nip.io"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: argo-workflows-server
          port: 2746
```

</details>

### 11.3 Event Bus (Argo Events)

**File:** `gitops/cicd/argo-events.yaml`

Argo Events listens for external triggers (like a `git push` to your Gitea repo) and triggers an Argo Workflow.

* **EventSource:** Receives external events (webhooks, S3, Kafka, etc.)
* **Sensor:** Matches events to triggers and creates workflows
* **EventBus:** Manages the message queue (Jetstream/NATS)

#### Event-Driven Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                        ARGO EVENTS ARCHITECTURE                                │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  EXTERNAL TRIGGERS                                                             │
│  ─────────────────                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │  Gitea   │ │  Harbor  │ │   S3     │ │  Kafka   │ │   Cron   │             │
│  │ Webhook  │ │ Webhook  │ │ Events   │ │ Messages │ │ Schedule │             │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘             │
│       │            │            │            │            │                   │
│       └────────────┴────────────┴────────────┴────────────┘                   │
│                                 │                                              │
│                                 ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                       EVENT SOURCES                                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │  │
│  │  │   webhook   │  │   minio     │  │   kafka     │  │   calendar  │     │  │
│  │  │ EventSource │  │ EventSource │  │ EventSource │  │ EventSource │     │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │  │
│  └─────────│────────────────│────────────────│────────────────│────────────┘  │
│            │                │                │                │               │
│            └────────────────┴────────────────┴────────────────┘               │
│                                    │                                          │
│                                    │ publish events                           │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                         EVENT BUS (Jetstream)                           │  │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    NATS Jetstream Cluster                          │ │  │
│  │  │  ┌─────────┐    ┌─────────┐    ┌─────────┐                        │ │  │
│  │  │  │ nats-0  │◀──▶│ nats-1  │◀──▶│ nats-2  │                        │ │  │
│  │  │  └─────────┘    └─────────┘    └─────────┘                        │ │  │
│  │  │       │              │              │                              │ │  │
│  │  │       └──────────────┼──────────────┘                              │ │  │
│  │  │                      │                                             │ │  │
│  │  │              Event Persistence                                     │ │  │
│  │  │              & Delivery Guarantee                                  │ │  │
│  │  └────────────────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    │ subscribe                                │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                            SENSORS                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │  │
│  │  │                    build-pipeline-sensor                        │    │  │
│  │  │                                                                 │    │  │
│  │  │  Dependencies:                    Triggers:                     │    │  │
│  │  │  ┌─────────────────────────┐     ┌─────────────────────────┐   │    │  │
│  │  │  │ - name: git-push        │     │ - template: workflow    │   │    │  │
│  │  │  │   eventSourceName: gitea│     │   name: ci-build        │   │    │  │
│  │  │  │   eventName: push       │     │   source: inline        │   │    │  │
│  │  │  │                         │────▶│   parameters:           │   │    │  │
│  │  │  │  Filters:               │     │     repo: event.body.   │   │    │  │
│  │  │  │  - branch: main         │     │       repository.url    │   │    │  │
│  │  │  │  - path: "src/**"       │     │     branch: event.body. │   │    │  │
│  │  │  │                         │     │       ref               │   │    │  │
│  │  │  └─────────────────────────┘     └─────────────────────────┘   │    │  │
│  │  └─────────────────────────────────────────────────────────────────┘    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    │ create workflow                          │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                      ARGO WORKFLOWS                                      │  │
│  │                                                                          │  │
│  │  Workflow: ci-build-abc123                                               │  │
│  │  Status: Running                                                         │  │
│  │  Triggered By: gitea/push (commit: def456)                               │  │
│  │                                                                          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

#### Supported Event Sources

| Source | Use Case | Configuration |
|--------|----------|---------------|
| **Webhook** | Git push, Harbor scan complete | HTTP endpoint |
| **S3/MinIO** | New artifact uploaded | Bucket notifications |
| **Kafka** | Message queue events | Topic subscription |
| **Calendar** | Scheduled builds | Cron expression |
| **Resource** | K8s resource changes | Watch API |
| **SNS/SQS** | AWS events | ARN subscription |

#### Example: Gitea Webhook EventSource

```yaml
# EventSource: Receives webhooks from Gitea
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gitea-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    push:
      port: "12000"
      endpoint: /push
      method: POST
---
# Sensor: Triggers workflow on push events
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: build-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: gitea-push
      eventSourceName: gitea-webhook
      eventName: push
      filters:
        data:
          - path: ref
            type: string
            value:
              - "refs/heads/main"
  triggers:
    - template:
        name: build-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-build-
              spec:
                workflowTemplateRef:
                  name: build-go-app
          parameters:
            - src:
                dependencyName: gitea-push
                dataKey: body.repository.clone_url
              dest: spec.arguments.parameters.0.value
```

<details>
<summary>📄 Click to expand full gitops/cicd/argo-events.yaml</summary>

```yaml
# ============================================================================
# ARGO EVENTS - Event-Driven Workflow Automation
# ============================================================================
# Component: Argo Events v2.4.0
# Purpose: Listens for external events and triggers Argo Workflows
# Dependencies: Argo Workflows, NATS Jetstream (embedded)
# ============================================================================
#
# ARCHITECTURE:
#   External Event ──▶ EventSource ──▶ EventBus ──▶ Sensor ──▶ Workflow
#
# COMPONENTS:
#   - Controller: Manages EventSources, Sensors, EventBus
#   - EventSource: Receives external events (webhook, S3, etc.)
#   - Sensor: Filters events and triggers actions
#   - EventBus: Message broker (Jetstream/NATS)
#
# SUPPORTED SOURCES:
#   - Webhook: HTTP endpoints for Git, Harbor, etc.
#   - S3/MinIO: Bucket event notifications
#   - Kafka: Message queue subscriptions
#   - Calendar: Cron-scheduled triggers
#   - Resource: Kubernetes resource watchers
#
# RESOURCE USAGE (ARM64):
#   - Controller: ~80MB
#   - EventBus (3x NATS): ~150MB total
#   - EventSource: ~30MB per source
#   - Sensor: ~30MB per sensor
#
# ============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-events
  namespace: argocd
  labels:
    app.kubernetes.io/component: event-bus
    app.kubernetes.io/part-of: cicd-pipeline
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-events
    targetRevision: 2.4.0
    helm:
      values: |
        # ──────────────────────────────────────────────────────────────────────
        # CONTROLLER CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        controller:
          replicas: 1
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
            limits:
              memory: "128Mi"
              cpu: "100m"

        # ──────────────────────────────────────────────────────────────────────
        # WEBHOOK CONTROLLER
        # ──────────────────────────────────────────────────────────────────────
        # Handles incoming HTTP webhooks from Gitea, Harbor, etc.
        webhook:
          enabled: true
          replicas: 1
          resources:
            requests:
              memory: "32Mi"
              cpu: "10m"
            limits:
              memory: "64Mi"
              cpu: "50m"

        # ──────────────────────────────────────────────────────────────────────
        # EVENTBUS (JETSTREAM/NATS)
        # ──────────────────────────────────────────────────────────────────────
        # Jetstream provides persistent event storage and at-least-once delivery
        # 3 replicas for high availability (can run on all worker nodes)
        eventbus:
          replicas: 1  # Single replica for home lab (use 3 for HA)
          nats:
            native:
              replicas: 3  # NATS cluster for message persistence
              # Authentication token for NATS connections
              auth: token
              # Container security context (non-root)
              containerSecurityContext:
                runAsNonRoot: true
                runAsUser: 1000
              # Resource limits for each NATS pod
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "10m"
                limits:
                  memory: "128Mi"
                  cpu: "100m"

        # ──────────────────────────────────────────────────────────────────────
        # CONFIGS (Event Routing)
        # ──────────────────────────────────────────────────────────────────────
        # Default configurations for EventSources and Sensors
        configs:
          jetstream:
            # Stream configuration for event persistence
            streamConfig: |
              maxAge: 72h
              replicas: 1
              storage: file

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

### 11.4 Security Tooling (Trivy Operator)

**File:** `gitops/security/trivy-operator.yaml`

Rather than installing standalone scanners, we deploy the **Trivy Operator** which continuously scans the running cluster and generates Kubernetes-native security reports.

#### Security Scanning Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                      TRIVY OPERATOR SECURITY SCANNING                          │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  SCAN TRIGGERS                                                                 │
│  ─────────────                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  • New Pod Created                                                       │  │
│  │  • ConfigMap/Secret Changed                                              │  │
│  │  • Scheduled Rescan (24h default)                                        │  │
│  │  • Image Tag Updated                                                     │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                      TRIVY OPERATOR CONTROLLER                           │  │
│  │                                                                          │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            │  │
│  │  │ Vulnerability  │  │ ConfigAudit    │  │ ExposedSecret  │            │  │
│  │  │   Scanner      │  │   Scanner      │  │   Scanner      │            │  │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘            │  │
│  │          │                   │                   │                      │  │
│  └──────────│───────────────────│───────────────────│──────────────────────┘  │
│             │                   │                   │                        │
│             │                   │                   │                        │
│             ▼                   ▼                   ▼                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     SCAN JOB PODS (Ephemeral)                           │  │
│  │                                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │  │
│  │  │  scan-vulnerabilityreport-nginx-abc123                          │    │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐   │    │  │
│  │  │  │  trivy image nginx:1.25 --format json                    │   │    │  │
│  │  │  │  → Downloads vulnerability DB                            │   │    │  │
│  │  │  │  → Scans image layers                                    │   │    │  │
│  │  │  │  → Reports CVEs                                          │   │    │  │
│  │  │  └──────────────────────────────────────────────────────────┘   │    │  │
│  │  └─────────────────────────────────────────────────────────────────┘    │  │
│  │                                                                          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    │ creates CRDs                             │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     CUSTOM RESOURCE REPORTS                              │  │
│  │                                                                          │  │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │  │
│  │  │ VulnerabilityReport (per container)                                │ │  │
│  │  │ ───────────────────────────────────────────────────────────────    │ │  │
│  │  │ metadata:                                                          │ │  │
│  │  │   name: replicaset-nginx-7bf8c77b5b-nginx                          │ │  │
│  │  │   namespace: default                                               │ │  │
│  │  │ report:                                                            │ │  │
│  │  │   critical: 2                                                      │ │  │
│  │  │   high: 5                                                          │ │  │
│  │  │   medium: 12                                                       │ │  │
│  │  │   vulnerabilities:                                                 │ │  │
│  │  │   - vulnerabilityID: CVE-2023-44487                                │ │  │
│  │  │     severity: CRITICAL                                             │ │  │
│  │  │     title: HTTP/2 Rapid Reset Attack                               │ │  │
│  │  └────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                          │  │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │  │
│  │  │ ConfigAuditReport (per workload)                                   │ │  │
│  │  │ ───────────────────────────────────────────────────────────────    │ │  │
│  │  │ report:                                                            │ │  │
│  │  │   checks:                                                          │ │  │
│  │  │   - checkID: KSV001                                                │ │  │
│  │  │     severity: MEDIUM                                               │ │  │
│  │  │     title: Process can elevate its own privileges                  │ │  │
│  │  │   - checkID: KSV003                                                │ │  │
│  │  │     severity: HIGH                                                 │ │  │
│  │  │     title: Default capabilities not dropped                        │ │  │
│  │  └────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                          │  │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │  │
│  │  │ ExposedSecretReport (per container)                                │ │  │
│  │  │ ───────────────────────────────────────────────────────────────    │ │  │
│  │  │ report:                                                            │ │  │
│  │  │   secrets:                                                         │ │  │
│  │  │   - target: /app/config.yaml                                       │ │  │
│  │  │     category: AWS                                                  │ │  │
│  │  │     title: AWS Access Key ID                                       │ │  │
│  │  └────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                          │
│                                    │ scrape metrics                           │
│                                    ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                   PROMETHEUS / GRAFANA                                   │  │
│  │                                                                          │  │
│  │  Metrics:                                                                │  │
│  │  • trivy_image_vulnerabilities{severity="Critical"} 42                  │  │
│  │  • trivy_image_vulnerabilities{severity="High"} 156                     │  │
│  │  • trivy_configauditreport_danger_count 8                               │  │
│  │                                                                          │  │
│  │  Alerts:                                                                 │  │
│  │  • CriticalVulnerabilityDetected (severity: critical)                   │  │
│  │  • MisconfiguredWorkload (severity: warning)                            │  │
│  │                                                                          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

#### Report Types

| Report Type | Scans | Example Finding |
|-------------|-------|-----------------|
| **VulnerabilityReport** | Container image CVEs | CVE-2023-44487 (HTTP/2 Rapid Reset) |
| **ConfigAuditReport** | K8s misconfigurations | Container running as root |
| **ExposedSecretReport** | Leaked secrets in images | AWS keys in config files |
| **RbacAssessmentReport** | RBAC issues | Overly permissive ClusterRole |
| **InfraAssessmentReport** | Node-level issues | Kernel vulnerabilities |

#### Useful Commands

```bash
# List all vulnerability reports
kubectl get vulnerabilityreports -A

# Get detailed report for a specific pod
kubectl get vulnerabilityreport -n default \
  replicaset-nginx-7bf8c77b5b-nginx -o yaml

# Count vulnerabilities by severity
kubectl get vulnerabilityreports -A -o json | \
  jq '[.items[].report.summary] | add'

# Find pods with critical vulnerabilities
kubectl get vulnerabilityreports -A -o json | \
  jq -r '.items[] | select(.report.summary.criticalCount > 0) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Get config audit failures
kubectl get configauditreports -A

# Check for exposed secrets
kubectl get exposedsecretreports -A
```

<details>
<summary>📄 Click to expand full gitops/security/trivy-operator.yaml</summary>

```yaml
# ============================================================================
# TRIVY OPERATOR - Continuous Security Scanning
# ============================================================================
# Component: Trivy Operator v0.19.1
# Purpose: Continuously scans cluster for vulnerabilities, misconfigurations,
#          and exposed secrets. Generates Kubernetes CRD reports.
# Dependencies: Prometheus (optional, for metrics)
# ============================================================================
#
# REPORT TYPES:
#   - VulnerabilityReport: Image CVE scanning
#   - ConfigAuditReport: K8s misconfigurations
#   - ExposedSecretReport: Secrets in container images
#   - RbacAssessmentReport: RBAC permission analysis
#
# SCAN TRIGGERS:
#   - New workload created
#   - Image tag updated
#   - Scheduled rescan (configurable)
#
# RESOURCE USAGE (ARM64):
#   - Operator: ~100MB
#   - Scan Jobs: ~200MB (ephemeral)
#
# ============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: trivy-operator
  namespace: argocd
  labels:
    app.kubernetes.io/component: security-scanner
    app.kubernetes.io/part-of: security-platform
spec:
  project: default
  source:
    repoURL: https://aquasecurity.github.io/helm-charts/
    chart: trivy-operator
    targetRevision: 0.19.1
    helm:
      values: |
        # ──────────────────────────────────────────────────────────────────────
        # TRIVY SCANNER CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        trivy:
          # Only report vulnerabilities with available fixes
          # Reduces noise from unfixable CVEs
          ignoreUnfixed: true
          
          # Severity levels to report (remove LOW for less noise)
          severity: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
          
          # Skip scanning of specific namespaces
          # Add more as needed (e.g., kube-system)
          skipDirs: "/proc,/sys,/dev"
          
          # Resource limits for scan jobs
          resources:
            requests:
              cpu: 100m
              memory: 100Mi
            limits:
              cpu: 500m
              memory: 500Mi
          
          # Database update settings
          # Trivy downloads vulnerability DB on first scan
          dbRepository: ghcr.io/aquasecurity/trivy-db
          dbRepositoryInsecure: false

        # ──────────────────────────────────────────────────────────────────────
        # OPERATOR CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        operator:
          # Namespaces to scan (empty = all namespaces)
          # Exclude system namespaces for faster scans
          # targetNamespaces: "default,apps,services"
          
          # Scan schedule (cron expression)
          # Default: Daily at 3 AM
          vulnerabilityScannerScanOnlyCurrentRevisions: true
          
          # Resource limits for operator
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 256Mi

        # ──────────────────────────────────────────────────────────────────────
        # REPORT CONFIGURATION
        # ──────────────────────────────────────────────────────────────────────
        # Enable/disable specific report types
        scanJob:
          # Vulnerability scanning (CVEs)
          vulnerabilityReports:
            scanner: Trivy
          
          # Configuration auditing (K8s best practices)
          configAuditReports:
            scanner: Trivy
          
          # Exposed secrets detection
          exposedSecretReports:
            scanner: Trivy
          
          # RBAC assessment
          rbacAssessmentReports:
            scanner: Trivy

        # ──────────────────────────────────────────────────────────────────────
        # PROMETHEUS INTEGRATION
        # ──────────────────────────────────────────────────────────────────────
        serviceMonitor:
          # Enable ServiceMonitor for Prometheus scraping
          enabled: true
          # Scrape interval
          interval: 60s
          # Additional labels for ServiceMonitor
          labels:
            release: prometheus
        
        # Trivy metrics endpoint
        # Exposes: trivy_image_vulnerabilities, trivy_configauditreport_*
        trivyOperator:
          metricsVulnerabilityId:
            enabled: true

  destination:
    server: https://kubernetes.default.svc
    namespace: trivy-system
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

#### Development Workflow Comparison

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                   TRADITIONAL vs SKAFFOLD WORKFLOW                             │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  TRADITIONAL (Slow - 5-10 minutes per change)                                  │
│  ─────────────────────────────────────────────                                 │
│                                                                                │
│  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐ │
│  │ Edit │──▶│ git  │──▶│ Push │──▶│ CI   │──▶│Harbor│──▶│ArgoCD│──▶│Deploy│ │
│  │ Code │   │commit│   │      │   │Build │   │      │   │Sync  │   │      │ │
│  └──────┘   └──────┘   └──────┘   └──────┘   └──────┘   └──────┘   └──────┘ │
│     │                                                                   ▲      │
│     │◀──────────────────── Wait 5-10 minutes ──────────────────────────│      │
│                                                                                │
│                                                                                │
│  SKAFFOLD (Fast - 10-30 seconds per change)                                    │
│  ───────────────────────────────────────────                                   │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │                    DEVELOPER MACHINE                                     │ │
│  │                                                                          │ │
│  │  ┌──────┐   save   ┌──────────────────────────────────────────────────┐ │ │
│  │  │ Edit │────────▶ │              SKAFFOLD DEV MODE                   │ │ │
│  │  │ Code │          │  ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐  │ │ │
│  │  └──────┘          │  │Detect │──▶│ Build │──▶│ Push  │──▶│Deploy │  │ │ │
│  │     ▲              │  │Change │   │ Image │   │Harbor │   │  K8s  │  │ │ │
│  │     │              │  └───────┘   └───────┘   └───────┘   └───────┘  │ │ │
│  │     │              │       │                                    │    │ │ │
│  │     │              │       └────────────────────────────────────┘    │ │ │
│  │     │◀─────────────│                  ~10-30 seconds                 │ │ │
│  │                    └──────────────────────────────────────────────────┘ │ │
│  │                                                                          │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                     │                                         │
│                                     │ kubectl apply                           │
│                                     ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │                    RASPBERRY PI CLUSTER                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐ │ │
│  │  │  Pod: my-app-dev-abc123                                             │ │ │
│  │  │  Image: harbor.192.168.0.210.nip.io/library/my-app:dev-abc123       │ │ │
│  │  │  Status: Running                                                    │ │ │
│  │  └─────────────────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

#### Skaffold Setup Instructions

**1. Install Skaffold:**

```powershell
# Windows (PowerShell)
choco install skaffold

# macOS
brew install skaffold

# Linux
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-arm64
chmod +x skaffold && sudo mv skaffold /usr/local/bin
```

**2. Create `skaffold.yaml` in your application repo:**

<details>
<summary>📄 Click to expand full skaffold.yaml</summary>

```yaml
# ============================================================================
# SKAFFOLD - Local Development Configuration
# ============================================================================
# Purpose: Rapid iteration development workflow
# Usage: skaffold dev (watch mode) or skaffold run (one-time build/deploy)
# ============================================================================
apiVersion: skaffold/v4beta3
kind: Config
metadata:
  name: my-app
build:
  # Build artifacts (container images)
  artifacts:
    - image: harbor.192.168.0.210.nip.io/library/my-app
      docker:
        dockerfile: Dockerfile
        # Build arguments (optional)
        buildArgs:
          GO_VERSION: "1.21"
      # Sync files without rebuilding (hot reload)
      sync:
        manual:
          - src: "src/**/*.go"
            dest: /app
  
  # Local build configuration
  local:
    # Push to Harbor registry
    push: true
    # Use Docker build cache
    useBuildkit: true

# Kubernetes manifests to deploy
manifests:
  rawYaml:
    - k8s/deployment.yaml
    - k8s/service.yaml

# Deploy configuration
deploy:
  kubectl:
    manifests:
      - k8s/deployment.yaml
      - k8s/service.yaml

# Port forwarding for local access
portForward:
  - resourceType: service
    resourceName: my-app
    port: 8080
    localPort: 8080

# Development profiles
profiles:
  # Debug profile with delve debugger
  - name: debug
    activation:
      - command: debug
    patches:
      - op: add
        path: /build/artifacts/0/docker/buildArgs/DEBUG
        value: "true"
  
  # Production-like profile
  - name: prod
    activation:
      - command: run
      - env: SKAFFOLD_PROFILE=prod
    build:
      tagPolicy:
        gitCommit:
          prefix: "prod-"
```

</details>

**3. Run Skaffold:**

```bash
# Development mode (watch for changes)
skaffold dev

# One-time build and deploy
skaffold run

# Build only (don't deploy)
skaffold build

# Debug mode (with delve)
skaffold debug
```

#### Skaffold Commands Reference

| Command | Purpose | Use Case |
|---------|---------|----------|
| `skaffold dev` | Watch mode, continuous deploy | Active development |
| `skaffold run` | One-time build and deploy | Testing before commit |
| `skaffold build` | Build images only | CI/CD integration |
| `skaffold debug` | Deploy with debugger attached | Troubleshooting |
| `skaffold render` | Output K8s manifests | Preview changes |
| `skaffold delete` | Remove deployed resources | Cleanup |

---

### 11.6 CI/CD Verification Script

**File:** `tests/06_cicd_test.sh`

Comprehensive verification script for CI/CD pipeline components.

**Verification Checklist:**

* **Argo Workflows:** Controller, server, artifact repository
* **Argo Events:** Controller, EventBus, webhook endpoint
* **Argo Image Updater:** Connection to Harbor registry
* **Trivy Operator:** Vulnerability report generation

<details>
<summary>📄 Click to expand full tests/06_cicd_test.sh</summary>

```bash
#!/bin/bash
# =============================================================================
# PHASE 7: CI/CD PIPELINE COMPREHENSIVE VERIFICATION
# =============================================================================
# Verifies all CI/CD and developer experience components:
#   - Argo Workflows (CI engine)
#   - Argo Events (Event-driven triggers)
#   - Argo Image Updater (GitOps automation)
#   - Trivy Operator (Security scanning)
#
# Prerequisites:
#   - Phase 7 components deployed via ArgoCD
#   - kubectl configured for the cluster
#   - curl available for HTTP checks
#
# Usage: bash tests/06_cicd_test.sh
# =============================================================================

set -euo pipefail

# Configuration
CLUSTER_IP="${CLUSTER_IP:-192.168.0.210}"
WORKFLOWS_URL="http://workflows.${CLUSTER_IP}.nip.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          $1"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} Test $1: $2"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────┘${NC}"
}

pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((TESTS_WARNED++))
}

info() {
    echo -e "   ${BLUE}ℹ${NC}  $1"
}

# =============================================================================
print_header "PHASE 7: CI/CD PIPELINE VERIFICATION"
# =============================================================================

# -----------------------------------------------------------------------------
# Test 1: Argo Workflows Controller
# -----------------------------------------------------------------------------
print_test "1" "Argo Workflows Controller"

WF_CONTROLLER=$(kubectl get pods -n argo-workflows \
    -l app.kubernetes.io/name=argo-workflows-controller \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$WF_CONTROLLER" -ge 1 ]; then
    pass "Argo Workflows Controller is running"
    
    # Check controller version
    WF_VERSION=$(kubectl get deployment -n argo-workflows \
        argo-workflows-workflow-controller \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | \
        cut -d: -f2 || echo "unknown")
    info "Controller version: $WF_VERSION"
else
    fail "Argo Workflows Controller is not running"
fi

# -----------------------------------------------------------------------------
# Test 2: Argo Workflows Server
# -----------------------------------------------------------------------------
print_test "2" "Argo Workflows Server & UI"

WF_SERVER=$(kubectl get pods -n argo-workflows \
    -l app.kubernetes.io/name=argo-workflows-server \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$WF_SERVER" -ge 1 ]; then
    pass "Argo Workflows Server is running"
    
    # Check UI accessibility
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WORKFLOWS_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        pass "Workflows UI accessible at $WORKFLOWS_URL"
    else
        warn "Workflows UI not accessible (HTTP $HTTP_CODE)"
    fi
else
    fail "Argo Workflows Server is not running"
fi

# -----------------------------------------------------------------------------
# Test 3: Argo Workflows Artifact Repository
# -----------------------------------------------------------------------------
print_test "3" "Argo Workflows Artifact Repository (MinIO)"

# Check if artifact repository is configured
ARTIFACT_REPO=$(kubectl get configmap -n argo-workflows \
    workflow-controller-configmap \
    -o jsonpath='{.data.artifactRepository}' 2>/dev/null || echo "")

if [ -n "$ARTIFACT_REPO" ]; then
    pass "Artifact repository configured"
    
    # Check MinIO connectivity
    MINIO_SVC=$(kubectl get svc -n storage minio --no-headers 2>/dev/null || echo "")
    if [ -n "$MINIO_SVC" ]; then
        info "MinIO service found in storage namespace"
    else
        warn "MinIO service not found - artifacts may not persist"
    fi
else
    warn "Artifact repository not configured"
fi

# -----------------------------------------------------------------------------
# Test 4: Argo Events Controller
# -----------------------------------------------------------------------------
print_test "4" "Argo Events Controller"

AE_CONTROLLER=$(kubectl get pods -n argo-events \
    -l app.kubernetes.io/name=argo-events-controller \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$AE_CONTROLLER" -ge 1 ]; then
    pass "Argo Events Controller is running"
else
    fail "Argo Events Controller is not running"
fi

# -----------------------------------------------------------------------------
# Test 5: Argo Events EventBus
# -----------------------------------------------------------------------------
print_test "5" "Argo Events EventBus (Jetstream)"

EVENTBUS=$(kubectl get eventbus -n argo-events --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$EVENTBUS" -gt 0 ]; then
    pass "EventBus configured"
    
    # Check EventBus status
    EB_STATUS=$(kubectl get eventbus -n argo-events default \
        -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null || echo "")
    if [ "$EB_STATUS" = "True" ]; then
        info "EventBus status: Deployed"
        
        # Count NATS pods
        NATS_PODS=$(kubectl get pods -n argo-events \
            -l eventbus-name=default \
            --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        info "NATS replicas running: $NATS_PODS"
    else
        warn "EventBus not fully deployed"
    fi
else
    warn "No EventBus found - event-driven pipelines won't work"
fi

# -----------------------------------------------------------------------------
# Test 6: Argo Events EventSources
# -----------------------------------------------------------------------------
print_test "6" "Argo Events EventSources"

EVENT_SOURCES=$(kubectl get eventsources -A --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$EVENT_SOURCES" -gt 0 ]; then
    pass "Found $EVENT_SOURCES EventSource(s)"
    
    # List EventSources
    echo ""
    kubectl get eventsources -A --no-headers 2>/dev/null | \
        awk '{printf "   • %-25s %-20s %s\n", $1, $2, $4}'
else
    warn "No EventSources configured yet"
    info "Create EventSources to trigger workflows from external events"
fi

# -----------------------------------------------------------------------------
# Test 7: Argo Image Updater
# -----------------------------------------------------------------------------
print_test "7" "Argo Image Updater"

IMAGE_UPDATER=$(kubectl get pods -n argocd \
    -l app.kubernetes.io/name=argocd-image-updater \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$IMAGE_UPDATER" -ge 1 ]; then
    pass "Argo Image Updater is running"
    
    # Check recent logs for Harbor connectivity
    HARBOR_ERROR=$(kubectl logs -n argocd \
        -l app.kubernetes.io/name=argocd-image-updater \
        --tail=50 2>/dev/null | grep -i "error.*harbor" || echo "")
    
    if [ -z "$HARBOR_ERROR" ]; then
        info "No Harbor connectivity errors in recent logs"
    else
        warn "Harbor connectivity issues detected in logs"
    fi
    
    # List watched applications
    WATCHED_APPS=$(kubectl get applications -n argocd \
        -o jsonpath='{range .items[*]}{.metadata.annotations.argocd-image-updater\.argoproj\.io/image-list}{"\n"}{end}' 2>/dev/null | \
        grep -v "^$" | wc -l || echo "0")
    info "Applications with image update annotations: $WATCHED_APPS"
else
    fail "Argo Image Updater is not running"
fi

# -----------------------------------------------------------------------------
# Test 8: Trivy Operator
# -----------------------------------------------------------------------------
print_test "8" "Trivy Operator"

TRIVY_OPERATOR=$(kubectl get pods -n trivy-system \
    -l app.kubernetes.io/name=trivy-operator \
    --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$TRIVY_OPERATOR" -ge 1 ]; then
    pass "Trivy Operator is running"
else
    # Try alternate namespace
    TRIVY_OPERATOR=$(kubectl get pods -n security \
        -l app.kubernetes.io/name=trivy-operator \
        --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$TRIVY_OPERATOR" -ge 1 ]; then
        pass "Trivy Operator is running (in security namespace)"
    else
        fail "Trivy Operator is not running"
    fi
fi

# -----------------------------------------------------------------------------
# Test 9: Trivy Vulnerability Reports
# -----------------------------------------------------------------------------
print_test "9" "Trivy Vulnerability Reports"

VULN_REPORTS=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$VULN_REPORTS" -gt 0 ]; then
    pass "Trivy is generating vulnerability reports ($VULN_REPORTS found)"
    
    # Count by severity
    CRITICAL=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | \
        jq '[.items[].report.summary.criticalCount // 0] | add' || echo "0")
    HIGH=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | \
        jq '[.items[].report.summary.highCount // 0] | add' || echo "0")
    
    info "Critical vulnerabilities: $CRITICAL"
    info "High vulnerabilities: $HIGH"
    
    if [ "$CRITICAL" -gt 0 ]; then
        warn "Critical vulnerabilities detected - review reports!"
    fi
else
    warn "No vulnerability reports yet (Trivy may still be scanning)"
    info "Reports will appear as pods are scanned"
fi

# -----------------------------------------------------------------------------
# Test 10: ArgoCD Application Health (CI/CD Apps)
# -----------------------------------------------------------------------------
print_test "10" "ArgoCD CI/CD Application Health"

CICD_APPS=("argo-workflows" "argo-events" "argo-image-updater" "trivy-operator")
HEALTHY_COUNT=0

for app in "${CICD_APPS[@]}"; do
    STATUS=$(kubectl get application -n argocd "$app" \
        -o jsonpath='{.status.health.status}' 2>/dev/null || echo "NotFound")
    SYNC=$(kubectl get application -n argocd "$app" \
        -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
    
    if [ "$STATUS" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
        info "✓ $app: Healthy/Synced"
        ((HEALTHY_COUNT++))
    elif [ "$STATUS" = "NotFound" ]; then
        info "○ $app: Not deployed"
    else
        warn "! $app: $STATUS/$SYNC"
    fi
done

if [ "$HEALTHY_COUNT" -ge 2 ]; then
    pass "Core CI/CD applications healthy ($HEALTHY_COUNT/${#CICD_APPS[@]})"
else
    warn "Some CI/CD applications not healthy"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                    VERIFICATION SUMMARY                                "
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "   Tests Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "   Warnings:      ${YELLOW}$TESTS_WARNED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "   ${GREEN}✅ All Phase 7 CI/CD tests passed!${NC}"
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                       ACCESS URLS                                     "
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "   • Argo Workflows:  $WORKFLOWS_URL"
    echo "   • ArgoCD:          http://argocd.${CLUSTER_IP}.nip.io"
    echo "   • Harbor:          https://harbor.${CLUSTER_IP}.nip.io"
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                       NEXT STEPS                                      "
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "   1. Create a WorkflowTemplate for your build pipeline"
    echo "   2. Configure Gitea webhook to trigger Argo Events"
    echo "   3. Annotate ArgoCD Applications for Image Updater"
    echo "   4. Review Trivy vulnerability reports"
    echo "   5. Set up Skaffold for local development"
    echo ""
    exit 0
else
    echo -e "   ${RED}❌ Some tests failed. Check component status above.${NC}"
    echo ""
    echo "   Troubleshooting:"
    echo "   • Check ArgoCD sync status: kubectl get applications -n argocd"
    echo "   • View pod logs: kubectl logs -n <namespace> -l app.kubernetes.io/name=<component>"
    echo "   • Verify secrets exist: kubectl get secrets -n argocd"
    echo ""
    exit 1
fi
```

</details>

### 11.7 Phase 7 Execution Steps

#### Deployment Checklist

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 7 DEPLOYMENT CHECKLIST                                │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  PRE-REQUISITES                                                                │
│  ─────────────                                                                 │
│  ☐ Phase 5 complete (Harbor registry deployed)                                 │
│  ☐ Phase 6 complete (MinIO storage available)                                  │
│  ☐ ArgoCD accessible and healthy                                               │
│  ☐ Gitea repository configured                                                 │
│                                                                                │
│  SECRETS TO CREATE                                                             │
│  ────────────────                                                              │
│  ☐ harbor-creds (argocd namespace) - for Image Updater                         │
│  ☐ argo-artifacts-creds (argo-workflows namespace) - for MinIO                 │
│                                                                                │
│  COMPONENTS TO DEPLOY                                                          │
│  ───────────────────                                                           │
│  ☐ Argo Workflows (CI engine)                                                  │
│  ☐ Argo Events (Event triggers)                                                │
│  ☐ Argo Image Updater (GitOps automation)                                      │
│  ☐ Trivy Operator (Security scanning)                                          │
│                                                                                │
│  VERIFICATION                                                                  │
│  ────────────                                                                  │
│  ☐ Workflows UI accessible                                                     │
│  ☐ Image Updater connected to Harbor                                           │
│  ☐ Vulnerability reports generating                                            │
│  ☐ EventBus deployed and healthy                                               │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

#### Step-by-Step Deployment

**Step 1: Create Required Secrets**

```bash
# Harbor credentials for Image Updater
kubectl create secret generic harbor-creds \
  --from-literal=username=admin \
  --from-literal=password='<your-harbor-password>' \
  -n argocd

# MinIO credentials for Argo Workflows artifacts
kubectl create namespace argo-workflows
kubectl create secret generic argo-artifacts-creds \
  --from-literal=accessKey=minioadmin \
  --from-literal=secretKey='<your-minio-password>' \
  -n argo-workflows

# Create argo-artifacts bucket in MinIO
kubectl exec -n storage deploy/minio -- \
  mc alias set myminio http://localhost:9000 minioadmin '<your-minio-password>'
kubectl exec -n storage deploy/minio -- \
  mc mb myminio/argo-artifacts
```

**Step 2: Commit & Push GitOps Files**

```bash
# Save all YAML files to gitops/ directories
git add gitops/cicd/argo-image-updater.yaml
git add gitops/cicd/argo-workflows.yaml
git add gitops/cicd/argo-events.yaml
git add gitops/security/trivy-operator.yaml
git commit -m "Add Phase 7: CI/CD Pipeline Components"
git push origin main
```

**Step 3: Verify ArgoCD Sync**

```bash
# Watch ArgoCD sync the new applications
kubectl get applications -n argocd -w

# Force sync if needed
argocd app sync argo-workflows
argocd app sync argo-events
argocd app sync argo-image-updater
argocd app sync trivy-operator
```

**Step 4: Verify Component Health**

```bash
# Argo Workflows
kubectl get pods -n argo-workflows
kubectl logs -n argo-workflows -l app.kubernetes.io/name=argo-workflows-controller --tail=20

# Argo Events
kubectl get pods -n argo-events
kubectl get eventbus -n argo-events

# Argo Image Updater
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=20

# Trivy Operator
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -A | head -10
```

**Step 5: Access Workflows UI**

Open `http://workflows.192.168.0.210.nip.io` in your browser. You should see the Argo Workflows dashboard.

**Step 6: Configure First Pipeline (Optional)**

```bash
# Create a test workflow
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
  namespace: argo-workflows
spec:
  entrypoint: whalesay
  templates:
  - name: whalesay
    container:
      image: docker/whalesay:latest
      command: [cowsay]
      args: ["Hello from Raspberry Pi!"]
EOF

# Watch the workflow
kubectl get workflows -n argo-workflows -w

# View workflow logs
argo logs -n argo-workflows @latest
```

**Step 7: Run Verification Script**

```bash
bash tests/06_cicd_test.sh
```

#### Post-Deployment Configuration

| Task | Command | Description |
|------|---------|-------------|
| **Configure Gitea Webhook** | Gitea UI → Settings → Webhooks | Point to Argo Events EventSource |
| **Annotate Apps for Image Updates** | Add annotations to ArgoCD Applications | Enable automatic image updates |
| **Create WorkflowTemplates** | `kubectl apply -f workflow-templates/` | Define reusable build pipelines |
| **Set up Skaffold** | Create `skaffold.yaml` in app repos | Local development workflow |
| **Review Trivy Reports** | `kubectl get vulnerabilityreports -A` | Address critical vulnerabilities |

#### Troubleshooting

| Issue | Diagnostic Command | Solution |
|-------|-------------------|----------|
| Workflows not starting | `kubectl logs -n argo-workflows -l app.kubernetes.io/name=argo-workflows-controller` | Check RBAC, resource limits |
| Image Updater not detecting new images | `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater` | Verify Harbor credentials |
| EventBus not ready | `kubectl get eventbus -n argo-events -o yaml` | Check NATS pod status |
| No vulnerability reports | `kubectl get pods -n trivy-system` | Trivy may still be initializing |
| MinIO artifact errors | `kubectl exec -n storage deploy/minio -- mc ls myminio/` | Verify bucket exists |

## 12. Phase 8: Day 2 Operations & Maintenance

This section outlines the routine tasks required to keep the cluster secure, up-to-date, and operational. Day 2 operations are what separate a "project" from a "production system."

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     DAY 2 OPERATIONS LIFECYCLE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PROACTIVE MAINTENANCE                            │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │   │
│  │  │ Security │  │    OS    │  │   K8s    │  │    Capacity      │   │   │
│  │  │ Patching │  │ Updates  │  │ Upgrades │  │    Planning      │   │   │
│  │  │ (Weekly) │  │(Monthly) │  │(Quarterly)│  │   (Ongoing)      │   │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │   │
│  │       │             │             │                  │             │   │
│  └───────┼─────────────┼─────────────┼──────────────────┼─────────────┘   │
│          │             │             │                  │                  │
│          ▼             ▼             ▼                  ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         MONITORING                                  │   │
│  │    Prometheus ──► Grafana ──► Alertmanager ──► Notification        │   │
│  │         │             │              │                              │   │
│  │         ▼             ▼              ▼                              │   │
│  │   [Metrics]     [Dashboards]   [PagerDuty/Slack]                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    BACKUP & DISASTER RECOVERY                       │   │
│  │                                                                     │   │
│  │   Velero ─────► MinIO S3 ─────► Offsite Backup                     │   │
│  │      │              │               │                               │   │
│  │      ▼              ▼               ▼                               │   │
│  │  [Scheduled]   [Replicated]   [Disaster Recovery]                  │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    INCIDENT RESPONSE                                │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │   │
│  │  │  Alert   │─►│  Triage  │─►│  Resolve │─►│   Post-Mortem    │   │   │
│  │  │ Received │  │  Impact  │  │   Issue  │  │   & Document     │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 2 Operations Summary

| Operation | Frequency | Downtime | Automation | Risk Level |
|-----------|-----------|----------|------------|------------|
| **Security Patches** | Weekly | None (rolling) | Ansible | Low |
| **OS Updates** | Monthly | Per-node (5min) | Ansible + drain | Low |
| **K8s Minor Upgrade** | Quarterly | None (rolling) | Manual + Ansible | Medium |
| **K8s Major Upgrade** | Yearly | Possible | Manual | High |
| **Velero Backup** | Nightly | None | Scheduled | None |
| **Certificate Renewal** | Yearly | Brief | cert-manager | Low |
| **Storage Cleanup** | Monthly | None | Manual/Script | Low |
| **Log Rotation** | Daily | None | Loki retention | None |

### 12.1 Upgrading Kubernetes

Since we pinned versions in Ansible, upgrades must be deliberate. Kubernetes follows semantic versioning: `MAJOR.MINOR.PATCH`.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KUBERNETES UPGRADE WORKFLOW                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                                                       │
│  │ 1. PRE-UPGRADE  │                                                       │
│  │    CHECKLIST    │                                                       │
│  └────────┬────────┘                                                       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  □ Review Release Notes for Breaking Changes                    │        │
│  │  □ Check API Deprecations (kubectl deprecations)               │        │
│  │  □ Verify etcd Backup Exists (Velero)                          │        │
│  │  □ Test Upgrade in Staging First                               │        │
│  │  □ Ensure All Nodes are Ready                                  │        │
│  │  □ Verify Sufficient Cluster Resources                         │        │
│  └────────────────────────────────────────────────────────────────┘        │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │ 2. UPGRADE      │───►│ 3. UPGRADE      │───►│ 4. UPGRADE      │        │
│  │    KUBEADM      │    │    CONTROL      │    │    WORKERS      │        │
│  │                 │    │    PLANE        │    │    (Rolling)    │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│           │                      │                      │                  │
│           ▼                      ▼                      ▼                  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │ apt install     │    │ kubeadm upgrade │    │ drain → upgrade │        │
│  │ kubeadm=1.32.x  │    │ apply v1.32.x   │    │ → uncordon      │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                         │                  │
│                                                         ▼                  │
│                               ┌─────────────────────────────────────┐      │
│                               │ 5. POST-UPGRADE VERIFICATION        │      │
│                               │    □ All nodes Ready                │      │
│                               │    □ All pods Running               │      │
│                               │    □ Cilium connectivity test       │      │
│                               │    □ Application health checks      │      │
│                               └─────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Upgrade Order:** Control Plane → Workers (always!)

#### Version Compatibility Matrix

| Component | Current | Target | Skew Allowed |
|-----------|---------|--------|--------------|
| **kubeadm** | 1.33.x | 1.34.x | Same as kubelet |
| **kubelet** | 1.33.x | 1.34.x | n-2 from API server |
| **kubectl** | 1.33.x | 1.34.x | ±1 from API server |
| **Cilium** | 1.16.x | Check matrix | Per Cilium docs |
| **containerd** | 1.7.x | 1.7.x | Usually stable |

#### Step-by-Step Upgrade Process

**Step 1: Pre-Upgrade Backup**
```bash
# Create backup before any upgrade
velero backup create pre-upgrade-$(date +%F) --wait

# Verify backup completed
velero backup describe pre-upgrade-$(date +%F)
```

**Step 2: Un-hold and Update kubeadm (Ansible)**

Update `ansible/hosts` vars to the new version (e.g., `1.32`) and run a playbook to unhold and update `kubeadm`.

```bash
# Update ansible/hosts with new version
# k8s_version: "1.32"

# Or manually on control plane
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.32.0-1.1
sudo apt-mark hold kubeadm
```

**Step 3: Upgrade Control Plane**
```bash
# On rpi4-1 (control plane)
# Check upgrade plan first
sudo kubeadm upgrade plan

# Apply the upgrade
sudo kubeadm upgrade apply v1.32.0

# Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**Step 4: Upgrade Worker Nodes (Rolling)**
```bash
# For each worker (rpi4-2, rpi4-3, rpi4-4)
# First drain the node
kubectl drain rpi4-2 --ignore-daemonsets --delete-emptydir-data

# SSH to worker and upgrade
ssh rpi4-2
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubeadm=1.32.0-1.1 kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
sudo apt-mark hold kubeadm kubelet kubectl
sudo kubeadm upgrade node
sudo systemctl daemon-reload
sudo systemctl restart kubelet
exit

# Uncordon the node
kubectl uncordon rpi4-2

# Verify node is ready before proceeding to next
kubectl get nodes
```

**Step 5: Post-Upgrade Verification**
```bash
# Verify all nodes upgraded
kubectl get nodes -o wide

# Check component versions
kubectl version --short

# Run connectivity test
cilium connectivity test

# Verify all pods healthy
kubectl get pods -A | grep -v Running | grep -v Completed
```

### 12.2 Rolling OS Upgrade Playbook

**File:** `ansible/playbooks/06_rolling_upgrade.yml`

This Ansible playbook provides **automated, zero-downtime OS patching** across the entire cluster. It handles drain/uncordon, package upgrades, and conditional reboots.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ROLLING UPGRADE PLAYBOOK WORKFLOW                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1: Worker Nodes (serial: 1 - one at a time)                         │
│  ─────────────────────────────────────────────────                         │
│                                                                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐                                 │
│  │ rpi4-2  │───►│ rpi4-3  │───►│ rpi4-4  │                                 │
│  │ Worker  │    │ Worker  │    │ Worker  │                                 │
│  └────┬────┘    └────┬────┘    └────┬────┘                                 │
│       │              │              │                                       │
│       ▼              ▼              ▼                                       │
│  For each node:                                                             │
│    1. kubectl drain (evict pods gracefully)                                 │
│    2. apt update && apt upgrade                                             │
│    3. Reboot if /var/run/reboot-required exists                            │
│    4. Wait for node Ready                                                   │
│    5. kubectl uncordon (allow scheduling)                                   │
│    6. Proceed to next node                                                  │
│                                                                             │
│  PHASE 2: Control Plane (last, with extra safety checks)                   │
│  ──────────────────────────────────────────────────────                    │
│                                                                             │
│  ┌─────────┐                                                               │
│  │ rpi4-1  │                                                               │
│  │ Control │  ← Verify all workers Ready before starting                   │
│  │  Plane  │  ← API server briefly unavailable during reboot               │
│  └─────────┘                                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage:**

```bash
# Upgrade all nodes (workers first, control plane last)
ansible-playbook -i ansible/hosts ansible/playbooks/06_rolling_upgrade.yml

# Upgrade specific node only
ansible-playbook -i ansible/hosts ansible/playbooks/06_rolling_upgrade.yml --limit rpi4-2

# Dry-run (check what would be upgraded without making changes)
ansible-playbook -i ansible/hosts ansible/playbooks/06_rolling_upgrade.yml --check

# Skip reboot even if kernel updated (not recommended for security patches)
ansible-playbook -i ansible/hosts ansible/playbooks/06_rolling_upgrade.yml -e "allow_reboot=false"
```

**Playbook Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `allow_reboot` | `true` | Reboot node if `/var/run/reboot-required` exists |
| `drain_timeout` | `300` | Seconds to wait for drain to complete |
| `ready_timeout` | `300` | Seconds to wait for node to become Ready after reboot |
| `eviction_grace_period` | `30` | Grace period for pod eviction |

<details>
<summary>📄 Click to expand full ansible/playbooks/06_rolling_upgrade.yml</summary>

```yaml
---
# ============================================================================
# ROLLING OS UPGRADE PLAYBOOK
# ============================================================================
# Description: Safe rolling OS updates across the cluster with zero downtime
# Use Case:    Security patches, kernel updates, package upgrades
#
# How It Works:
#   1. Drains workloads from the target node
#   2. Runs apt update && apt upgrade
#   3. Reboots if a kernel update requires it
#   4. Waits for the node to rejoin the cluster
#   5. Uncordons the node to accept workloads again
#   6. Proceeds to the next node (serial execution)
#
# Safety Features:
#   - Serial execution (one node at a time)
#   - Automatic drain with timeout
#   - Graceful pod eviction
#   - Health checks before proceeding
#   - Control plane upgraded last (default)
#
# Usage:
#   # Upgrade all nodes (workers first, control plane last)
#   ansible-playbook -i hosts playbooks/06_rolling_upgrade.yml
#
#   # Upgrade specific node only
#   ansible-playbook -i hosts playbooks/06_rolling_upgrade.yml --limit rpi4-2
#
#   # Dry-run (check what would be upgraded)
#   ansible-playbook -i hosts playbooks/06_rolling_upgrade.yml --check
#
#   # Skip reboot even if kernel updated
#   ansible-playbook -i hosts playbooks/06_rolling_upgrade.yml -e "allow_reboot=false"
#
# Pre-requisites:
#   - kubectl configured on control node (or local machine)
#   - Cluster healthy (all nodes Ready)
#   - Sufficient capacity to handle drained workloads
#
# Author: Kubernetes on Raspberry Pi Guide
# ============================================================================

# Worker nodes upgraded first (one at a time)
- name: Rolling OS Upgrade - Worker Nodes
  hosts: small
  become: true
  serial: 1
  
  vars:
    allow_reboot: true
    drain_timeout: 300
    ready_timeout: 300
    eviction_grace_period: 30

  tasks:
    - name: Drain node
      ansible.builtin.command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets --delete-emptydir-data
        --grace-period={{ eviction_grace_period }}
        --timeout={{ drain_timeout }}s --force
      delegate_to: "{{ groups['big'][0] }}"
    
    - name: Update packages
      ansible.builtin.apt:
        update_cache: yes
        upgrade: safe
        autoremove: yes
    
    - name: Check if reboot required
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: reboot_required
    
    - name: Reboot if required
      ansible.builtin.reboot:
        reboot_timeout: 300
        post_reboot_delay: 30
      when: reboot_required.stat.exists and allow_reboot
    
    - name: Wait for node Ready
      ansible.builtin.command: >
        kubectl wait --for=condition=Ready
        node/{{ inventory_hostname }} --timeout={{ ready_timeout }}s
      delegate_to: "{{ groups['big'][0] }}"
    
    - name: Uncordon node
      ansible.builtin.command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: "{{ groups['big'][0] }}"

# Control plane upgraded last
- name: Rolling OS Upgrade - Control Plane
  hosts: big
  become: true
  serial: 1
  
  vars:
    allow_reboot: true
    drain_timeout: 300
    ready_timeout: 300
    eviction_grace_period: 30

  tasks:
    - name: Verify all workers Ready
      ansible.builtin.shell: |
        kubectl get nodes --no-headers | grep -v {{ inventory_hostname }} | grep -v Ready && exit 1 || exit 0
      changed_when: false
    
    - name: Drain control plane
      ansible.builtin.command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets --delete-emptydir-data
        --grace-period={{ eviction_grace_period }}
        --timeout={{ drain_timeout }}s --force
    
    - name: Update packages
      ansible.builtin.apt:
        update_cache: yes
        upgrade: safe
        autoremove: yes
    
    - name: Check if reboot required
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: reboot_required
    
    - name: Reboot if required
      ansible.builtin.reboot:
        reboot_timeout: 300
        post_reboot_delay: 60
      when: reboot_required.stat.exists and allow_reboot
    
    - name: Wait for API server
      ansible.builtin.command: kubectl cluster-info
      retries: 30
      delay: 10
      until: cluster_info.rc == 0
      register: cluster_info
    
    - name: Wait for node Ready
      ansible.builtin.command: >
        kubectl wait --for=condition=Ready
        node/{{ inventory_hostname }} --timeout={{ ready_timeout }}s
    
    - name: Uncordon node
      ansible.builtin.command: kubectl uncordon {{ inventory_hostname }}
    
    - name: Display final status
      ansible.builtin.command: kubectl get nodes
      register: final_status
    
    - name: Show completion
      ansible.builtin.debug:
        msg: "Rolling upgrade complete!\n{{ final_status.stdout }}"
```

</details>

### 12.3 Manual OS Patching

For manual patching or patching a single node without the Ansible playbook:

```bash
# 1. Drain Node (Move workloads elsewhere)
kubectl drain rpi4-2 --ignore-daemonsets --delete-emptydir-data

# 2. SSH and Update
ssh rpi4-2
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get autoremove -y
# Reboot if kernel was updated
if [ -f /var/run/reboot-required ]; then sudo reboot; fi
exit

# 3. Wait for node to rejoin (if rebooted)
kubectl wait --for=condition=Ready node/rpi4-2 --timeout=300s

# 4. Uncordon (Allow workloads back)
kubectl uncordon rpi4-2

# 5. Verify health before moving to next node
kubectl get pods -A -o wide | grep rpi4-2
```

> 💡 **Tip:** Use the Ansible playbook (`06_rolling_upgrade.yml`) for regular patching—it handles all nodes automatically with proper safety checks.

### 12.4 Cluster Reset (The Nuclear Option)

**File:** `ansible/playbooks/05_reset_cluster.yml`

This playbook is a safety net for your learning process. If you misconfigure the cluster or networking beyond repair, run this to wipe the nodes clean so you can restart from Phase 2 (Cluster Init) without re-flashing SD cards.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CLUSTER RESET DECISION TREE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                    ┌─────────────────────────┐                              │
│                    │   Cluster Problem?      │                              │
│                    └───────────┬─────────────┘                              │
│                                │                                            │
│              ┌─────────────────┼─────────────────┐                          │
│              ▼                 ▼                 ▼                          │
│     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐               │
│     │  Pod Issues?   │ │ Network Issues?│ │ Node Corrupted?│               │
│     └───────┬────────┘ └───────┬────────┘ └───────┬────────┘               │
│             │                  │                  │                         │
│             ▼                  ▼                  ▼                         │
│     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐               │
│     │ kubectl delete │ │ cilium status  │ │ kubeadm reset  │               │
│     │ pod --force    │ │ hubble observe │ │ (single node)  │               │
│     └────────────────┘ └───────┬────────┘ └────────────────┘               │
│                                │                                            │
│                     ┌──────────┴──────────┐                                 │
│                     ▼                     ▼                                 │
│            ┌────────────────┐    ┌────────────────┐                         │
│            │  CNI Fixable?  │    │  etcd Corrupt? │                         │
│            │  Reinstall     │    │  or Total Loss │                         │
│            │  Cilium        │    └───────┬────────┘                         │
│            └────────────────┘            │                                  │
│                                          ▼                                  │
│                               ┌──────────────────────┐                      │
│                               │   ⚠️ NUCLEAR OPTION  │                      │
│                               │   Full Cluster Reset │                      │
│                               │   05_reset_cluster   │                      │
│                               └──────────────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Pre-Reset Checklist

| Check | Command | Purpose |
|-------|---------|---------|
| **Backup Exists** | `velero backup get` | Ensure you can restore |
| **Data Exported** | `kubectl get all -A -o yaml > cluster-export.yaml` | Emergency export |
| **Longhorn Data** | Check `/mnt/usb-data/longhorn` | PV data location |
| **GitOps Repo** | `git status` | All configs committed |
| **Document State** | Screenshot/notes | What broke and why |

#### What Gets Reset vs Preserved

| Component | Reset? | Location | Notes |
|-----------|--------|----------|-------|
| **Kubernetes State** | ✅ Yes | etcd | All K8s objects gone |
| **CNI Config** | ✅ Yes | `/etc/cni/net.d` | Cilium config wiped |
| **IPtables Rules** | ✅ Yes | Memory | Flushed completely |
| **Kube Configs** | ✅ Yes | `~/.kube` | Need new join tokens |
| **Container Images** | ❌ No | containerd cache | Speeds up rebuild |
| **Longhorn Data** | ❌ No | `/mnt/usb-data` | PVs preserved |
| **OS Configuration** | ❌ No | `/etc/` | Ansible configs remain |

<details>
<summary>📄 Click to expand full ansible/playbooks/05_reset_cluster.yml</summary>

```yaml
---
# ============================================================================
# CLUSTER RESET PLAYBOOK - THE NUCLEAR OPTION
# ============================================================================
# Description: Complete cluster reset without reflashing SD cards
# Use Case:    Unrecoverable cluster state, fresh start needed
# Warning:     This will destroy all Kubernetes state!
#
# What gets RESET:
#   - All Kubernetes objects (pods, services, deployments, etc.)
#   - CNI configuration and network state
#   - IPtables rules
#   - Kube configs and certificates
#
# What gets PRESERVED:
#   - OS configuration (Ansible-managed)
#   - Longhorn data on USB drives (unless explicitly wiped)
#   - Container image cache (speeds up rebuild)
#
# Usage:
#   ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml
#
# Post-Reset:
#   1. Re-run 03_cluster_init.yml to initialize new cluster
#   2. Re-run bootstrap scripts for ArgoCD, etc.
#   3. Restore from Velero backup if available
# ============================================================================

- name: Phase 8 - Cluster Reset (The Nuclear Option)
  hosts: all
  become: true

  vars:
    # Set to true to also wipe Longhorn data
    wipe_storage_data: false
    longhorn_data_path: /mnt/usb-data/longhorn

  tasks:
    # =========================================================================
    # SAFETY CONFIRMATION
    # =========================================================================
    - name: Display Reset Warning
      debug:
        msg: |
          ╔══════════════════════════════════════════════════════════════════╗
          ║                    ⚠️  CLUSTER RESET WARNING ⚠️                  ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║  This playbook will:                                             ║
          ║    • Reset kubeadm on ALL nodes                                  ║
          ║    • Flush ALL iptables rules                                    ║
          ║    • Delete ALL CNI configurations                               ║
          ║    • Remove ALL kube configs                                     ║
          ║                                                                  ║
          ║  Longhorn data will be: {{ 'WIPED' if wipe_storage_data else 'PRESERVED' }}
          ╚══════════════════════════════════════════════════════════════════╝

    - name: Confirm Reset
      pause:
        prompt: |
          
          ⚠️  WARNING: This will DESTROY the Kubernetes cluster on ALL nodes!
          
          Press ENTER to continue or Ctrl+C to abort...

    # =========================================================================
    # KUBERNETES RESET
    # =========================================================================
    - name: Reset Kubeadm
      command: kubeadm reset -f
      ignore_errors: yes
      register: kubeadm_reset

    - name: Display Kubeadm Reset Result
      debug:
        msg: "Kubeadm reset {{ 'succeeded' if kubeadm_reset.rc == 0 else 'had errors (continuing anyway)' }}"

    # =========================================================================
    # NETWORK CLEANUP
    # =========================================================================
    - name: Flush IPtables - Filter Table
      command: iptables -F
      ignore_errors: yes

    - name: Flush IPtables - NAT Table
      command: iptables -t nat -F
      ignore_errors: yes

    - name: Flush IPtables - Mangle Table
      command: iptables -t mangle -F
      ignore_errors: yes

    - name: Delete IPtables Chains
      command: iptables -X
      ignore_errors: yes

    - name: Flush ip6tables (if exists)
      shell: |
        ip6tables -F || true
        ip6tables -t nat -F || true
        ip6tables -X || true
      ignore_errors: yes

    # =========================================================================
    # CNI CLEANUP
    # =========================================================================
    - name: Remove CNI Configuration Directory
      file:
        path: /etc/cni/net.d
        state: absent

    - name: Remove Cilium CNI Binary
      file:
        path: /opt/cni/bin/cilium-cni
        state: absent
      ignore_errors: yes

    - name: Remove CNI Network Interfaces
      shell: |
        # Cilium interfaces
        ip link delete cilium_host 2>/dev/null || true
        ip link delete cilium_net 2>/dev/null || true
        ip link delete cilium_vxlan 2>/dev/null || true
        # IPVS interface
        ip link delete kube-ipvs0 2>/dev/null || true
        # Flannel (if ever used)
        ip link delete flannel.1 2>/dev/null || true
        ip link delete cni0 2>/dev/null || true
        # Any remaining veth interfaces
        for iface in $(ip link show | grep -oP 'lxc[a-f0-9]+' || true); do
          ip link delete $iface 2>/dev/null || true
        done
      ignore_errors: yes

    # =========================================================================
    # KUBE CONFIG CLEANUP
    # =========================================================================
    - name: Remove Root Kube Config
      file:
        path: /root/.kube
        state: absent

    - name: Remove User Kube Configs
      shell: |
        # Remove kube configs for common users
        rm -rf /home/*/.kube 2>/dev/null || true
      ignore_errors: yes

    - name: Remove Kubelet Config
      file:
        path: /etc/kubernetes
        state: absent
      ignore_errors: yes

    - name: Remove Kubelet Data
      file:
        path: /var/lib/kubelet
        state: absent
      ignore_errors: yes

    # =========================================================================
    # OPTIONAL: STORAGE DATA CLEANUP
    # =========================================================================
    - name: Wipe Longhorn Data (if requested)
      file:
        path: "{{ longhorn_data_path }}"
        state: absent
      when: wipe_storage_data | bool

    - name: Recreate Longhorn Directory (if wiped)
      file:
        path: "{{ longhorn_data_path }}"
        state: directory
        mode: '0755'
      when: wipe_storage_data | bool

    # =========================================================================
    # CLEANUP COMPLETION
    # =========================================================================
    - name: Clear containerd State (optional - keeps images)
      shell: |
        # Stop containerd temporarily
        systemctl stop containerd || true
        # Remove container state but keep images
        rm -rf /var/lib/containerd/io.containerd.runtime.v2.task/* || true
        # Restart containerd
        systemctl start containerd
      ignore_errors: yes
      when: false  # Disabled by default - enable if needed

    - name: Display Reset Complete Message
      debug:
        msg: |
          ╔══════════════════════════════════════════════════════════════════╗
          ║                    ✅ CLUSTER RESET COMPLETE                     ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║  Next Steps:                                                     ║
          ║    1. Run: ansible-playbook -i hosts playbooks/03_cluster_init.yml
          ║    2. Run: ./bootstrap/argocd/install.sh                         ║
          ║    3. Apply: kubectl apply -f gitops/root-app.yaml              ║
          ║    4. (Optional) Restore: velero restore create --from-backup   ║
          ╚══════════════════════════════════════════════════════════════════╝
```

</details>

#### Usage

```bash
# Standard reset (preserves Longhorn data)
ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml

# Reset with storage wipe (DANGER: loses all PV data!)
ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml \
    -e "wipe_storage_data=true"

# Reset single node only
ansible-playbook -i ansible/hosts ansible/playbooks/05_reset_cluster.yml \
    --limit rpi4-2
```

#### Post-Reset Recovery

```bash
# 1. Re-initialize the cluster
ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml

# 2. Install ArgoCD
./bootstrap/argocd/install.sh

# 3. Apply GitOps root application
kubectl apply -f gitops/root-app.yaml

# 4. Wait for applications to sync
watch argocd app list

# 5. (Optional) Restore from backup
velero restore create --from-backup <backup-name>
```

### 12.5 Backup & Disaster Recovery

We utilize **Velero** (installed in Phase 5) for comprehensive backup and disaster recovery capabilities.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VELERO BACKUP ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         KUBERNETES CLUSTER                          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │   │
│  │  │   Pods   │  │ Services │  │ ConfigMaps│  │    Secrets       │   │   │
│  │  │          │  │          │  │          │  │   (encrypted)    │   │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │   │
│  │       │             │             │                  │             │   │
│  │       └─────────────┴─────────────┴──────────────────┘             │   │
│  │                              │                                      │   │
│  │                              ▼                                      │   │
│  │                    ┌──────────────────┐                            │   │
│  │                    │     VELERO       │                            │   │
│  │                    │   Controller     │                            │   │
│  │                    └────────┬─────────┘                            │   │
│  └─────────────────────────────┼───────────────────────────────────────┘   │
│                                │                                            │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         MINIO S3 STORAGE                            │   │
│  │                                                                     │   │
│  │   ┌─────────────────┐    ┌─────────────────┐                       │   │
│  │   │  Cluster State  │    │  Volume Snapshots│                       │   │
│  │   │    Backups      │    │    (Longhorn)    │                       │   │
│  │   │                 │    │                  │                       │   │
│  │   │  • Deployments  │    │  • PVC Data      │                       │   │
│  │   │  • Services     │    │  • Database      │                       │   │
│  │   │  • ConfigMaps   │    │  • User Files    │                       │   │
│  │   │  • Secrets      │    │                  │                       │   │
│  │   └─────────────────┘    └─────────────────┘                       │   │
│  │            │                      │                                 │   │
│  │            └──────────┬───────────┘                                 │   │
│  │                       ▼                                             │   │
│  │            ┌──────────────────┐                                     │   │
│  │            │  velero-backups  │  ◄── S3 Bucket                     │   │
│  │            │     bucket       │                                     │   │
│  │            └──────────────────┘                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                │                                            │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    OFFSITE REPLICATION (Optional)                   │   │
│  │   MinIO ──► mc mirror ──► Cloud S3 / NAS / Remote MinIO            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Velero Commands Reference

| Operation | Command | Description |
|-----------|---------|-------------|
| **List Backups** | `velero backup get` | Show all backups |
| **Create Backup** | `velero backup create <name>` | Manual backup |
| **Describe Backup** | `velero backup describe <name>` | Backup details |
| **Download Backup** | `velero backup download <name>` | Get backup tarball |
| **Delete Backup** | `velero backup delete <name>` | Remove backup |
| **List Restores** | `velero restore get` | Show all restores |
| **Create Restore** | `velero restore create --from-backup <name>` | Restore from backup |
| **List Schedules** | `velero schedule get` | Show backup schedules |
| **Create Schedule** | `velero schedule create <name> --schedule="0 2 * * *"` | Create schedule |

#### Backup Strategies

**Strategy 1: Namespace-Based Backups**
```bash
# Backup specific namespace
velero backup create gitea-backup \
    --include-namespaces gitea \
    --ttl 720h

# Backup multiple namespaces
velero backup create apps-backup \
    --include-namespaces gitea,harbor,minio \
    --ttl 720h
```

**Strategy 2: Label-Based Backups**
```bash
# Backup resources with specific label
velero backup create critical-backup \
    --selector app.kubernetes.io/part-of=critical \
    --ttl 720h
```

**Strategy 3: Scheduled Backups**
```bash
# Nightly full cluster backup at 2 AM
velero schedule create nightly-backup \
    --schedule="0 2 * * *" \
    --ttl 168h

# Weekly namespace backup on Sundays
velero schedule create weekly-apps \
    --schedule="0 3 * * 0" \
    --include-namespaces gitea,harbor \
    --ttl 720h
```

**Strategy 4: Pre-Upgrade Backup**
```bash
# Full backup before any upgrade
velero backup create pre-upgrade-$(date +%F-%H%M) \
    --wait \
    --ttl 720h

# Verify backup completed
velero backup describe pre-upgrade-$(date +%F-%H%M) --details
```

#### Disaster Recovery Scenarios

**Scenario 1: Single Application Recovery**
```bash
# Application accidentally deleted
velero restore create gitea-restore \
    --from-backup nightly-backup \
    --include-namespaces gitea

# Monitor restore progress
velero restore describe gitea-restore
```

**Scenario 2: Full Cluster Recovery**
```bash
# Cluster completely wiped (ran 05_reset_cluster.yml)

# Step 1: Re-initialize cluster
ansible-playbook -i ansible/hosts ansible/playbooks/03_cluster_init.yml

# Step 2: Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
    --namespace velero \
    --create-namespace \
    -f velero-values.yaml

# Step 3: Wait for Velero to connect to MinIO
kubectl wait --for=condition=available deployment/velero -n velero --timeout=300s

# Step 4: Restore from backup
velero restore create full-restore --from-backup <latest-backup>

# Step 5: Monitor restoration
watch velero restore describe full-restore
```

**Scenario 3: Partial Restore (Specific Resources)**
```bash
# Restore only deployments and services
velero restore create partial-restore \
    --from-backup nightly-backup \
    --include-resources deployments,services

# Restore excluding certain namespaces
velero restore create restore-except-monitoring \
    --from-backup nightly-backup \
    --exclude-namespaces monitoring,logging
```

#### Backup Verification Script

```bash
#!/bin/bash
# verify-backups.sh - Check backup health

echo "═══════════════════════════════════════════"
echo "       VELERO BACKUP VERIFICATION          "
echo "═══════════════════════════════════════════"

# Check Velero is running
echo -e "\n[1] Velero Status:"
kubectl get pods -n velero

# List recent backups
echo -e "\n[2] Recent Backups:"
velero backup get --output=table | head -10

# Check for failed backups
echo -e "\n[3] Failed Backups:"
FAILED=$(velero backup get -o json | jq -r '.items[] | select(.status.phase=="Failed") | .metadata.name')
if [ -z "$FAILED" ]; then
    echo "✓ No failed backups"
else
    echo "⚠ Failed backups found:"
    echo "$FAILED"
fi

# Check backup storage location
echo -e "\n[4] Backup Storage Location:"
velero backup-location get

# Check latest backup age
echo -e "\n[5] Latest Backup Age:"
LATEST=$(velero backup get -o json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
if [ -n "$LATEST" ]; then
    velero backup describe "$LATEST" | grep -E "Started|Completed|Expiration"
fi

echo -e "\n═══════════════════════════════════════════"
```

### 12.6 Troubleshooting Cheatsheet

A comprehensive guide to diagnosing and resolving common issues in your Raspberry Pi Kubernetes cluster.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TROUBLESHOOTING DECISION TREE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         ┌──────────────────┐                                │
│                         │  What's broken?  │                                │
│                         └────────┬─────────┘                                │
│                                  │                                          │
│       ┌────────────┬─────────────┼─────────────┬────────────┐              │
│       ▼            ▼             ▼             ▼            ▼              │
│  ┌─────────┐ ┌─────────┐ ┌───────────┐ ┌──────────┐ ┌──────────┐          │
│  │   Pod   │ │ Network │ │  Storage  │ │  Node    │ │  ArgoCD  │          │
│  │ Issues  │ │ Issues  │ │  Issues   │ │ Issues   │ │  Issues  │          │
│  └────┬────┘ └────┬────┘ └─────┬─────┘ └────┬─────┘ └────┬─────┘          │
│       │           │            │            │            │                 │
│       ▼           ▼            ▼            ▼            ▼                 │
│  • describe   • cilium    • longhorn   • journalctl • app sync            │
│  • logs         status      ui         • kubelet   • app diff             │
│  • events     • hubble    • pvc        • dmesg     • refresh              │
│  • exec         observe     status     • top       • hard-refresh         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Quick Reference Table

| Category | Symptom | Diagnostic Command | Common Fix |
|----------|---------|-------------------|------------|
| **Pods** | CrashLoopBackOff | `kubectl logs <pod> --previous` | Check app config/resources |
| **Pods** | Pending | `kubectl describe pod <pod>` | Check resources/affinity |
| **Pods** | ImagePullBackOff | `kubectl describe pod <pod>` | Check image name/registry |
| **Network** | No connectivity | `cilium connectivity test` | Restart Cilium pods |
| **Network** | DNS failures | `nslookup kubernetes.default` | Check CoreDNS pods |
| **Network** | Service unreachable | `kubectl get endpoints` | Check selector/ports |
| **Storage** | PVC Pending | `kubectl describe pvc` | Check Longhorn status |
| **Storage** | Volume full | Longhorn UI | Expand PVC or cleanup |
| **Node** | NotReady | `kubectl describe node` | Check kubelet logs |
| **Node** | High CPU/Memory | `kubectl top nodes` | Drain and investigate |
| **ArgoCD** | Sync failed | `argocd app sync --prune` | Check diff and resources |
| **ArgoCD** | OutOfSync | `argocd app diff` | Review changes |

#### Detailed Troubleshooting Commands

**Pod Troubleshooting**
```bash
# Get pod status and events
kubectl describe pod <pod-name> -n <namespace>

# View current logs
kubectl logs <pod-name> -n <namespace>

# View previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# Follow logs in real-time
kubectl logs -f <pod-name> -n <namespace>

# Exec into pod for debugging
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Get all pods with issues
kubectl get pods -A | grep -v Running | grep -v Completed

# Check resource usage
kubectl top pod <pod-name> -n <namespace>
```

**Network Troubleshooting**
```bash
# Cilium status
cilium status

# Full connectivity test
cilium connectivity test

# Watch network flows
hubble observe --follow

# DNS test
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default

# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v http://<service>.<namespace>.svc.cluster.local

# Check Cilium endpoints
kubectl get ciliumendpoints -A

# View network policies
kubectl get networkpolicies -A
```

**Storage Troubleshooting**
```bash
# Check PVC status
kubectl get pvc -A

# Describe problematic PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn nodes
kubectl get nodes.longhorn.io -n longhorn-system

# Access Longhorn UI
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80

# Check disk pressure
df -h /mnt/usb-data/longhorn

# List Longhorn replicas
kubectl get replicas.longhorn.io -n longhorn-system
```

**Node Troubleshooting**
```bash
# Get node status
kubectl get nodes -o wide

# Describe node issues
kubectl describe node <node-name>

# Check kubelet logs (on node)
sudo journalctl -u kubelet -f

# Check system logs
sudo dmesg | tail -50

# Check resource usage
kubectl top nodes

# Check node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Cordon node (prevent scheduling)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

**ArgoCD Troubleshooting**
```bash
# Check application status
argocd app get <app-name>

# View sync status
argocd app list

# Force sync with prune
argocd app sync <app-name> --prune --force

# View application diff
argocd app diff <app-name>

# Refresh application
argocd app get <app-name> --refresh

# Hard refresh (clear cache)
argocd app get <app-name> --hard-refresh

# View application logs
argocd app logs <app-name>

# Delete and recreate stuck app
argocd app delete <app-name>
kubectl apply -f gitops/<path-to-app>.yaml
```

**Certificate Troubleshooting**
```bash
# Check certificates
kubectl get certificates -A

# Describe certificate issues
kubectl describe certificate <cert-name> -n <namespace>

# Check certificate requests
kubectl get certificaterequests -A

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check secret containing cert
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### 12.7 Operational Runbooks

Standardized procedures for common operational tasks.

#### Runbook: Adding a New Worker Node

```bash
# 1. Prepare the new node (rpi4-5)
# Add to ansible/hosts under [workers]

# 2. Run node preparation
ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml --limit rpi4-5

# 3. Install K8s binaries
ansible-playbook -i ansible/hosts ansible/playbooks/02_k8s_binaries.yml --limit rpi4-5

# 4. Get join command from control plane
ssh rpi4-1 "sudo kubeadm token create --print-join-command"

# 5. Run join command on new node
ssh rpi4-5 "sudo <join-command>"

# 6. Label the new node
kubectl label node rpi4-5 node-role.kubernetes.io/worker=worker

# 7. Verify node joined
kubectl get nodes
```

#### Runbook: Replacing a Failed SD Card

```bash
# 1. Flash new SD card with Raspberry Pi OS Lite (64-bit)

# 2. Boot node and configure SSH access

# 3. Run Ansible playbooks
ansible-playbook -i ansible/hosts ansible/playbooks/01_node_prep.yml --limit <node>
ansible-playbook -i ansible/hosts ansible/playbooks/02_k8s_binaries.yml --limit <node>

# 4. If control plane - restore from etcd backup
# If worker - rejoin cluster with new token

# 5. Verify node health
kubectl get nodes
kubectl get pods -A -o wide | grep <node>
```

#### Runbook: Handling Memory Pressure

```bash
# 1. Identify high-memory pods
kubectl top pods -A --sort-by=memory | head -20

# 2. Check for memory leaks
kubectl describe node <node> | grep -A5 "Allocated resources"

# 3. Temporary relief - restart problematic pods
kubectl rollout restart deployment/<deployment> -n <namespace>

# 4. Long-term fix - adjust resource limits
kubectl edit deployment <deployment> -n <namespace>
# Increase limits.memory or add requests.memory

# 5. Consider adding more workers or reducing replicas
```

### 12.8 Health Check Script

A comprehensive cluster health verification script.

```bash
#!/bin/bash
# cluster-health.sh - Comprehensive cluster health check
# Usage: ./cluster-health.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              KUBERNETES CLUSTER HEALTH CHECK                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

check_pass() { ((PASSED++)); echo -e "${GREEN}✓ PASS${NC}: $1"; }
check_fail() { ((FAILED++)); echo -e "${RED}✗ FAIL${NC}: $1"; }
check_warn() { ((WARNINGS++)); echo -e "${YELLOW}⚠ WARN${NC}: $1"; }

# ============================================================================
echo -e "\n[1/8] NODE STATUS"
echo "────────────────────────────────────────"
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    check_pass "All nodes are Ready"
    kubectl get nodes -o wide
else
    check_fail "$NOT_READY node(s) not Ready"
    kubectl get nodes | grep -v " Ready"
fi

# ============================================================================
echo -e "\n[2/8] SYSTEM PODS (kube-system)"
echo "────────────────────────────────────────"
FAILED_PODS=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ "$FAILED_PODS" -eq 0 ]; then
    check_pass "All kube-system pods healthy"
else
    check_fail "$FAILED_PODS kube-system pod(s) unhealthy"
    kubectl get pods -n kube-system | grep -v "Running\|Completed"
fi

# ============================================================================
echo -e "\n[3/8] CILIUM CNI STATUS"
echo "────────────────────────────────────────"
if cilium status --wait=false 2>/dev/null | grep -q "OK"; then
    check_pass "Cilium is healthy"
else
    check_fail "Cilium has issues"
    cilium status 2>/dev/null || echo "Cilium CLI not available"
fi

# ============================================================================
echo -e "\n[4/8] STORAGE (Longhorn)"
echo "────────────────────────────────────────"
LH_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
if [ "$LH_PODS" -eq 0 ]; then
    check_pass "Longhorn pods healthy"
else
    check_warn "$LH_PODS Longhorn pod(s) unhealthy"
fi

PENDING_PVC=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -i pending | wc -l)
if [ "$PENDING_PVC" -eq 0 ]; then
    check_pass "No pending PVCs"
else
    check_warn "$PENDING_PVC PVC(s) pending"
fi

# ============================================================================
echo -e "\n[5/8] ARGOCD STATUS"
echo "────────────────────────────────────────"
ARGO_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -v "Running" | wc -l)
if [ "$ARGO_PODS" -eq 0 ]; then
    check_pass "ArgoCD pods healthy"
else
    check_fail "$ARGO_PODS ArgoCD pod(s) unhealthy"
fi

# Check for OutOfSync apps
OUTOFSYNC=$(argocd app list -o json 2>/dev/null | jq -r '.[] | select(.status.sync.status!="Synced") | .metadata.name' | wc -l)
if [ "$OUTOFSYNC" -eq 0 ]; then
    check_pass "All ArgoCD apps synced"
else
    check_warn "$OUTOFSYNC app(s) out of sync"
fi

# ============================================================================
echo -e "\n[6/8] CERTIFICATES"
echo "────────────────────────────────────────"
CERT_ISSUES=$(kubectl get certificates -A -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[]?.status!="True") | .metadata.name' | wc -l)
if [ "$CERT_ISSUES" -eq 0 ]; then
    check_pass "All certificates valid"
else
    check_warn "$CERT_ISSUES certificate(s) have issues"
fi

# ============================================================================
echo -e "\n[7/8] RESOURCE UTILIZATION"
echo "────────────────────────────────────────"
echo "Node Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics not available"

# Check for nodes with high usage
HIGH_CPU=$(kubectl top nodes --no-headers 2>/dev/null | awk '{gsub(/%/,"",$3); if($3>80) print $1}' | wc -l)
if [ "$HIGH_CPU" -gt 0 ]; then
    check_warn "$HIGH_CPU node(s) with CPU > 80%"
else
    check_pass "CPU utilization normal"
fi

# ============================================================================
echo -e "\n[8/8] BACKUP STATUS (Velero)"
echo "────────────────────────────────────────"
VELERO_OK=$(kubectl get pods -n velero --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$VELERO_OK" -gt 0 ]; then
    check_pass "Velero is running"
    LAST_BACKUP=$(velero backup get -o json 2>/dev/null | jq -r '.items | sort_by(.status.completionTimestamp) | last | .metadata.name // "none"')
    echo "  Last backup: $LAST_BACKUP"
else
    check_warn "Velero not running"
fi

# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                         SUMMARY                                  ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  ${GREEN}Passed: %2d${NC}  │  ${YELLOW}Warnings: %2d${NC}  │  ${RED}Failed: %2d${NC}                   ║\n" $PASSED $WARNINGS $FAILED
echo "╚══════════════════════════════════════════════════════════════════╝"

if [ "$FAILED" -gt 0 ]; then
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    exit 0
else
    exit 0
fi
```

Save as `tests/07_operations_test.sh` and run regularly:
```bash
chmod +x tests/07_operations_test.sh
./tests/07_operations_test.sh
```

### 12.9 Secrets Migration to OpenBao

This guide initially deploys services with **default credentials** (e.g., `password123` for MinIO, `Harbor12345` for Harbor) to simplify the bootstrap process. For production use, these credentials should be rotated and stored in OpenBao (a community-maintained fork of HashiCorp Vault).

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SECRETS MIGRATION WORKFLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CURRENT STATE (Bootstrap)                                                  │
│  ─────────────────────────                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │   MinIO     │    │   Harbor    │    │    Loki     │                     │
│  │ password123 │    │ Harbor12345 │    │ password123 │                     │
│  │  (inline)   │    │  (inline)   │    │  (inline)   │                     │
│  └─────────────┘    └─────────────┘    └─────────────┘                     │
│                                                                             │
│  TARGET STATE (Production)                                                  │
│  ─────────────────────────                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          OpenBao                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  secret/minio     → rootUser, rootPassword                  │   │   │
│  │  │  secret/harbor    → adminPassword, secretKey                │   │   │
│  │  │  secret/loki      → s3AccessKey, s3SecretKey               │   │   │
│  │  │  secret/velero    → awsAccessKey, awsSecretKey             │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │                                         │
│                                  ▼                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │   MinIO     │    │   Harbor    │    │    Loki     │                     │
│  │ K8s Secret  │◄───│ K8s Secret  │◄───│ K8s Secret  │                     │
│  │(from Bao)   │    │(from Bao)   │    │(from Bao)   │                     │
│  └─────────────┘    └─────────────┘    └─────────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Prerequisites

1. **OpenBao deployed and initialized** (Phase 5)
2. **External Secrets Operator** (optional, for automatic sync)
3. **kubectl access** to the cluster

#### Step 1: Initialize OpenBao

```bash
# Port-forward to OpenBao
kubectl port-forward svc/openbao -n openbao 8200:8200 &
export VAULT_ADDR='http://127.0.0.1:8200'

# Initialize OpenBao (first time only - SAVE THESE KEYS!)
bao operator init -key-shares=1 -key-threshold=1

# Example output (SAVE THIS!):
# Unseal Key 1: <your-unseal-key>
# Initial Root Token: <your-root-token>

# Unseal OpenBao
bao operator unseal <your-unseal-key>

# Login with root token
export VAULT_TOKEN='<your-root-token>'
bao login $VAULT_TOKEN
```

#### Step 2: Enable KV Secrets Engine

```bash
# Enable KV v2 secrets engine
bao secrets enable -path=secret kv-v2
```

#### Step 3: Store New Credentials in OpenBao

```bash
# Generate strong passwords (or use your own)
MINIO_PASSWORD=$(openssl rand -base64 24)
HARBOR_PASSWORD=$(openssl rand -base64 24)
HARBOR_SECRET=$(openssl rand -base64 24)

# Store MinIO credentials
bao kv put secret/minio \
  rootUser="admin" \
  rootPassword="$MINIO_PASSWORD"

# Store Harbor credentials  
bao kv put secret/harbor \
  adminPassword="$HARBOR_PASSWORD" \
  secretKey="$HARBOR_SECRET"

# Store Velero/Loki S3 credentials (same as MinIO)
bao kv put secret/s3 \
  accessKey="admin" \
  secretKey="$MINIO_PASSWORD"

# Verify secrets stored
bao kv get secret/minio
bao kv get secret/harbor
bao kv get secret/s3

# IMPORTANT: Save these passwords somewhere secure!
echo "MinIO Password: $MINIO_PASSWORD"
echo "Harbor Password: $HARBOR_PASSWORD"
```

#### Step 4: Update MinIO Password

```bash
# Get current MinIO password from OpenBao
NEW_MINIO_PASS=$(bao kv get -field=rootPassword secret/minio)

# Update MinIO secret in Kubernetes
kubectl create secret generic minio-credentials \
  --from-literal=rootUser=admin \
  --from-literal=rootPassword="$NEW_MINIO_PASS" \
  -n storage --dry-run=client -o yaml | kubectl apply -f -

# Restart MinIO to pick up new credentials
kubectl rollout restart deployment/minio -n storage

# Wait for MinIO to be ready
kubectl rollout status deployment/minio -n storage
```

#### Step 5: Update Harbor Password

```bash
# Get new Harbor password from OpenBao
NEW_HARBOR_PASS=$(bao kv get -field=adminPassword secret/harbor)
NEW_HARBOR_SECRET=$(bao kv get -field=secretKey secret/harbor)

# Update Harbor core secret
kubectl create secret generic harbor-core \
  --from-literal=HARBOR_ADMIN_PASSWORD="$NEW_HARBOR_PASS" \
  --from-literal=secretKey="$NEW_HARBOR_SECRET" \
  -n harbor --dry-run=client -o yaml | kubectl apply -f -

# Restart Harbor components
kubectl rollout restart deployment -n harbor
```

#### Step 6: Update Dependent Services

Services that connect to MinIO need the new credentials:

```bash
# Get S3 credentials
S3_ACCESS=$(bao kv get -field=accessKey secret/s3)
S3_SECRET=$(bao kv get -field=secretKey secret/s3)

# Update Loki S3 credentials
kubectl create secret generic loki-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET" \
  -n observability --dry-run=client -o yaml | kubectl apply -f -

# Update Velero S3 credentials
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: velero-s3-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id = $S3_ACCESS
    aws_secret_access_key = $S3_SECRET
EOF

# Restart affected services (Reloader will handle this if annotated)
kubectl rollout restart deployment/loki -n observability
kubectl rollout restart deployment/velero -n velero
```

#### Step 7: Verify Services

```bash
# Test MinIO access with new credentials
kubectl exec -n storage deploy/minio -- mc alias set myminio http://localhost:9000 admin "$NEW_MINIO_PASS"
kubectl exec -n storage deploy/minio -- mc ls myminio/

# Test Harbor login
echo "$NEW_HARBOR_PASS" | docker login harbor.192.168.0.210.nip.io -u admin --password-stdin

# Check all pods are running
kubectl get pods -n storage
kubectl get pods -n harbor
kubectl get pods -n observability
kubectl get pods -n velero
```

#### (Optional) Step 8: Set Up External Secrets Operator

For automatic secret synchronization from OpenBao to Kubernetes:

```bash
# Install External Secrets Operator via Helm
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Create ClusterSecretStore pointing to OpenBao
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: openbao
spec:
  provider:
    vault:
      server: "http://openbao.openbao.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: openbao-token
          namespace: external-secrets
          key: token
EOF

# Create ExternalSecret for MinIO (example)
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: minio-credentials
  namespace: storage
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: openbao
  target:
    name: minio-credentials
  data:
    - secretKey: rootUser
      remoteRef:
        key: secret/data/minio
        property: rootUser
    - secretKey: rootPassword
      remoteRef:
        key: secret/data/minio
        property: rootPassword
EOF
```

#### Security Checklist

| Task | Status |
|------|--------|
| OpenBao initialized and unsealed | ☐ |
| Root token stored securely (not in cluster!) | ☐ |
| MinIO password rotated | ☐ |
| Harbor password rotated | ☐ |
| Loki S3 credentials updated | ☐ |
| Velero S3 credentials updated | ☐ |
| Default passwords removed from GitOps manifests | ☐ |
| Services verified working | ☐ |

> ⚠️ **Important:** After migrating secrets, update your GitOps manifests to reference Kubernetes Secrets instead of inline values. This prevents ArgoCD from overwriting your rotated credentials on the next sync.

---

### 12.10 Component Cleanup Commands

Unlike the nuclear `05_reset_cluster.yml`, these commands allow **clean removal of individual components** without destroying the entire cluster.

#### Cleanup via ArgoCD (Recommended)

For components managed by ArgoCD, use the ArgoCD CLI or UI:

```bash
# Delete an ArgoCD Application (this cleans up all its resources)
argocd app delete <app-name> --cascade

# Examples:
argocd app delete fluent-bit --cascade    # Remove Fluent Bit
argocd app delete kubeshark --cascade     # Remove Kubeshark (frees up memory!)
argocd app delete opencost --cascade      # Remove OpenCost

# To prevent ArgoCD from redeploying, first disable auto-sync:
argocd app set <app-name> --sync-policy none
argocd app delete <app-name> --cascade
```

#### Cleanup via Helm (Bootstrap Components)

For manually bootstrapped components:

```bash
# List all Helm releases
helm list -A

# Uninstall bootstrap components (reverse order!)
helm uninstall argocd -n argocd          # ⚠️ This removes GitOps!
helm uninstall traefik -n traefik
helm uninstall metrics-server -n kube-system
helm uninstall longhorn -n longhorn-system  # ⚠️ Data loss warning!

# After Helm uninstall, clean up leftover resources
kubectl delete namespace argocd
kubectl delete namespace traefik
kubectl delete namespace longhorn-system
```

#### Cleanup Specific Components

| Component | Cleanup Commands |
|-----------|------------------|
| **Prometheus Stack** | `helm uninstall kube-prometheus-stack -n monitoring` |
| **Loki Stack** | `helm uninstall loki-stack -n logging` |
| **Velero** | `helm uninstall velero -n velero` |
| **Harbor** | `helm uninstall harbor -n harbor` |
| **Cert-Manager** | `helm uninstall cert-manager -n cert-manager; kubectl delete namespace cert-manager` |
| **Kyverno** | `helm uninstall kyverno -n kyverno; kubectl delete -f https://github.com/kyverno/kyverno/releases/download/v1.11.0/install.yaml` |

#### Cleanup CRDs

Some components leave CRDs behind. Remove them manually:

```bash
# List CRDs by component prefix
kubectl get crds | grep -E "cert-manager|kyverno|velero|longhorn|argo"

# Delete CRDs (⚠️ This removes all resources of that type!)
kubectl delete crds --selector=app.kubernetes.io/name=cert-manager
kubectl delete crds --selector=app.kubernetes.io/name=kyverno

# Or delete individual CRDs
kubectl delete crd certificates.cert-manager.io
kubectl delete crd clusterpolicies.kyverno.io
```

#### Cleanup PVCs and Data

```bash
# List all PVCs
kubectl get pvc -A

# Delete PVCs (⚠️ Data loss!)
kubectl delete pvc <pvc-name> -n <namespace>

# Force delete stuck PVCs
kubectl patch pvc <pvc-name> -n <namespace> -p '{"metadata":{"finalizers":null}}'
kubectl delete pvc <pvc-name> -n <namespace> --force

# Clean Longhorn volumes directly
kubectl delete volumes.longhorn.io -n longhorn-system --all
```

> **⚠️ Important:** Before removing components, ensure:
> 1. No other components depend on it
> 2. Data is backed up (for storage components)
> 3. ArgoCD auto-sync is disabled (to prevent redeployment)
