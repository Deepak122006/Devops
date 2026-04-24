# 🚀 DevSecOps Pipeline — Production-Ready CI/CD on AWS

A fully automated, secure CI/CD pipeline for a Java Spring Boot application deployed on AWS EKS.
Integrates security scanning (Trivy), image signing (Cosign), GitOps (ArgoCD), and live monitoring (Prometheus + Grafana).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVSECOPS PIPELINE FLOW                             │
└─────────────────────────────────────────────────────────────────────────────┘

  Developer Push
       │
       ▼
  ┌─────────┐     Webhook      ┌───────────────────────────────────────────┐
  │ GitHub  │ ───────────────► │            Jenkins Pipeline                │
  │  Repo   │                  │                                           │
  └─────────┘                  │  1. Checkout & Setup Tools                │
       ▲                       │  2. Maven Build (compile + package)       │
       │ git push              │  3. Unit Tests + JaCoCo Coverage          │
       │ (manifest)            │  4. SonarQube Static Analysis             │
       │                       │  5. Quality Gate check                    │
  ┌─────────┐                  │  6. Nexus Repository publish              │
  │ Jenkins │ ◄────────────────│  7. Docker Image Build                    │
  │  (CI)   │                  │  8. Trivy Vulnerability Scan ────────────►│ FAIL if CRITICAL
  └─────────┘                  │  9. Cosign Image Signing                  │
                               │  10. ECR Push                             │
                               │  11. Update k8s manifest + git push       │
                               └───────────────────────────────────────────┘
                                                  │
                               ┌──────────────────▼──────────────────┐
                               │           AWS ECR                    │
                               │  (Docker image registry)            │
                               └──────────────────┬──────────────────┘
                                                  │ image pull
                               ┌──────────────────▼──────────────────┐
                               │           ArgoCD (GitOps)           │
                               │  Watches GitHub repo for manifest   │
                               │  changes → auto-syncs to EKS        │
                               └──────────────────┬──────────────────┘
                                                  │
                               ┌──────────────────▼──────────────────┐
                               │         AWS EKS Cluster              │
                               │  Namespace: devsecops                │
                               │  ┌──────────────────────────────┐   │
                               │  │  Spring Boot App (2 replicas) │   │
                               │  │  HPA: CPU 70% / Memory 80%   │   │
                               │  │  ALB Ingress (public)        │   │
                               │  └──────────────────────────────┘   │
                               └──────────────────┬──────────────────┘
                                                  │ /actuator/prometheus
                               ┌──────────────────▼──────────────────┐
                               │    Prometheus + Grafana (monitoring) │
                               │    AlertManager (alerting)           │
                               └─────────────────────────────────────┘
```

### AWS Infrastructure

```
VPC: 10.0.0.0/16
├── Public Subnets  (10.0.101-103.0/24) — ALB, CI Server, NAT Gateway
└── Private Subnets (10.0.1-3.0/24)    — EKS nodes

EKS Cluster: devsecops-eks (t3.medium × 3)
ECR Repository: devsecops-app
CI Server (EC2): t3.large — Jenkins + SonarQube + Nexus via Docker Compose
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Terraform | >= 1.6 | https://developer.hashicorp.com/terraform/install |
| kubectl | >= 1.28 | https://kubernetes.io/docs/tasks/tools/ |
| Helm | >= 3.13 | https://helm.sh/docs/intro/install/ |
| Docker Desktop | >= 24 | https://www.docker.com/products/docker-desktop/ |
| Java | 21 | https://adoptium.net/ |
| Maven | >= 3.9 | https://maven.apache.org/download.cgi |
| Cosign | >= 2.2 | https://docs.sigstore.dev/cosign/installation/ |

---

## Setup Guide

### Phase 0 — Local Validation

```powershell
# Set Java 21
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.10'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

# Validate Maven tests pass
cd app
mvn test -B --no-transfer-progress
cd ..

# Validate Docker Compose config is valid
docker compose -f docker-compose/docker-compose.yml config
```

✅ **Gate:** All 8 Maven tests pass. Compose config prints with no errors.

---

### Phase 1 — Secrets & Configuration

```powershell
# Copy the environment template
Copy-Item .env.example .env
```

Edit `.env` with your real values:

| Variable | Description |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `GIT_USER` | Your GitHub username |
| `GIT_TOKEN` | GitHub PAT with `repo` scope |
| `JENKINS_ADMIN_PASSWORD` | Jenkins admin password |
| `SONAR_TOKEN` | SonarQube project token |
| `NEXUS_PASSWORD` | Nexus admin password |
| `COSIGN_PRIVATE_KEY_B64` | Base64-encoded cosign private key |

Create Terraform variables:

```powershell
cd terraform
# Edit terraform.tfvars — set your real public IP
# admin_cidr_blocks = ["YOUR_PUBLIC_IP/32"]
```

✅ **Gate:** `git status --short` shows `.env` and `terraform.tfvars` are NOT tracked.

---

### Phase 2 — Terraform Backend

Verify the S3 backend resources exist:

```powershell
aws s3api head-bucket --bucket devsecops-tf-state-idris
aws dynamodb describe-table --table-name devsecops-tf-lock --region us-east-1
```

```powershell
cd terraform
terraform init -reconfigure
terraform validate
```

✅ **Gate:** `terraform validate` prints `Success! The configuration is valid.`

---

### Phase 3 — Infrastructure Provisioning

```powershell
cd terraform
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Expected resources created:
- VPC + subnets + NAT gateway
- EKS cluster (`devsecops-eks`) with managed node group
- ECR repository (`devsecops-app`)
- CI EC2 instance with Elastic IP
- IAM roles (IRSA for app, EBS CSI, Load Balancer Controller)

✅ **Gate:**
```powershell
aws eks list-clusters --region us-east-1
aws ecr describe-repositories --region us-east-1
terraform state list
```

---

### Phase 4 — Kubernetes Access

```powershell
# Connect to EKS
aws eks update-kubeconfig --region us-east-1 --name devsecops-eks

# Verify nodes
kubectl get nodes

# Install Metrics Server (required by HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# AWS Load Balancer Controller (required by ALB Ingress)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=devsecops-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::545586474227:role/AmazonEKSLoadBalancerControllerRole
```

✅ **Gate:**
```powershell
kubectl get nodes          # All nodes Ready
kubectl get deployment -n kube-system aws-load-balancer-controller  # 2/2 Ready
```

---

### Phase 5 — Local CI Stack

```powershell
# Start all CI services
docker compose --env-file .env -f docker-compose/docker-compose.yml up -d

# Wait ~2 minutes, then check status
docker compose -f docker-compose/docker-compose.yml ps
```

| Service | URL | Default Credentials |
|---|---|---|
| Jenkins | http://localhost:8090/jenkins | admin / see `.env` `JENKINS_ADMIN_PASSWORD` |
| SonarQube | http://localhost:9000 | admin / `SonarAdmin@2024!` |
| Nexus | http://localhost:8081 | admin / `NexusAdmin@2026!` |

Run setup scripts (only needed once):

```bash
bash scripts/setup-sonarqube.sh
bash scripts/setup-nexus.sh
```

✅ **Gate:** All 3 services show `Up (healthy)` in `docker compose ps`.

---

### Phase 6 — Application Build & ECR Push

```powershell
# Build and test
cd app
mvn clean package -B --no-transfer-progress
cd ..

# Build Docker image
docker build -t devsecops-app:local -f app/Dockerfile app/

# Test locally
docker run --rm -p 8080:8080 devsecops-app:local
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 545586474227.dkr.ecr.us-east-1.amazonaws.com
docker tag devsecops-app:local 545586474227.dkr.ecr.us-east-1.amazonaws.com/devsecops-app:latest
docker push 545586474227.dkr.ecr.us-east-1.amazonaws.com/devsecops-app:latest
```

✅ **Gate:**
```powershell
aws ecr describe-images --region us-east-1 --repository-name devsecops-app
```

---

### Phase 7 — Jenkins Pipeline

Add these credentials at `http://localhost:8090/jenkins/credentials`:

| Credential ID | Type | Value |
|---|---|---|
| `github-credentials` | Username/Password | `Deepak122006` / GitHub PAT |
| `sonarqube-token` | Secret text | SonarQube project token |
| `nexus-credentials` | Username/Password | `jenkins-deployer` / `NexusDeploy@2026!` |
| `cosign-private-key` | Secret text | Base64 of `cosign/cosign.key` |
| `cosign-password` | Secret text | `Cosign@DevSecOps2026!` |
| `argocd-token` | Secret text | kubectl-fetched ArgoCD password |

Create a Jenkins pipeline job pointing to this repo's `jenkins/Jenkinsfile`.

Pipeline stages:
1. Checkout & Setup Tools
2. Maven Build
3. Unit Tests + JaCoCo
4. SonarQube Analysis
5. Quality Gate
6. Publish to Nexus
7. Docker Build
8. **Trivy Vulnerability Scan** (fails on CRITICAL/HIGH)
9. **Cosign Image Signing**
10. Push to ECR
11. Update Manifest & trigger ArgoCD

✅ **Gate:** Full pipeline GREEN with Trivy report and ECR image.

---

### Phase 8 — GitOps Deployment (ArgoCD)

```bash
bash scripts/setup-argocd.sh

# Apply GitOps config
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/application.yaml
```

Access ArgoCD UI:
```powershell
kubectl port-forward svc/argocd-server 8888:80 -n argocd
# Open: http://localhost:8888
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

✅ **Gate:**
```powershell
kubectl get pods -n devsecops          # All Running
kubectl get hpa -n devsecops           # HPA active
argocd app get devsecops-app           # Status: Healthy, Synced
```

---

### Phase 9 — Monitoring

```bash
bash scripts/setup-monitoring.sh
```

Access Grafana:
```powershell
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Open: http://localhost:3000  (admin / GrafanaAdmin@2026!)
```

Verify app metrics:
```powershell
kubectl port-forward svc/devsecops-app-svc 8080:80 -n devsecops
curl http://localhost:8080/actuator/prometheus
```

Recommended Grafana dashboards to import:
- JVM Micrometer (ID: 4701)
- Spring Boot Statistics (ID: 6756)
- Kubernetes Cluster (ID: 7249)

✅ **Gate:** Prometheus shows `devsecops-app` target as UP.

---

### Phase 10 — Production Hardening

- [ ] Restrict `admin_cidr_blocks` in `terraform.tfvars` to your real IP(s)
- [ ] Rotate all generated passwords before sharing access
- [ ] Enable CloudWatch alarms for EKS node CPU/memory
- [ ] Set up Slack/email alerts in AlertManager
- [ ] Enable EKS control plane logging to CloudWatch
- [ ] Review and tighten IAM policies (least-privilege)

---

## AWS Resources (Current Deployment)

| Resource | Value |
|---|---|
| EKS Cluster | `devsecops-eks` — 3 × `t3.medium` nodes |
| ECR Repository | `545586474227.dkr.ecr.us-east-1.amazonaws.com/devsecops-app` |
| CI Server (EC2) | `52.203.132.178` (Elastic IP), `t3.large` |
| VPC | `vpc-03f008300d5e449a5` |
| App IRSA Role | `arn:aws:iam::545586474227:role/devsecops-app-role` |
| LBC IRSA Role | `arn:aws:iam::545586474227:role/AmazonEKSLoadBalancerControllerRole` |

---

## Quick Access Commands

```powershell
# ──── CI Tools ─────────────────────────────────────────────────
# Start the local CI stack
docker compose --env-file .env -f docker-compose/docker-compose.yml up -d

# Jenkins:   http://localhost:8090/jenkins
# SonarQube: http://localhost:9000
# Nexus:     http://localhost:8081

# ──── Kubernetes ───────────────────────────────────────────────
# Connect to cluster
aws eks update-kubeconfig --region us-east-1 --name devsecops-eks

# Check app
kubectl get all -n devsecops
kubectl logs -l app=devsecops-app -n devsecops --tail=50

# ──── ArgoCD ───────────────────────────────────────────────────
kubectl port-forward svc/argocd-server 8888:80 -n argocd
# http://localhost:8888

# ──── Grafana ──────────────────────────────────────────────────
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# http://localhost:3000  (admin / GrafanaAdmin@2026!)

# ──── App ──────────────────────────────────────────────────────
kubectl port-forward svc/devsecops-app-svc 8080:80 -n devsecops
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/prometheus
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `ErrImagePull` in EKS | Check IRSA role ARN on ServiceAccount; re-run `aws ecr get-login-password` |
| ArgoCD stuck `OutOfSync` | `argocd app sync devsecops-app --force` |
| HPA shows `<unknown>` | Verify Metrics Server is running: `kubectl get deployment metrics-server -n kube-system` |
| Trivy fails in Jenkins | Check Jenkins container has internet access; verify ECR image was pushed first |
| Cosign fails | Verify `cosign-private-key` credential in Jenkins is the base64 value (not the raw PEM) |
| Jenkins can't push to GitHub | Regenerate GitHub PAT with `repo` scope; update `github-credentials` in Jenkins |
| SonarQube unreachable from Jenkins | Use `http://sonarqube:9000` (Docker network) not `localhost:9000` |
| Terraform `init` fails | Verify S3 bucket `devsecops-tf-state-idris` exists and IAM has permissions |
| kubectl `Unauthorized` | Re-run `aws eks update-kubeconfig --region us-east-1 --name devsecops-eks` |

---

## Cleanup

> ⚠️ **This will delete all AWS resources and incur no further charges.**

```powershell
# 1. Remove Kubernetes resources
kubectl delete namespace devsecops argocd monitoring --ignore-not-found

# 2. Destroy all Terraform-managed AWS infrastructure
cd terraform
terraform destroy

# 3. Stop local CI stack
docker compose -f docker-compose/docker-compose.yml down -v

# 4. (Optional) Delete the S3 backend bucket
aws s3 rm s3://devsecops-tf-state-idris --recursive
aws s3 rb s3://devsecops-tf-state-idris
aws dynamodb delete-table --table-name devsecops-tf-lock --region us-east-1
```

---

## Security Notes

- All EC2 EBS volumes are encrypted at rest
- EKS nodes use private subnets — no direct internet exposure
- App pods run as non-root (UID 1000) with dropped capabilities
- IAM access follows least-privilege via IRSA (no hardcoded keys in pods)
- Docker images are signed with Cosign — unsigned images are rejected
- Trivy scan blocks builds with CRITICAL or HIGH CVEs
- Secrets are managed via `.env` (gitignored) and Jenkins credentials store
