import os, pandas as pd, plotly.graph_objects as go, ccxt
from dotenv import load_dotenv
import streamlit as st

# Load .env if present; don't crash if missing
load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"), override=False)

from dashboard.sidebar_status import render_sidebar_status
from dashboard.tab_env_health import render_env_health
from dashboard.tab_balances import render_balances
from dashboard.tab_ai_summary import render_ai_summary
from dashboard.tab_fees_arbitrage import render_fees_arbitrage
from dashboard.tab_big_numbers import render_big_numbers
from dashboard.tab_notion_snapshot import render_notion_snapshot
from dashboard.tab_trade import render_trade

st.set_page_config(page_title="Coinbase Pipeline — EVERYTHING", layout="wide")
HAS_COINBASE = bool(os.getenv("CB_API_KEY") and os.getenv("CB_API_SECRET") and os.getenv("CB_API_PASSPHRASE"))
render_sidebar_status(HAS_COINBASE)
st.title("Trading Control Panel")

tabs = st.tabs(["Dashboard","Balances","Trade","AI Summary","Arbitrage/Fees","Env Health Check","Daily Arbitrage (Notion)"])
tab_dash, tab_bal, tab_trade, tab_ai, tab_arb, tab_env, tab_notion = tabs

with tab_dash:
    render_big_numbers()

with tab_bal:

    render_balances()

with tab_ai:
    render_ai_summary()

with tab_arb:
    render_fees_arbitrage()

with tab_env:
    render_env_health()

with tab_notion:
    render_notion_snapshot()
