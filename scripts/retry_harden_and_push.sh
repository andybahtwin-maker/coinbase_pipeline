#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$PWD}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
# Default to SSH; set REMOTE_URL=HTTPS if you prefer
REMOTE_URL="${REMOTE_URL:-git@github.com:andybahtwin-maker/coinbase_pipeline.git}"
STAMP="$(date +%F-%H%M%S)"

cd "$REPO"

echo "🔒 Safety tags before retry…"
git fetch "$REMOTE" || true
git tag "safety/retry-before-${STAMP}" || true
git tag "safety/retry-remote-${STAMP}" "$REMOTE/$BRANCH" || true

echo "🧹 Clearing previous filter-repo metadata & stale refs…"
rm -rf .git/filter-repo || true
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d || true
git reflog expire --expire=now --all || true
git gc --prune=now --aggressive || true

# Ensure these paths are gone from history
PURGE_ARGS=(
  --invert-paths
  --path .venv
  --path node_modules
  --path snapshots
  --path logs
  --path .env
  --path-glob ".env.*"
  --path source.env
  --path cb_ecdsa.pem
  --path cdp_api_key.json
  --path cdp_api_key.json.disabled
  --path-glob "*.zip"
  --path-glob "*.tar.gz"
)

use_filter_repo() {
  echo "🧽 Trying git filter-repo…"
  git filter-repo --force "${PURGE_ARGS[@]}"
}

use_filter_branch() {
  echo "🧽 Fallback: git filter-branch… (slower)"
  set +e
  git filter-branch --force --index-filter \
    "git rm -r --cached --ignore-unmatch .venv node_modules snapshots logs; \
     git rm -r --cached --ignore-unmatch .env .env.* source.env cb_ecdsa.pem cdp_api_key.json cdp_api_key.json.disabled; \
     git rm -r --cached --ignore-unmatch '*.zip' '*.tar.gz'" \
    --prune-empty --tag-name-filter cat -- --all
  RC=$?
  set -e
  if [[ $RC -ne 0 ]]; then
    echo "❌ filter-branch failed; please install git-filter-repo or share the error output."
    exit 1
  fi
}

if command -v git-filter-repo >/dev/null 2>&1 || git filter-repo -h >/dev/null 2>&1; then
  if ! use_filter_repo; then
    echo "⚠️ filter-repo failed; falling back to filter-branch…"
    use_filter_branch
  fi
else
  use_filter_branch
fi

echo "🔗 Restoring origin remote…"
git remote remove "$REMOTE" 2>/dev/null || true
git remote add "$REMOTE" "$REMOTE_URL"
git remote -v

echo "🧼 Final GC…"
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d || true
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "🔧 Fix branch tracking (if needed)…"
git config --unset-all branch.${BRANCH}.remote 2>/dev/null || true
git config --unset-all branch.${BRANCH}.merge  2>/dev/null || true
git branch --set-upstream-to=${REMOTE}/${BRANCH} ${BRANCH} 2>/dev/null || true

echo "⬆️  Push cleaned history (force-with-lease)…"
git fetch "$REMOTE" || true
if ! git push --force-with-lease "$REMOTE" "$BRANCH"; then
  echo "↪️ Lease failed; pushing with explicit confirmation…"
  if [[ "${CONFIRM_FORCE:-}" == "YES" ]]; then
    git push --force "$REMOTE" "$BRANCH"
  else
    echo "Refused hard force. Re-run with: CONFIRM_FORCE=YES $0"
    exit 2
  fi
fi

echo "✅ Pushed cleaned history."
echo "🔑 Reminder: rotate any exposed keys (Coinbase, etc.)."
