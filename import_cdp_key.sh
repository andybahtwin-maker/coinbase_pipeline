#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/projects/coinbase_pipeline"
DOWNLOADS="$HOME/Downloads"
SRC="$DOWNLOADS/cdp_api_key.json"
DEST="$PROJECT_DIR/cdp_api_key.json"

if [[ ! -f "$SRC" ]]; then
  echo "❌ Expected $SRC but it was not found."
  exit 1
fi

mkdir -p "$PROJECT_DIR"
cp -f "$SRC" "$DEST"
chmod 600 "$DEST"
echo "✅ Copied key to $DEST"

# ensure gitignore
GI="$PROJECT_DIR/.gitignore"
touch "$GI"
grep -qxF "cdp_api_key.json" "$GI" || echo "cdp_api_key.json" >> "$GI"

# strip old HMAC creds if present
ENV="$PROJECT_DIR/.env"
if [[ -f "$ENV" ]]; then
  sed -i.bak '/^COINBASE_API_KEY=/d;/^COINBASE_API_SECRET=/d;/^COINBASE_API_PASSPHRASE=/d' "$ENV" || true
  echo "ℹ️  Removed old HMAC vars from .env (backup at .env.bak)"
fi

echo "🎯 All set. Run:  python diag_cdp.py"
