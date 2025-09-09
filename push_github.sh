#!/usr/bin/env bash
set -euo pipefail

USER="andybahtwin-maker"
REPO="coinbase_pipeline"

# Using your current token (replace later with a new one)
TOKEN="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"

# Remove existing origin if present
git remote remove origin 2>/dev/null || true

# Add origin with HTTPS+token
git remote add origin https://$TOKEN@github.com/$USER/$REPO.git

# Push main branch
git branch -M main
git push -u origin main

echo "✅ Code pushed to https://github.com/$USER/$REPO"
echo "⚠️  Reminder: Revoke and replace this token in GitHub → Settings → Developer Settings → Personal Access Tokens."
