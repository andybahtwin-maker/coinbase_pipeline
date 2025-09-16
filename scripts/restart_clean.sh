#!/usr/bin/env bash
set -euo pipefail
echo "==> Killing old Streamlit…"
pkill -f "streamlit run" 2>/dev/null || true
command -v fuser >/dev/null 2>&1 && fuser -k 8501/tcp 2>/dev/null || true
echo "==> Clearing caches…"
rm -rf ~/.cache/streamlit ~/.streamlit/logs 2>/dev/null || true
chmod +x ./run_simple.sh
echo "==> Starting dashboard on http://localhost:8501"
exec ./run_simple.sh
