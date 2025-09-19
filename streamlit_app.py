import os
import streamlit as st
import pandas as pd
import ccxt
from datetime import datetime

# Load environment
CB_API_KEY = os.getenv("CB_API_KEY", "")
CB_API_SECRET = os.getenv("CB_API_SECRET", "")
CB_API_PASSPHRASE = os.getenv("CB_API_PASSPHRASE", "")

st.set_page_config(page_title="Crypto Arbitrage Dashboard", layout="wide")

st.sidebar.title("⚡ Status")
if CB_API_KEY and CB_API_SECRET and CB_API_PASSPHRASE:
    st.sidebar.success("Coinbase API keys loaded")
else:
    st.sidebar.error("Missing Coinbase credentials in .env")

# Set up exchanges
exchanges = {
    "coinbase": ccxt.coinbase({
        "apiKey": CB_API_KEY,
        "secret": CB_API_SECRET,
        "password": CB_API_PASSPHRASE,
    }),
    "binance": ccxt.binance(),
    "kraken": ccxt.kraken(),
}

def fetch_price(exchange, symbol="BTC/USDT"):
    try:
        ticker = exchanges[exchange].fetch_ticker(symbol)
        return ticker["last"]
    except Exception as e:
        st.sidebar.warning(f"{exchange} error: {e}")
        return None

st.title("📊 Bitcoin Arbitrage Monitor")

# Fetch prices
prices = {}
for ex in exchanges:
    prices[ex] = fetch_price(ex)

valid_prices = {k: v for k, v in prices.items() if v is not None}

if valid_prices:
    df = pd.DataFrame(list(valid_prices.items()), columns=["Exchange", "Price"])
    st.subheader("Current BTC Prices")
    st.table(df)

    max_ex = df.loc[df["Price"].idxmax()]
    min_ex = df.loc[df["Price"].idxmin()]
    spread = max_ex["Price"] - min_ex["Price"]

    st.metric(
        label="Best Arbitrage Spread (USD)",
        value=f"${spread:,.2f}",
        delta=f"Buy on {min_ex['Exchange']} / Sell on {max_ex['Exchange']}"
    )

    st.line_chart(df.set_index("Exchange"))
else:
    st.error("No valid price data available.")
