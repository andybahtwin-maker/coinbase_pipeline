set -euo pipefail

echo "==> Pruning local bloat (node/backups/caches)…"
mkdir -p .local_archive

# Common offenders (safe to remove)
rm -rf node_modules .cache .local .mozilla .pytest_cache __pycache__ || true

# Sweep *.bak and *_bak_* backups into archive (don’t delete, just move)
find . -maxdepth 1 -type f \( -name "*.bak" -o -name "*.bak_*" -o -name "*_bak*" \) -print0 | xargs -0 -I{} mv {} .local_archive/ || true
find . -maxdepth 1 -type f -name "streamlit_app_full.py.bak*" -print0 | xargs -0 -I{} mv {} .local_archive/ || true

# Ensure git ignores heavy stuff
cat > .gitignore <<'GI'
# Python
__pycache__/
*.pyc
.venv/
*.egg-info/

# Node / web
node_modules/
dist/
build/

# OS/editor
.DS_Store
Thumbs.db

# Secrets & env
.env
.env.*
cdp_api_key*.json
*secret*
*token*
*credentials*

# Caches / logs / junk
.cache/
.local/
*.log
*.bak
*_bak*
*.bak_*

# Big local dirs we never want in repo
/Downloads/
/Music/
/Videos/
/Desktop/
/dwhelper/
/.os/
/json/tmp/
GI

echo "==> Cleaning tracked junk from git index (keeps files locally)"
git rm -r --cached -q --ignore-unmatch node_modules .cache .local .mozilla __pycache__ || true
git add .gitignore
echo "==> Done. Large junk ignored; backups moved to .local_archive/"
