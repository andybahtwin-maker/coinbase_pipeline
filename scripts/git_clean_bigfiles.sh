#!/usr/bin/env bash
set -euo pipefail

echo "==> Move giant files to local archive"
mkdir -p .local_archive
for f in coinbase_pipeline-backup-*.tar.gz coinbase_pipeline.zip; do
  [ -f "$f" ] && mv "$f" .local_archive/ || true
done

echo "==> Add to .gitignore"
cat >> .gitignore <<'GI'

# Ignore local archives and large backups
.local_archive/
*.tar.gz
*.zip
*.bak*
*_bak*
GI

echo "==> Remove from Git index (keep files locally)"
git rm --cached -r .local_archive *.tar.gz *.zip *.bak* *_bak* 2>/dev/null || true

echo "==> Commit cleaned state"
git add .gitignore
git commit -m "chore: remove large backup files, ignore archives"
echo "Now run: git push origin main"
