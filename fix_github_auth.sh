#!/usr/bin/env bash
set -euo pipefail

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null

# 1) Set the correct HTTPS remote (no token embedded)
REPO_URL="https://github.com/andybahtwin-maker/coinbase_pipeline.git"
git remote set-url origin "$REPO_URL"

# 2) Purge any cached/bad credentials for github.com
#    (git may have stored the broken ghp_... as the "username")
git credential reject <<CREDS
protocol=https
host=github.com
CREDS

# 3) Use the built-in credential cache so you don't get spammed every push
git config --global credential.helper 'cache --timeout=7200'
git config --global credential.useHttpPath true

echo
echo "✅ Remote reset to: $(git remote get-url origin)"
echo "🧹 Cleared cached credentials for github.com"
echo
echo "NEXT STEP:"
echo "  Run:  git push origin main"
echo "  When prompted:"
echo "    Username: your GitHub username (andybahtwin-maker)"
echo "    Password: your GitHub Personal Access Token (PAT) with 'repo' scope"
echo
echo "Tip: Create a PAT at https://github.com/settings/tokens (classic) or https://github.com/settings/personal-access-tokens"
echo "     Scope needed: repo  (no need for org/admin scopes)"
