#!/usr/bin/env bash
set -euo pipefail
# ensure venv
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip >/dev/null 2>&1 || true
[ -f requirements.txt ] && pip install -r requirements.txt || true
exec streamlit run dashboard/simple_app.py --server.port=8501 --server.headless=false
