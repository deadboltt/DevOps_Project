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

## Phase 2: Infrastructure as Code — AWS VPC, IAM & EKS via Terraform

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: Production Kubernetes workloads cannot run in default networks or on untagged subnets. They require isolated networking across multiple Availability Zones, least-privilege IAM policies, and declarative lifecycle management.
* **Task**: Design and implement modular Terraform infrastructure to provision an AWS VPC with public and private subnets, IAM roles for control plane and worker nodes, an OIDC provider for IRSA, and an Amazon EKS cluster with managed node groups.
* **Action**:
  1. Built modular Terraform configs (`vpc.tf`, `iam.tf`, `eks.tf`, `outputs.tf`) targeting `ap-south-1`.
  2. Isolated worker nodes strictly in 3 private subnets across 3 AZs, while public subnets handle ingress ALBs.
  3. Configured Kubernetes-native AWS tags (`kubernetes.io/role/elb = 1` and `kubernetes.io/role/internal-elb = 1`) to enable dynamic load balancer discovery.
  4. Established an IAM OIDC Identity Provider to enable IAM Roles for Service Accounts (IRSA), eliminating hardcoded cloud credentials in pods.
  5. Implemented cost-containment engineering: single NAT Gateway for development, optional Spot instances, and automated `deploy.ps1` and `teardown.ps1` scripts.
* **Result**: A 100% validated, declarative infrastructure ready for reproducible provisioning and clean zero-leak teardown.

---

### 2. Key Actions & The Architectural "Why"

| Component | Architectural Decision | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **Private Subnets for Nodes** | Deployed worker nodes only in private subnets with no public IPs | **Defense in Depth**: Kubernetes nodes run container runtimes and host processes that should never be reachable from the public internet. Only managed ingress (ALB) in public subnets routes traffic inward. |
| **Subnet Discovery Tags** | Added `kubernetes.io/role/elb = 1` on public subnets | The AWS Load Balancer Controller relies on this exact tag to dynamically discover which subnets are allowed to host internet-facing Application Load Balancers without hardcoding subnet IDs. |
| **Single NAT Gateway in Dev** | Deployed 1 NAT Gateway instead of 3 (one per AZ) | AWS charges ~$32/month per NAT Gateway plus data transfer. In development, a single shared NAT in AZ-a routes egress traffic for all private subnets, saving ~$64/month while preserving security isolation. |
| **IAM OIDC & IRSA** | Configured `aws_iam_openid_connect_provider` on the EKS cluster | **Security Best Practice**: Pods should never use long-lived AWS IAM access keys stored in Kubernetes Secrets. IRSA uses OpenID Connect (OIDC) federation to inject short-lived, auto-rotated STS tokens directly into service accounts. |
| **Automated Teardown Script** | Built `scripts/teardown.ps1` (`terraform destroy -auto-approve`) | Prevents cloud cost creep. An idle EKS control plane costs $73/month. Having a one-click automated teardown script ensures engineers destroy resources when testing concludes. |

---

### 3. Command Reference Used in Phase 2

```powershell
# 1. Initialize Terraform providers & download AWS plugin (~> 5.0)
terraform -chdir=terraform init

# 2. Validate syntax and resource graph dependencies
terraform -chdir=terraform validate

# 3. Canonical code formatting
terraform -chdir=terraform fmt

# 4. Automated deployment and cluster connection
.\scripts\deploy.ps1

# 5. One-click cost-safe teardown (when testing is complete)
.\scripts\teardown.ps1
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "How do your Kubernetes pods securely access AWS services like S3 or DynamoDB?"
* **Junior Answer**: *"I create an IAM user in AWS, generate an access key and secret key, and save them in a Kubernetes Secret."*
* **Senior Answer**: *"I use **IAM Roles for Service Accounts (IRSA)**. In our Terraform code, we configure an IAM OIDC Identity Provider tied to the EKS cluster's issuer URL. We then attach an IAM role with an assume-role trust policy referencing the Kubernetes ServiceAccount. When the pod starts, the AWS EKS Pod Identity Webhook automatically projects a temporary, short-lived AWS STS token into the container. This eliminates static credentials and adheres to the principle of least privilege."*

#### Q2: "Why did you place worker nodes in private subnets and what enables them to pull container images?"
* **Junior Answer**: *"For security, and they use the internet."*
* **Senior Answer**: *"Worker nodes must never be exposed to the public internet to prevent unauthorized ingress and direct OS-level attacks. However, worker nodes still require outbound internet access to pull base container images from public registries, communicate with the EKS API server, and fetch OS security patches. We route all outbound traffic from the private subnets through a NAT Gateway located in a public subnet, which in turn routes out through the Internet Gateway."*

#### Q3: "What happens if you forget to tag your subnets with `kubernetes.io/role/elb`?"
* **Junior Answer**: *"Kubernetes gives an error."*
* **Senior Answer**: *"When you deploy an Ingress or a Service of type `LoadBalancer` using the AWS Load Balancer Controller, the controller queries the AWS EC2 API looking for subnets tagged with `kubernetes.io/role/elb = 1` for public ALBs or `kubernetes.io/role/internal-elb = 1` for internal ALBs. Without these tags, the controller cannot determine where to provision the load balancer, resulting in failed provisioning and ingress sync timeouts."*

---

## Roadmap of Upcoming Phases (To Be Documented):
- **Phase 3**: Microservice Application Development, Health Probes & Multi-Stage Dockerfile
- **Phase 4**: Automated CI Pipeline (GitLab CI / GitHub Actions) & Security Scanning (Trivy)
- **Phase 5**: GitOps Deployment Engine — ArgoCD Installation & Application Syncing
- **Phase 6**: Observability Stack — Prometheus Operator, Grafana Dashboards & Slack Alertmanager
- **Phase 7**: End-to-End Validation, MTTR Benchmark & Portfolio Documentation

