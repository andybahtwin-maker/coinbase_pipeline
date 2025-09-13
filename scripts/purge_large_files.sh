#!/usr/bin/env bash
set -euo pipefail

BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
STAMP="$(date +%F-%H%M%S)"

echo "🔒 Safety tags before history rewrite…"
git fetch "$REMOTE" || true
git tag "safety/before-purge-${STAMP}" || true
git tag "safety/remote-${STAMP}" "$REMOTE/$BRANCH" || true

# 1) Ensure .gitignore blocks future archives/logs
if [[ ! -f .gitignore ]] || ! grep -qE '(^|\n)(logs/|\*.log|\*.zip|\*.tar\.gz|\.secrets\.baseline)' .gitignore; then
  {
    echo "# Logs"
    echo "logs/"
    echo "*.log"
    echo
    echo "# Archives (prevent >100MB mistakes)"
    echo "*.zip"
    echo "*.tar.gz"
    echo
    echo "# Security baselines"
    echo ".secrets.baseline"
  } >> .gitignore
  git add .gitignore
  git commit -m "chore: tighten .gitignore for logs/archives/baseline" || true
fi

# 2) Stop tracking current big files in the working tree (keeps them on disk)
git rm -r --cached --ignore-unmatch coinbase_pipeline.zip || true
git rm -r --cached --ignore-unmatch logs || true
git rm -r --cached --ignore-unmatch *.tar.gz || true
git commit -m "chore: stop tracking archives and logs" || true

# 3) Rewrite history to REMOVE the big blobs
remove_with_filter_repo() {
  echo "🧹 Using git filter-repo to purge big files from history…"
  git filter-repo --force --invert-paths \
    --path coinbase_pipeline.zip \
    --path-glob '*.tar.gz' \
    --path-glob '*.zip'
}

remove_with_filter_branch() {
  echo "🧹 Using git filter-branch fallback to purge big files..."
  set +e
  git filter-branch --force --index-filter \
    "git rm -r --cached --ignore-unmatch coinbase_pipeline.zip *.zip *.tar.gz" \
    --prune-empty --tag-name-filter cat -- --all
  RC=$?
  set -e
  if [[ $RC -ne 0 ]]; then
    echo "❌ git filter-branch failed. You may need to install git-filter-repo."
    exit 1
  fi
}

if command -v git-filter-repo >/dev/null 2>&1 || git filter-repo -h >/dev/null 2>&1; then
  remove_with_filter_repo
else
  remove_with_filter_branch
fi

# 4) Garbage-collect to drop orphaned blobs locally
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d || true
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5) Push rewritten history (force-with-lease)
echo "⬆️  Force-pushing rewritten history to $REMOTE/$BRANCH (with lease)…"
git push --force-with-lease "$REMOTE" "$BRANCH"

echo "✅ Done. If anything looks off, you can inspect tags:"
echo "   git show safety/before-purge-${STAMP}"
echo "   git show safety/remote-${STAMP}"
