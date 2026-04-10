#!/bin/bash
# ============================================================
# setup-monitoring.sh — Install Prometheus + Grafana via Helm
# Run AFTER: aws eks update-kubeconfig --name devsecops-eks
# ============================================================
set -euo pipefail

MONITORING_NS="monitoring"
GRAFANA_PASS="${GRAFANA_PASSWORD:-Grafana@2024!}"
APP_NS="devsecops"
APP_NAME="devsecops-app"

echo "======================================================"
echo "  Monitoring Stack Setup — $(date)"
echo "======================================================"

# ── Add Helm repo ──────────────────────────────────────────
echo "[1/4] Adding Prometheus Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ── Create namespace ───────────────────────────────────────
echo "[2/4] Creating monitoring namespace..."
kubectl create namespace "$MONITORING_NS" --dry-run=client -o yaml | kubectl apply -f -

# ── Install kube-prometheus-stack ─────────────────────────
echo "[3/4] Installing Prometheus + Grafana stack (~3 min)..."
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NS" \
  --values monitoring/prometheus/values.yaml \
  --set grafana.adminPassword="$GRAFANA_PASS" \
  --wait \
  --timeout 10m

# ── Apply custom alert rules ───────────────────────────────
echo "[4/4] Applying custom alerting rules..."
kubectl apply -f monitoring/prometheus/rules.yaml

echo ""
echo "======================================================"
echo " ✅ Monitoring setup complete!"
echo ""
echo "  Access Grafana (port-forward):"
echo "    kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n $MONITORING_NS"
echo "    → http://localhost:3000  (admin / $GRAFANA_PASS)"
echo ""
echo "  Access Prometheus:"
echo "    kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n $MONITORING_NS"
echo "    → http://localhost:9090"
echo "======================================================"
