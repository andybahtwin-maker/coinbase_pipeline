import os
import pandas as pd
import streamlit as st

import demo_data as demo

st.set_page_config(page_title="Coinbase Pipeline — Demo Mode", layout="wide")

st.title("🟢 Demo Mode: Coinbase Pipeline (No API keys required)")
st.caption("This is a safe, offline demo that mimics the dashboard with fake data so reviewers can click around.")

colA, colB = st.columns([1,1])

with colA:
    st.subheader("Spot Prices (BTC-USD)")
    prices = pd.DataFrame(demo.fake_prices())
    st.dataframe(prices, use_container_width=True)
    st.line_chart(pd.DataFrame([p["price"] for p in demo.fake_price_series()]), height=220)

    # 👉 New comparison section
    hi = prices.loc[prices["price"].idxmax()]
    lo = prices.loc[prices["price"].idxmin()]
    diff = hi["price"] - lo["price"]
    pct = (diff / lo["price"]) * 100 if lo["price"] else 0
    st.metric(
        "Exchange Spread",
        f"${diff:,.2f} ({pct:.2f}%)",
        help=f"Highest: {hi['exchange']} @ ${hi['price']:,.2f} | Lowest: {lo['exchange']} @ ${lo['price']:,.2f}"
    )

with colB:
    st.subheader("Balances (Fake)")
    bals = pd.DataFrame(demo.fake_balances())
    st.dataframe(bals, use_container_width=True)
    btc_row = bals.loc[bals["asset"]=="BTC","amount"]
    if not btc_row.empty:
        btc_amt = float(btc_row.iloc[0])
        ref_price = prices["price"].mean()
        usd_val = btc_amt * ref_price
        st.metric("Estimated USD (BTC portion)", f"${usd_val:,.2f}")

st.divider()
st.write("Tip: use **run_demo.sh** for a one-liner. When you're ready for the real app with APIs, run your normal start script.")
if st.button("Refresh fake data"):
    st.experimental_rerun()
