#!/bin/bash
# ============================================================
# bootstrap.sh — Full EC2 first-run setup
# Usage: sudo bash scripts/bootstrap.sh
# Calls install-tools.sh, then starts the CI docker compose stack
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================================" 
echo "  DevSecOps Full Bootstrap — $(date)"
echo "======================================================"

# Step 1: Install all tools
bash "$SCRIPT_DIR/install-tools.sh"

# Step 2: Load .env if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
  echo "[Bootstrap] Loading .env..."
  set -o allexport
  source "$PROJECT_ROOT/.env"
  set +o allexport
else
  echo "[Bootstrap] ⚠️  .env not found. Copy .env.example to .env and fill in values."
  exit 1
fi

# Step 3: Start CI stack
echo "[Bootstrap] Starting CI stack (Jenkins + SonarQube + Nexus)..."
cd "$PROJECT_ROOT"
docker compose -f docker-compose/docker-compose.yml up -d

echo ""
echo "======================================================"
echo " ✅ Bootstrap complete! CI stack is starting..."
echo ""
echo "  Wait ~2 min for services to be healthy, then access:"
echo "  Jenkins:   http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "  SonarQube: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "  Nexus:     http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081"
echo "======================================================"
