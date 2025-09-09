#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/projects/coinbase_pipeline"
DOWNLOADS="$HOME/Downloads"
DEST_FILE="$PROJECT_DIR/cdp_api_key.json"

mkdir -p "$PROJECT_DIR"

# Find newest matching JSON (handles spaces, (1).json, etc.)
mapfile -d '' CANDIDATES < <(find "$DOWNLOADS" -maxdepth 1 -type f -iname '*cdp*key*.json' -print0 2>/dev/null || true)
if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "❌ No files matching *cdp*key*.json in $DOWNLOADS"
  exit 1
fi

# Pick newest by mtime
NEWEST="$(ls -t -- "${CANDIDATES[@]}" | head -n1)"

echo "📦 Importing: $NEWEST"
cp -f -- "$NEWEST" "$DEST_FILE"
chmod 600 "$DEST_FILE"
echo "✅ Stored at: $DEST_FILE"

# Ensure gitignore
GI="$PROJECT_DIR/.gitignore"
touch "$GI"
grep -qxF "cdp_api_key.json" "$GI" || echo "cdp_api_key.json" >> "$GI"

# Remove HMAC envs to avoid conflicts (keep a backup)
ENV="$PROJECT_DIR/.env"
if [[ -f "$ENV" ]]; then
  sed -i.bak '/^COINBASE_API_KEY=/d;/^COINBASE_API_SECRET=/d;/^COINBASE_API_PASSPHRASE=/d' "$ENV" || true
  echo "ℹ️  Cleaned legacy HMAC vars from .env (backup at .env.bak)"
fi

echo "🎯 Done. Next: run diag to verify."
