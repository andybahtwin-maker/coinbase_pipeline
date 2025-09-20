import json, pathlib as pl, pandas as pd
import streamlit as st
import plotly.express as px

st.set_page_config(page_title="🟠 Bitcoin Portfolio Demo", layout="wide")
st.title("🟠 Bitcoin Portfolio Demo (No Secrets)")

fees_p = pl.Path("demo_data/fees_config.json")
ticks_p = pl.Path("demo_data/sample_ticks.csv")
if not (fees_p.exists() and ticks_p.exists()):
    st.error("Missing demo_data files. They are committed by finish_portfolio_now.sh.")
    st.stop()

fees = json.loads(fees_p.read_text())
df = pd.read_csv(ticks_p, parse_dates=["timestamp"])

cb = df[df.exchange=="coinbase"].iloc[-1]["price"]
bn = df[df.exchange=="binance"].iloc[-1]["price"]
cb_fee = fees["coinbase"]["taker_bps"]/10000
bn_fee = fees["binance"]["taker_bps"]/10000
gross = cb - bn
net = cb*(1 - cb_fee) - bn*(1 + bn_fee)
mid = (cb + bn)/2
net_pct = (net/mid)*100

c1,c2,c3,c4 = st.columns(4)
c1.metric("Coinbase (USD)", f"${cb:,.2f}")
c2.metric("Binance (USDT~USD)", f"${bn:,.2f}")
c3.metric("Gross Spread", f"${gross:,.2f}")
c4.metric("Net Spread (after fees)", f"${net:,.2f}", f"{net_pct:.3f}%")

st.divider()
st.subheader("Price Trace (Demo)")
fig = px.line(df, x="timestamp", y="price", color="exchange", title="Coinbase vs Binance (demo ticks)")
st.plotly_chart(fig, use_container_width=True)

st.subheader("Recent Ticks")
st.dataframe(df.sort_values("timestamp").tail(50), use_container_width=True, height=260)

with st.expander("Fee Configuration"):
    st.json(fees)

st.caption("Portfolio-safe demo using committed data. No API keys required.")
