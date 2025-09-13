#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -d ".venv" ]]; then
  ./.venv/bin/pip install -q -r requirements.txt || true
  ./.venv/bin/pip install -q pyyaml || true
  ./.venv/bin/python bridge_orchestrator_to_notion.py
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt || true
  python3 -m pip install -q pyyaml || true
  python3 bridge_orchestrator_to_notion.py
fi
