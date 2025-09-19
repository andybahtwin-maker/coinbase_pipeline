#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# activate venv
source .venv/bin/activate

# load .env from secrets
set -a
. secrets/.env
set +a

# ensure PYTHONPATH
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"

# launch Streamlit
exec streamlit run dashboard/simple_app.py
