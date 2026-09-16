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

## Phase 4: Automated CI Pipeline, DevSecOps & Kubernetes Manifests

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: Manual builds and deployments introduce human error, inconsistent container tags, and security risks. Enterprise platforms require automated testing, vulnerability scanning, and seamless synchronization between application code and deployment manifests.
* **Task**: Design an automated Continuous Integration (CI) and DevSecOps pipeline using GitHub Actions to test code, scan for vulnerabilities with Aqua Security Trivy, publish immutable container images to GitHub Container Registry (GHCR), and automatically update Kubernetes manifests for GitOps delivery.
* **Action**:
  1. Authored `.github/workflows/ci.yml` running automated unit tests on every pull request and commit.
  2. Integrated Aqua Security Trivy to scan the codebase and container filesystem for High and Critical CVEs (Shift-Left Security).
  3. Configured Docker Buildx to build and publish multi-stage container images to GHCR, tagging each build with its unique, immutable Git commit SHA (`github.sha`).
  4. Authored production Kubernetes manifests (`k8s/deployment.yaml`, `k8s/service.yaml`, `k8s/hpa.yaml`, `k8s/servicemonitor.yaml`) with zero-downtime rolling updates (`maxSurge: 1, maxUnavailable: 0`), non-root security contexts, and CPU/memory resource quotas.
  5. Built the automated GitOps bridge: upon successful build and test, the CI pipeline automatically updates the image tag in `k8s/deployment.yaml` and commits with `[skip ci]` to trigger ArgoCD.
* **Result**: A completely automated, zero-touch CI/CD pipeline bridging code commits directly to GitOps cluster manifests without storing cluster credentials in CI.

---

### 2. Key Actions & The Architectural "Why"

| Component / Step | Architectural Decision | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **Commit SHA Tagging (Immutability)** | Tag images with short Git SHA instead of `:latest` | Using `:latest` is an anti-pattern in production. Kubernetes caches images based on tags; with `:latest`, Kubernetes may not pull updated images if the node already cached a previous `:latest`. Commit SHA tagging guarantees immutability, auditability, and instant one-click rollbacks. |
| **Shift-Left Security (Trivy Scan)** | Integrated Trivy container scanner into CI | Finding vulnerabilities in production is expensive and dangerous. Shift-left security scans dependencies and base OS packages during the CI build stage, blocking vulnerable code before it reaches the container registry. |
| **Rolling Update (`maxSurge: 1`)** | `maxSurge: 1` and `maxUnavailable: 0` | Guarantees **Zero Downtime**. Kubernetes spins up a new pod and waits for its `/ready` probe to succeed *before* draining and terminating an old pod. At no point is the service under-provisioned. |
| **Resource Requests & Limits** | Configured CPU (100m/250m) and RAM (128Mi/256Mi) | Prevents the "noisy neighbor" problem where a single runaway pod consumes all CPU/RAM on the worker node and causes node kernel panics. Also mandatory for Horizontal Pod Autoscaler (HPA) to calculate metric thresholds. |
| **CI-to-GitOps Bridge (`[skip ci]`)** | Automated commit updating `k8s/deployment.yaml` with `[skip ci]` | Connects CI (builder) to GitOps (deployer). When CI publishes an image, it commits the new tag to Git. Adding `[skip ci]` prevents Git from triggering another infinite recursive CI pipeline run. |

---

### 3. Command Reference Used in Phase 4

```bash
# 1. Manually test Trivy scanner locally (via Docker)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest fs .

# 2. Inspect Kubernetes manifests syntax locally
kubectl apply --dry-run=client -f k8s/deployment.yaml
kubectl apply --dry-run=client -f k8s/service.yaml
kubectl apply --dry-run=client -f k8s/hpa.yaml

# 3. Simulate rolling update status check
kubectl rollout status deployment/gitops-microservice
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "Why should you never use the `:latest` tag in production Kubernetes deployments?"
* **Junior Answer**: *"Because it's hard to know which version is running."*
* **Senior Answer**: *"Using `:latest` violates container immutability and causes severe operational issues:*
  * *1. **Kubernetes Image Caching**: The default `imagePullPolicy` for `:latest` is `Always`, but if a node network glitch occurs or image digests match, Kubernetes may not pull the new build.*
  * *2. **Rollback Impossibility**: If a bug occurs, you cannot simply say 'roll back to the previous version' because both the broken version and the previous version were named `:latest`.*
  * *3. **Lack of Auditability**: By tagging every image with its exact 7-character Git commit SHA, we can trace every single running container in our cluster directly back to the exact line of code, author, and pull request that produced it."*

#### Q2: "What is the difference between Resource Requests and Resource Limits in Kubernetes?"
* **Junior Answer**: *"Requests are what the pod wants, limits are what it can't exceed."*
* **Senior Answer**: *"The distinction affects two different Kubernetes subsystems:*
  * ***Requests (Scheduling)**: Used by `kube-scheduler` to place the pod on a node that has enough free CPU and RAM. If no node has enough capacity to satisfy the Request, the pod stays in `Pending` state.*
  * ***Limits (Enforcement)**: Enforced by the Linux kernel (`cgroups`). If a pod tries to exceed its CPU Limit, the kernel throttles the CPU (causing slow responses, but no crashes). However, if a pod exceeds its **Memory Limit**, the Linux kernel immediately issues an **OOMKill (Out of Memory)** signal, terminating the container."*

#### Q3: "In GitOps, how does the CI pipeline trigger a deployment without cluster access?"
* **Junior Answer**: *"GitLab CI or GitHub Actions connects to the cluster and runs `kubectl apply`."*
* **Senior Answer**: *"In pure GitOps, CI **never** connects to the Kubernetes cluster. Granting CI write access to production clusters violates least privilege and exposes admin credentials in build runners. Instead, CI builds the container image, pushes it to the registry, and simply makes a commit to the GitOps repository updating the image tag in `deployment.yaml`. ArgoCD, running inside the cluster, detects the new commit in Git and pulls the update automatically. This ensures our cluster remains completely private with zero open inbound firewall ports for CI."*

---

## Phase 5: GitOps Deployment Engine — ArgoCD & Continuous Delivery

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: Pushing deployments from external CI tools creates high-severity security vulnerabilities (storing cluster admin credentials outside the VPC) and fails to prevent configuration drift when engineers make manual changes via `kubectl`.
* **Task**: Implement an enterprise pull-based GitOps engine using ArgoCD on Amazon EKS, configuring declarative Application resources, automated synchronization, self-healing, and multi-tenant security boundaries.
* **Action**:
  1. Configured ArgoCD Helm values (`gitops/argocd-values.yaml`) with Prometheus metrics enabled for continuous delivery observability.
  2. Established an `AppProject` resource (`gitops/project.yaml`) enforcing least privilege by whitelisting only our authorized GitHub repository and target namespaces.
  3. Authored the declarative ArgoCD `Application` manifest (`gitops/application.yaml`) connecting `deadboltt/DevOps_Project.git` directly to the cluster with `automated.prune: true` and `automated.selfHeal: true`.
  4. Built an automated deployment script (`scripts/setup-argocd.ps1`) to provision the controller, wait for readiness, extract initial admin credentials, and establish local dashboard access.
* **Result**: A zero-trust, pull-based delivery pipeline where Git is the single source of truth. Any commit to `k8s/` triggers an automated rollout, and any manual cluster tampering is reverted within seconds.

---

### 2. Key Actions & The Architectural "Why"

| Feature | Implementation | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **Pull-Based GitOps Architecture** | ArgoCD inside EKS pulls from Git; no inbound ports opened | **Zero-Trust Security**: The cluster never exposes its Kubernetes API to GitHub Actions or the public internet. No `kubeconfig` or AWS IAM credentials ever leave the VPC. |
| **Self-Healing (`selfHeal: true`)** | Reverts any live resource that diverges from Git | Prevents "cowboy engineering" (engineers manually running `kubectl edit` or `kubectl scale` in production). If someone manually alters a pod replica count, ArgoCD detects the drift and immediately reconciles it back to Git. |
| **Automated Pruning (`prune: true`)** | Deletes cluster resources when their YAML is removed from Git | Prevents "zombie/orphaned resources". In standard CI scripts (`kubectl apply -f`), deleting a YAML file from Git does NOT delete it from the cluster. With `prune: true`, Git deletion equals cluster deletion. |
| **Multi-Tenant AppProject** | Defined `gitops/project.yaml` | In enterprise environments, teams should not be allowed to deploy arbitrary resources to arbitrary namespaces. `AppProject` acts as a security sandbox restricting target clusters, namespaces, and allowed Kubernetes API groups. |
| **Sync Waves & Backoff Retry** | Configured exponential backoff retry in Application spec | Prevents sync failures caused by transient network blips or dependencies not yet initialized. |

---

### 3. Command Reference Used in Phase 5

```powershell
# 1. Automated ArgoCD controller deployment
.\scripts\setup-argocd.ps1

# 2. Port-forward ArgoCD Web Dashboard
kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:443

# 3. View live ArgoCD application sync status via CLI
kubectl get applications -n argocd
kubectl get pods -n default -l app=gitops-microservice

# 4. Demonstrate Self-Healing (Manual Tamper Test)
# Manually scale deployment to 0:
kubectl scale deployment/gitops-microservice --replicas=0
# Watch ArgoCD immediately detect the drift and scale it back to 2 replicas:
kubectl get pods -l app=gitops-microservice -w
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "Why is GitOps considered more secure than traditional CI/CD push deployments?"
* **Junior Answer**: *"Because it uses Git to store everything."*
* **Senior Answer**: *"GitOps fundamentally alters the trust boundary. In a push model (Jenkins/GitLab/GitHub Actions), the CI runner must store long-lived cluster administrator credentials to run `kubectl apply`. If a runner is compromised or a developer tampers with a pipeline script, the entire cluster is compromised. In pull-based GitOps (ArgoCD), the agent lives inside the private network and opens only outbound HTTPS connections to Git. No credentials leave the cluster, no inbound firewall ports are opened, and the cluster pulls only signed, approved Git commits."*

#### Q2: "What is Configuration Drift, and how does ArgoCD detect and resolve it?"
* **Junior Answer**: *"Drift is when things are different, and ArgoCD fixes it."*
* **Senior Answer**: *"Configuration Drift occurs when the live state of a cluster deviates from the desired state declared in version control (e.g., an engineer SSHs in or runs `kubectl patch` during an incident). ArgoCD continuously compares the live JSON/YAML manifest in the Kubernetes API against the target manifest in Git. When divergence occurs, ArgoCD marks the application as `OutOfSync`. If `selfHeal: true` is enabled, the reconciliation loop immediately applies the Git declaration over the live state, restoring cluster integrity automatically without human intervention."*

#### Q3: "What is the purpose of the `prune: true` setting in ArgoCD?"
* **Junior Answer**: *"To clean up old files."*
* **Senior Answer**: *"In declarative Kubernetes management, deleting a YAML file from a repository does not cause `kubectl apply` to delete the object from the cluster; it simply stops updating it, leaving an orphaned 'zombie' resource running indefinitely. When `prune: true` is enabled in ArgoCD's sync policy, ArgoCD tracks resources previously managed by the application. If a resource exists in the cluster but is absent from the target Git commit, ArgoCD safely issues a delete command to the Kubernetes API, keeping the cluster in exact 1:1 parity with the repository."*

---

## Phase 6: Observability Stack — Prometheus, Grafana & Slack Alerting

### 1. The 60-Second Interview Pitch (STAR Format)
* **Situation**: Operating production microservices without telemetry leads to delayed incident response and silent performance degradation. Platform engineers must provide developers with standardized metrics, automated alerting, and intuitive dashboards out of the box.
* **Task**: Design and deploy a cloud-native observability platform using Prometheus Operator, Alertmanager, and Grafana (`kube-prometheus-stack`), configure custom PromQL alerting rules, route incident alerts to Slack, and provision SRE 4 Golden Signals dashboards declaratively via GitOps.
* **Action**:
  1. Configured `kube-prometheus-stack` Helm values (`monitoring/values.yaml`) enabling automated `ServiceMonitor` discovery and Grafana ConfigMap dashboard sidecars.
  2. Defined `PrometheusRule` alerts for total service outages, HTTP 5xx error rate spikes (>5%), latency degradation (p95 > 500ms), and pod crash loops.
  3. Integrated `AlertmanagerConfig` routing critical and warning notifications to a `#alerts` Slack channel via webhook with rich contextual metadata.
  4. Authored a production Grafana dashboard JSON visualizing the Google SRE 4 Golden Signals (Traffic, Errors, Latency, Saturation) packaged into a labeled ConfigMap for automated GitOps provisioning.
  5. Built an automated deployment script (`scripts/setup-monitoring.ps1`) for single-command installation and port-forwarding.
* **Result**: Zero-touch observability where new microservices are scraped automatically upon deployment, SRE dashboards load instantly without manual UI clicks, and critical incidents fire directly into Slack within 60 seconds.

---

### 2. Key Actions & The Architectural "Why"

| Feature | Implementation | Why It Matters (The Senior Engineering Rationale) |
| :--- | :--- | :--- |
| **Pull vs. Push Metrics Model** | Prometheus scrapes `/metrics` endpoints; apps don't push | In a push model, if the metrics collector crashes, thousands of application threads back up trying to push metrics. With pull-based Prometheus, applications remain fast and decoupled. Prometheus controls scrape frequency and automatically detects dead targets (`up == 0`). |
| **SRE 4 Golden Signals Dashboard** | Configured panels for Traffic, Errors, Latency, and Saturation | Standardized by Google Site Reliability Engineering: instead of 50 confusing graphs, these 4 metrics tell on-call engineers everything they need to know about system health at a glance. |
| **GitOps Dashboard Provisioning** | Packaged dashboard JSON inside a ConfigMap with label `grafana_dashboard=1` | Eliminates "ClickOps". Creating dashboards manually in Grafana's UI causes configuration loss if the Grafana pod restarts. The sidecar pattern treats dashboards as version-controlled code in Git. |
| **Alertmanager Grouping & Inhibit** | Configured `groupBy`, `groupWait: 15s`, `repeatInterval: 4h` | **Prevents Alert Fatigue**: When a cluster network switch fails, 50 individual pods crash. Alertmanager groups them into a single consolidated Slack notification instead of spamming engineers with 50 separate pings. |
| **Dynamic ServiceMonitor Discovery** | Configured `serviceMonitorSelector: {}` in PrometheusSpec | Eliminates manual Prometheus target configuration. When developers deploy a new microservice with a `ServiceMonitor` resource, Prometheus automatically discovers and begins scraping it within seconds. |

---

### 3. Command Reference Used in Phase 6

```powershell
# 1. Automated Observability Stack Deployment
.\scripts\setup-monitoring.ps1

# 2. Access Grafana Dashboard (Credentials: admin / admin)
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80
# Open browser at: http://localhost:3001

# 3. Access Prometheus Query Interface
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open browser at: http://localhost:9090

# 4. PromQL Diagnostic Queries
# Instant error rate query:
sum(rate(http_requests_total{status_code=~"5.."}[2m])) / sum(rate(http_requests_total[2m]))

# 95th Percentile Latency query:
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

---

### 4. High-Probability Interview Questions & Model Answers

#### Q1: "Why does Prometheus use a Pull model instead of a Push model?"
* **Junior Answer**: *"Because that's how Prometheus was designed."*
* **Senior Answer**: *"A pull model provides significant reliability and architectural benefits:*
  * *1. **Health Detection**: If a microservice crashes, it cannot push an alert that it died. With a pull model, Prometheus attempts to scrape the endpoint; if it receives connection refused, `up == 0` immediately triggers an alert.*
  * *2. **Centralized Overload Protection**: In a push model, if 500 pods burst under high traffic, they will overwhelm the central monitoring server with push traffic. In a pull model, Prometheus pulls only on its own schedule (e.g., every 15s), preventing monitoring collapse during traffic surges.*
  * *3. **Decoupled Architecture**: Microservices simply expose a lightweight text endpoint (`/metrics`) and don't need to know where the Prometheus server lives or manage external network queues."*

#### Q2: "What are the 4 Golden Signals in Site Reliability Engineering (SRE)?"
* **Junior Answer**: *"CPU, Memory, Disk, and Network."*
* **Senior Answer**: *"Those are low-level host metrics. The 4 Golden Signals defined by Google SRE focus on user-facing service health:*
  * *1. **Latency**: The time it takes to service a request (differentiating between successful request latency and failed request latency).*
  * *2. **Traffic**: A measure of how much demand is being placed on your system (e.g., HTTP Requests Per Second).*
  * *3. **Errors**: The rate of requests that fail, either explicitly (HTTP 500s) or implicitly (wrong content returned).*
  * *4. **Saturation**: How 'full' your service is, measuring the most constrained system resource (e.g., CPU, Memory, or database connection pool limits)."*

#### Q3: "How does Grafana dynamically discover dashboards in a Kubernetes cluster without manual imports?"
* **Junior Answer**: *"You upload the JSON file in the Grafana UI."*
* **Senior Answer**: *"In our platform, we use the **Grafana Sidecar pattern**. In our Helm values, we enable `sidecar.dashboards.enabled = true` and specify a label selector (`grafana_dashboard: '1'`). The sidecar container runs alongside Grafana in the same pod and uses the Kubernetes Watch API to listen for any ConfigMap bearing that label. When our GitOps pipeline applies a new dashboard ConfigMap, the sidecar intercepts the event, extracts the JSON data, and injects it directly into Grafana's local filesystem via an in-memory volume. The dashboard appears in the UI instantly with zero downtime and zero manual clicks."*

---

## Roadmap of Upcoming Phases (To Be Documented):
- **Phase 7**: End-to-End Validation, MTTR Benchmark & Portfolio Documentation





