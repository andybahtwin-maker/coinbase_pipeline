#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Force demo mode (no live API calls)
export DEMO_MODE=1

# Venv bootstrap
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate

# Make sure streamlit is present
grep -q '^streamlit\b' requirements.txt 2>/dev/null || echo "streamlit" >> requirements.txt
pip install -r requirements.txt

# Minimal fallback app if missing
if [ ! -f streamlit_app.py ]; then
  cat > streamlit_app.py <<'PY'
import os
import time
import streamlit as st

DEMO = os.getenv("DEMO_MODE","0") == "1"
POS_COLOR="green"; NEG_COLOR="red"; FEE_COLOR="blue"

st.set_page_config(page_title="Coinbase Pipeline — Demo", layout="wide")
st.title("Coinbase Pipeline — Demo Showcase")
st.caption("DEMO_MODE is ON — no live API calls. Colors: green=positive, red=negative, blue=fees.")

col1, col2, col3 = st.columns(3)
col1.metric("Sample PnL", "+2.4%", "+0.8%")
col2.metric("Avg Fee (bps)", "5.2", None, help="Illustrative fee metric", delta_color="off")
col3.metric("Best Spread (24h)", "0.87%", "+0.12%")

st.subheader("Recent Arbitrage Spreads (mock)")
import random
rows = [{"pair": p, "spread_pct": round(random.uniform(-0.3, 1.2), 3)}
        for p in ["BTC/USD","ETH/USD","XRP/USD","SOL/USD","ADA/USD"]]
st.dataframe(rows, use_container_width=True)

st.subheader("Color Legend")
st.markdown(f"- <span style='color:{POS_COLOR}'>Positive</span> | "
            f"<span style='color:{NEG_COLOR}'>Negative</span> | "
            f"<span style='color:{FEE_COLOR}'>Fees</span>", unsafe_allow_html=True)

if not DEMO:
    st.warning("DEMO_MODE is off. Turn it on with DEMO_MODE=1 to avoid real API calls.")
PY
fi

# Run the app
streamlit run streamlit_app.py
