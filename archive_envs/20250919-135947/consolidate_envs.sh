#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/projects/coinbase_pipeline"
OUTPUT="$PROJECT_DIR/.env"

echo "[1/3] Scanning for .env files..."
find "$HOME" -type f \( -iname "*.env" -o -iname ".env" \) 2>/dev/null > "$PROJECT_DIR/all_env_files.txt"

echo "[2/3] Extracting only valid KEY=VALUE pairs..."
: > "$OUTPUT.tmp"
while read -r f; do
  [ -f "$f" ] || continue
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=.*$' "$f" || true
done < "$PROJECT_DIR/all_env_files.txt" \
  | sed 's/^[ \t]*//;s/[ \t]*$//' \
  | sort -u \
  > "$OUTPUT.tmp"

echo "[3/3] Deduplicating, preferring last-seen values..."
awk -F= '!/^$/ {
  key=$1; sub(/^[ \t]+/,"",key); sub(/[ \t]+$/,"",key);
  val=$0; map[key]=val
}
END { for (k in map) print map[k] }' "$OUTPUT.tmp" \
  | sort \
  > "$OUTPUT"

rm -f "$OUTPUT.tmp"

echo "✅ Consolidated .env written to $OUTPUT"
echo "👉 Open it with: gedit $OUTPUT &"
