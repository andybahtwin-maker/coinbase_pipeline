import os, time
import streamlit as st
import ccxt

def _coinbase_private():
    apiKey=os.getenv("CB_API_KEY")
    secret=os.getenv("CB_API_SECRET")
    passphrase=os.getenv("CB_API_PASSPHRASE")
    if not (apiKey and secret and passphrase):
        return None
    ex = ccxt.coinbase({
        "apiKey": apiKey,
        "secret": secret,
        "password": passphrase,   # ccxt uses "password" for passphrase
        "enableRateLimit": True,
    })
    try:
        ex.load_markets()
        return ex
    except Exception:
        return None

def render_trade():
    st.header("Trade")
    allow_live = os.getenv("ALLOW_LIVE_TRADES","no").lower() in ("1","true","yes","y")
    mode = "LIVE" if allow_live else "SIMULATED"
    st.warning(f"Order Mode: {mode}. Set ALLOW_LIVE_TRADES=yes in .env to enable live orders.", icon="⚠️") if not allow_live else st.success("LIVE orders enabled via .env", icon="🔥")

    c1, c2, c3, c4 = st.columns(4)
    with c1:
        side = st.selectbox("Side", ["buy","sell"], index=0, key="trade_side")
    with c2:
        symbol = st.selectbox("Symbol", ["BTC/USD","ETH/USD","SOL/USD"], index=0, key="trade_symbol")
    with c3:
        qty = st.number_input("Amount (base)", min_value=0.0, value=0.001, step=0.001, key="trade_qty")
    with c4:
        order_type = st.selectbox("Type", ["market"], index=0, key="trade_type")

    ex = _coinbase_private()
    if ex is None:
        st.error("Coinbase credentials not detected or invalid. Cannot place orders.")
        return

    # Show current price
    try:
        ticker = ex.fetch_ticker(symbol)
        last = ticker.get("last") or ticker.get("close")
        if last:
            st.metric(label=f"{symbol} Last", value=f"{last:,.2f}")
    except Exception as e:
        st.info(f"Price load failed: {e}")

    colA, colB = st.columns([1,1])
    with colA:
        confirm = st.checkbox("I understand the risks", value=False, key="trade_confirm")
    with colB:
        go = st.button(f"Submit {side.upper()} ({mode})", use_container_width=True, key="trade_submit")

    if go:
        if not confirm:
            st.error("Please confirm the checkbox to proceed.")
            return
        if qty <= 0:
            st.error("Amount must be > 0")
            return
        if allow_live:
            try:
                o = ex.create_order(symbol, order_type, side, qty)
                st.success(f"Order placed: {o.get('id','(no id)')}")
                st.json(o)
            except Exception as e:
                st.error(f"Order failed: {e}")
        else:
            # Simulate
            st.info(f"[SIMULATED] Would place {side} {qty} {symbol} ({order_type})")
