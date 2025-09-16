#!/bin/bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

# 1) Backup
cp -n streamlit_app_full.py streamlit_app_full.py.bak_shim || true

# 2) Clean any stray "\1" lines from earlier regex patch
sed -i '/^\\1$/d' streamlit_app_full.py

# 3) Inject a compatibility shim so old calls like
#    _safe_autorefresh(interval=auto*1000, key="auto_refresh")
#    keep working by redirecting to _quick_auto_refresh(seconds=...)
python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# Ensure 'import streamlit as st' exists (won't duplicate)
if not re.search(r'^\s*import\s+streamlit\s+as\s+st\b', s, flags=re.M):
    s = "import streamlit as st\n" + s

# Ensure 'import os' exists (needed by _quick_auto_refresh)
if not re.search(r'^\s*import\s+os\b', s, flags=re.M):
    s = s.replace("import streamlit as st", "import streamlit as st\nimport os", 1)

# If our core helper is missing, add it
if "_quick_auto_refresh(" not in s:
    inject = """
def _quick_auto_refresh(seconds: float | int = 0):
    \"\"\"Core-only auto refresh. Default 5 min if nothing else is set.
    - Manual: sidebar '↻ Refresh now' button
    - Auto: sleep 'seconds' then rerun; falls back across Streamlit versions
    \"\"\"
    try:
        if st.sidebar.button("↻ Refresh now"):
            try:
                st.rerun()
            except Exception:
                st.experimental_rerun()
        # Default 5 minutes unless overridden by env or argument
        auto = 300
        auto_env = os.getenv("AUTO_SEC", "").strip()
        if auto_env.isdigit():
            auto = int(auto_env)
        if seconds and float(seconds) > 0:
            auto = int(float(seconds))
        if auto and auto > 0:
            import time
            time.sleep(auto)
            try:
                st.rerun()
            except Exception:
                st.experimental_rerun()
    except Exception:
        pass
"""
    # Put right after the first import block
    s = re.sub(r'(^.*?import\s+os.*?$)', r'\1\n' + inject, s, count=1, flags=re.S|re.M)

# Add a *compatibility shim* for legacy code using _safe_autorefresh(interval=..., key=...)
if "_safe_autorefresh(" not in s or "def _safe_autorefresh(" not in s:
    shim = """
def _safe_autorefresh(*, interval=None, key=None):
    \"\"\"Compatibility shim:
    Accepts 'interval' in milliseconds and delegates to _quick_auto_refresh(seconds).
    Ignores 'key'. Safe to keep old call sites working.
    \"\"\"
    try:
        ms = float(interval) if interval is not None else 0
    except Exception:
        ms = 0
    secs = int(ms / 1000) if ms > 0 else 0
    return _quick_auto_refresh(seconds=secs)
"""
    # Append shim after _quick_auto_refresh
    if "_quick_auto_refresh(" in s:
        s = re.sub(r'(_quick_auto_refresh\(.*?\)\n)', r'\1' + shim + "\n", s, count=1, flags=re.S)
    else:
        s += "\n" + shim + "\n"

# Normalize any accidental direct references to st.autorefresh / st_autorefresh to use the shim
s = re.sub(r'\bst\.autorefresh\s*\(', r'_safe_autorefresh(', s)
s = re.sub(r'\bst_autorefresh\s*\(', r'_safe_autorefresh(', s)

p.write_text(s)
print("Injected compatibility shim ✅")
PY

echo "Done. Run your app:"
echo "  . .venv/bin/activate && streamlit run streamlit_app_full.py"
