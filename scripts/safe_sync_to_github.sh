#!/usr/bin/env bash
set -euo pipefail

echo "==> Safe GitHub sync starting..."

# 1. Ensure we're in repo root
cd "$(dirname "$0")/.."

# 2. Protect secrets: ignore .env and backups
if ! grep -q '^.env' .gitignore 2>/dev/null; then
  echo ".env" >> .gitignore
  echo ".env.*" >> .gitignore
fi

# 3. Stage all changes except ignored
git add -A

# 4. Commit with timestamped message
git commit -m "Safe sync: $(date -u +'%Y-%m-%d %H:%M:%S UTC')" || \
  echo "==> Nothing to commit."

# 5. Push to origin main
git push origin main

echo "==> Sync complete!"
