# ============================================================
# Makefile - DevSecOps Pipeline Automation
# WHY: Provides a single interface for all common tasks.
# Usage: make <target>
# ============================================================

.PHONY: help setup-all infra-plan infra-apply infra-destroy \
        ci-stack ci-start ci-stop ci-logs \
        app-build app-test app-docker \
        k8s-deploy k8s-status k8s-delete \
        argocd-setup monitoring-setup \
        cosign-setup trivy-scan clean

# Default target
.DEFAULT_GOAL := help

# Variables (override with: make deploy AWS_REGION=eu-west-1)
AWS_REGION     ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ACCOUNT_ID")
ECR_REGISTRY   ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
APP_NAME       ?= devsecops-app
IMAGE_TAG      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")
FULL_IMAGE     ?= $(ECR_REGISTRY)/$(APP_NAME):$(IMAGE_TAG)
COMPOSE_FILE   ?= docker-compose/docker-compose.yml
MONITORING_NS  ?= monitoring

# Colors for output
RED    = \033[0;31m
GREEN  = \033[0;32m
YELLOW = \033[1;33m
BLUE   = \033[0;34m
NC     = \033[0m   # No Color

##@ Help
help: ## Show this help message
	@echo ""
	@echo "$(BLUE)DevSecOps Pipeline - Makefile$(NC)"
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(BLUE)<target>$(NC)\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""

##@ Infrastructure
infra-plan: ## Run Terraform plan (preview AWS changes)
	@echo "$(BLUE)Running Terraform plan...$(NC)"
	cd terraform && terraform init && terraform plan

infra-apply: ## Apply Terraform changes (provision AWS infrastructure)
	@echo "$(YELLOW)Applying Terraform... This will create AWS resources!$(NC)"
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "$(GREEN)✅ Infrastructure provisioned!$(NC)"
	@cd terraform && terraform output

infra-destroy: ## Destroy all Terraform-managed infrastructure
	@echo "$(RED)⚠️  WARNING: This will DESTROY all AWS infrastructure!$(NC)"
	@read -p "Type 'destroy' to confirm: " confirm && [ "$$confirm" = "destroy" ]
	cd terraform && terraform destroy -auto-approve

kubeconfig: ## Update local kubeconfig for EKS access
	aws eks update-kubeconfig --region $(AWS_REGION) --name devsecops-eks

##@ CI Tools
ci-stack: ## Start all CI tools (Jenkins + SonarQube + Nexus)
	@echo "$(BLUE)Starting CI stack...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✅ CI stack started!"
	@echo "  Jenkins:   http://localhost:8090"
	@echo "  SonarQube: http://localhost:9000"
	@echo "  Nexus:     http://localhost:8081$(NC)"

ci-start: ## Start CI tools (alias for ci-stack)
	@make ci-stack

sonarqube-setup: ## Bootstrap SonarQube (create project, token, webhook)
	@echo "$(BLUE)Configuring SonarQube...$(NC)"
	bash scripts/setup-sonarqube.sh

nexus-setup: ## Bootstrap Nexus (create repos + deployer user)
	@echo "$(BLUE)Configuring Nexus...$(NC)"
	bash scripts/setup-nexus.sh

ci-stop: ## Stop all CI tools
	@echo "$(YELLOW)Stopping CI stack...$(NC)"
	docker compose -f $(COMPOSE_FILE) down

ci-logs: ## Tail logs from all CI tools
	docker compose -f $(COMPOSE_FILE) logs -f

ci-status: ## Show status of CI containers
	docker compose -f $(COMPOSE_FILE) ps

jenkins-logs: ## Tail Jenkins logs only
	docker logs -f jenkins

nexus-password: ## Get initial Nexus admin password
	@docker exec nexus cat /nexus-data/admin.password 2>/dev/null || echo "Already configured"

##@ Application
app-build: ## Build the Spring Boot JAR
	@echo "$(BLUE)Building Maven project...$(NC)"
	cd app && mvn clean package -B -DskipTests --no-transfer-progress
	@echo "$(GREEN)✅ Build complete: $(shell ls app/target/*.jar 2>/dev/null)$(NC)"

app-test: ## Run unit tests
	@echo "$(BLUE)Running tests...$(NC)"
	cd app && mvn test -B --no-transfer-progress
	@echo "$(GREEN)✅ Tests passed!$(NC)"

app-docker-build: ## Build Docker image locally
	@echo "$(BLUE)Building Docker image: $(FULL_IMAGE)$(NC)"
	docker build -t $(FULL_IMAGE) -t $(ECR_REGISTRY)/$(APP_NAME):latest -f app/Dockerfile app/
	@echo "$(GREEN)✅ Image built: $(FULL_IMAGE)$(NC)"

app-docker-run: ## Run the Docker image locally for testing
	docker run -p 8080:8080 --name $(APP_NAME)-test --rm $(FULL_IMAGE)

trivy-scan: ## Scan Docker image with Trivy locally
	@echo "$(BLUE)Scanning $(FULL_IMAGE) with Trivy...$(NC)"
	trivy image --severity CRITICAL,HIGH --exit-code 1 $(FULL_IMAGE)

ecr-login: ## Login to AWS ECR
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_REGISTRY)

ecr-push: app-docker-build ecr-login ## Build and push image to ECR
	@echo "$(BLUE)Pushing to ECR...$(NC)"
	docker push $(FULL_IMAGE)
	docker push $(ECR_REGISTRY)/$(APP_NAME):latest
	@echo "$(GREEN)✅ Pushed: $(FULL_IMAGE)$(NC)"

##@ Kubernetes
k8s-deploy: ## Apply all Kubernetes manifests
	@echo "$(BLUE)Applying Kubernetes manifests...$(NC)"
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/ingress.yaml
	kubectl apply -f k8s/hpa.yaml
	@echo "$(GREEN)✅ Manifests applied!$(NC)"

k8s-status: ## Check status of all resources in devsecops namespace
	@echo "$(BLUE)Kubernetes Resources in 'devsecops' namespace:$(NC)"
	kubectl get all -n devsecops
	@echo ""
	kubectl get hpa -n devsecops
	@echo ""
	kubectl get ingress -n devsecops

k8s-logs: ## Tail application pod logs
	kubectl logs -f -l app=$(APP_NAME) -n devsecops --all-containers=true

k8s-exec: ## Exec into an app pod (for debugging)
	kubectl exec -it -n devsecops \
		$(shell kubectl get pod -n devsecops -l app=$(APP_NAME) -o jsonpath="{.items[0].metadata.name}") \
		-- /bin/sh

k8s-delete: ## Delete all app resources from Kubernetes
	kubectl delete -f k8s/ --ignore-not-found=true

##@ GitOps / ArgoCD
argocd-setup: ## Install ArgoCD on EKS cluster
	bash scripts/setup-argocd.sh

argocd-sync: ## Force ArgoCD to sync the app
	argocd app sync $(APP_NAME)

argocd-status: ## Check ArgoCD app status
	argocd app get $(APP_NAME)

##@ Monitoring
monitoring-setup: ## Install Prometheus + Grafana on EKS
	bash scripts/setup-monitoring.sh

monitoring-port-forward: ## Port-forward Grafana to localhost:3000
	@echo "$(BLUE)Grafana available at: http://localhost:3000$(NC)"
	kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n $(MONITORING_NS)

prometheus-port-forward: ## Port-forward Prometheus to localhost:9090
	@echo "$(BLUE)Prometheus available at: http://localhost:9090$(NC)"
	kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n $(MONITORING_NS)

##@ Security
cosign-setup: ## Generate Cosign key pair for image signing
	bash cosign/cosign-setup.sh

cosign-verify: ## Verify image signature
	cosign verify --key cosign/cosign.pub $(FULL_IMAGE)

##@ Full Setup
setup-all: ## Run complete setup (EC2 bootstrap + CI stack + SonarQube + Nexus)
	@echo "$(BLUE)Running full DevSecOps bootstrap...$(NC)"
	sudo bash scripts/bootstrap.sh

env-setup: ## Copy .env.example → .env (first-time onboarding)
	@if [ -f .env ]; then \
		echo "$(YELLOW).env already exists. Delete it first if you want to reset.$(NC)"; \
	else \
		cp .env.example .env; \
		echo "$(GREEN)✅ .env created from .env.example"; \
		echo "   → Fill in your real values before running make ci-stack$(NC)"; \
	fi

##@ Cleanup
clean: ## Clean Maven build artifacts
	cd app && mvn clean

clean-docker: ## Remove all project Docker images
	docker rmi $(FULL_IMAGE) || true
	docker rmi $(ECR_REGISTRY)/$(APP_NAME):latest || true
	docker image prune -f
