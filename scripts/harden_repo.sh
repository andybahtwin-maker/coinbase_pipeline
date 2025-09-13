#!/usr/bin/env bash
set -euo pipefail

BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
REMOTE_URL_DEFAULT="git@github.com:andybahtwin-maker/coinbase_pipeline.git"
REMOTE_URL="${REMOTE_URL:-$REMOTE_URL_DEFAULT}"
STAMP="$(date +%F-%H%M%S)"

echo "🔒 Safety tags before rewrite…"
git fetch "$REMOTE" || true
git tag "safety/before-harden-${STAMP}" || true
git tag "safety/remote-${STAMP}" "$REMOTE/$BRANCH" || true

# 1) Harden .gitignore
cat > .gitignore <<'IGN'
# Python
__pycache__/
*.pyc
.venv/
env/
venv/

# Node
node_modules/
npm-debug.log*
yarn-error.log*

# IDE / OS
.DS_Store
*.swp

# Logs & snapshots
logs/
*.log
snapshots/

# Archives
*.zip
*.tar.gz

# Secrets (NEVER COMMIT)
.env
.env.*
source.env
*.pem
*key*.json*
cdp_api_key.json*
cb_ecdsa.pem
IGN

git add .gitignore
git commit -m "chore(security): harden .gitignore (secrets, venv, node_modules, logs, archives)" || true

# 2) Stop tracking currently-tracked offenders (keeps files on disk)
git rm -r --cached --ignore-unmatch \
  .venv node_modules snapshots logs \
  || true

git rm --cached --ignore-unmatch \
  .env .env.* source.env cb_ecdsa.pem cdp_api_key.json cdp_api_key.json.disabled \
  || true

git rm --cached --ignore-unmatch *.zip *.tar.gz || true

git commit -m "chore(security): stop tracking secrets and local artifacts" || true

# 3) Rewrite history to purge sensitive paths
use_filter_repo() {
  echo "🧹 Using git filter-repo…"
  git filter-repo --force --invert-paths \
    --path .venv \
    --path node_modules \
    --path snapshots \
    --path logs \
    --path .env \
    --path-glob ".env.*" \
    --path source.env \
    --path cb_ecdsa.pem \
    --path cdp_api_key.json \
    --path cdp_api_key.json.disabled \
    --path-glob "*.zip" \
    --path-glob "*.tar.gz"
}

use_filter_branch() {
  echo "🧹 Using git filter-branch fallback…"
  set +e
  git filter-branch --force --index-filter \
    "git rm -r --cached --ignore-unmatch .venv node_modules snapshots logs; \
     git rm -r --cached --ignore-unmatch .env .env.* source.env cb_ecdsa.pem cdp_api_key.json cdp_api_key.json.disabled; \
     git rm -r --cached --ignore-unmatch '*.zip' '*.tar.gz'" \
    --prune-empty --tag-name-filter cat -- --all
  RC=$?
  set -e
  if [[ $RC -ne 0 ]]; then
    echo "❌ filter-branch failed. Consider installing git-filter-repo."
    exit 1
  fi
}

if command -v git-filter-repo >/dev/null 2>&1 || git filter-repo -h >/dev/null 2>&1; then
  use_filter_repo
else
  use_filter_branch
fi

# filter-repo removes origin; restore it cleanly
echo "🔗 Restoring remote…"
git remote remove "$REMOTE" 2>/dev/null || true
git remote add "$REMOTE" "${REMOTE_URL}"

# Clean refs and GC
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d || true
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Fix duplicate branch config from prior runs (if any)
git config --unset-all branch.${BRANCH}.remote || true
git config --unset-all branch.${BRANCH}.merge || true
git branch --set-upstream-to=${REMOTE}/${BRANCH} ${BRANCH} 2>/dev/null || true

echo "⬆️  Pushing cleaned history (force-with-lease)…"
git fetch "$REMOTE" || true
git push --force-with-lease "$REMOTE" "$BRANCH"

echo "✅ Hardened repo pushed."
echo "🔑 NOW ROTATE EXPOSED KEYS (Coinbase, email, etc.)."
