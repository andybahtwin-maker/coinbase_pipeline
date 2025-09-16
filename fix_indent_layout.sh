#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_indent.$(date +%s)" || true

python - <<'PY'
from pathlib import Path

p = Path("streamlit_app_full.py")
text = p.read_text()

# Normalize: convert tabs → 4 spaces
text = text.replace("\t", "    ")

lines = text.splitlines()

# Find the for-loop where symbols are rendered
start = None
for i, ln in enumerate(lines):
    if "for sym in syms:" in ln:
        start = i
        break

if start is None:
    print("ERROR: Couldn't find 'for sym in syms:'")
    raise SystemExit(1)

loop_indent = len(lines[start]) - len(lines[start].lstrip())

# Build replacement block
pad = " " * (loop_indent + 4)
new_block = [
    f"{pad}try:",
    f"{pad}    data = fetch_prices(sym)",
    f"{pad}    stamp = data['sources']['bitstamp']",
    f"{pad}    finex = data['sources']['bitfinex']",
    f"{pad}    diff_abs = data['diff_abs']",
    f"{pad}    diff_pct = data['diff_pct']",
    f"{pad}    taker_pct = float(os.getenv('TAKER_PCT', '0.19'))",
    f"{pad}    maker_pct = float(os.getenv('MAKER_PCT', '0.10'))",
    f"{pad}    f_stamp = est_fees(stamp, trade_usd, role, taker_pct, maker_pct)",
    f"{pad}    f_finex = est_fees(finex, trade_usd, role, taker_pct, maker_pct)",
    "",
    f"{pad}    st.markdown(f\"#### { '{' }sym{'}' } snapshot\")",
    f"{pad}    top_left, top_right = st.columns(2)",
    f"{pad}    with top_left:",
    f"{pad}        st.metric(\"Bitstamp\", f\"${ '{' }stamp:,.2f{'}' }\")",
    f"{pad}        st.caption(f\"{ '{' }role{'}' } fee ≈ ${ '{' }f_stamp['fee_usd']:,.2f{'}' }\")",
    f"{pad}    with top_right:",
    f"{pad}        st.metric(\"Bitfinex\", f\"${ '{' }finex:,.2f{'}' }\")",
    f"{pad}        st.caption(f\"{ '{' }role{'}' } fee ≈ ${ '{' }f_finex['fee_usd']:,.2f{'}' }\")",
    "",
    f"{pad}    st.divider()",
    f"{pad}    bottom_left, bottom_right = st.columns(2)",
    f"{pad}    with bottom_left:",
    f"{pad}        st.metric(\"Spread ($)\", f\"{ '{' }diff_abs:+,.2f{'}' }\")",
    f"{pad}        st.caption(f\"Spread (%) { '{' }diff_pct:+.4f{'}' }%\")",
    f"{pad}    with bottom_right:",
    f"{pad}        roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']",
    f"{pad}        st.metric(\"2-leg fee est.\", f\"${ '{' }roundtrip_fee:,.2f{'}' }\")",
    f"{pad}        st.caption(\"Sum of fees across both venues\")",
    f"{pad}except Exception as ex:",
    f"{pad}    st.error(f\"{ '{' }sym{'}' }: { '{' }ex{'}' }\")",
]

# Trim old loop body
j = start + 1
while j < len(lines):
    raw = lines[j]
    if raw.strip() and not raw.strip().startswith("#"):
        if (len(raw) - len(raw.lstrip())) <= loop_indent:
            break
    j += 1
body_end = j

new_lines = lines[:start+1] + new_block + lines[body_end:]
p.write_text("\n".join(new_lines) + "\n")
print("✅ Cleaned indentation + replaced per-symbol layout")
PY
