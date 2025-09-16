#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_renderfunc.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
import re

p = Path("streamlit_app_full.py")
text = p.read_text()

# 0) Normalize tabs→spaces and drop any stray "\1" lines
text = text.replace("\t", "    ")
text = "\n".join([ln for ln in text.splitlines() if ln.strip() != r"\1"])

# 1) Append a clean renderer function if missing (top-level, consistent indent)
if "def render_symbol(sym, data, trade_usd, role, taker_pct, maker_pct):" not in text:
    render_fn = """
def render_symbol(sym, data, trade_usd, role, taker_pct, maker_pct):
    stamp = data['sources']['bitstamp']
    finex = data['sources']['bitfinex']
    diff_abs = data['diff_abs']
    diff_pct = data['diff_pct']

    f_stamp = est_fees(stamp, trade_usd, role, taker_pct, maker_pct)
    f_finex = est_fees(finex, trade_usd, role, taker_pct, maker_pct)

    top_left, top_right = st.columns(2)
    with top_left:
        st.metric(f"{sym} — Bitstamp", f"${stamp:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_stamp['fee_usd']:,.2f}")
    with top_right:
        st.metric(f"{sym} — Bitfinex", f"${finex:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_finex['fee_usd']:,.2f}")

    roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']

    bottom_left, bottom_right = st.columns(2)
    with bottom_left:
        st.metric("Spread ($)", f"{diff_abs:+,.2f}")
        st.caption(f"Spread (%) {diff_pct:+.4f}%")
    with bottom_right:
        st.metric("2-leg fee est.", f"${roundtrip_fee:,.2f}")
        st.caption("Sum of one-leg fees across both venues")
"""
    # Append with a separating newline
    if not text.endswith("\n"):
        text += "\n"
    text += render_fn

# 2) Replace the ENTIRE body of: for sym in syms:  with a clean, tiny body
lines = text.splitlines()
start = None
for i, ln in enumerate(lines):
    if "for sym in syms:" in ln:
        start = i
        base = len(ln) - len(ln.lstrip())
        break

if start is not None:
    # find end of loop body
    j = start + 1
    while j < len(lines):
        stripped = lines[j].strip()
        if stripped and not stripped.startswith("#"):
            indent = len(lines[j]) - len(lines[j].lstrip())
            if indent <= base:
                break
        j += 1
    end = j  # exclusive

    # Build new minimal body with consistent 4-space indent
    pad = " " * (base + 4)
    new_body = [
        pad + "data = fetch_prices(sym)",
        pad + "taker_pct = float(os.getenv('TAKER_PCT', '0.19'))",
        pad + "maker_pct = float(os.getenv('MAKER_PCT', '0.10'))",
        pad + "render_symbol(sym, data, trade_usd, role, taker_pct, maker_pct)",
    ]
    lines = lines[:start+1] + new_body + lines[end:]

text = "\n".join(lines) + "\n"
p.write_text(text)
print("Inserted render_symbol() and simplified loop body ✅")
PY
