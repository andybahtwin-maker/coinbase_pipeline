#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d .venv ]]; then ./.venv/bin/pip install -q -r requirements.txt; ./.venv/bin/python orchestrate_arbitrage.py
else python3 -m pip install -q -r requirements.txt; python3 orchestrate_arbitrage.py; fi
