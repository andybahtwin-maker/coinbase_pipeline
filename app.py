import os, io, math, time
import pandas as pd
import streamlit as st
from dotenv import load_dotenv

from coinbase_helpers import get_coinbase_balances
from exchanges import fetch_all_prices
from emailer import send_email

st.set_page_config(page_title="BTC Dashboard", page_icon="🟠", layout="centered")
st.title("🟠 Bitcoin Dashboard")

load_dotenv()
st.caption("Your Coinbase BTC (if API creds are valid) + public BTC prices from multiple exchanges. Email yourself a CSV snapshot on demand.")

# ── Coinbase balances (soft-fail)
btc_available = None
rows, err = get_coinbase_balances()
if err:
    st.caption(f"Coinbase balance: [unavailable] {err}")
else:
    dfb = pd.DataFrame(rows)
    btc_rows = dfb[dfb["asset"].str.upper()=="BTC"]
    if not btc_rows.empty:
        btc_available = float(btc_rows["available"].sum())
        st.subheader("Your Coinbase BTC")
        st.metric("Available BTC", f"{btc_available:,.8f}")
    else:
        st.caption("Coinbase balance: 0 BTC (or none returned)")

# ── Prices
rows = fetch_all_prices()
df = pd.DataFrame(rows)
st.subheader("Live BTC Prices (no API keys)")
st.dataframe(df, use_container_width=True)

valid = df.dropna(subset=["price"])
if not valid.empty:
    pmin = valid["price"].min()
    pmax = valid["price"].max()
    spread = pmax - pmin
    pct = (spread / pmin * 100.0) if pmin else math.nan
    c1,c2,c3 = st.columns(3)
    c1.metric("Min (USD-ish)", f"${pmin:,.2f}")
    c2.metric("Max (USD-ish)", f"${pmax:,.2f}")
    c3.metric("Spread", f"${spread:,.2f} ({pct:.3f}%)")

st.divider()
st.subheader("Email a CSV Snapshot")
st.caption("Uses SMTP/Gmail env vars you merged: SMTP_HOST/PORT/USER/PASS, EMAIL_FROM, EMAIL_TO.")

def _csv_bytes(df: pd.DataFrame) -> bytes:
    buf = io.StringIO(); df.to_csv(buf, index=False); return buf.getvalue().encode()

if st.button("📧 Email me the current snapshot"):
    try:
        atts = []
        if not df.empty:
            atts.append(("btc_prices.csv", _csv_bytes(df)))
        if btc_available is not None:
            atts.append(("coinbase_btc_balance.csv", _csv_bytes(pd.DataFrame([{"asset":"BTC","available":btc_available}]))))
        msg = send_email(
            subject=f"BTC Snapshot • {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}",
            body="Attached: current prices" + (", Coinbase BTC" if btc_available is not None else " (no Coinbase balance)"),
            attachments=atts or [("empty.csv", b"no,data")]
        )
        st.success(msg)
    except Exception as e:
        st.error(f"Email failed: {e}")

st.caption("Exchanges: Coinbase, Kraken, Binance (USDT), Bitstamp, Bitfinex. Values are fetched on page load.")
