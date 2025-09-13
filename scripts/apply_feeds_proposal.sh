#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$PWD}"
cd "$ROOT"

if [[ ! -f config/feeds.yaml.proposed ]]; then
  echo "❌ No proposal found at config/feeds.yaml.proposed"
  exit 1
fi

cp config/feeds.yaml{.proposed,}
echo "✅ Applied config/feeds.yaml from proposal."

# install deps and run
if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
  ./.venv/bin/python orchestrate_feeds.py
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt
  python3 orchestrate_feeds.py
fi
