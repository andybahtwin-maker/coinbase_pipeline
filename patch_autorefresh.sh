set -euo pipefail
cd ~/projects/coinbase_pipeline

# 1) Ensure streamlit-extras is in requirements.txt (idempotent)
if ! grep -qi '^streamlit-extras' requirements.txt; then
  printf '\nstreamlit-extras>=0.4.0\n' >> requirements.txt
fi

# 2) Patch streamlit_app_full.py to use st_autorefresh with safe fallback
python - <<'PY'
from pathlib import Path
p = Path("streamlit_app_full.py")
s = p.read_text()

import re

# Ensure we import streamlit at top (keep existing)
if not re.search(r'^\s*import\s+streamlit\s+as\s+st\b', s, flags=re.M):
    s = "import streamlit as st\n" + s

# Inject helper import+fallback once, just after first streamlit import
if "from streamlit_extras.app_autorefresh import st_autorefresh" not in s and "def _safe_autorefresh(" not in s:
    s = re.sub(
        r'(^\s*import\s+streamlit\s+as\s+st\s*$)',
        r"""\\1

# Try the extras autorefresh; provide a safe fallback otherwise.
try:
    from streamlit_extras.app_autorefresh import st_autorefresh as _extras_autorefresh
except Exception:
    _extras_autorefresh = None

def _safe_autorefresh(interval_ms: int, key: str = "auto_refresh"):
    if _extras_autorefresh is not None:
        return _extras_autorefresh(interval=interval_ms, key=key)
    # Fallback: sleep then rerun (works on all Streamlit versions)
    import time
    time.sleep(max(0, interval_ms)/1000.0)
    try:
        st.rerun()  # Streamlit >= 1.27
    except Exception:
        try:
            st.experimental_rerun()  # older Streamlit
        except Exception:
            pass  # last resort: do nothing

""",
        s,
        count=1,
        flags=re.M
    )

# Replace any st.autorefresh(...) calls with _safe_autorefresh(...)
s = re.sub(r'\bst\.autorefresh\s*\(', r'_safe_autorefresh(', s)

# If you previously had st_autorefresh imported directly, normalize to _safe_autorefresh
s = re.sub(r'\bst_autorefresh\s*\(', r'_safe_autorefresh(', s)

# Also handle a common pattern where you compute seconds and multiply by 1000 later
# Nothing needed here; the function expects ms like your current call.

Path("streamlit_app_full.py").write_text(s)
print("Patched streamlit_app_full.py ✅")
PY

# 3) Install deps
. .venv/bin/activate
pip install -r requirements.txt
echo "All set. Run your app as usual:"
echo "  . .venv/bin/activate && streamlit run streamlit_app_full.py"
