import os
import time
import streamlit as st

# If you want to use Coinbase via ccxt:
try:
    import ccxt
except ImportError:
    ccxt = None

from dotenv import load_dotenv
load_dotenv()

# Load Coinbase credentials
COINBASE_API_KEY = os.getenv("COINBASE_API_KEY")
COINBASE_API_SECRET = os.getenv("COINBASE_API_SECRET")

# Constants
DEFAULT_REFRESH_SEC = 300

# Sidebar / UI
st.set_page_config(page_title="Crypto Arbitrage Dashboard", layout="wide")
st.title("Crypto Arbitrage Portfolio Demo")

with st.sidebar:
    st.header("Controls")
    symbols_input = st.text_input("Symbols (comma-separated)", "BTC/USD, ETH/USD")
    trade_size = st.number_input("Trade size (USD)", min_value=10, value=1000, step=10)
    role = st.radio("Role", ["taker", "maker"], index=0, key="role")
    refresh_sec = st.number_input("Auto-refresh every (seconds)", min_value=30, value=int(os.getenv("AUTO_SEC", str(DEFAULT_REFRESH_SEC))), step=30, key="refresh_interval")
    if st.button("↻ Refresh now", key="refresh_now"):
        st.experimental_rerun()

# Function to fetch price from Coinbase
def fetch_coinbase(symbol):
    if not ccxt or not COINBASE_API_KEY or not COINBASE_API_SECRET:
        return None
    try:
        exchange = ccxt.coinbase({
            "apiKey": COINBASE_API_KEY,
            "secret": COINBASE_API_SECRET,
        })
        ticker = exchange.fetch_ticker(symbol)
        return float(ticker['last'])
    except Exception:
        return None

# Fallback dummy data
def dummy_price(symbol):
    dummy = {
        "BTC/USD": 30000,
        "ETH/USD": 1800,
    }
    return dummy.get(symbol.upper(), None)

# Fee rate
def fee_rate(role):
    return 0.002 if role == "taker" else 0.001

# Main loop
symbols = [s.strip().upper() for s in symbols_input.split(",") if s.strip()]
if not symbols:
    st.error("Please enter at least one symbol like 'BTC/USD'.")
else:
    for sym in symbols:
        st.subheader(f"{sym} Arbitrage")

        price = fetch_coinbase(sym)
        used_coinbase = True
        if price is None:
            price = dummy_price(sym)
            used_coinbase = False

        if price is None:
            st.error(f"Cannot fetch price for {sym}")
            continue

        # Fee calculation
        f_rate = fee_rate(role)
        fee_one_leg = trade_size * f_rate
        roundtrip_fee = fee_one_leg * 2

        # Layout
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Coinbase Price", f"${price:,.2f}")
            st.caption(f"{'Using Coinbase live' if used_coinbase else 'Using dummy data'}")
        with col2:
            st.metric("2-leg Fee Estimate", f"${roundtrip_fee:,.2f}")

        st.metric("Trade Size", f"${trade_size:,.2f}", delta=f"Role: {role}", delta_color="off")
        st.divider()

# Auto refresh
if refresh_sec > 0:
    time.sleep(refresh_sec)
    st.experimental_rerun()
