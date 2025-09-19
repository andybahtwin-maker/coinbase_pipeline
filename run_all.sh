#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# venv
if [ ! -d .venv ]; then python3 -m venv .venv; fi
source .venv/bin/activate
# deps
python -m pip install --upgrade pip wheel setuptools >/dev/null 2>&1 || true
pip install -r requirements.txt >/dev/null 2>&1 || true
# load env (optional)
if [ -f .env ]; then set -a; . .env; set +a; fi
# ensure imports see the project
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
# launch the combined app with all tabs
exec streamlit run dashboard/app_all.py
