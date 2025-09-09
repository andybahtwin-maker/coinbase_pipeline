#!/usr/bin/env bash
set -euo pipefail

# ensure venv
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install -r requirements.txt >/dev/null

exec streamlit run app.py
