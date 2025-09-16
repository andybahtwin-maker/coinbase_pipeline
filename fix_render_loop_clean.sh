#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
BACKUP="${FILE}.bak_renderloop.$(date +%s)"
cp -n "$FILE" "$BACKUP" || true
echo "Backup -> $BACKUP"

python - <<'PY'
from pathlib import Path

p = Path("streamlit_app_full.py")
lines = p.read_text().splitlines()

def is_blank_or_comment(s: str) -> bool:
    t = s.strip()
    return t == "" or t.startswith("#")

# 1) Neutralize any EMPTY `try:` (no indented body).
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == "try:":
        indent = len(line) - len(line.lstrip())
        j = i + 1
        has_body = False
        while j < len(lines):
            if is_blank_or_comment(lines[j]):
                j += 1; continue
            ind = len(lines[j]) - len(lines[j].lstrip())
            # body exists only if it is MORE indented
            has_body = ind > indent
            break
        if not has_body:
            out.append(" " * indent + "# [FIXED] removed dangling try:")
            i += 1
            continue
    out.append(line)
    i += 1
lines = out

# 2) Replace the entire `for sym in syms:` block body with a clean 2×2 layout.
#    We detect the block by indentation and rebuild it.
i = 0
replaced = False
while i < len(lines):
    if "for sym in syms:" in lines[i]:
        loop_indent = len(lines[i]) - len(lines[i].lstrip())
        start = i
        i += 1
        # find the end of the block (first line with indent <= loop_indent and not blank/comment)
        end = i
        while end < len(lines):
            if lines[end].strip() == "":
                end += 1; continue
            ind = len(lines[end]) - len(lines[end].lstrip())
            if ind <= loop_indent:
                break
            end += 1
        # Build new body (indented by loop_indent+4)
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
            f"{pad}    top_left, top_right = st.columns(2)",
            f"{pad}    with top_left:",
            f"{pad}        st.metric(f\"{ '{' }sym{'}' } — Bitstamp\", f\"${ '{' }stamp:,.2f{'}' }\")",
            f"{pad}        st.caption(f\"{ '{' }role{'}' } fee @ { '{' }(taker_pct if role=='taker' else maker_pct):.2f{'}' }% ≈ ${ '{' }f_stamp['fee_usd']:,.2f{'}' }\")",
            f"{pad}    with top_right:",
            f"{pad}        st.metric(f\"{ '{' }sym{'}' } — Bitfinex\", f\"${ '{' }finex:,.2f{'}' }\")",
            f"{pad}        st.caption(f\"{ '{' }role{'}' } fee @ { '{' }(taker_pct if role=='taker' else maker_pct):.2f{'}' }% ≈ ${ '{' }f_finex['fee_usd']:,.2f{'}' }\")",
            "",
            f"{pad}    roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']",
            "",
            f"{pad}    bottom_left, bottom_right = st.columns(2)",
            f"{pad}    with bottom_left:",
            f"{pad}        st.metric(\"Spread ($)\", f\"{ '{' }diff_abs:+,.2f{'}' }\")",
            f"{pad}        st.caption(f\"Spread (%) { '{' }diff_pct:+.4f{'}' }%\")",
            f"{pad}    with bottom_right:",
            f"{pad}        st.metric(\"2-leg fee est.\", f\"${ '{' }roundtrip_fee:,.2f{'}' }\")",
            f"{pad}        st.caption(\"Sum of one-leg fees across both venues\")",
            f"{pad}except Exception as ex:",
            f"{pad}    st.error(f\"{ '{' }sym{'}' }: { '{' }ex{'}' }\")",
        ]
        lines = lines[:start+1] + new_body + lines[end:]
        replaced = True
        break
    i += 1

if not replaced:
    print("WARN: Did not find 'for sym in syms:' loop to replace; file left unchanged.")
else:
    print("Replaced 'for sym in syms:' block with clean 2×2 layout ✅")

Path("streamlit_app_full.py").write_text("\n".join(lines))
PY
