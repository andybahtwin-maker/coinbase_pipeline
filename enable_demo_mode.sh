#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating demo data module (demo_data.py)…"
cat > demo_data.py <<'PY'
from datetime import datetime, timedelta
import random

random.seed(42)

EXCHANGES = ["Coinbase", "Kraken", "Binance", "Bitstamp", "Bitfinex"]

def fake_prices():
    base = 55000.0
    out = []
    for ex in EXCHANGES:
        jitter = random.uniform(-800, 800)
        out.append({"exchange": ex, "symbol": "BTC-USD", "price": round(base + jitter, 2)})
    return out

def fake_balances():
    assets = [
        {"asset": "BTC", "amount": 0.12345678},
        {"asset": "USDC", "amount": 1500.0},
        {"asset": "ETH", "amount": 2.5},
    ]
    return assets

def fake_price_series(points=50):
    base = 55000.0
    now = datetime.utcnow()
    data = []
    val = base
    for i in range(points):
        val += random.uniform(-150, 150)
        data.append({"t": (now - timedelta(minutes=(points-i))).isoformat(), "price": round(val, 2)})
    return data
PY

echo "==> Creating standalone Streamlit demo app (demo_app.py)…"
cat > demo_app.py <<'PY'
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
PY

echo "==> Creating run_demo.sh…"
cat > run_demo.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv >/dev/null 2>&1 || true
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install streamlit pandas >/dev/null

echo "==> Launching Streamlit demo on http://localhost:8501"
exec streamlit run demo_app.py
SH
chmod +x run_demo.sh

echo "==> Done. Start the demo with: ./run_demo.sh"
