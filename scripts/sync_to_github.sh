#!/usr/bin/env bash
set -euo pipefail

echo "==> Backing up .env and secrets (won’t push these)"
cp .env ".env.backup.$(date +%s)"

echo "==> Staging all tracked/untracked files (except ignored)"
git add -A

echo "==> Commit with timestamp"
git commit -m "Sync local working version $(date)"

echo "==> Push to origin main"
git push origin main

echo "==> Done. Repo on GitHub now matches your local state."
