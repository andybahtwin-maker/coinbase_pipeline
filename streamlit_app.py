import streamlit as st
from fees import FeeBook, render_opportunity_detail

st.set_page_config(page_title="Coinbase Pipeline Demo", layout="wide")

st.sidebar.header("Calc Options")
_default_usd = FeeBook().default_usd()
_usd_size = st.sidebar.number_input("Trade size (USD)", min_value=10.0, value=_default_usd, step=10.0)
_include_fees = st.sidebar.checkbox("Include fees", value=True)
_role = st.sidebar.radio("Role", ["taker", "maker"], index=0)

st.title("Coinbase Pipeline Demo")
st.subheader("Top Spread Opportunities")

# demo pairs (replace with your real loop later)
opportunities = [
    ("bitstamp", 25000.0, "bitfinex", 25200.0),
    ("kraken", 24980.0, "coinbase", 25150.0),
]

for buy_ex, buy_px, sell_ex, sell_px in opportunities:
    st.markdown(f"**Buy {buy_ex} @ {buy_px:,.2f} → Sell {sell_ex} @ {sell_px:,.2f}**")
    render_opportunity_detail(buy_ex, buy_px, sell_ex, sell_px,
                              usd_size=_usd_size, include_fees=_include_fees, role=_role)
    st.divider()
