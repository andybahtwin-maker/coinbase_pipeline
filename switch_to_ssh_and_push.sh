#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(pwd)"
GH_USER="andybahtwin-maker"
GH_REPO="coinbase_pipeline"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

echo "Repo: $REPO_DIR"

# 1) Create SSH key if missing (no passphrase for simplicity; you can add one later)
if [[ ! -f "$KEY_PATH" ]]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  ssh-keygen -t ed25519 -C "$GH_USER@github" -f "$KEY_PATH" -N ""
  echo "✅ Created SSH key: $KEY_PATH"
else
  echo "ℹ️ SSH key already exists: $KEY_PATH"
fi

# 2) Start agent and add key
eval "$(ssh-agent -s)" >/dev/null
ssh-add -q "$KEY_PATH"
echo "🔑 ssh-agent running and key added."

# 3) Show public key to add in GitHub → Settings → SSH and GPG keys → New SSH key
echo
echo "----- COPY BELOW INTO GITHUB (Title: this laptop) -----"
cat "$KEY_PATH.pub"
echo "----- END COPY -----"
echo

# 4) Set remote to SSH (no more HTTPS prompts)
SSH_REMOTE="git@github.com:$GH_USER/$GH_REPO.git"
git remote set-url origin "$SSH_REMOTE"
echo "🔗 Remote set to: $(git remote get-url origin)"

# 5) Test GitHub SSH access (will be 'success' once you add key to GitHub)
echo "🧪 Testing GitHub SSH connectivity..."
ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true

# 6) Try pushing
echo "🚀 Attempting push..."
git push origin main || {
  echo
  echo "❗ Push failed. Likely because the SSH key isn't added to GitHub yet."
  echo "   Go to: https://github.com/settings/keys → 'New SSH key' → paste the key printed above."
  echo "   Then rerun: git push origin main"
  exit 1
}
echo "✅ Push succeeded over SSH."
