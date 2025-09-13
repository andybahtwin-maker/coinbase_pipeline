import httpx
from typing import Dict, List

_MAP = {
    "BTC-USD": "XXBTZUSD",
    "XRP-USD": "XRPUSD",
}

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    pairs = ",".join(_MAP[s] for s in symbols if s in _MAP)
    if not pairs:
        return {}
    r = httpx.get(f"https://api.kraken.com/0/public/Ticker?pair={pairs}", timeout=10)
    r.raise_for_status()
    j = r.json()["result"]
    rev = {v:k for k,v in _MAP.items()}
    out = {}
    for k, v in j.items():
        sym = rev.get(k)
        if not sym: continue
        out[sym] = float(v["c"][0])
    return out
