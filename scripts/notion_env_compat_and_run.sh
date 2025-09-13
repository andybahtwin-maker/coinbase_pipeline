#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

# load your existing .env
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1090
  source .env
  set +a
fi

# map to expected names if missing
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"
export NOTION_PARENT_PAGE_ID="${NOTION_PARENT_PAGE_ID:-${NOTION_PAGE_ID:-}}"

# sanity check
: "${NOTION_TOKEN:?NOTION_TOKEN missing (set NOTION_TOKEN or NOTION_API_KEY in .env)}"
: "${NOTION_PARENT_PAGE_ID:?NOTION_PARENT_PAGE_ID missing (set NOTION_PARENT_PAGE_ID or NOTION_PAGE_ID in .env)}"

# deps + run
grep -qi '^requests' requirements.txt 2>/dev/null || echo 'requests>=2.32' >> requirements.txt
if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
  ./.venv/bin/python bridge_orchestrator_to_notion.py
else
  echo "⚠️ .venv not found — using system python."
  python3 -m pip install -q -r requirements.txt
  python3 bridge_orchestrator_to_notion.py
fi
