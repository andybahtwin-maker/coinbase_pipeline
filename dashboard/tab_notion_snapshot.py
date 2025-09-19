import io
import streamlit as st
import pandas as pd

def _mk_callout(title: str, body: str, emoji: str="ℹ️"):
    st.markdown(
        f"""
<div style="border:1px solid #3333;border-radius:12px;padding:12px;margin-bottom:8px;">
  <div style="font-size:14px;opacity:.7;">{emoji} {title}</div>
  <div style="font-size:20px;font-weight:700;margin-top:4px;">{body}</div>
</div>
        """,
        unsafe_allow_html=True
    )

# Data lifted from your Notion page snapshot (BTC/ETH/XRP rows) on 2025-09-13
# See repo chat for details.
NOTION_TABLE_MD = """pair,spot,24h_low,24h_high,best_bid,best_ask,spread_pct,fee_buy_pct,fee_sell_pct,effective_buy,effective_sell,edge_after_fees_pct
BTC-USD,116303.430000,114774.190000,116833.250000,116285.000000,116285.010000,0.000009,0.600000,0.600000,116982.720060,115587.290000,-1.192851
ETH-USD,4709.305000,4489.470000,4744.750000,4707.870000,4707.880000,0.000212,0.600000,0.600000,4736.127280,4679.622780,-1.193053
XRP-USD,3.104800,3.017600,3.139400,3.104500,3.104600,0.003221,0.600000,0.600000,3.123228,3.085873,-1.196026
"""

def render_notion_snapshot():
    st.header("Daily Crypto Arbitrage — Notion Snapshot")
    st.caption("Static snapshot imported from your Notion page (kept in-app so something real always shows).")

    # Callouts exactly as kept in your Notion block
    _mk_callout("BTC Balance", "0.00000000 BTC • Total: 0.00000000 BTC", "💰")
    _mk_callout("BTC Spread", "gross $144.00 • 0.12%", "📘")
    _mk_callout("Top Net Edge", "$-560.70  •  -0.48%  (after fees across all symbols)", "⚡")

    # Table
    df = pd.read_csv(io.StringIO(NOTION_TABLE_MD))
    st.dataframe(df, width='stretch')

    # Quick highlights
    try:
        worst = df.sort_values("edge_after_fees_pct").iloc[0]
        st.markdown(
            f"**Worst Net Edge in snapshot:** {worst['pair']}  •  {worst['edge_after_fees_pct']:.6f}%"
        )
    except Exception:
        pass