#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# choose python/pip (prefer venv)
if [[ -x ".venv/bin/python" ]]; then
  PY=".venv/bin/python"
  PIP=".venv/bin/pip"
else
  echo "⚠️ .venv not found — falling back to system Python"
  PY="python3"
  PIP="python3 -m pip"
fi

# load env from .env if present
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"
export NOTION_PARENT_PAGE_ID="${NOTION_PARENT_PAGE_ID:-${NOTION_PAGE_ID:-}}"

# deps
grep -qi '^python-dotenv' requirements.txt 2>/dev/null || echo 'python-dotenv>=1.0' >> requirements.txt
$PIP install -q -r requirements.txt

# quick sanity: show interpreter + httpx version
$PY - <<'PY'
import sys
print("🐍 Using:", sys.executable)
try:
    import httpx
    print("✅ httpx:", httpx.__version__)
except Exception as e:
    print("❌ httpx import failed:", e)
PY

# run publisher
$PY - <<'PY'
import os, re
from analytics.arbitrage import load_config, analyze
from notion_publish import publish_boxes_colored

cfg=load_config()
syms=cfg["symbols"]; prov=cfg["providers"]
metrics, tables = analyze(syms, prov, notional=10_000.0)

print(f"🧪 metrics count: {len(metrics)}  (sample keys: {list(metrics.keys())[:6]}...)")
print(f"🔑 token? {'yes' if (os.getenv('NOTION_TOKEN') or os.getenv('NOTION_API_KEY')) else 'no'}")
print(f"📄 parent? {'yes' if (os.getenv('NOTION_PARENT_PAGE_ID') or os.getenv('NOTION_PAGE_ID')) else 'no'}")

parent = os.getenv("NOTION_PARENT_PAGE_ID") or os.getenv("NOTION_PAGE_ID")
if parent and re.fullmatch(r"[0-9a-fA-F]{32}", parent):
    parent = f"{parent[0:8]}-{parent[8:12]}-{parent[12:16]}-{parent[16:20]}-{parent[20:32]}"
print("📄 parent id (normalized):", parent)

page_id = publish_boxes_colored(metrics)
print("✅ published colored page:", page_id)
PY
