#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_full_layout.$(date +%s)" || true

python - <<'PY'
from pathlib import Path

p = Path("streamlit_app_full.py")
text = p.read_text()

# Normalize whitespace and remove stray regex artifacts
text = text.replace("\t", "    ")
lines = [ln for ln in text.splitlines() if ln.strip() != r"\1"]

# Locate the for-loop that iterates symbols
start = None
for i, ln in enumerate(lines):
    if "for sym in syms:" in ln:
        start = i
        break

if start is None:
    print("ERROR: Could not find 'for sym in syms:' loop. No changes made.")
    raise SystemExit(1)

loop_indent = len(lines[start]) - len(lines[start].lstrip())
body_start = start + 1

# Find the end of the loop body (first non-comment/non-empty line with indent <= loop_indent)
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

pad = " " * (loop_indent + 4)

new_body = [
    f"{pad}try:",
    f"{pad}    data = fetch_prices(sym)",
    f"{pad}    stamp = data['sources']['bitstamp']",
    f"{pad}    finex = data['sources']['bitfinex']",
    f"{pad}    diff_abs = data['diff_abs']",
    f"{pad}    diff_pct = data['diff_pct']",
    "",
    f"{pad}    taker_pct = float(os.getenv('TAKER_PCT', '0.19'))",
    f"{pad}    maker_pct = float(os.getenv('MAKER_PCT', '0.10'))",
    f"{pad}    f_stamp = est_fees(stamp, trade_usd, role, taker_pct, maker_pct)",
    f"{pad}    f_finex = est_fees(finex, trade_usd, role, taker_pct, maker_pct)",
    "",
    f"{pad}    st.markdown(f\"#### { '{' }sym{'}' } snapshot\")",
    f"{pad}    top_left, top_right = st.columns(2)",
    f"{pad}    with top_left:",
    f"{pad}        st.metric(\"Bitstamp\", f\"${ '{' }stamp:,.2f{'}' }\")",
    f"{pad}        st.caption(f\"{ '{' }role{'}' } fee @ { '{' }(taker_pct if role=='taker' else maker_pct):.2f{'}' }% ≈ ${ '{' }f_stamp['fee_usd']:,.2f{'}' }\")",
    f"{pad}    with top_right:",
    f"{pad}        st.metric(\"Bitfinex\", f\"${ '{' }finex:,.2f{'}' }\")",
    f"{pad}        st.caption(f\"{ '{' }role{'}' } fee @ { '{' }(taker_pct if role=='taker' else maker_pct):.2f{'}' }% ≈ ${ '{' }f_finex['fee_usd']:,.2f{'}' }\")",
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

# Splice in the clean body
new_lines = lines[:start+1] + new_body + lines[body_end:]
p.write_text("\n".join(new_lines) + "\n")
print("✅ Replaced per-symbol render with clean 2×2 layout and correct indentation")
PY
