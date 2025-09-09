#!/usr/bin/env bash
set -euo pipefail

echo "🔒 Hardening repo security..."

# 1. Add safe .gitignore if missing
if [ ! -f .gitignore ]; then
  echo "Creating .gitignore..."
  cat <<'GITIGNORE' > .gitignore
# Environment and secret files
.env
.env.*
!.env.example

# Keys and certificates
*.pem
*.key
*.crt

# Python cache
__pycache__/
*.py[cod]
*.pyo
*.pyd
*.so
*.egg-info/

# Local dev / IDE
.vscode/
.idea/
.DS_Store
GITIGNORE
else
  echo "Updating existing .gitignore..."
  grep -qxF '.env' .gitignore || echo '.env' >> .gitignore
  grep -qxF '.env.*' .gitignore || echo '.env.*' >> .gitignore
  grep -qxF '!.env.example' .gitignore || echo '!.env.example' >> .gitignore
fi

# 2. Add a clean .env.example template
if [ ! -f .env.example ]; then
  echo "Creating .env.example..."
  cat <<'ENVEXAMPLE' > .env.example
# Example environment variables for Coinbase Pipeline
COINBASE_API_KEY=your_api_key_here
COINBASE_API_SECRET=your_api_secret_here
EMAIL_USER=example@gmail.com
EMAIL_PASS=your_app_password_here
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
ENVEXAMPLE
fi

# 3. Remove any tracked secrets from git history
if git ls-files | grep -qE '\.env(\.bak)?|\.pem|\.key'; then
  echo "Removing tracked secret files..."
  git rm --cached -f $(git ls-files | grep -E '\.env(\.bak)?|\.pem|\.key')
fi

echo "✅ Repo hardened. Next steps:"
echo "1. Rotate any API keys or secrets that may already be committed."
echo "2. Commit these changes: git add .gitignore .env.example harden_repo.sh && git commit -m 'Harden repo security'"
echo "3. If you want to purge leaked secrets from full git history, run:"
echo "     npx git-filter-repo --path .env --invert-paths"
