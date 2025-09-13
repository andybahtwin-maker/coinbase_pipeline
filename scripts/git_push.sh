#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# safety backup
STAMP=$(date +%F-%H%M%S)
tar -czf "../coinbase_pipeline-backup-$STAMP.tgz" .

# ensure .gitignore is sane
cat <<'EOF' > .gitignore
# venv & local
.venv/
__pycache__/
*.pyc

# logs & artifacts
logs/
*.log
*.tgz
*.tar.gz
*.zip

# secrets
.env
.env.*
*.pem
.secrets.baseline
EOF

git add .
git commit -m "chore: update project state before push" || echo "ℹ️ nothing to commit"

# ensure remote origin
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin git@github.com:andybahtwin-maker/coinbase_pipeline.git
fi

# push (force-with-lease to handle history rewrites)
git push --force-with-lease origin main
