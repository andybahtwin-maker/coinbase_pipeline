from __future__ import annotations
import math, random, time
from dataclasses import dataclass
from typing import List, Dict
import pandas as pd

# Deterministic-ish randomness per symbol so it "feels" stable across refreshes
def _seed(sym: str) -> None:
    random.seed(hash(sym) % 2_000_000 + int(time.time() // 3))  # changes every ~3s

SYMBOLS = ["BTC/USD","ETH/USD","XRP/USD","SOL/USD","ADA/USD"]
EXCHANGES = ["bitstamp","bitfinex","coinbase","kraken","bybit","okx"]

@dataclass
class Quote:
    exchange: str
    symbol: str
    price: float

def price_matrix(symbols=SYMBOLS, exchanges=EXCHANGES) -> pd.DataFrame:
    rows = []
    for sym in symbols:
        _seed(sym)
        base = {"BTC/USD": 115_000, "ETH/USD": 4_500, "XRP/USD": 3.0,
                "SOL/USD": 190, "ADA/USD": 3.2}.get(sym, 100.0)
        for ex in exchanges:
            # Each exchange drifts slightly
            drift = (hash(ex) % 50 - 25) / 10_000.0
            noise = random.uniform(-0.002, 0.002)
            px = base * (1 + drift + noise)
            rows.append({"exchange": ex, "symbol": sym, "price": round(px, 4)})
    return pd.DataFrame(rows)

def top_spreads(n=3) -> List[Dict]:
    df = price_matrix()
    out = []
    for sym, g in df.groupby("symbol"):
        lo = g.loc[g["price"].idxmin()]
        hi = g.loc[g["price"].idxmax()]
        edge_pct = (hi["price"] - lo["price"]) / lo["price"]
        out.append({
            "symbol": sym,
            "buy_ex": lo["exchange"], "buy_px": float(lo["price"]),
            "sell_ex": hi["exchange"], "sell_px": float(hi["price"]),
            "edge_pct": float(edge_pct)
        })
    out.sort(key=lambda d: d["edge_pct"], reverse=True)
    return out[:n]

def recent_trades(symbol="BTC/USD", n=30) -> pd.DataFrame:
    _seed("TRD"+symbol)
    base = {"BTC/USD": 115_000, "ETH/USD": 4_500, "XRP/USD": 3.0,
            "SOL/USD": 190, "ADA/USD": 3.2}.get(symbol, 100.0)
    t0 = int(time.time())
    rows=[]
    for i in range(n):
        ts = t0 - (n-i)*random.randint(1,3)
        px = base * (1 + random.uniform(-0.003,0.003))
        sz = abs(random.gauss(1.0, 0.5))
        ex = random.choice(EXCHANGES)
        side = random.choice(["buy","sell"])
        rows.append({"t": ts, "price": round(px,2), "size": round(sz,3), "exchange": ex, "side": side})
    return pd.DataFrame(rows)

def orderbook_snapshot(symbol="BTC/USD", depth=10) -> pd.DataFrame:
    _seed("OBK"+symbol)
    mid = {"BTC/USD": 115_000, "ETH/USD": 4_500, "XRP/USD": 3.0,
           "SOL/USD": 190, "ADA/USD": 3.2}.get(symbol, 100.0)
    spread = mid*0.0008
    bids = [{"side":"bid","px": round(mid - i*spread/depth,2), "qty": round(abs(random.gauss(2,0.8)),3)} for i in range(1,depth+1)]
    asks = [{"side":"ask","px": round(mid + i*spread/depth,2), "qty": round(abs(random.gauss(2,0.8)),3)} for i in range(1,depth+1)]
    return pd.DataFrame(bids+asks)

def exchange_status() -> pd.DataFrame:
    rows=[]
    for ex in EXCHANGES:
        h = (hash(ex)+int(time.time()//10))%7
        st = ["OK","OK","OK","DEGRADED","MAINT","OK","OK"][h]
        rows.append({"exchange": ex, "status": st, "latency_ms": int(20+10*(h%3)+random.random()*10)})
    return pd.DataFrame(rows)

def volumes_24h(symbols=SYMBOLS) -> pd.DataFrame:
    _seed("VOL")
    rows=[]
    for sym in symbols:
        base = {"BTC/USD": 2.1e9, "ETH/USD": 1.3e9, "XRP/USD": 4.2e8,
                "SOL/USD": 6.6e8, "ADA/USD": 2.9e8}.get(sym, 1e8)
        rows.append({"symbol": sym, "usd_volume": int(base*(0.9+random.random()*0.2))})
    return pd.DataFrame(rows)
