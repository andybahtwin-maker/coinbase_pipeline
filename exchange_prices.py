import os, time
import pandas as pd, numpy as np, ccxt

DEFAULT_SYMBOLS=[s.strip() for s in os.getenv("SYMBOLS","BTC/USD,XRP/USD").split(",")]
DEFAULT_EXCHANGES=[e.strip() for e in os.getenv("EXCHANGES","coinbase,binance,kraken,bitstamp,bitfinex").split(",")]

def _load(names):
    out={}
    for n in names:
        if hasattr(ccxt, n):
            out[n]=getattr(ccxt, n)({"enableRateLimit": True})
    return out

def fetch_tickers(symbols=None, exchanges=None):
    symbols = symbols or DEFAULT_SYMBOLS
    ex = _load(exchanges or DEFAULT_EXCHANGES)
    rows=[]
    for exn, inst in ex.items():
        for sym in symbols:
            try:
                t=inst.fetch_ticker(sym)
                last=t.get("last") or t.get("close")
                bid,ask=t.get("bid"), t.get("ask")
                price = last or ((bid+ask)/2.0 if bid and ask else None)
                if price is None: 
                    continue
                rows.append({"exchange":exn,"symbol":sym,"price":float(price)})
            except Exception:
                rows.append({"exchange":exn,"symbol":sym,"price":np.nan})
    return pd.DataFrame(rows)

def calc_spreads(df: pd.DataFrame):
    pivot=df.pivot_table(index=["symbol"], columns="exchange", values="price", aggfunc="last")
    sym_rows=[]
    for sym,row in pivot.iterrows():
        s=row.dropna()
        if s.empty: 
            continue
        mx_ex, mx = s.idxmax(), s.max()
        mn_ex, mn = s.idxmin(), s.min()
        spread_abs = mx - mn
        spread_pct = (spread_abs / mn * 100.0) if mn else np.nan
        sym_rows.append({
            "symbol": sym,
            "min_ex": mn_ex, "min_price": mn,
            "max_ex": mx_ex, "max_price": mx,
            "spread_abs": spread_abs, "spread_pct": spread_pct
        })
    sym_summary=pd.DataFrame(sym_rows).sort_values("spread_pct", ascending=False)

    pairs=[]
    for sym,row in pivot.iterrows():
        s=row.dropna(); exs=list(s.index)
        for i in range(len(exs)):
            for j in range(len(exs)):
                if i==j: 
                    continue
                b_ex, s_ex = exs[i], exs[j]
                b, s_ = s[b_ex], s[s_ex]
                if not (np.isfinite(b) and np.isfinite(s_)) or b<=0:
                    continue
                edge = (s_ - b)/b*100.0
                pairs.append({"symbol":sym,"buy_ex":b_ex,"buy":b,"sell_ex":s_ex,"sell":s_,"edge_pct":edge})
    pair_detail=pd.DataFrame(pairs).sort_values(["symbol","edge_pct"], ascending=False)
    return pivot, sym_summary, pair_detail

def make_summary_text(sym_summary, top_n=4):
    if sym_summary.empty:
        return "No reliable spreads."
    lines=[]
    for r in sym_summary.head(top_n).itertuples():
        lines.append(f"{r.symbol}: {r.spread_pct:.2f}% (buy {r.min_ex} @ {r.min_price:.2f} → sell {r.max_ex} @ {r.max_price:.2f})")
    return "\n".join(lines)
