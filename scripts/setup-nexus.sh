#!/bin/bash
# ============================================================
# setup-nexus.sh — Bootstrap Nexus repos + deploy user
# Run AFTER Nexus container is healthy (http://<IP>:8081)
# ============================================================
set -euo pipefail

NEXUS_HOST="${NEXUS_URL:-http://localhost:8081}"
NEXUS_CONTAINER="${NEXUS_CONTAINER:-nexus}"
NEXUS_ADMIN_PASS="${NEXUS_PASSWORD:-NexusAdmin@2024!}"
NEXUS_DEPLOY_USER="${NEXUS_DEPLOY_USER:-jenkins-deployer}"
NEXUS_DEPLOY_PASS="${NEXUS_DEPLOY_PASS:-NexusDeploy@2024!}"

echo "======================================================"
echo "  Nexus Repository Setup — $(date)"
echo "======================================================"

# ── Wait for Nexus to be ready ─────────────────────────────
echo "[1/5] Waiting for Nexus to be healthy..."
for i in $(seq 1 30); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$NEXUS_HOST/service/rest/v1/status" || true)
  if [ "$STATUS" = "200" ]; then
    echo "  Nexus is UP ✅"
    break
  fi
  echo "  Attempt $i/30 — waiting 10s..."
  sleep 10
done

# ── Get initial admin password ─────────────────────────────
echo "[2/5] Getting initial Nexus admin password..."
INITIAL_PASS=$(docker exec "$NEXUS_CONTAINER" \
  cat /nexus-data/admin.password 2>/dev/null || echo "$NEXUS_ADMIN_PASS")

echo "  Initial password retrieved."

# ── Change admin password ──────────────────────────────────
echo "[3/5] Changing admin password..."
curl -s -X PUT "$NEXUS_HOST/service/rest/v1/security/users/admin/change-password" \
  -u "admin:$INITIAL_PASS" \
  -H "Content-Type: text/plain" \
  -d "$NEXUS_ADMIN_PASS" || true

NEXUS_AUTH="admin:$NEXUS_ADMIN_PASS"

# ── Create Maven repositories ──────────────────────────────
echo "[4/5] Creating Maven repositories..."
# Snapshots repo
curl -s -X POST "$NEXUS_HOST/service/rest/v1/repositories/maven/hosted" \
  -u "$NEXUS_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-snapshots",
    "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "ALLOW"},
    "maven": {"versionPolicy": "SNAPSHOT", "layoutPolicy": "STRICT"}
  }' | jq . || true

# Releases repo
curl -s -X POST "$NEXUS_HOST/service/rest/v1/repositories/maven/hosted" \
  -u "$NEXUS_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-releases",
    "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "ALLOW_ONCE"},
    "maven": {"versionPolicy": "RELEASE", "layoutPolicy": "STRICT"}
  }' | jq . || true

# ── Create Jenkins deployer user ───────────────────────────
echo "[5/5] Creating Jenkins deployer user..."
curl -s -X POST "$NEXUS_HOST/service/rest/v1/security/users" \
  -u "$NEXUS_AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$NEXUS_DEPLOY_USER\",
    \"firstName\": \"Jenkins\",
    \"lastName\": \"Deployer\",
    \"emailAddress\": \"jenkins@devsecops.local\",
    \"password\": \"$NEXUS_DEPLOY_PASS\",
    \"status\": \"active\",
    \"roles\": [\"nx-anonymous\", \"nx-developer\"]
  }" | jq . || true

echo ""
echo "======================================================"
echo " ✅ Nexus setup complete!"
echo "  Repos created: maven-snapshots, maven-releases"
echo "  Deploy user:   $NEXUS_DEPLOY_USER / $NEXUS_DEPLOY_PASS"
echo "  Add these to Jenkins credentials as 'nexus-credentials'"
echo "======================================================"
