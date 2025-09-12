#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$PWD}"
cd "$ROOT"

./repo_cleanup.sh "$ROOT"

if [[ -d .venv ]]; then
  ./.venv/bin/python scripts/wire_visual_hook.py
else
  python3 scripts/wire_visual_hook.py
fi

echo
echo "Now test the UI with sample data:"
echo "  scripts/show_metrics.sh"
