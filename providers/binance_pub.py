import httpx
from typing import Dict, List

def _bn_symbol(sym: str) -> str:
    if sym.endswith("-USD"):
        base = sym.split("-")[0]
        return f"{base}USDT"
    return sym.replace("-", "")

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    out = {}
    with httpx.Client(timeout=10) as s:
        for sym in symbols:
            b = _bn_symbol(sym)
            r = s.get("https://api.binance.com/api/v3/ticker/price", params={"symbol": b})
            if r.status_code == 200:
                out[sym] = float(r.json()["price"])
    return out
