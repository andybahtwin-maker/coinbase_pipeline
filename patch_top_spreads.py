from pathlib import Path

target = Path("streamlit_app.py")
lines = target.read_text().splitlines()
out = []
inserted = False

for line in lines:
    if not inserted and "Top Spread Opportunities" in line:
        out.append(line)
        out.append("")
        out.append("# Fee-aware helpers")
        out.append("from fees import FeeBook, TradeLeg, TradeAssumptions, compute_dollars")
        out.append("fb = FeeBook('fees_config.json')")
        out.append("import streamlit as st")
        out.append("usd_size = st.sidebar.number_input('Trade size (USD)', min_value=50.0, max_value=100000.0, value=float(fb.default_usd()), step=50.0)")
        out.append("include_fees = st.sidebar.checkbox('Include fees', value=True)")
        out.append("role = st.sidebar.radio('Role', options=['taker','maker'], index=0, horizontal=True)")
        out.append("")
        out.append("def render_opportunity(asset, spread_pct, buy_ex, buy_px, sell_ex, sell_px):")
        out.append("    buy = TradeLeg(buy_ex, buy_px, role)")
        out.append("    sell = TradeLeg(sell_ex, sell_px, role)")
        out.append("    result = compute_dollars(buy, sell, TradeAssumptions(usd_size, include_fees, role))")
        out.append("    fee_txt = (f\" | Fees: ${result['buy_fee_usd']:.2f} + ${result['sell_fee_usd']:.2f}\" if include_fees else '')")
        out.append("    st.markdown(")
        out.append("        f\"**{asset}** — {spread_pct:.2f}% spread\\\\n\"")
        out.append("        f\"Buy {buy_ex} @ {buy_px:.2f} → Sell {sell_ex} @ {sell_px:.2f}\\\\n\"")
        out.append("        f\"💵 For ${result['usd_size']:,.0f}: Gross ${result['gross_spread_usd']:.2f}{fee_txt} → **Net ${result['net_profit_usd']:.2f}**\"")
        out.append("    )")
        inserted = True
        continue
    out.append(line)

target.write_text("\n".join(out))
print(\"✅ streamlit_app.py patched with fee-aware rendering.\")
