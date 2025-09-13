#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

# 1) ensure python-dotenv in deps
grep -qi '^python-dotenv' requirements.txt 2>/dev/null || echo 'python-dotenv>=1.0' >> requirements.txt

# 2) patch bridge_orchestrator_to_notion.py to auto-load .env and map var names
python3 - "$PWD/bridge_orchestrator_to_notion.py" <<'PY'
from pathlib import Path
p = Path("bridge_orchestrator_to_notion.py")
s = p.read_text(encoding="utf-8")

inject = '''
# --- env autoload (dotenv) + compatibility mapping ---
import os
try:
    from dotenv import load_dotenv
    load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"))
except Exception:
    pass
# Map legacy names if canonical ones are missing
if not os.environ.get("NOTION_TOKEN") and os.environ.get("NOTION_API_KEY"):
    os.environ["NOTION_TOKEN"] = os.environ["NOTION_API_KEY"]
if not os.environ.get("NOTION_PARENT_PAGE_ID") and os.environ.get("NOTION_PAGE_ID"):
    os.environ["NOTION_PARENT_PAGE_ID"] = os.environ["NOTION_PAGE_ID"]
# --- end env autoload ---
'''

if "env autoload (dotenv)" not in s:
    # insert right after imports
    lines = s.splitlines()
    for i, ln in enumerate(lines[:50]):
        if ln.strip().startswith("PUBLISH_FN_CANDIDATES"):
            insert_at = i
            break
    else:
        insert_at = 0
    lines.insert(insert_at, inject.strip())
    s = "\n".join(lines)
    p.write_text(s, encoding="utf-8")
    print("✅ bridge now autoloads .env and maps NOTION_API_KEY/NOTION_PAGE_ID")
else:
    print("ℹ️ bridge was already patched")
PY

# 3) install deps
if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
else
  python3 -m pip install -q -r requirements.txt
fi

echo "✅ Patch complete. You can now run either script."
echo "   - ./scripts/notion_env_compat_and_run.sh   (works already)"
echo "   - ./scripts/run_notion_bridge_now.sh       (now works too)"
