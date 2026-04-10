#!/bin/bash
# ============================================================
# cosign-setup.sh — Generate Cosign key pair for image signing
# WHY: Image signing proves to ArgoCD/K8s that an image was
#      built and pushed by YOUR Jenkins pipeline, not a 3rd party.
#
# Usage: bash cosign/cosign-setup.sh
# Output: cosign.key (private), cosign.pub (public)
# ============================================================
set -euo pipefail

COSIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================"
echo "  Cosign Key Pair Generation — $(date)"
echo "======================================================"

# Check cosign is installed
if ! command -v cosign &>/dev/null; then
  echo "❌ cosign not found. Install it from https://github.com/sigstore/cosign"
  exit 1
fi

cd "$COSIGN_DIR"

# Generate key pair (will prompt for password)
echo "[1/3] Generating Cosign key pair (you'll be prompted for a passphrase)..."
echo "  ⚠️  Remember this passphrase — Jenkins needs it as 'cosign-password' credential"
cosign generate-key-pair

echo ""
echo "[2/3] Base64-encoding private key for .env / Jenkins Secret File credential..."
COSIGN_KEY_B64=$(base64 -w 0 cosign.key)
echo "  COSIGN_PRIVATE_KEY_B64=$COSIGN_KEY_B64"
echo ""
echo "  → Copy the above line into your .env file"

echo ""
echo "[3/3] Public key (add this to your README for verification):"
cat cosign.pub

echo ""
echo "======================================================"
echo " ✅ Cosign setup complete!"
echo ""
echo "  Files created:"
echo "    cosign/cosign.key  (🔒 PRIVATE — never commit this!)"
echo "    cosign/cosign.pub  (✅ public  — safe to commit)"
echo ""
echo "  Jenkins setup:"
echo "    1. Add cosign.key as Jenkins 'Secret File' credential → id: cosign-private-key"
echo "    2. Add cosign passphrase as Jenkins 'Secret Text' credential → id: cosign-password"
echo "======================================================"
