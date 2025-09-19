import os
import math
import pandas as pd
import streamlit as st
import plotly.graph_objects as go
import ccxt

# ---------- Helpers ----------
def _safe_ex(id_: str, auth: bool = False):
    """
    Return a ccxt exchange instance.
    If auth=True and id_=='coinbase', use env creds.
    """
    try:
        if auth and id_ == "coinbase":
            k = os.getenv("CB_API_KEY")
            s = os.getenv("CB_API_SECRET")
            p = os.getenv("CB_API_PASSPHRASE")
            if not (k and s and p):
                return None
            ex = ccxt.coinbase({"enableRateLimit": True})
            ex.api_key = k
            ex.secret = s
            ex.password = p
        else:
            ex = getattr(ccxt, id_)({"enableRateLimit": True})
        ex.load_markets()
        return ex
    except Exception:
        return None

def _norm_pair(ex_id: str, base: str, quote: str) -> str:
    # Coinbase uses USD; Binance prefers USDT
    if ex_id == "coinbase":
        return f"{base}/USD"
    if ex_id == "binance" and quote == "USD":
        return f"{base}/USDT"
    return f"{base}/{quote}"

def _last_price(ex, pair: str):
    try:
        t = ex.fetch_ticker(pair)
        return t.get("last") or t.get("close") or t.get("ask") or t.get("bid")
    except Exception:
        return None

def _ohlcv(ex, pair: str, tf: str = "1h", limit: int = 200):
    try:
        return ex.fetch_ohlcv(pair, timeframe=tf, limit=limit) or []
    except Exception:
        return []

def _coinbase_balance_usd():
    """
    Return (total_usd, df) using private Coinbase creds.
    df columns: Asset, Amount, Price(USD), Value(USD)
    """
    ex = _safe_ex("coinbase", auth=True)
    if not ex:
        return None, None
    try:
        bal = ex.fetch_balance()
    except Exception:
        return None, None

    rows = []
    total = 0.0
    for sym, amt in (bal.get("total") or {}).items():
        try:
            amt = float(amt)
        except Exception:
            continue
        if amt <= 0:
            continue
        if sym == "USD":
            px = 1.0
        else:
            pair = f"{sym}/USD"
            px = _last_price(ex, pair) or 0.0
        val = amt * (px or 0.0)
        total += val
        rows.append({"Asset": sym, "Amount": amt, "Price(USD)": px, "Value(USD)": val})

    df = pd.DataFrame(rows).sort_values("Value(USD)", ascending=False) if rows else pd.DataFrame(
        columns=["Asset", "Amount", "Price(USD)", "Value(USD)"]
    )
    return total, df

# ---------- Main UI ----------
def render_big_numbers():
    st.markdown(
        """
        <style>
        .metric-row .stMetric {padding: 12px 16px; border: 1px solid rgba(255,255,255,0.1); border-radius: 14px;}
        </style>
        """,
        unsafe_allow_html=True,
    )

    # Controls (unique keys so no collisions with other tabs)
    c1, c2, c3 = st.columns(3)
    with c1:
        base = st.selectbox("Asset", ["BTC", "ETH", "SOL"], index=0, key="hero_asset")
    with c2:
        quote = st.selectbox("Quote", ["USD"], index=0, key="hero_quote")  # Coinbase is USD; keeps things stable
    with c3:
        tf = st.selectbox("Timeframe", ["1m", "5m", "15m", "1h", "4h", "1d"], index=3, key="hero_tf")

    # Live prices
    cb_ex = _safe_ex("coinbase", auth=False)
    bn_ex = _safe_ex("binance", auth=False)
    cb_pair = _norm_pair("coinbase", base, quote)
    bn_pair = _norm_pair("binance", base, quote)

    cb_px = _last_price(cb_ex, cb_pair) if cb_ex else None
    bn_px = _last_price(bn_ex, bn_pair) if bn_ex else None

    # Real spread
    spread_val = None
    spread_pct = None
    if cb_px and bn_px:
        spread_val = bn_px - cb_px   # ref (binance) - coinbase
        spread_pct = (spread_val / cb_px) * 100 if cb_px else None

    # Coinbase balances (private)
    total_usd, df_bal = _coinbase_balance_usd()

    # Hero row: Total Balance, Coinbase price, Spread vs Binance
    st.markdown('<div class="metric-row">', unsafe_allow_html=True)
    m1, m2, m3 = st.columns(3)
    with m1:
        if total_usd is not None:
            st.metric("Total Balance (USD)", f"${total_usd:,.2f}")
        else:
            st.metric("Total Balance (USD)", "—")
    with m2:
        if cb_px:
            st.metric(f"{base}/USD @ Coinbase", f"{cb_px:,.2f}")
        else:
            st.metric(f"{base}/USD @ Coinbase", "—")
    with m3:
        if spread_val is not None and spread_pct is not None:
            sign = "+" if spread_val >= 0 else ""
            st.metric("Spread vs Binance", f"${spread_val:,.2f}", f"{sign}{spread_pct:.2f}%")
        else:
            st.metric("Spread vs Binance", "—", None)
    st.markdown("</div>", unsafe_allow_html=True)

    # Candle (Coinbase)
    if cb_ex:
        ohl = _ohlcv(cb_ex, cb_pair, tf=tf, limit=240)
        if ohl:
            df = pd.DataFrame(ohl, columns=["ts", "open", "high", "low", "close", "vol"])
            fig = go.Figure(data=[go.Candlestick(
                x=pd.to_datetime(df["ts"], unit="ms"),
                open=df["open"], high=df["high"], low=df["low"], close=df["close"]
            )])
            fig.update_layout(height=420, margin=dict(l=10, r=10, t=10, b=10))
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No OHLCV for that selection.")
    else:
        st.warning("Coinbase public market feed unavailable right now.")

    # Balances table (top 10)
    st.subheader("Coinbase Balances")
    if df_bal is not None and not df_bal.empty:
        top = df_bal.head(10)
        # prettier number format
        fmt = top.copy()
        fmt["Amount"] = fmt["Amount"].map(lambda x: f"{x:,.6f}")
        fmt["Price(USD)"] = fmt["Price(USD)"].map(lambda x: f"{x:,.4f}")
        fmt["Value(USD)"] = fmt["Value(USD)"].map(lambda x: f"{x:,.2f}")
        st.dataframe(fmt, use_container_width=True)
    else:
        st.caption("No balances returned. Add CB_API_KEY / CB_API_SECRET / CB_API_PASSPHRASE to .env if missing.")
