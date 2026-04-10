# 🚀 Production-Ready DevSecOps Pipeline

**Java Spring Boot → Kubernetes on AWS with full CI/CD, Security Scanning & Monitoring**

## Architecture Flow

```
GitHub → Jenkins → Maven Build → SonarQube → Nexus → Docker → Trivy → Cosign → ECR → ArgoCD → Kubernetes → Prometheus → Grafana
```

## Project Structure

```
antigarvity-ddevops/
├── app/                        # Spring Boot Application
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── jenkins/                    # Jenkins Configuration
│   ├── Jenkinsfile
│   └── plugins.txt
├── k8s/                        # Kubernetes Manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── configmap.yaml
├── argocd/                     # ArgoCD Configuration
│   ├── application.yaml
│   └── project.yaml
├── monitoring/                 # Prometheus + Grafana
│   ├── prometheus/
│   │   ├── values.yaml
│   │   └── rules.yaml
│   └── grafana/
│       └── dashboards/
├── terraform/                  # AWS Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── eks.tf
│   ├── ecr.tf
│   └── security-groups.tf
├── scripts/                    # Automation Scripts
│   ├── setup-jenkins.sh
│   ├── setup-sonarqube.sh
│   ├── setup-nexus.sh
│   ├── setup-argocd.sh
│   ├── setup-monitoring.sh
│   ├── install-tools.sh
│   └── bootstrap.sh
├── sonarqube/                  # SonarQube Config
│   └── sonar-project.properties
├── docker-compose/             # Local Dev Stack
│   └── docker-compose.yml
├── cosign/                     # Image Signing
│   └── cosign-setup.sh
├── Makefile                    # Automation Commands
└── README.md
```

## Quick Start

```bash
# 1. Clone & enter project
git clone https://github.com/IdrisShaik/Devops_Project.git
cd antigarvity-ddevops

# 2. Bootstrap everything (AWS EC2)
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh

# 3. Or use Makefile
make help
make setup-all
make deploy
```

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | AWS Infrastructure (EC2 + EKS + ECR) | ⬜ |
| 2 | CI Tools (Jenkins + SonarQube + Nexus) | ⬜ |
| 3 | Spring Boot Application | ⬜ |
| 4 | Jenkins Pipeline | ⬜ |
| 5 | Security (Trivy + Cosign) | ⬜ |
| 6 | ArgoCD + Kubernetes CD | ⬜ |
| 7 | Monitoring (Prometheus + Grafana) | ⬜ |
