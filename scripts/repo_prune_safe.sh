set -euo pipefail

echo "==> Archiving backup clutter -> .local_archive/"
mkdir -p .local_archive
# Move only top-level backups (preserve code history; do not delete)
find . -maxdepth 1 -type f -name "*.bak*" -print0 | xargs -0 -I{} mv "{}" .local_archive/ 2>/dev/null || true
find . -maxdepth 1 -type f -name "*_bak*" -print0 | xargs -0 -I{} mv "{}" .local_archive/ 2>/dev/null || true
[ -d .local_archive ] && echo "   archived backups in .local_archive/"

echo "==> Remove common junk dirs (local only, keep git history clean)"
rm -rf node_modules .cache __pycache__ .pytest_cache .streamlit/logs 2>/dev/null || true

echo "==> Tighten .gitignore"
cat > .gitignore <<'GI'
# Python
__pycache__/
*.pyc
.venv/
*.egg-info/

# Streamlit
.streamlit/secrets.toml
.streamlit/logs/

# Node/web
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
*token*
*secret*
*credentials*

# Caches/logs/backups
.cache/
*.log
*.bak
*_bak*
*.bak_*

# Local data artifacts
/local_data/
/data/*.csv
/local_archive/
/json/tmp/
GI

echo "==> Remove from git index (keep files locally)"
git rm -r --cached -q --ignore-unmatch node_modules .cache __pycache__ .pytest_cache .streamlit/logs .local_archive || true
git add .gitignore
echo "==> Done. Repo is lean; local clutter ignored."
