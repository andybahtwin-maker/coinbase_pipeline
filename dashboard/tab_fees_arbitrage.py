import streamlit as st, pandas as pd, ccxt
FEE_TABLE=[
    {"Exchange":"Coinbase Advanced","Maker %":0.40,"Taker %":0.60},
    {"Exchange":"Binance","Maker %":0.10,"Taker %":0.10},
    {"Exchange":"Kraken","Maker %":0.16,"Taker %":0.26},
    {"Exchange":"KuCoin","Maker %":0.10,"Taker %":0.10},
]
def _ex(id_):
    try: e=getattr(ccxt,id_)(); e.load_markets(); return e
    except Exception: return None
def _p(ex,sym):
    try: t=ex.fetch_ticker(sym); return t.get("last") or t.get("close")
    except Exception: return None
def render_fees_arbitrage():
    st.header("Arbitrage & Fees")
    st.subheader("Indicative Fee Comparison")
    st.dataframe(pd.DataFrame(FEE_TABLE), width='stretch')
    st.subheader("Spot Arbitrage (Live Prices)")
    base=st.selectbox("Asset",["BTC","ETH","SOL"],0)
    quote=st.selectbox("Quote",["USD","USDT","USDC"],0)
    pair_binance=f"{base}/USDT" if quote=="USD" else f"{base}/{quote}"
    pair_kraken =f"{base}/USD"  if quote=="USDT" else f"{base}/{quote}"
    pair_coinbase=f"{base}/USD" if quote!="USD" else f"{base}/{quote}"
    pair_kucoin =f"{base}/{quote}"
    exs={"binance":(pair_binance,_ex("binance")),
         "kraken":(pair_kraken,_ex("kraken")),
         "coinbase":(pair_coinbase,_ex("coinbase")),
         "kucoin":(pair_kucoin,_ex("kucoin"))}
    rows=[]
    for name,(sym,ex) in exs.items():
        if ex:
            p=_p(ex,sym)
            if p: rows.append({"Exchange":name,"Symbol":sym,"Price":p})
    if not rows:
        st.warning("No live prices available for that selection."); return
    spot=pd.DataFrame(rows).sort_values("Price")
    st.dataframe(spot, width='stretch')
    lo,hi=spot.iloc[0], spot.iloc[-1]
    spread=hi["Price"]-lo["Price"]; pct=(spread/lo["Price"]*100) if lo["Price"] else 0
    st.markdown(f"**Best Buy:** {lo['Exchange']} @ {lo['Price']:,.2f}  •  "
                f"**Best Sell:** {hi['Exchange']} @ {hi['Price']:,.2f}  •  "
                f"**Gross Spread:** {spread:,.2f} ({pct:.2f}%)")
    st.caption("Net profit must include fees/withdrawals/slippage/latency.")
