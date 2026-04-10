#!/bin/bash
# ============================================================
# setup-sonarqube.sh — Bootstrap SonarQube project + token + webhook
# Run AFTER SonarQube container is healthy (http://<IP>:9000)
# ============================================================
set -euo pipefail

SONAR_HOST="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_ADMIN_USER="admin"
SONAR_ADMIN_PASS="${SONAR_ADMIN_PASS:-admin}"  # SonarQube default first-login password
SONAR_NEW_PASS="${SONAR_NEW_PASS:-SonarAdmin@2024!}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
PROJECT_KEY="devsecops-app"
PROJECT_NAME="DevSecOps App"

echo "======================================================"
echo "  SonarQube Setup — $(date)"
echo "======================================================"

# ── Wait for SonarQube to be ready ────────────────────────
echo "[1/5] Waiting for SonarQube to be healthy..."
for i in $(seq 1 30); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SONAR_HOST/api/system/status")
  if [ "$STATUS" = "200" ]; then
    SONAR_STATUS=$(curl -s "$SONAR_HOST/api/system/status" | jq -r '.status')
    if [ "$SONAR_STATUS" = "UP" ]; then
      echo "  SonarQube is UP ✅"
      break
    fi
  fi
  echo "  Attempt $i/30 — waiting 10s..."
  sleep 10
done

# ── Change default password ────────────────────────────────
echo "[2/5] Changing default admin password..."
curl -s -X POST "$SONAR_HOST/api/users/change_password" \
  -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASS" \
  --data-urlencode "login=admin" \
  --data-urlencode "password=$SONAR_NEW_PASS" \
  --data-urlencode "previousPassword=$SONAR_ADMIN_PASS" || true

SONAR_AUTH="$SONAR_ADMIN_USER:$SONAR_NEW_PASS"

# ── Create project ─────────────────────────────────────────
echo "[3/5] Creating SonarQube project..."
curl -s -X POST "$SONAR_HOST/api/projects/create" \
  -u "$SONAR_AUTH" \
  --data-urlencode "name=$PROJECT_NAME" \
  --data-urlencode "project=$PROJECT_KEY" \
  --data-urlencode "visibility=private" \
  | jq .

# ── Generate token for Jenkins ─────────────────────────────
echo "[4/5] Generating SonarQube token for Jenkins..."
TOKEN_RESPONSE=$(curl -s -X POST "$SONAR_HOST/api/user_tokens/generate" \
  -u "$SONAR_AUTH" \
  --data-urlencode "name=jenkins-token" \
  --data-urlencode "login=admin")

SONAR_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')

echo ""
echo "  ⚠️  SAVE THIS TOKEN — it's shown only once!"
echo "  SONAR_TOKEN=$SONAR_TOKEN"
echo ""

# ── Create Jenkins webhook ─────────────────────────────────
echo "[5/5] Creating Jenkins webhook in SonarQube..."
curl -s -X POST "$SONAR_HOST/api/webhooks/create" \
  -u "$SONAR_AUTH" \
  --data-urlencode "name=jenkins" \
  --data-urlencode "url=$JENKINS_URL/sonarqube-webhook/" \
  | jq .

echo ""
echo "======================================================"
echo " ✅ SonarQube setup complete!"
echo "  1. Add SONAR_TOKEN to Jenkins credentials as 'sonarqube-token'"
echo "  2. Update .env: SONAR_TOKEN=$SONAR_TOKEN"
echo "======================================================"
