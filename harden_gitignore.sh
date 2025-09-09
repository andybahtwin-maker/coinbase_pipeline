#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(pwd)"
echo "Repo: $REPO_DIR"

# 1) Ensure .git exists
git rev-parse --is-inside-work-tree >/dev/null

# 2) Create snapshots/.gitkeep so the folder exists but CSVs are ignored
mkdir -p snapshots
touch snapshots/.gitkeep

# 3) Desired ignore rules (project-specific + Python defaults)
cat > .gitignore.additions <<'RULES'
# --- Secrets & env ---
.env
*.env
*.env.*.bak
*.bak
cdp_api_key.json
cdp_api_key*.json
cdp*api*key*.json
*_api_key*.json
*.pem
*.key

# --- Local runtime / venv ---
.venv/
__pycache__/
*.py[cod]
*.egg-info/
.cache/
.DS_Store

# --- Node stuff (in case) ---
node_modules/
npm-debug.log*
yarn.lock
package-lock.json

# --- Data / outputs ---
data/
snapshots/*.csv
!snapshots/.gitkeep

# --- IDE/editor noise ---
.vscode/
.idea/
*.swp
*.swo
RULES

# 4) Merge: append missing lines only (idempotent)
touch .gitignore
awk 'NR==FNR{a[$0]=1;next} {print} END{for(k in a){print k}}' .gitignore .gitignore.additions \
  | awk 'NF' | awk '!seen[$0]++' > .gitignore.new
mv .gitignore.new .gitignore
rm -f .gitignore.additions

# 5) Untrack any secrets/artifacts already in Git history index (leave files on disk)
echo "Untracking any accidentally committed secrets/artifacts (keeping local copies)…"
# Build a list of tracked paths matching our ignores
TRACKED_TO_UNTRACK=$(git ls-files -z -- \
  '.env' '*.env' '*.env.*.bak' '*.bak' \
  'cdp_api_key.json' 'cdp_api_key*.json' 'cdp*api*key*.json' '*_api_key*.json' \
  '*.pem' '*.key' \
  '.venv' '.venv/*' \
  'data/*' 'snapshots/*.csv' 2>/dev/null | tr -d '\0' || true)

if [ -n "${TRACKED_TO_UNTRACK:-}" ]; then
  # shellcheck disable=SC2086
  git rm --cached -r $TRACKED_TO_UNTRACK || true
else
  echo "  (No tracked sensitive/artifact files found.)"
fi

# 6) Stage safe files and commit
git add .gitignore snapshots/.gitkeep || true
git commit -m "Harden .gitignore; keep snapshots folder; untrack local secrets/artifacts" || true

echo "Done. If you want to push:"
echo "  git push origin main"
