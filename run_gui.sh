#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
. .venv/bin/activate
STREAMLIT_BROWSER_GATHER_USAGE_STATS=false \
streamlit run streamlit_app.py --server.port 8501 --server.headless true
