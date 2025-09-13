#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PAGE_ID="${PAGE_ID:-26a9c46ac8fd80f7bd52c712ef50c4ca}"

# pick python (prefer venv)
if [[ -x ".venv/bin/python" ]]; then
  PY=".venv/bin/python"; PIP=".venv/bin/pip"
else
  PY="python3"; PIP="python3 -m pip"
fi

# load env & map names
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"

# deps
grep -qi '^python-dotenv' requirements.txt 2>/dev/null || echo 'python-dotenv>=1.0' >> requirements.txt
$PIP install -q -r requirements.txt

# analyze and update fixed page
$PY - <<PY2
from analytics.arbitrage import load_config, analyze
from notion_publish import update_fixed_page_colored
import os, re
cfg=load_config(); syms=cfg["symbols"]; prov=cfg["providers"]
metrics,tables = analyze(syms, prov, notional=10_000.0)

page_id=os.environ.get("PAGE_ID") or "${PAGE_ID}"
# normalize just to log
if re.fullmatch(r"[0-9a-fA-F]{32}", page_id):
    page_id=f"{page_id[0:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:32]}"
print("📄 Target page:", page_id)
update_fixed_page_colored(metrics, page_id)
PY2
