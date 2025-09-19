import io, os
import pandas as pd
import streamlit as st
from dotenv import load_dotenv

# Load env if present (no hard fail)
load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"), override=False)

st.set_page_config(page_title="Coinbase Pipeline — Notion Snapshot", layout="wide")
st.title("Daily Arbitrage (Notion Snapshot)")

def callout(emoji: str, title: str, body: str):
    st.markdown(
        f"""
<div style="border:1px solid rgba(255,255,255,.15);border-radius:12px;padding:12px;margin-bottom:10px;">
  <div style="font-size:14px;opacity:.75;">{emoji} {title}</div>
  <div style="font-size:20px;font-weight:700;margin-top:4px;">{body}</div>
</div>
        """,
        unsafe_allow_html=True
    )

# --- STATIC SNAPSHOT CONTENT (so it's never empty) ---
CALL_BTC_BAL = ("💰", "BTC Balance", "0.00000000 BTC • Total: 0.00000000 BTC")
CALL_BTC_SPR = ("📘", "BTC Spread", "gross $144.00 • 0.12%")
CALL_TOP_EDGE = ("⚡", "Top Net Edge", "$-560.70  •  -0.48%  (after fees across all symbols)")

CSV_SNAPSHOT = """pair,spot,24h_low,24h_high,best_bid,best_ask,spread_pct,fee_buy_pct,fee_sell_pct,effective_buy,effective_sell,edge_after_fees_pct
BTC-USD,116285.005000,114774.190000,116833.250000,116280.700000,116280.710000,0.000009,0.600000,0.600000,116978.394260,115583.015800,-1.192851
ETH-USD,4709.050000,4489.470000,4744.750000,4707.460000,4707.470000,0.000212,0.600000,0.600000,4735.714820,4679.215240,-1.193053
XRP-USD,3.104650,3.017600,3.139400,3.104400,3.104700,0.009663,0.600000,0.600000,3.123328,3.085774,-1.202390
"""

c1, c2, c3 = st.columns(3)
with c1: callout(*CALL_BTC_BAL)
with c2: callout(*CALL_BTC_SPR)
with c3: callout(*CALL_TOP_EDGE)

st.subheader("Snapshot Table")
df = pd.read_csv(io.StringIO(CSV_SNAPSHOT))
st.dataframe(df, width='stretch')

# Small highlight so it looks like a real analysis
worst = df.sort_values("edge_after_fees_pct").iloc[0]
st.markdown(f"**Worst Net Edge (snapshot):** {worst['pair']} • {worst['edge_after_fees_pct']:.6f}%")

st.caption("This tab is static by design so the UI is never empty. We can later swap this to live data without changing the layout.")
