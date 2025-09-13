#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# env compat
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"
export NOTION_PARENT_PAGE_ID="${NOTION_PARENT_PAGE_ID:-${NOTION_PAGE_ID:-}}"
# deps + run
if [[ -d .venv ]]; then ./.venv/bin/pip install -q -r requirements.txt; else python3 -m pip install -q -r requirements.txt; fi
python3 - <<'PY'
from analytics.arbitrage import load_config, analyze
from notion_publish import publish_boxes_colored
cfg=load_config(); syms=cfg["symbols"]; prov=cfg["providers"]
metrics,tables = analyze(syms, prov, notional=10_000.0)
publish_boxes_colored(metrics)
print("✅ published to notion (colored, fees in title)")
PY
