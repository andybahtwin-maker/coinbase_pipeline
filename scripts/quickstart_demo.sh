#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv || true
. .venv/bin/activate || true
python -m pip install --upgrade pip >/dev/null 2>&1 || true
if [ -f requirements.lock.txt ]; then
  pip install -r requirements.lock.txt >/dev/null 2>&1 || pip install -r requirements.lock.txt
else
  # minimal demo deps; your full requirements.txt can be installed later
  pip install streamlit==1.37.1 pandas==2.2.2 plotly==6.3.0 >/dev/null 2>&1 || true
fi
exec bash run_app.sh
