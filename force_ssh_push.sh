#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/projects/coinbase_pipeline"
GH_USER="andybahtwin-maker"
GH_REPO="coinbase_pipeline"
SSH_REMOTE="git@github.com:${GH_USER}/${GH_REPO}.git"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

cd "$REPO_DIR"

# 0) Stop using HTTPS for this repo (prevents PAT prompts)
git remote set-url origin "$SSH_REMOTE" 2>/dev/null || git remote add origin "$SSH_REMOTE"

# 1) Ensure ssh-agent has a key
eval "$(ssh-agent -s)" >/dev/null
if [[ -f "$KEY_PATH" ]]; then
  ssh-add -l >/dev/null 2>&1 || true
  ssh-add "$KEY_PATH" >/dev/null 2>&1 || true
fi

# 2) Quick connectivity test (will print the success banner)
ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true

# 3) Commit anything pending and push over SSH
git add -A
git commit -m "Sync" || true
git branch -M main
git push -u origin main

echo "✅ Pushed to $SSH_REMOTE"
