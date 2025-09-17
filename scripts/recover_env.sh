#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

echo "==> Scanning repo for env files and backups…"
# Find likely env files in repo (skip venv + .git)
find . \
  -path './.venv' -prune -o \
  -path './.git' -prune -o \
  -type f \( -name '.env' -o -name '.env.*' -o -name '*env*.bak' -o -name '*.env' \) -print \
| sed 's|^\./||' | sort > .env_candidates_repo.txt || true

echo "==> Scanning common local backup spots…"
# Look in a local archive folder if present
if [ -d ".local_archive" ]; then
  find .local_archive -type f -print | sort >> .env_candidates_repo.txt
fi

# Grep for known keys across repo to catch misnamed files
echo "==> Grepping for known key names in repo… (this can take a moment)"
grep -RnasI --binary-files=without-match \
  -E 'GROQ_API_KEY|OPENAI_API_KEY|CB_API_KEY|CDP_API_KEY_FILE|NOTION_TOKEN' \
  -- . 2>/dev/null | sed 's|^\./||' > .env_hits_repo.txt || true

# Also check shell rc files (sometimes keys live there)
echo "==> Checking shell rc files for exported keys…"
RC_HITS=""
for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
  [ -f "$f" ] && RC_HITS+=$(grep -nE 'GROQ_API_KEY|OPENAI_API_KEY|CB_API_KEY|CDP_API_KEY_FILE|NOTION_TOKEN' "$f" || true; echo)
done
printf "%s" "$RC_HITS" > .env_hits_shell.txt

echo
echo "==> Possible env files in repo:"
cat .env_candidates_repo.txt || true
echo
echo "==> Lines with secrets-like keys found in repo (file:line:match):"
[ -s .env_hits_repo.txt ] && sed -n '1,120p' .env_hits_repo.txt || echo "(none found)"
echo
echo "==> Shell rc files hits (may contain exports):"
[ -s .env_hits_shell.txt ] && sed -n '1,120p' .env_hits_shell.txt || echo "(none found)"

# Attempt automated recovery: pick the most recent file containing GROQ_API_KEY or OPENAI_API_KEY
echo
echo "==> Attempting to select best candidate automatically…"
BEST=""
while IFS= read -r p; do
  if [ -f "$p" ] && grep -qE '^(GROQ_API_KEY|OPENAI_API_KEY)=' "$p"; then
    BEST="$p"
  fi
done < <( (cat .env_candidates_repo.txt 2>/dev/null || true) )

if [ -n "$BEST" ]; then
  echo "==> Found candidate with AI keys: $BEST"
  cp -f "$BEST" .env.recovered
  echo "==> Wrote .env.recovered (does NOT replace your .env)."
  exit 0
fi

# If nothing matched, try any candidate that at least has Coinbase keys
while IFS= read -r p; do
  if [ -f "$p" ] && grep -qE '^(CB_API_KEY|CDP_API_KEY_FILE)=' "$p"; then
    BEST="$p"
  fi
done < <( (cat .env_candidates_repo.txt 2>/dev/null || true) )

if [ -n "$BEST" ]; then
  echo "==> Found candidate with Coinbase fields: $BEST"
  cp -f "$BEST" .env.recovered
  echo "==> Wrote .env.recovered (add GROQ_API_KEY manually)."
  exit 0
fi

echo "==> No enriched env found. Check .env_hits_repo.txt and .env_hits_shell.txt manually."
exit 1
