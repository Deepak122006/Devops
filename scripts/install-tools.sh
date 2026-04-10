#!/bin/bash
# ============================================================
# install-tools.sh — EC2 User Data Bootstrap Script
# WHY: Runs once on first EC2 boot to install all CI tool deps.
#      Referenced by terraform/main.tf user_data.
# ============================================================
set -euo pipefail
LOG="/var/log/devsecops-bootstrap.log"
exec > >(tee -a "$LOG") 2>&1

echo "======================================================"
echo "  DevSecOps Bootstrap — $(date)"
echo "======================================================"

# ── System Update ──────────────────────────────────────────
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl wget git unzip gnupg \
  apt-transport-https ca-certificates \
  software-properties-common lsb-release \
  jq make

# ── Docker ─────────────────────────────────────────────────
echo "[Step 1] Installing Docker..."
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# ── Docker Compose v2 ──────────────────────────────────────
echo "[Step 2] Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
  | jq -r '.tag_name')
curl -fsSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ── AWS CLI v2 ─────────────────────────────────────────────
echo "[Step 3] Installing AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ── kubectl ────────────────────────────────────────────────
echo "[Step 4] Installing kubectl..."
KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# ── Helm ───────────────────────────────────────────────────
echo "[Step 5] Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── Trivy ──────────────────────────────────────────────────
echo "[Step 6] Installing Trivy..."
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
  https://aquasecurity.github.io/trivy-repo/deb \
  $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt-get update -y && apt-get install -y trivy

# ── Cosign ─────────────────────────────────────────────────
echo "[Step 7] Installing Cosign..."
COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest \
  | jq -r '.tag_name')
curl -fsSL \
  "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# ── ArgoCD CLI ─────────────────────────────────────────────
echo "[Step 8] Installing ArgoCD CLI..."
ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest \
  | jq -r '.tag_name')
curl -fsSL \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
  -o /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd

# ── Java 21 (for local Maven runs if needed) ───────────────
echo "[Step 9] Installing Java 21..."
apt-get install -y openjdk-21-jdk-headless
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment
echo "export PATH=\$JAVA_HOME/bin:\$PATH"  >> /etc/environment

# ── Maven ──────────────────────────────────────────────────
echo "[Step 10] Installing Maven..."
MVN_VERSION="3.9.6"
curl -fsSL \
  "https://archive.apache.org/dist/maven/maven-3/${MVN_VERSION}/binaries/apache-maven-${MVN_VERSION}-bin.tar.gz" \
  | tar -xz -C /opt/
ln -sf /opt/apache-maven-${MVN_VERSION}/bin/mvn /usr/local/bin/mvn

# ── Signal completion ─────────────────────────────────────
echo ""
echo "======================================================"
echo " ✅ All tools installed successfully! — $(date)"
echo "======================================================"

# Verify installs
docker --version
docker-compose --version
aws --version
kubectl version --client
helm version --short
trivy --version
cosign version
argocd version --client
java -version
mvn -version
