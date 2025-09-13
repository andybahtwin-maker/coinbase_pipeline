#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d "$ROOT/.venv" ]]; then
  "$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
  "$ROOT/.venv/bin/python" "$ROOT/orchestrate_feeds.py"
else
  echo "⚠️ .venv not found — using system python."
  python3 -m pip install -q -r "$ROOT/requirements.txt"
  python3 "$ROOT/orchestrate_feeds.py"
fi
