#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
REFRESH="$(python3 - <<'PY'
import yaml; print(yaml.safe_load(open("config/feeds.yaml"))["render"]["refresh_seconds"])
PY
)"
while true; do
  clear
  date
  if [[ -d .venv ]]; then ./.venv/bin/python orchestrate_arbitrage.py; else python3 orchestrate_arbitrage.py; fi
  sleep "${REFRESH:-30}"
done
