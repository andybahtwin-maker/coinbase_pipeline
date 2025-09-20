#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv || true
. .venv/bin/activate
python -m pip install --upgrade pip >/dev/null 2>&1 || true
pip install streamlit==1.37.1 pandas==2.2.2 plotly==6.3.0 >/dev/null 2>&1 || true
exec python -m streamlit run ui/portfolio_app.py --server.headless true
