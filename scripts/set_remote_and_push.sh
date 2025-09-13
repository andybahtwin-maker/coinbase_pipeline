#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/set_remote_and_push.sh                         # uses defaults below
#   REMOTE_URL=git@github.com:andybahtwin-maker/coinbase_pipeline.git scripts/set_remote_and_push.sh  # SSH
#   REMOTE_NAME=origin BRANCH=main scripts/set_remote_and_push.sh

REPO="${1:-$HOME/projects/coinbase_pipeline}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
REMOTE_URL="${REMOTE_URL:-https://github.com/andybahtwin-maker/coinbase_pipeline.git}"
BRANCH="${BRANCH:-main}"

cd "$REPO"

# Ensure branch exists / is named as expected
git rev-parse --verify "$BRANCH" >/dev/null 2>&1 || git branch -M "$BRANCH"

# Configure remote
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

# Show remotes (sanity)
git remote -v

# Push and set upstream
git push -u "$REMOTE_NAME" "$BRANCH"
