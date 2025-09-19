import ccxt, pandas as pd, streamlit as st
def _ex(id_):
    try:
        e=getattr(ccxt, id_)(); e.load_markets(); return e
    except Exception: return None
def _price(ex,sym):
    try:
        t=ex.fetch_ticker(sym); return t.get("last") or t.get("close") or t.get("ask") or t.get("bid")
    except Exception: return None
def render_balances():
    st.header("Balances")
    c1,c2,c3 = st.columns(3)
    with c1: exch = st.selectbox("Exchange (for prices)", ["binance","kraken","kucoin","coinbase"], 0, key="bal_ex")
    with c2: base = st.selectbox("Asset",["BTC","ETH","SOL","ADA","XRP","DOGE"],0, key="bal_asset")
    with c3: quote= st.selectbox("Quote",["USDT","USD","USDC"],0, key="bal_quote")
    ex=_ex(exch); sym=f"{base}/{quote}"
    if exch=="binance" and quote=="USD": sym=f"{base}/USDT"
    if exch in ["kraken","coinbase"] and quote=="USDT": sym=f"{base}/USD"
    p=_price(ex,sym) if ex else None
    if p: st.metric(f"{sym} @ {exch}", f"{p:,.4f}")
    else: st.warning("Live price unavailable for that pair on that exchange.")
    # sample holdings so UI isn't empty
    df=pd.DataFrame({"Asset":[base,"USDC","USD"],"Amount":[1.0,250.0,100.0]})
    if p:
        df["Price (USD)"]=[p if a==base else 1.0 for a in df["Asset"]]
        df["Value (USD)"]=df["Amount"]*df["Price (USD)"]
        st.subheader("Portfolio (sample)")
        st.dataframe(df, width='stretch')
        st.write(f"**Total (USD):** {df['Value (USD)'].sum():,.2f}")
    else:
        st.info("Add API keys later to pull real Coinbase balances.")
