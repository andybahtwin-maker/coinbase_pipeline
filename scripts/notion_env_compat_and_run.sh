#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Compatibility: accept NOTION_SECRET, NOTION_API_KEY, or NOTION_TOKEN
if [[ -z "${NOTION_TOKEN:-}" && -n "${NOTION_SECRET:-}" ]]; then
  export NOTION_TOKEN="$NOTION_SECRET"
fi
if [[ -z "${NOTION_TOKEN:-}" && -n "${NOTION_API_KEY:-}" ]]; then
  export NOTION_TOKEN="$NOTION_API_KEY"
fi

if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

PYBIN="${PYBIN:-./.venv/bin/python}"
exec "$PYBIN" bridge_orchestrator_to_notion.py
