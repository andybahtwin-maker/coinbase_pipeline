#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_layout.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
p = Path("streamlit_app_full.py")
txt = p.read_text().replace("\t", "    ")

out = []
inside = False
for line in txt.splitlines():
    if line.strip().startswith("for sym in syms:"):
        inside = True
        out.append(line)
        # insert clean layout
        out.append("    try:")
        out.append("        top_left, top_right = st.columns(2)")
        out.append("        with top_left:")
        out.append("            st.subheader(f\"{sym}-USD Bitstamp\")")
        out.append("            st.metric(\"Price\", f\"${bitstamp_price:,.2f}\")")
        out.append("            st.caption(f\"{role} fee: ${f_stamp['fee_usd']:,.2f}\")")
        out.append("        with top_right:")
        out.append("            st.subheader(f\"{sym}-USD Bitfinex\")")
        out.append("            st.metric(\"Price\", f\"${bitfinex_price:,.2f}\")")
        out.append("            st.caption(f\"{role} fee: ${f_finex['fee_usd']:,.2f}\")")
        out.append("        bot_left, bot_right = st.columns(2)")
        out.append("        with bot_left:")
        out.append("            st.subheader(\"Spread\")")
        out.append("            st.metric(\"Diff\", f\"${spread_dollar:,.2f}\", f\"{spread_percent:.2f}%\")")
        out.append("        with bot_right:")
        out.append("            roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']")
        out.append("            st.metric(\"2-leg fee est.\", f\"${roundtrip_fee:,.2f}\")")
        out.append("    except Exception as e:")
        out.append("        st.error(f\"Layout error: {e}\")")
        continue
    if inside:
        # skip old indented block
        if line.startswith("    "):
            continue
        inside = False
    out.append(line)

p.write_text("\n".join(out) + "\n")
print("Fixed layout + indentation ✅")
PY
