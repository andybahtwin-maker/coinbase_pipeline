#!/usr/bin/env bash
set -euo pipefail

# Set the GitHub remote (SSH form; change to HTTPS if you prefer)
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:andybahtwin-maker/coinbase_pipeline.git

# Double-check remote
echo "==> Remote set to:"
git remote -v

# Push cleaned history to GitHub
echo "==> Force pushing clean repo to GitHub..."
git push origin main --force

echo "==> Done. GitHub now has the cleaned repo (no big backups, no junk)."
