set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/projects/coinbase_pipeline}"
BRANCH="snapshot-$(date +%Y%m%d-%H%M%S)"

cd "$REPO_DIR"

# Safety: never commit secrets
grep -qE '(^|/)\.env$' .gitignore || echo ".env" >> .gitignore
grep -qE '(^|/)cdp_api_key\.json$' .gitignore || echo "cdp_api_key.json" >> .gitignore
grep -qE '(^|/)\.venv/?' .gitignore || echo ".venv/" >> .gitignore
grep -qE '(^|/)__pycache__/?' .gitignore || echo "__pycache__/" >> .gitignore

git add .gitignore
git commit -m "harden: ensure .env, keys, venv, __pycache__ ignored" || true

# Create a clean snapshot branch from current HEAD (or init repo if needed)
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Initializing git repo..."
  git init
  git add .
  git commit -m "initial local import"
fi

git checkout -b "$BRANCH" || git checkout "$BRANCH"

# Stage everything but keep .env/keys ignored
git add -A
git commit -m "snapshot: local working state $(date -Iseconds)" || true

# Prefer SSH if available; fall back to HTTPS using your existing origin
if ! git remote get-url origin >/dev/null 2>&1; then
  # Set your origin to GitHub repo if missing
  git remote add origin git@github.com:andybahtwin-maker/coinbase_pipeline.git || \
  git remote add origin https://github.com/andybahtwin-maker/coinbase_pipeline.git
fi

# Try SSH push first
if git remote get-url origin | grep -q '^git@github.com:'; then
  git push -u origin "$BRANCH"
else
  # If origin is HTTPS and you’re already authenticated locally, this works.
  # If not, switch to SSH quickly:
  echo "If HTTPS push prompts, cancel and run: git remote set-url origin git@github.com:andybahtwin-maker/coinbase_pipeline.git"
  git push -u origin "$BRANCH"
fi

echo
echo "✓ Pushed local snapshot branch: $BRANCH"
echo "  Open: https://github.com/andybahtwin-maker/coinbase_pipeline/tree/$BRANCH"
