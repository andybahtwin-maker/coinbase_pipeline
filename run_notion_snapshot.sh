#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -d .venv ]; then python3 -m venv .venv; fi
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools >/dev/null
pip install -r requirements.txt >/dev/null
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
exec streamlit run dashboard/simple_app.py
