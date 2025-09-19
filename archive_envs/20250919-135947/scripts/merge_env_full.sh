#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/projects/coinbase_pipeline"
FINAL_ENV="$TARGET_DIR/.env.full"
BACKUP="$TARGET_DIR/.env.backup.$(date +%s)"

echo "==> Backing up current .env to $BACKUP"
[ -f "$TARGET_DIR/.env" ] && cp "$TARGET_DIR/.env" "$BACKUP"

echo "==> Collecting all env-like files under ~/projects..."
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
      if [ -n "$key" ] && [ -n "$val" ]; then
        if [ -z "${SEEN[$key]:-}" ]; then
          echo "$key=$val"
          SEEN[$key]=1
        fi
      fi
    done < "$f"
    echo
  done
} > "$FINAL_ENV"

echo "==> Wrote merged env to $FINAL_ENV"
echo "==> Open in gedit for review:"
echo "    gedit $FINAL_ENV &"
