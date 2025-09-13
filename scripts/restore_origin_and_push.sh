#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$HOME/projects/coinbase_pipeline}"
BRANCH="${BRANCH:-main}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
# Use SSH by default (you already used it). Swap to HTTPS if you prefer.
REMOTE_URL="${REMOTE_URL:-git@github.com:andybahtwin-maker/coinbase_pipeline.git}"

cd "$REPO"

echo "🧹 Cleaning duplicate branch config (if any)…"
git config --unset-all branch.${BRANCH}.remote || true
git config --unset-all branch.${BRANCH}.merge || true

echo "🔗 Restoring remote '$REMOTE_NAME' → $REMOTE_URL"
git remote remove "$REMOTE_NAME" 2>/dev/null || true
git remote add "$REMOTE_NAME" "$REMOTE_URL"

echo "🔎 Remotes:"
git remote -v

echo "🔧 Setting upstream tracking for ${BRANCH}"
git branch --set-upstream-to=${REMOTE_NAME}/${BRANCH} ${BRANCH} 2>/dev/null || true

echo "⬆️  Pushing rewritten history (force-with-lease)…"
git push --force-with-lease "$REMOTE_NAME" "$BRANCH"

echo "✅ Done. Refresh GitHub to verify."
