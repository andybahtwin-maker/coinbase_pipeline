#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-$HOME/projects/coinbase_pipeline}"
cd "$REPO"

mkdir -p providers
: > providers/__init__.py

# 1) sanitize config/feeds.yaml module paths
python3 - "$REPO/config/feeds.yaml" <<'PY' || true
import sys, yaml, re, os
from pathlib import Path

p = Path(sys.argv[1])
if not p.exists():
    sys.exit(0)

cfg = yaml.safe_load(p.read_text(encoding="utf-8"))
prov = cfg.get("providers", {})
changed = False

def normalize(mod: str) -> str:
    if not isinstance(mod, str):
        return mod
    m = mod.strip()
    # strip leading dots
    m = m.lstrip(".")
    # squash accidental absolute-ish paths like home.andhe001.projects.coinbase_pipeline.providers.binance_feed
    parts = m.split(".")
    if "providers" in parts:
        i = parts.index("providers")
        m = ".".join(parts[i:i+2]) if len(parts) >= i+2 else "providers"
        # if file-style like providers/binance_feed.py somehow crept in
    m = m.replace("/", ".")
    if m.endswith(".py"):
        m = m[:-3]
    # ensure prefix
    if not m.startswith("providers."):
        # last two tokens heuristic
        toks = m.split(".")
        if len(toks) >= 2:
            m = "providers." + ".".join(toks[-1:])
    return m

for name, meta in list(prov.items()):
    if not isinstance(meta, dict): 
        continue
    mod = meta.get("module")
    if mod:
        new = normalize(mod)
        if new != mod:
            meta["module"] = new
            changed = True

if changed:
    p.write_text(yaml.safe_dump(cfg, sort_keys=False), encoding="utf-8")
    print("✅ normalized modules in config/feeds.yaml")
else:
    print("ℹ️ config/feeds.yaml modules already look good")
PY

# 2) harden orchestrate_feeds.load_provider for odd paths
python3 - <<'PY'
from pathlib import Path
import re

fp = Path("orchestrate_feeds.py")
s = fp.read_text(encoding="utf-8")

pattern = r"def\s+load_provider\([^)]*\):\n(?:.*\n){1,40}?\s+return\s+\w+\n"
robust = '''
def load_provider(module_path: str, fn_name: str):
    import importlib, importlib.util, sys, os
    module_path = (module_path or "").strip()
    # strip accidental leading dots
    while module_path.startswith("."):
        module_path = module_path[1:]
    # try file-location import if looks like a path
    if os.path.sep in module_path and os.path.exists(module_path):
        spec = importlib.util.spec_from_file_location("dynamic_provider", module_path)
        mod = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(mod)
    else:
        # ensure repo root is on sys.path for 'providers.*'
        if os.getcwd() not in sys.path:
            sys.path.insert(0, os.getcwd())
        # collapse accidental long prefixes like home.user.repo.providers.x
        parts = module_path.replace("/", ".").split(".")
        if "providers" in parts:
            i = parts.index("providers")
            module_path = ".".join(parts[i:i+2]) if len(parts) >= i+2 else "providers"
        # strip .py suffix if present
        if module_path.endswith(".py"):
            module_path = module_path[:-3]
        mod = importlib.import_module(module_path)
    fn = getattr(mod, fn_name)
    return fn
'''.lstrip()

if "def load_provider(" in s:
    s = re.sub(r"def\s+load_provider\([^)]*\):[\s\S]*?return\s+\w+\n", robust, s, count=1)
else:
    # append if missing
    s = s.rstrip() + "\n\n" + robust

fp.write_text(s, encoding="utf-8")
print("✅ hardened load_provider in orchestrate_feeds.py")
PY

# 3) ensure deps
grep -qi '^pyyaml' requirements.txt 2>/dev/null || echo 'pyyaml>=6.0' >> requirements.txt
grep -qi '^rich' requirements.txt 2>/dev/null   || echo 'rich>=13.7' >> requirements.txt

if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt
fi

# 4) run publish via your existing notion code
./scripts/publish_via_existing_notion.sh
