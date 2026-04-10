#!/bin/bash
# ============================================================
# setup-argocd.sh — Install & configure ArgoCD on EKS
# Run AFTER: aws eks update-kubeconfig --name devsecops-eks
# ============================================================
set -euo pipefail

APP_NAME="devsecops-app"
ARGOCD_NS="argocd"
APP_NS="devsecops"
GIT_REPO="${GIT_REPO:-https://github.com/IdrisShaik/Devops_Project.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "======================================================"
echo "  ArgoCD Setup on EKS — $(date)"
echo "======================================================"

# ── Verify kubectl access ──────────────────────────────────
echo "[1/6] Verifying kubectl EKS access..."
kubectl cluster-info || { echo "❌ kubectl not configured. Run: aws eks update-kubeconfig --name devsecops-eks"; exit 1; }

# ── Install ArgoCD ─────────────────────────────────────────
echo "[2/6] Installing ArgoCD..."
kubectl create namespace "$ARGOCD_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$ARGOCD_NS" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "  Waiting for ArgoCD pods to be ready (~2 min)..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n "$ARGOCD_NS" \
  --timeout=300s

# ── Expose via LoadBalancer ────────────────────────────────
echo "[3/6] Exposing ArgoCD server via AWS LoadBalancer..."
kubectl patch svc argocd-server -n "$ARGOCD_NS" \
  -p '{"spec": {"type": "LoadBalancer"}}'

echo "  Waiting for LoadBalancer EXTERNAL-IP (~30s)..."
sleep 30
ARGOCD_LB=$(kubectl get svc argocd-server -n "$ARGOCD_NS" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "  ArgoCD URL: https://$ARGOCD_LB"

# ── Get admin password ─────────────────────────────────────
echo "[4/6] Getting initial admin password..."
ARGOCD_PASS=$(kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "  Initial password: $ARGOCD_PASS"

# ── Log in & generate API token ───────────────────────────
echo "[5/6] Generating ArgoCD API token for Jenkins..."
argocd login "$ARGOCD_LB" \
  --username admin \
  --password "$ARGOCD_PASS" \
  --insecure \
  --grpc-web

ARGOCD_TOKEN=$(argocd account generate-token --account admin)
echo "  ARGOCD_TOKEN=$ARGOCD_TOKEN"

# ── Create ArgoCD App ──────────────────────────────────────
echo "[6/6] Creating ArgoCD Application..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: $ARGOCD_NS
spec:
  project: default
  source:
    repoURL: $GIT_REPO
    targetRevision: $GIT_BRANCH
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NS
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo ""
echo "======================================================"
echo " ✅ ArgoCD setup complete!"
echo "  URL:   https://$ARGOCD_LB"
echo "  User:  admin"
echo "  Pass:  $ARGOCD_PASS"
echo ""
echo "  Add to .env:  ARGOCD_SERVER=$ARGOCD_LB"
echo "  Add to .env:  ARGOCD_TOKEN=$ARGOCD_TOKEN"
echo "  Add ARGOCD_TOKEN to Jenkins credentials as 'argocd-token'"
echo "======================================================"
