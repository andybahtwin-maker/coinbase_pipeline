#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv >/dev/null 2>&1 || true
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install streamlit pandas >/dev/null

echo "==> Launching Streamlit demo on http://localhost:8501"
exec streamlit run demo_app.py
