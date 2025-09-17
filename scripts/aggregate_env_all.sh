#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/projects/coinbase_pipeline"
TARGET_ENV="$TARGET_DIR/.env"
BACKUP="$TARGET_DIR/.env.backup.$(date +%s)"

echo "==> Backing up current env..."
[ -f "$TARGET_ENV" ] && cp "$TARGET_ENV" "$BACKUP" && echo "    saved $BACKUP"

echo "==> Scanning ~/projects for env-like files..."
mapfile -t CANDIDATES < <(find "$HOME/projects" \
  -path '*/.venv/*' -prune -o \
  -path '*/.git/*' -prune -o \
  -type f \( -name ".env" -o -name ".env.*" -o -name "*.env" -o -name "*.env.example" -o -name "*.bak" \) -print)

declare -A VALUES
declare -A MTIMES

for f in "${CANDIDATES[@]}"; do
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    [ -z "$key" ] && continue
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    if [ -n "$val" ]; then
      if [ -z "${MTIMES[$key]:-}" ] || [ "$mtime" -gt "${MTIMES[$key]}" ]; then
        VALUES["$key"]="$val"
        MTIMES["$key"]=$mtime
      fi
    fi
  done <"$f"
done

OUT="$TARGET_DIR/.env.merged"
echo "==> Writing merged env -> $OUT"
{
  for k in "${!VALUES[@]}"; do
    echo "$k=${VALUES[$k]}"
  done | sort
} > "$OUT"

echo "==> Done. Open in gedit for review:"
echo "    gedit $OUT &"
