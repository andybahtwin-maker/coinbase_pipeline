#!/usr/bin/env bash
set -euo pipefail

# Install git-filter-repo if missing
if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "Installing git-filter-repo..."
  pip install git-filter-repo
fi

echo "==> Purging backup/archive files from all history..."
git filter-repo --force \
  --path-glob '*.tar.gz' \
  --path-glob '*.zip' \
  --path-glob '*.bak*' \
  --path-glob '*_bak*' \
  --invert-paths

echo "==> Updating .gitignore so junk never comes back..."
cat >> .gitignore <<'GI'

# Ignore archives, backups, and junk
*.tar.gz
*.zip
*.bak*
*_bak*
.local_archive/
GI

git add .gitignore
git commit -m "chore: purge backups/archives and add ignore rules"

echo "==> Force pushing cleaned repo to GitHub..."
git push origin main --force

echo "==> Done. Repo is now lean; backups and archives are gone from GitHub."
