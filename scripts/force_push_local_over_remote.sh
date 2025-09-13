#!/usr/bin/env bash
set -euo pipefail
: "${CONFIRM_FORCE:?Set CONFIRM_FORCE=YES to proceed.}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
STAMP="$(date +%F-%H%M%S)"

echo "🔒 Tagging safety points before force-push…"
git fetch "$REMOTE"
git tag "safety/local-${STAMP}" || true
git tag "safety/remote-${STAMP}" "$REMOTE/$BRANCH" || true

echo "⚠️ Force-pushing local $BRANCH to $REMOTE/$BRANCH (with lease)…"
git push --force-with-lease "$REMOTE" "$BRANCH"

echo "✅ Remote overwritten. (Safety tags created: safety/local-${STAMP}, safety/remote-${STAMP})"
