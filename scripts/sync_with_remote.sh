#!/usr/bin/env bash
set -euo pipefail
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
STAMP="$(date +%F-%H%M%S)"

echo "🔒 Creating safety backup branches…"
git branch "backup/local-pre-rebase-${STAMP}" || true
git fetch "$REMOTE"
git branch "backup/remote-${BRANCH}-${STAMP}" "$REMOTE/$BRANCH" || true

echo "📊 Recent graph (local & remote):"
git log --oneline --graph --decorate --all --max-count=25 || true
echo

# Make sure .gitignore stops noisy stuff
if ! grep -q '^logs/' .gitignore 2>/dev/null; then
  {
    echo '# Logs'
    echo 'logs/'
    echo '*.log'
    echo
    echo '# Backups'
    echo '*.tar.gz'
    echo
    echo '# Security baselines'
    echo '.secrets.baseline'
  } >> .gitignore
  git add .gitignore
  git commit -m "chore: gitignore logs/backups/baseline" || true
fi

# If logs were ever tracked, untrack them (keep files on disk)
if git ls-files --error-unmatch logs >/dev/null 2>&1; then
  git rm -r --cached logs || true
  git commit -m "chore: stop tracking logs/" || true
fi

echo "⬇️  Rebase local ${BRANCH} onto ${REMOTE}/${BRANCH}…"
git fetch "$REMOTE"
git rebase "$REMOTE/$BRANCH" || {
  echo
  echo "⚠️ Rebase hit conflicts."
  echo "   Fix conflicts in your editor, then run:"
  echo "     git add <resolved files>"
  echo "     git rebase --continue"
  echo "   To bail out:"
  echo "     git rebase --abort"
  exit 2
}

echo "⬆️  Push (fast-forward) to $REMOTE/$BRANCH…"
git push "$REMOTE" "$BRANCH"

echo "✅ Synced successfully."
