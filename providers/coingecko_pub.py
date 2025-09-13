import httpx
from typing import Dict, List

_MAP = {
    "BTC-USD": "bitcoin",
    "XRP-USD": "ripple",
}

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    ids = ",".join(_MAP[s] for s in symbols if s in _MAP)
    if not ids:
        return {}
    r = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                  params={"ids": ids, "vs_currencies": "usd"}, timeout=10)
    r.raise_for_status()
    j = r.json()
    out = {}
    for s in symbols:
        cid = _MAP.get(s)
        if cid and cid in j and "usd" in j[cid]:
            out[s] = float(j[cid]["usd"])
    return out
