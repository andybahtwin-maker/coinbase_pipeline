# Remove the cache decorator, leave function as plain Python
def fetch_prices(timeout_ms=5000):
    import ccxt
    pairs = {
        "coinbase": "BTC/USD",
        "kraken":   "BTC/USD",
        "binance":  "BTC/USDT",
        "bitstamp": "BTC/USD",
        "bitfinex": "BTC/USD",
    }
    rows = []
    for ex_name, symbol in pairs.items():
        try:
            ex = getattr(ccxt, ex_name)({"timeout": timeout_ms, "enableRateLimit": True})
            t = ex.fetch_ticker(symbol)
            last = float(t["last"])
            bid = float(t.get("bid") or last)
            ask = float(t.get("ask") or last)
            rows.append({"exchange": ex_name, "symbol": symbol, "last": last, "bid": bid, "ask": ask})
        except Exception as e:
            rows.append({"exchange": ex_name, "symbol": symbol, "last": np.nan, "bid": np.nan, "ask": np.nan, "error": str(e)[:160]})
    return pd.DataFrame(rows)
