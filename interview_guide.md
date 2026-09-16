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

## Phase 3: Application Development, Health Probes & Multi-Stage Dockerfile

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: In modern cloud platform engineering, infrastructure exists to run workloads. However, deploying raw code without cloud-native health probes, observability endpoints, and security hardening causes erratic rolling updates and security vulnerabilities.
* **Task**: Develop a production-grade microservice equipped with Kubernetes liveness and readiness probes, Prometheus metrics collection, automated unit tests, and an optimized multi-stage Docker container.
* **Action**:
  1. Built the microservice (`app/src/server.js`) exposing `/` (app info), `/healthz` (liveness probe), `/ready` (readiness probe), and `/metrics` (Prometheus metrics).
  2. Implemented `prom-client` to capture both default Node.js runtime metrics and custom HTTP request latency histograms with route/status labeling.
  3. Integrated a `SIGTERM` graceful shutdown handler to allow in-flight HTTP connections to drain cleanly during Kubernetes rolling updates.
  4. Authored automated unit tests with Jest and Supertest (`app/test/server.test.js`), achieving 100% pass rate across all endpoints.
  5. Built a multi-stage `Dockerfile`: Stage 1 runs tests and compiles dependencies; Stage 2 copies only production artifacts onto minimal `node:20-alpine`, dropping root privileges to `USER node`.
* **Result**: An ultra-compact (<80MB), non-root container image with built-in observability, ready for zero-downtime Kubernetes deployments and CI pipeline automation.

---

### 2. Key Actions & The Architectural "Why"

| Feature | Implementation | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **Liveness Probe (`/healthz`)** | Returns 200 OK + uptime; fails on process freeze | If an application suffers a thread deadlock or memory leak, process managers like systemd may not know it's stuck. The kubelet calls `/healthz`: if it fails, Kubernetes kills and restarts the pod automatically. |
| **Readiness Probe (`/ready`)** | Returns 200 OK only when dependencies are ready | During pod startup or heavy database warmup, sending traffic immediately causes HTTP 502/503 errors for users. The kubelet withholds traffic from the Pod's Service endpoints until `/ready` returns 200. |
| **Graceful Shutdown (`SIGTERM`)** | Intercepts `SIGTERM` and runs `server.close()` | During rolling deployments, Kubernetes terminates old pods. Without a graceful shutdown handler, active user requests are abruptly severed. Our handler drains active requests before closing the socket. |
| **Multi-Stage Docker Build** | Stage 1 (Builder/Test) → Stage 2 (Minimal Runner) | Eliminates build tools (compilers, git, devDependencies) from the final production image. This reduces image pull times across the cluster from minutes to seconds and eliminates known CVE vulnerabilities. |
| **Non-Root User (`USER node`)** | Runs container processes as unprivileged UID 1000 | **Security Hardening**: If a zero-day remote code execution vulnerability compromises the application, the attacker is trapped as an unprivileged user and cannot modify root files or escape to the host node. |
| **Prometheus Metrics (`/metrics`)** | Exports metrics in Prometheus text exposition format | Rather than relying on external agents, the application exposes native Prometheus counters and latency histograms. This feeds directly into our Grafana dashboards and Alertmanager in Phase 6. |

---

### 3. Command Reference Used in Phase 3

```powershell
# 1. Install microservice dependencies
npm.cmd install --prefix app

# 2. Execute automated unit test suite
npm.cmd test --prefix app

# 3. Local container testing with Docker Compose
docker compose up --build -d

# 4. Verify local endpoints
curl http://localhost:3000/
curl http://localhost:3000/healthz
curl http://localhost:3000/ready
curl http://localhost:3000/metrics

# 5. Stop local container
docker compose down
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "What is the critical difference between a Liveness Probe and a Readiness Probe?"
* **Junior Answer**: *"Liveness checks if the app is alive, readiness checks if it is ready."*
* **Senior Answer**: *"The difference lies in how Kubernetes acts upon failure:*
  * *If a **Liveness Probe** fails, Kubernetes assumes the application is deadlocked or unrecoverable and **restarts the container**.*
  * *If a **Readiness Probe** fails, Kubernetes **does NOT restart the container**. Instead, it temporarily removes the pod's IP from the Kubernetes Service Endpoints so no user traffic is routed to it while it finishes booting or recovers from a transient dependency failure.*
  * *Conflating the two is dangerous: if an external database goes down and you put that check in a liveness probe, Kubernetes will enter an infinite pod restart cascade across your entire cluster."*

#### Q2: "Why is running containers as root considered a severe security risk?"
* **Junior Answer**: *"Because root has too many permissions."*
* **Senior Answer**: *"Container runtimes share the underlying host Linux kernel. By default, UID 0 inside an unprivileged container is mapped to UID 0 (root) on the host node unless user namespaces are configured. If an attacker exploits an application vulnerability to escape the container boundary, they immediately gain full root control over the physical or virtual EC2 host, allowing them to compromise all neighboring pods and steal IAM node credentials."*

#### Q3: "What happens during a Kubernetes rolling update if your application does not handle `SIGTERM`?"
* **Junior Answer**: *"It just stops."*
* **Senior Answer**: *"When Kubernetes replaces an old pod with a new one, it sends a `SIGTERM` signal to the process and begins a termination grace period (default 30 seconds). If the application doesn't trap `SIGTERM`, it either abruptly drops active TCP connections or the process ignores it until Kubernetes forcefully kills it with `SIGKILL`. This causes user-facing HTTP 502/504 errors. A proper graceful shutdown handler stops accepting new connections, drains existing HTTP requests, closes database pools, and exits cleanly with code 0."*

---

## Roadmap of Upcoming Phases (To Be Documented):
- **Phase 4**: Automated CI Pipeline (GitLab CI / GitHub Actions) & Security Scanning (Trivy)
- **Phase 5**: GitOps Deployment Engine — ArgoCD Installation & Application Syncing
- **Phase 6**: Observability Stack — Prometheus Operator, Grafana Dashboards & Slack Alertmanager
- **Phase 7**: End-to-End Validation, MTTR Benchmark & Portfolio Documentation


