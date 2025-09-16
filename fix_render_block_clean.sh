#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_renderblock.$(date +%s)" || true
python - <<'PY'
from pathlib import Path

p = Path("streamlit_app_full.py")
text = p.read_text()

# 0) sanitize: remove stray "\1" lines and normalize tabs to 4 spaces
lines = text.replace("\t", "    ").splitlines()
lines = [ln for ln in lines if ln.strip() != r"\1"]

# find the for-loop
idx = None
for i, ln in enumerate(lines):
    if "for sym in syms:" in ln:
        idx = i
        break

if idx is None:
    print("WARN: could not find 'for sym in syms:'; no changes.")
    raise SystemExit(0)

loop_indent = len(lines[idx]) - len(lines[idx].lstrip())
body_start = idx + 1

# find end of loop body: first non-blank/non-comment line with indent <= loop_indent
j = body_start
while j < len(lines):
    raw = lines[j]
    stripped = raw.strip()
    if stripped and not stripped.startswith("#"):
        ind = len(raw) - len(raw.lstrip())
        if ind <= loop_indent:
            break
    j += 1
body_end = j  # exclusive

# new clean body (no try/except to avoid parser expecting 'except')
block = """
data = fetch_prices(sym)
stamp = data['sources']['bitstamp']
finex = data['sources']['bitfinex']
diff_abs = data['diff_abs']
diff_pct = data['diff_pct']

taker_pct = float(os.getenv('TAKER_PCT', '0.19'))
maker_pct = float(os.getenv('MAKER_PCT', '0.10'))
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
""".strip("\n").splitlines()

pad = " " * (loop_indent + 4)
new_body = [pad + ln if ln else "" for ln in block]

# splice: keep header "for sym in syms:" line, replace its body
out = lines[:idx+1] + new_body + lines[body_end:]
p.write_text("\n".join(out) + "\n")
print("Replaced 'for sym in syms:' body with clean 2×2 layout (consistent spaces) ✅")
PY
