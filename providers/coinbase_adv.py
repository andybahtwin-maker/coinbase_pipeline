import os, httpx
from typing import Dict, List

def _cb_symbol(sym: str) -> str:
    return sym  # e.g., "BTC-USD"

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    out = {}
    headers = {}
    # If you want, set COINBASE_API_KEY in .env; not required for public tickers
    api_key = os.getenv("COINBASE_API_KEY") or os.getenv("CB_API_KEY")
    if api_key:
        headers["CB-ACCESS-KEY"] = api_key
    with httpx.Client(timeout=10) as s:
        for sym in symbols:
            p = _cb_symbol(sym)
            r = s.get(f"https://api.exchange.coinbase.com/products/{p}/ticker", headers=headers)
            if r.status_code == 200:
                data = r.json()
                out[sym] = float(data["price"])
    return out
