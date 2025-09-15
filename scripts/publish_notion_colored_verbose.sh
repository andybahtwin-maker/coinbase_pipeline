#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

PYBIN="${PYBIN:-./.venv/bin/python}"
echo "🐍 Using: $(realpath "$PYBIN")"

"$PYBIN" - <<'PY'
import httpx, sys
print(f"✅ httpx: {httpx.__version__}")
PY

: "${PAGE_ID:?PAGE_ID must be set in env (export PAGE_ID=...)}"
exec "$PYBIN" bridge_orchestrator_to_notion.py
