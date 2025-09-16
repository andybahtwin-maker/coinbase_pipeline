#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

cp -n streamlit_app_full.py streamlit_app_full.py.bak_sidebar || true

python - <<'PY'
import re
from pathlib import Path

p = Path("streamlit_app_full.py")
s = p.read_text()

# --- 1) Ensure unique keys on widgets (idempotent) ---
def add_key(call_regex, key_name):
    global s
    s = re.sub(
        call_regex + r'(?P<open>\()[^)]*?(?P<close>\))',
        lambda m: (
            m.group(0)[:-1] + (", " if m.group(0)[-2] != "(" else "") + f'key="{key_name}")'
            if "key=" not in m.group(0) else m.group(0)
        ),
        s, flags=re.M
    )

add_key(r'\bst\.text_input\(\s*"Symbols \(comma-separated\)"', "symbols_input")
add_key(r'\bst\.number_input\(\s*"Auto-refresh \(seconds\)"', "auto_refresh_seconds")
add_key(r'\bst\.number_input\(\s*"Trade size \(USD\)"', "trade_size_usd")
add_key(r'\bst\.radio\(\s*"Role"', "role_select")

# --- 2) Remove duplicate "Controls" sidebars; keep only the LAST one ---
lines = s.splitlines()
blocks = []  # list of (start_idx, end_idx, has_controls)

i = 0
while i < len(lines):
    m = re.match(r'^(\s*)with\s+st\.sidebar\s*:\s*$', lines[i])
    if not m:
        i += 1
        continue
    indent = len(m.group(1))
    start = i
    i += 1
    # capture block until line with indent <= current indent (non-empty)
    end = i
    while end < len(lines):
        line = lines[end]
        if line.strip() == "":
            end += 1
            continue
        # count leading spaces
        sp = len(line) - len(line.lstrip(" "))
        if sp <= indent:
            break
        end += 1
    block_text = "\n".join(lines[start:end])
    has_controls = 'st.subheader("Controls")' in block_text or "st.subheader('Controls')" in block_text
    blocks.append((start, end, has_controls))
    i = end

# Identify all sidebar blocks that look like "Controls"
control_blocks = [b for b in blocks if b[2]]
if len(control_blocks) > 1:
    # keep only the last, remove earlier ones
    to_remove = control_blocks[:-1]
    # Remove from bottom to top to keep indices valid
    for start, end, _ in sorted(to_remove, key=lambda x: x[0], reverse=True):
        del lines[start:end]

s_new = "\n".join(lines)

# Also clean any stray literal "\1" lines from prior patches
s_new = re.sub(r'^\s*\\1\s*$', "", s_new, flags=re.M)

Path("streamlit_app_full.py").write_text(s_new)
print("Sidebar deduplicated and keys applied ✅")
PY

echo "Now run:"
echo "  . .venv/bin/activate && streamlit run streamlit_app_full.py"
