#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/projects"
TARGET="$BASE/coinbase_pipeline/.env.master"
BACKUP="$BASE/coinbase_pipeline/.env.backup.$(date +%s)"

echo "==> Backing up current .env (if present)..."
cp "$BASE/coinbase_pipeline/.env" "$BACKUP" 2>/dev/null || true

echo "==> Scanning $BASE for env files..."
mapfile -t FILES < <(find "$BASE" -type f -name ".env*" ! -path "*/.venv/*" ! -path "*/.git/*")

TMP="$(mktemp)"
> "$TMP"

for f in "${FILES[@]}"; do
  echo "# --- from $f ---" >> "$TMP"
  grep -E '^[A-Z0-9_]+=' "$f" | grep -vE '^\s*#' >> "$TMP" || true
  echo >> "$TMP"
done

echo "==> Deduplicating keys (last value wins)..."
awk -F= '
  {key=$1; sub(/^[[:space:]]+|[[:space:]]+$/, "", key); if(key!=""){last[key]=$0}}
  END{for(k in last) print last[k]}
' "$TMP" | sort > "$TARGET"

rm "$TMP"

echo "==> Merged env written to $TARGET"
echo "Open it with: gedit $TARGET"
echo "When ready, activate it with: cp $TARGET $BASE/coinbase_pipeline/.env"
