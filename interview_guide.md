# DevOps Platform Engineering: Interview Guide & Phase Logs
## Project: Full GitOps EKS Platform

> **Purpose**: This living document captures everything done in each phase of this project. It translates hands-on terminal commands and infrastructure configurations into **senior-level interview answers**, STAR-format pitches, and architectural rationale.
> 
> *A new section will be added to this document upon completion of each phase.*

---

## Phase 1: Environment Baseline, Toolchain Audit & Day-Zero Security

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: Starting an enterprise-grade cloud platform from scratch requires a stable local toolchain, secure repository boundaries, and clear architectural consensus before provisioning any cloud infrastructure.
* **Task**: Prepare the development environment, audit all required platform engineering tools, connect to remote version control, enforce day-zero credential protection, and establish the Architecture Decision Record (ADR).
* **Action**:
  1. Authoring an ADR (`decision.md`) detailing the trade-offs of choosing EKS, Terraform, ArgoCD, and Prometheus, along with strict cost-containment rules.
  2. Establishing upstream Git tracking with `https://github.com/deadboltt/DevOps_Project` and configuring an enterprise `.gitignore` to block `.tfstate`, AWS credentials, and `kubeconfig` files.
  3. Programmatically auditing the toolchain (`aws-cli`, `terraform`, `kubectl`, `docker`), verifying AWS credentials non-destructively via `aws sts get-caller-identity` in `ap-south-1`, and provisioning missing tools (`Helm v4`) via Windows Package Manager.
* **Result**: Zero-friction setup with validated AWS IAM connectivity, hardened repository security, and full tooling readiness for infrastructure provisioning.

---

### 2. Key Actions & The Architectural "Why"

| Step | Action Taken | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **1. Architecture Decision Record** | Created `decision.md` before writing code | Jumping straight into cloud consoles leads to architectural drift and unbudgeted costs. An ADR aligns requirements, justifies technology choices (e.g., pull-based GitOps vs push-based CI), and documents DORA metrics. |
| **2. Day-Zero Security Hygiene** | Configured `.gitignore` for `.tfstate`, `.aws/`, `*.pem`, and `kubeconfig` | Terraform state files store unencrypted variables and secrets. Committing state files or cloud keys to public GitHub repositories is the #1 cause of cloud credential compromises. |
| **3. Remote Sync & Branch Tracking** | Initialized Git, linked remote origin, and tracked `master` | Ensures all future code, Helm charts, and CI/CD pipelines have clean upstream tracking with zero detached-HEAD states or merge bottlenecks. |
| **4. Non-Destructive IAM Audit** | Executed `aws sts get-caller-identity` | Validates that local AWS credentials work, confirms the active IAM user (`Project1`) and Account ID (`926753675443`), without performing any mutating API calls or risking infrastructure state. |
| **5. Toolchain Audit & Provisioning** | Verified Terraform, kubectl, Docker; installed Helm v4 | Modern Kubernetes workloads are rarely deployed as bare YAML manifests. Helm acts as the package manager for Kubernetes operators (ArgoCD, Prometheus). Catching and installing missing tools early prevents mid-pipeline failures. |

---

### 3. Command Reference Used in Phase 1

```powershell
# 1. Initialize Git and link upstream
git init
git remote add origin https://github.com/deadboltt/DevOps_Project.git
git fetch origin
git checkout -b master origin/master

# 2. Verify AWS Identity and active Region
aws sts get-caller-identity
aws configure get region

# 3. Audit Installed Platform Engineering Toolchain
aws --version          # AWS CLI v2.36.21
terraform -version     # Terraform v1.16.2
kubectl version --client # kubectl v1.36.1
docker --version       # Docker v29.7.2

# 4. Install Helm Package Manager
winget install -e --id Helm.Helm --accept-source-agreements --accept-package-agreements
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "Why do you use an Architecture Decision Record (ADR)?"
* **Junior Answer**: *"To write notes about what tools we are using."*
* **Senior Answer**: *"An ADR captures the architectural context, evaluated alternatives, and deliberate trade-offs of a decision at a specific point in time. For example, our ADR explains why we chose pull-based GitOps with ArgoCD over push-based pipelines (eliminating the need to store cluster admin credentials in CI and providing automatic drift detection), and it outlines our AWS cost-control strategy."*

#### Q2: "Why is `.gitignore` considered a security tool in DevOps?"
* **Junior Answer**: *"It keeps the repository clean from junk files."*
* **Senior Answer**: *"In Infrastructure as Code, `.gitignore` is a primary defense against credential leaks. Terraform state files (`.tfstate`) often contain database passwords, API tokens, and IAM secret keys in plaintext. By enforcing `.gitignore` before writing any infrastructure code, we guarantee that local state files and cloud keys never leak to version control."*

#### Q3: "What is the difference between `kubectl` and `Helm`?"
* **Junior Answer**: *"They both deploy apps to Kubernetes."*
* **Senior Answer**: *"`kubectl` is the raw client CLI used to interact directly with the Kubernetes API server for individual declarative manifests. `Helm` is the package manager for Kubernetes. It introduces templating, parameterized `values.yaml`, dependency management, and release versioning with rollback capabilities. We use `kubectl` for ad-hoc debugging and `Helm` for deploying complex third-party operators like ArgoCD and the Prometheus monitoring stack."*

---

## Roadmap of Upcoming Phases (To Be Documented):
- **Phase 2**: Infrastructure as Code — AWS VPC, IAM & EKS Cluster via Terraform
- **Phase 3**: Microservice Application Development, Health Probes & Multi-Stage Dockerfile
- **Phase 4**: Automated CI Pipeline (GitLab CI / GitHub Actions) & Security Scanning (Trivy)
- **Phase 5**: GitOps Deployment Engine — ArgoCD Installation & Application Syncing
- **Phase 6**: Observability Stack — Prometheus Operator, Grafana Dashboards & Slack Alertmanager
- **Phase 7**: End-to-End Validation, MTTR Benchmark & Portfolio Documentation
