#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/projects/coinbase_pipeline"
FINAL_ENV="$TARGET_DIR/.env.full"
ACTIVE_ENV="$TARGET_DIR/.env"
BACKUP="$ACTIVE_ENV.backup.$(date +%s)"

echo "==> Backing up current .env (if exists) -> $BACKUP"
[ -f "$ACTIVE_ENV" ] && cp "$ACTIVE_ENV" "$BACKUP"

echo "==> Collecting env-like files across ~/projects..."
mapfile -t FILES < <(find "$HOME/projects" \
  -path '*/.venv/*' -prune -o \
  -path '*/.git/*' -prune -o \
  -type f \( -name ".env" -o -name ".env.*" -o -name "*.env" -o -name "*.env.example" -o -name "*.bak" \) -print)

declare -A SEEN

{
  for f in "${FILES[@]}"; do
    echo "# --- from $f ---"
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      [ -z "$key" ] && continue
      # Keep first non-empty occurrence
      if [ -n "$val" ] && [ -z "${SEEN[$key]:-}" ]; then
        echo "$key=$val"
        SEEN[$key]=1
      fi
    done < "$f"
    echo
  done
} > "$FINAL_ENV"

echo "==> Replacing active .env with merged file"
cp "$FINAL_ENV" "$ACTIVE_ENV"

echo "==> All done."
echo "   Final merged: $FINAL_ENV"
echo "   Active env:   $ACTIVE_ENV"
echo "   Backup:       $BACKUP"
echo
echo "==> Opening in gedit for review..."
gedit "$FINAL_ENV" &
