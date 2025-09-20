import os, json, pathlib as pl, pandas as pd
import streamlit as st
import plotly.express as px

st.set_page_config(page_title="🟠 Bitcoin Portfolio Demo", layout="wide")
st.title("🟠 Bitcoin Portfolio Demo (No Secrets)")

st.caption("This page is designed to *always* render: demo data is bundled, and visualizations are embedded.")

fees_p = pl.Path("demo_data/fees_config.json")
ticks_p = pl.Path("demo_data/sample_ticks.csv")
if not (fees_p.exists() and ticks_p.exists()):
    st.error("Missing demo_data. Commit includes these files; if absent, run scripts/enable_demo_mode.sh.")
    st.stop()

fees = json.loads(fees_p.read_text())
df = pd.read_csv(ticks_p, parse_dates=["timestamp"])

# simple fee-adjusted spread calc on the latest point
latest_cb = df[df.exchange=="coinbase"].iloc[-1]["price"]
latest_bn = df[df.exchange=="binance"].iloc[-1]["price"]
cb_fee = fees["coinbase"]["taker_bps"]/10000
bn_fee = fees["binance"]["taker_bps"]/10000
gross = latest_cb - latest_bn
net = latest_cb*(1 - cb_fee) - latest_bn*(1 + bn_fee)
mid = (latest_cb + latest_bn) / 2
net_pct = (net / mid) * 100

c1, c2, c3, c4 = st.columns(4)
c1.metric("Coinbase (USD)", f"${latest_cb:,.2f}")
c2.metric("Binance (USDT~USD)", f"${latest_bn:,.2f}")
c3.metric("Gross Spread", f"${gross:,.2f}")
c4.metric("Net Spread (after fees)", f"${net:,.2f}", f"{net_pct:.3f}%")

st.divider()
st.subheader("Price Trace (Demo)")
df_plot = df.copy()
df_plot["t"] = df_plot["timestamp"]
fig = px.line(df_plot, x="t", y="price", color="exchange", title="Coinbase vs Binance (demo ticks)")
st.plotly_chart(fig, use_container_width=True)

st.subheader("Recent Ticks")
st.dataframe(df.sort_values("timestamp").tail(50), use_container_width=True, height=260)

with st.expander("Fee Configuration"):
    st.json(fees)

st.info("Demo Mode is always-on for this page. Live pages appear when keys and libs exist, but this page is your portfolio-safe default.", icon="🪄")
