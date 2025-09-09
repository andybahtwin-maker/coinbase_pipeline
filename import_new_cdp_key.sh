#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/projects/coinbase_pipeline"
DOWNLOADS="$HOME/Downloads"
SRC_FILE="$DOWNLOADS/cdp_API_key (1).json"
DEST_FILE="$PROJECT_DIR/cdp_api_key.json"

# Make sure project dir exists
mkdir -p "$PROJECT_DIR"

# Move and normalize filename
if [[ -f "$SRC_FILE" ]]; then
    echo "[*] Moving new API key from Downloads..."
    mv -f "$SRC_FILE" "$DEST_FILE"
    chmod 600 "$DEST_FILE"
    echo "[+] Key stored at $DEST_FILE"
else
    echo "[!] Could not find $SRC_FILE — double-check Downloads."
    exit 1
fi

# Ensure gitignore entry
if ! grep -q "cdp_api_key.json" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
    echo "cdp_api_key.json" >> "$PROJECT_DIR/.gitignore"
    echo "[+] Added to .gitignore"
fi

# Optional: clean conflicting old Coinbase env vars
ENV_FILE="$PROJECT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "[*] Cleaning old COINBASE_* vars from .env..."
    sed -i.bak '/^COINBASE_/d' "$ENV_FILE"
    echo "[+] Cleaned. Backup saved at .env.bak"
fi

echo "[✓] New Coinbase JSON key is ready to use."
echo "    Run: python coinbase_helpers.py --test"
