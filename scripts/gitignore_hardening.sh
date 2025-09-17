#!/usr/bin/env bash
set -euo pipefail

TARGET=".gitignore"
BACKUP=".gitignore.backup.$(date +%s)"

echo "==> Backing up current $TARGET -> $BACKUP"
cp "$TARGET" "$BACKUP" 2>/dev/null || true

# Patterns we always want ignored
read -r -d '' PATTERNS <<'EOF'
# --- Secrets & Local Overrides ---
.env
.env.*
*.env
*.env.*
*.bak
*.backup*
*.local
*.secrets
*.secret
cdp_api_key.json
notion_key.json
*credentials*.json
*token*.json
*pass*.txt
*secret*.txt
*keys*.txt
# --- Python junk ---
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.cache/
# --- Streamlit logs ---
.streamlit/logs
# --- OS / Editor junk ---
.DS_Store
Thumbs.db
*.swp
*.swo
EOF

# Append if not already in file
touch "$TARGET"
while IFS= read -r line; do
  if ! grep -Fxq "$line" "$TARGET"; then
    echo "$line" >> "$TARGET"
  fi
done <<< "$PATTERNS"

echo "==> Hardened $TARGET (safe to push now)"
echo "==> If needed, restore with: cp $BACKUP $TARGET"
