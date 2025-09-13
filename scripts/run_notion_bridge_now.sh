#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

# deps
grep -qi '^requests' requirements.txt 2>/dev/null || echo 'requests>=2.32' >> requirements.txt
if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
  ./.venv/bin/python bridge_orchestrator_to_notion.py
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt
  python3 bridge_orchestrator_to_notion.py
fi
