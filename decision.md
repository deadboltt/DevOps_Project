# Architecture & Engineering Decisions Record (ADR)
## Project: Full GitOps EKS Platform (Production Flagship)

This document tracks all foundational architecture, tooling, security, and cost decisions for the **Full GitOps EKS Platform**. It serves as an immutable reference and portfolio explanation of why each technology was chosen.

---

## 1. High-Level Architecture Overview

```mermaid
flowchart TD
    subgraph Developer_Workflow [1. Development & Version Control]
        Dev([Developer]) -->|Push Code| AppRepo[App Source Repo / GitLab]
        Dev -->|Push Manifests| ConfigRepo[GitOps Config Repo / K8s Manifests]
    end

    subgraph CI_Pipeline [2. Continuous Integration - GitLab CI]
        AppRepo -->|Trigger| TestJob[Lint & Unit Tests]
        TestJob -->|Pass| BuildJob[Docker Build & Trivy Scan]
        BuildJob -->|Push Image| Registry[Container Registry: ECR / Docker Hub]
        BuildJob -->|Update Image Tag| ConfigRepo
    end

    subgraph IaC [3. Infrastructure as Code - Terraform]
        TF[Terraform] -->|Provision| VPC[AWS VPC: Public/Private Subnets + NAT]
        TF -->|Provision| IAM[IAM Roles for Service Accounts - IRSA]
        TF -->|Provision| EKS[Amazon EKS Cluster: Control Plane + Managed Node Group]
    end

    subgraph CD_GitOps [4. GitOps Continuous Delivery - ArgoCD]
        EKS -->|Runs| ArgoCD[ArgoCD Controller]
        ConfigRepo -.->|Poll & Sync (Declarative)| ArgoCD
        ArgoCD -->|Deploy / Rollout| K8sWorkload[Application Pods & Services]
    end

    subgraph Observability [5. Observability & Alerting]
        EKS -->|Runs| Prom[Prometheus Operator]
        Prom -->|Scrapes Metrics| K8sWorkload
        Prom -->|Metrics Source| Grafana[Grafana Dashboards]
        Prom -->|Trigger Alert| AlertManager[Alertmanager]
        AlertManager -->|Webhook Notification| Slack[#alerts Slack Channel]
    end
```

---

## 2. Technology Selection & Rationale

| Layer | Technology Selected | Why It Was Chosen | Alternatives Considered | Trade-off / Decision |
| :--- | :--- | :--- | :--- | :--- |
| **Cloud Provider** | **AWS (Amazon Web Services)** | Global industry standard; deepest enterprise Kubernetes integration via EKS. | GCP (GKE), Azure (AKS) | EKS has a fixed control plane cost ($0.10/hr), requiring strict teardown discipline during learning. |
| **Infrastructure as Code** | **Terraform** | Declarative, cloud-agnostic, massive community modules (`terraform-aws-modules/eks`). | CloudFormation, Pulumi | Terraform requires careful state management (S3 + DynamoDB locking). |
| **Container Platform** | **Amazon EKS (Kubernetes v1.30+)** | Production-standard orchestration; demonstrates mastery of controllers, RBAC, and cloud networking. | AWS ECS, Standalone EC2 | EKS is more complex than ECS, but represents what enterprise Platform Engineers build. |
| **Continuous Integration** | **GitLab CI** (or GitHub Actions) | Built-in container registry, robust matrix builds, native Kubernetes integration. | Jenkins, CircleCI | GitLab CI YAML pipelines are modern and reproducible; Jenkins adds high server maintenance overhead. |
| **GitOps Continuous Delivery**| **ArgoCD** | Pull-based deployment model: cluster pulls state from Git rather than CI having cluster admin credentials. | FluxCD, Jenkins push deployment | ArgoCD provides an intuitive web UI for visualization and instant rollback diffs. |
| **Observability** | **Prometheus + Grafana (kube-prometheus-stack)** | The defacto cloud-native monitoring standard; rich PromQL query ecosystem and pre-built Grafana dashboards. | Datadog, AWS CloudWatch | Datadog is expensive; Prometheus stack is open-source and native to Kubernetes. |
| **Alerting** | **Alertmanager → Slack** | Immediate chatops feedback loop for platform errors and pod crashloops. | PagerDuty, Email | Slack webhooks are free, fast to integrate, and visually clear for portfolio demos. |

---

## 3. Critical Strategy Decisions

### Decision 1: Pull-based GitOps (ArgoCD) vs Push-based CI
- **Choice**: **Pull-based GitOps via ArgoCD**.
- **Rationale**: 
  1. **Security**: GitLab CI never needs AWS credentials or `kubectl` access into our private EKS cluster.
  2. **Drift Detection**: If someone manually edits a pod or service with `kubectl edit`, ArgoCD flags the drift and reconciles it back to Git state.
  3. **Instant Rollback**: Rolling back to a previous version is simply a `git revert` in the manifest repository.

### Decision 2: Managed Node Groups vs Self-Managed EC2
- **Choice**: **AWS EKS Managed Node Groups**.
- **Rationale**: AWS automates OS patches, security updates, and node drain procedures during Kubernetes upgrades, reducing maintenance operational overhead.

### Decision 3: Cost-Control Safety Strategy (Crucial for Learning)
- **Problem**: Running an EKS cluster continuously costs:
  - EKS Control Plane: ~$73/month ($0.10/hour).
  - 2x `t3.medium` EC2 instances: ~$60/month.
  - NAT Gateway: ~$32/month.
- **Decision**:
  1. Use modular Terraform scripts with a single automated destroy command (`terraform destroy`).
  2. Maintain a `scripts/teardown.sh` script to prevent unexpected cloud bills.
  3. For zero-cost local prototyping, validate the exact same Helm/ArgoCD manifests using a local **KinD (Kubernetes in Docker)** or **Minikube** cluster before pushing to AWS.

### Decision 4: Separation of Repositories (App vs GitOps Manifests)
- **Choice**: Two distinct repositories or isolated directories:
  1. **App Repository**: Application source code, unit tests, and `Dockerfile`.
  2. **GitOps Manifest Repository**: Declarative Kubernetes manifests / Helm charts, ArgoCD application definition.
- **Rationale**: Prevents infinite CI loops (committing a new image tag doesn't trigger application rebuilds).

---

## 4. Key Metrics to Measure & Document in the Portfolio

To present this as a senior-tier flagship platform project, the following metrics will be tracked and documented in the final `README.md`:

| Metric | Target | How It Is Measured |
| :--- | :--- | :--- |
| **Deployment Frequency** | Automated on every merge to `main` | GitLab CI pipeline completion + ArgoCD sync time |
| **Lead Time for Changes** | < 5 minutes | Time from git commit to pod running healthy in cluster |
| **Mean Time to Recovery (MTTR)** | < 60 seconds | One-click or `git revert` rollback via ArgoCD |
| **Cluster Health & Uptime** | 99.9% | Prometheus Golden Signals (Error rate, Latency, Saturation) |
