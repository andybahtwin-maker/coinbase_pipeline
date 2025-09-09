#!/usr/bin/env bash
set -euo pipefail

PROJECT="$HOME/projects/coinbase_pipeline"
REPO_URL="https://github.com/andybahtwin-maker/coinbase_pipeline.git"

cd "$PROJECT"

# Make sure .gitignore exists and is safe
cat > .gitignore <<EOG
# Ignore secrets and local files
cdp_api_key*.json
.env
.venv/
__pycache__/
*.pyc
*.sqlite3
*.log
EOG

# Init git if needed
git init

# Add remote (ignore error if already set)
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

# Stage and commit everything
git add .
git commit -m "Push current coinbase_pipeline project"

# Push to GitHub
git branch -M main
git push -u origin main --force
