#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_layout_fix.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
import re

p = Path("streamlit_app_full.py")
s = p.read_text()

# 0) Remove any stray literal "\1" lines from past patches
s = re.sub(r'^\s*\\1\s*$', '', s, flags=re.M)

# 1) If our previous 2x2 marker exists, replace that whole block with a clean (no-try) block
start_m = "# --- Begin 2x2 layout replacement ---"
end_m   = "# --- end_layout ---"
if start_m in s and end_m in s:
    pre, rest = s.split(start_m, 1)
    body, post = rest.split(end_m, 1)
    new_block = f"""{start_m}
top_left, top_right = st.columns(2)
with top_left:
    st.metric(f"{{sym}} — Bitstamp", f"${{stamp:,.2f}}")
    st.caption(f"{{role}} fee @ {{ (taker_pct if role=='taker' else maker_pct):.2f}}% ≈ ${{f_stamp['fee_usd']:.2f}}")
with top_right:
    st.metric(f"{{sym}} — Bitfinex", f"${{finex:,.2f}}")
    st.caption(f"{{role}} fee @ {{ (taker_pct if role=='taker' else maker_pct):.2f}}% ≈ ${{f_finex['fee_usd']:.2f}}")

roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']

bottom_left, bottom_right = st.columns(2)
with bottom_left:
    st.metric("Spread ($)", f"{{diff_abs:+,.2f}}")
    st.caption(f"Spread (%) {{diff_pct:+.4f}}%")
with bottom_right:
    st.metric("2-leg fee est.", f"${{roundtrip_fee:,.2f}}")
    st.caption("Sum of one-leg fees across both venues")
{end_m}"""
    s = pre + new_block + post

# 2) Fix any dangling 'try:' immediately before our layout: if a line stripped == 'try:', turn it into a comment.
lines = s.splitlines()
for i in range(1, len(lines)):
    curr = lines[i].strip()
    prev = lines[i-1].strip()
    if ("top_left, top_right = st.columns(2)" in curr) and (prev == "try:"):
        # Replace the previous 'try:' with a harmless comment
        indent = len(lines[i-1]) - len(lines[i-1].lstrip(" "))
        lines[i-1] = " " * indent + "# removed dangling try: (no body)"

s = "\n".join(lines)

# 3) Global safety pass: convert any naked 'try:' lines with no indented body into a guarded block.
fixed = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == "try:":
        indent = len(line) - len(line.lstrip(" "))
        # Peek next non-empty, non-comment line
        j = i + 1
        has_body = False
        while j < len(lines):
            nxt = lines[j]
            if nxt.strip() == "":
                j += 1; continue
            if nxt.strip().startswith("#"):
                j += 1; continue
            nxt_indent = len(nxt) - len(nxt.lstrip(" "))
            if nxt_indent > indent:
                has_body = True
            break
        if not has_body:
            # Replace naked try with a no-op + except to avoid SyntaxError
            fixed.append(" " * indent + "try:")
            fixed.append(" " * (indent + 4) + "pass  # inserted to close empty try")
            fixed.append(" " * indent + "except Exception as _e:")
            fixed.append(" " * (indent + 4) + "st.error(f'Patched empty try: {_e}')")
            i += 1
            continue
    fixed.append(line)
    i += 1

s = "\n".join(fixed)

Path("streamlit_app_full.py").write_text(s)
print("Clean 2x2 layout in place; dangling try blocks neutralized ✅")
PY
