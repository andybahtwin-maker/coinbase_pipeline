import streamlit as st
from fees import FeeBook, TradeLeg, TradeAssumptions, compute_dollars

def render_opportunities(top_opportunities):
    fb = FeeBook("fees_config.json")
    with st.sidebar:
        st.subheader("Calc Options")
        usd_size = st.number_input("Trade size (USD)", min_value=25.0, max_value=100000.0,
                                   value=float(fb.default_usd()), step=25.0)
        include_fees = st.checkbox("Include fees", value=True)
        role = st.radio("Role", options=["taker","maker"], index=0, horizontal=True)

    for opp in top_opportunities:
        buy_ex = opp["buy_ex"]
        buy_price = opp["buy_price"]
        sell_ex = opp["sell_ex"]
        sell_price = opp["sell_price"]
        asset = opp.get("asset","BTC")

        st.write(f"Buy {buy_ex} @ {buy_price} → sell {sell_ex} @ {sell_price}")

        buy = TradeLeg(exchange=buy_ex, price=buy_price, role=role)
        sell = TradeLeg(exchange=sell_ex, price=sell_price, role=role)
        out = compute_dollars(buy, sell, TradeAssumptions(usd_size, include_fees, role))
        fee_txt = f" | Fees: ${out['buy_fee_usd']:.2f} + ${out['sell_fee_usd']:.2f}" if include_fees else ""
        st.caption(
            f"💵 For ${out['usd_size']:,.0f}: Gross ${out['gross_spread_usd']:.2f}{fee_txt} "
            f"→ **Net ${out['net_profit_usd']:.2f}**"
        )
