#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

cp -n streamlit_app_full.py streamlit_app_full.py.bak_layout || true

python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# Find the original 4-column block and replace it with a 2x2 layout
pat = re.compile(
    r"""
    \s*col1\s*,\s*col2\s*,\s*col3\s*,\s*col4\s*=\s*st\.columns\([^\)]*\)\s*\n
    (?:\s*with\s+col1:\s*\n.*?)+
    (?:\s*with\s+col2:\s*\n.*?)+
    (?:\s*with\s+col3:\s*\n.*?)+
    (?:\s*with\s+col4:\s*\n.*?)+
    """,
    re.S | re.X
)

rep = r"""
top_left, top_right = st.columns(2)
with top_left:
    st.metric(f"{sym} — Bitstamp", f"${stamp:,.2f}")
    st.caption(f"{role} fee @ { (taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_stamp['fee_usd']:.2f}")
with top_right:
    st.metric(f"{sym} — Bitfinex", f"${finex:,.2f}")
    st.caption(f"{role} fee @ { (taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_finex['fee_usd']:.2f}")

# compute once so it's available to bottom row
roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']

bottom_left, bottom_right = st.columns(2)
with bottom_left:
    st.metric("Spread ($)", f"{diff_abs:+,.2f}")
    st.caption(f"Spread (%) {diff_pct:+.4f}%")
with bottom_right:
    st.metric("2-leg fee est.", f"${roundtrip_fee:,.2f}")
    st.caption("Sum of one-leg fees across both venues")
"""

new_s, n = pat.subn(rep, s, count=1)
if n == 0:
    print("No 4-column block found; nothing changed.")
else:
    p.write_text(new_s)
    print("Reflowed layout to 2x2 ✅")
PY
