#!/usr/bin/env bash
set -euo pipefail

BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"

echo "🔄 Fetching latest from $REMOTE…"
git fetch "$REMOTE"

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "$REMOTE/$BRANCH" || echo 'UNKNOWN')"

echo "🔎 Local  $BRANCH: $LOCAL_SHA"
echo "🔎 Remote $BRANCH: $REMOTE_SHA"

echo "⬆️  Trying force-with-lease (standard)…"
if git push --force-with-lease "$REMOTE" "$BRANCH"; then
  echo "✅ Pushed with --force-with-lease"
  exit 0
fi

if [[ "$REMOTE_SHA" != "UNKNOWN" ]]; then
  echo "↪️ Retrying with explicit lease against $REMOTE_SHA…"
  if git push --force-with-lease=refs/heads/$BRANCH:$REMOTE_SHA "$REMOTE" "$BRANCH"; then
    echo "✅ Pushed with explicit --force-with-lease"
    exit 0
  fi
fi

echo "⚠️ Still blocked."
if [[ "${CONFIRM_FORCE:-}" == "YES" ]]; then
  echo "🚨 CONFIRM_FORCE=YES set — performing hard force push…"
  git push --force "$REMOTE" "$BRANCH"
  echo "✅ Hard force push completed."
else
  cat <<'MSG'
Refused to hard force without confirmation.

If you’re sure you want to overwrite the remote branch, run:
  CONFIRM_FORCE=YES scripts/push_after_rewrite.sh

(Or inspect differences first:)
  git log --oneline --decorate --graph -n 20 --all
MSG
  exit 2
fi
