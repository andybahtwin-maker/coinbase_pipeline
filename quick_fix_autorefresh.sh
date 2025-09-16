set -euo pipefail
cd ~/projects/coinbase_pipeline

# Safety backup
cp -n streamlit_app_full.py streamlit_app_full.py.bak || true

python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# Ensure import streamlit as st exists
if not re.search(r'^\s*import\s+streamlit\s+as\s+st\b', s, flags=re.M):
    s = "import streamlit as st\n" + s

# Ensure os import
if not re.search(r'^\s*import\s+os\b', s, flags=re.M):
    s = s.replace("import streamlit as st", "import streamlit as st\nimport os", 1)

# Add a tiny refresh helper if missing
if "_quick_auto_refresh" not in s:
    inject = """
def _quick_auto_refresh(seconds: float | int = 0):
    \"\"\"Core-only auto refresh. Set seconds>0 to sleep then rerun; safe on all versions.\"\"\"
    try:
        # manual refresh UI (always available)
        if st.sidebar.button("↻ Refresh now"):
            try:
                st.rerun()
            except Exception:
                st.experimental_rerun()
        # default: 5 minutes if nothing else is set
        auto = 300
        # env-driven auto refresh (AUTO_SEC) overrides default
        auto_env = os.getenv("AUTO_SEC", "").strip()
        if auto_env.isdigit():
            auto = int(auto_env)
        # If caller passed a value, prefer it
        if seconds and seconds > 0:
            auto = int(seconds)
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
    # Insert helper after first import block
    s = re.sub(r'(^.*?import\s+os.*?$)', r'\1\n' + inject, s, count=1, flags=re.S|re.M)

# Replace any st.autorefresh(...) with our helper
s = re.sub(r'\bst\.autorefresh\s*\(\s*interval\s*=\s*([^\),]+)\s*(?:,\s*key\s*=\s*[^)]*)?\)',
           r'_quick_auto_refresh(seconds=int(\1/1000))', s)

# Also normalize any st_autorefresh(...) you might have tried before
s = re.sub(r'\bst_autorefresh\s*\(\s*interval\s*=\s*([^\),]+)\s*(?:,\s*key\s*=\s*[^)]*)?\)',
           r'_quick_auto_refresh(seconds=int(\1/1000))', s)

# If no explicit call found, do nothing else; the button + default 5min will still apply.
Path("streamlit_app_full.py").write_text(s)
print("Patched streamlit_app_full.py ✅ (default refresh = 5 minutes)")
PY

echo "Done. Usage:"
echo "  . .venv/bin/activate && streamlit run streamlit_app_full.py"
echo "  # Will auto-refresh every 5 minutes unless AUTO_SEC is set differently"
