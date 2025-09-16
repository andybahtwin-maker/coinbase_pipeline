#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

cp -n streamlit_app_full.py streamlit_app_full.py.bak_layout2 || true

python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# If the 4-column layout exists, replace it
pat = re.compile(
    r"\s*col1\s*,\s*col2\s*,\s*col3\s*,\s*col4\s*=\s*st\.columns\([^\)]*\)\s*\n"
    r"(?:.|\n)*?(?=\n\s*# end_layout|\Z)",  # stop at marker or EOF
    re.M
)

rep = """
# --- Begin 2x2 layout replacement ---
try:
    top_left, top_right = st.columns(2)
    with top_left:
        st.metric(f"{sym} — Bitstamp", f"${stamp:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_stamp['fee_usd']:.2f}")
    with top_right:
        st.metric(f"{sym} — Bitfinex", f"${finex:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_finex['fee_usd']:.2f}")

    roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']

    bottom_left, bottom_right = st.columns(2)
    with bottom_left:
        st.metric("Spread ($)", f"{diff_abs:+,.2f}")
        st.caption(f"Spread (%) {diff_pct:+.4f}%")
    with bottom_right:
        st.metric("2-leg fee est.", f"${roundtrip_fee:,.2f}")
        st.caption("Sum of one-leg fees across both venues")
except Exception as e:
    st.error(f"Layout error: {e}")
# --- end_layout ---
"""

new_s, n = pat.subn(rep, s, count=1)
if n == 0:
    print("No matching 4-column layout found.")
else:
    p.write_text(new_s)
    print("Replaced 4-column with safe 2x2 layout ✅")
PY
