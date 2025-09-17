#!/usr/bin/env bash
set -euo pipefail

TARGET="$HOME/projects/coinbase_pipeline/.env"
BACKUP="$HOME/projects/coinbase_pipeline/.env.pre_ai_merge_$(date +%s).bak"

echo "==> Target .env: $TARGET"
[ -f "$TARGET" ] || { echo "!! Target .env not found: $TARGET"; exit 1; }

# Collect candidate env files across ~/projects (skip venvs and git)
echo "==> Scanning ~/projects for env files with AI keys..."
mapfile -t CANDIDATES < <(find "$HOME/projects" \
  -path '*/.venv/*' -prune -o \
  -path '*/.git/*' -prune -o \
  -type f \( -name '.env' -o -name '.env.*' -o -name '*.env' \) -print)

# Filter to those that actually contain non-empty AI keys
declare -A MTIMES
FILTERED=()
for f in "${CANDIDATES[@]}"; do
  if grep -qE '^[[:space:]]*GROQ_API_KEY=[^#[:space:]].+' "$f" || \
     grep -qE '^[[:space:]]*OPENAI_API_KEY=[^#[:space:]].+' "$f"; then
    FILTERED+=("$f")
    MTIMES["$f"]=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
  fi
done

if [ ${#FILTERED[@]} -eq 0 ]; then
  echo "!! No .env with non-empty GROQ_API_KEY or OPENAI_API_KEY found under ~/projects."
  echo "   You can still open $TARGET and paste your key manually."
  exit 2
fi

# Pick the most recently modified candidate
BEST="${FILTERED[0]}"
BEST_MTIME="${MTIMES["$BEST"]}"
for f in "${FILTERED[@]}"; do
  if [ "${MTIMES["$f"]}" -gt "$BEST_MTIME" ]; then
    BEST="$f"
    BEST_MTIME="${MTIMES["$f"]}"
  fi
done

echo "==> Using keys from: $BEST"

# Extract values (strip quotes)
extract_val() {
  local key="$1" file="$2"
  local line
  line="$(grep -E "^[[:space:]]*$key=" "$file" | tail -n1 || true)"
  line="${line#*=}"
  line="${line%\"}"; line="${line#\"}"
  line="${line%\'}"; line="${line#\'}"
  echo -n "$line"
}

GROQ_API_KEY_VAL="$(extract_val GROQ_API_KEY "$BEST")"
OPENAI_API_KEY_VAL="$(extract_val OPENAI_API_KEY "$BEST")"

cp "$TARGET" "$BACKUP"
echo "==> Backed up current .env to $BACKUP"

# Update or append values in the target
update_or_append() {
  local key="$1" val="$2"
  if [ -n "$val" ]; then
    if grep -q "^$key=" "$TARGET"; then
      sed -i "s|^$key=.*|$key=$val|" "$TARGET"
    else
      echo "$key=$val" >> "$TARGET"
    fi
  fi
}

update_or_append "GROQ_API_KEY" "$GROQ_API_KEY_VAL"
update_or_append "OPENAI_API_KEY" "$OPENAI_API_KEY_VAL"

echo "==> Merge complete. Keys from $BEST have been added into $TARGET"
