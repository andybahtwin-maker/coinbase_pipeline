#!/bin/bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

cp -n streamlit_app_full.py streamlit_app_full.py.bak_keys || true

python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# Helper: add a key=... argument if the call doesn't already include a key=
def add_key(call_regex, key_name):
    global s
    # only match calls that don't already have 'key=' inside the parentheses
    s = re.sub(
        call_regex + r'(?P<args>\([^)]*(?<!key\s*=)[^)]*\))',
        lambda m: m.group(0)[:-1] + f', key="{key_name}")',
        s,
        flags=re.M
    )

# 1) Sidebar controls — ensure unique keys
add_key(r'\bst\.text_input\(\s*"Symbols \(comma-separated\)"', "symbols_input")
add_key(r'\bst\.number_input\(\s*"Auto-refresh \(seconds\)"', "auto_refresh_seconds")
add_key(r'\bst\.number_input\(\s*"Trade size \(USD\)"', "trade_size_usd")
add_key(r'\bst\.radio\(\s*"Role"', "role_select")

# 2) As a safety net, also ensure our refresh shim call has a stable key if it ever used one
s = re.sub(
    r'(_safe_autorefresh\(\s*)(seconds\s*=\s*[^,\)]+)(\s*\))',
    r'\1\2, key="auto_refresh_shim"\3',
    s
)

p.write_text(s)
print("Applied unique keys to sidebar widgets ✅")
PY
