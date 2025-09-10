import os
import ccxt

def get_btc_balance():
    """
    Returns (available, total) BTC as floats (or 0.0, 0.0 if unavailable).
    Uses read-only API credentials from env: COINBASE_API_KEY / COINBASE_API_SECRET
    """
    key = os.getenv("COINBASE_API_KEY")
    sec = os.getenv("COINBASE_API_SECRET")
    if not key or not sec:
        return 0.0, 0.0
    try:
        ex = ccxt.coinbase({
            "apiKey": key,
            "secret": sec,
            "enableRateLimit": True,
        })
        bal = ex.fetch_balance()
        # CCXT normalizes tickers to 'BTC' key for spot balances when present
        info = bal.get("BTC") or {}
        free = float(info.get("free") or 0.0)
        total = float(info.get("total") or 0.0)
        return free, total
    except Exception:
        return 0.0, 0.0
