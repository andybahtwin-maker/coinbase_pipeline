import httpx

def cbx_price(timeout=15.0):  # Coinbase Exchange (BTC-USD)
    url = "https://api.exchange.coinbase.com/products/BTC-USD/ticker"
    with httpx.Client(timeout=timeout, headers={"User-Agent":"rafael-coinbase-pipeline"}) as c:
        j = c.get(url).json()
        return float(j.get("price") or j.get("last") or 0.0)

def kraken_price(timeout=15.0):  # Kraken (XXBTZUSD)
    url = "https://api.kraken.com/0/public/Ticker?pair=XXBTZUSD"
    with httpx.Client(timeout=timeout) as c:
        j = c.get(url).json()
        # Result is { "result": {"XXBTZUSD": {"c": ["last", ...], ...}}}
        res = j.get("result",{})
        if not res:
            return 0.0
        key = list(res.keys())[0]
        last = res[key]["c"][0]
        return float(last)

def binance_price(timeout=15.0):  # Binance (USDT pair)
    url = "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
    with httpx.Client(timeout=timeout) as c:
        j = c.get(url).json()
        return float(j["price"])

def bitstamp_price(timeout=15.0):
    url = "https://www.bitstamp.net/api/v2/ticker/btcusd"
    with httpx.Client(timeout=timeout) as c:
        j = c.get(url).json()
        return float(j["last"])

def bitfinex_price(timeout=15.0):
    url = "https://api-pub.bitfinex.com/v2/ticker/tBTCUSD"
    with httpx.Client(timeout=timeout) as c:
        arr = c.get(url).json()
        # arr[6] is last price per docs; sometimes arr[0] is bid etc.
        # Defensive: try [6], then [0]
        try:
            return float(arr[6])
        except Exception:
            return float(arr[0])

def fetch_all_prices():
    results = []
    for name, fn in [
        ("Coinbase", cbx_price),
        ("Kraken", kraken_price),
        ("Binance (USDT)", binance_price),
        ("Bitstamp", bitstamp_price),
        ("Bitfinex", bitfinex_price),
    ]:
        try:
            price = fn()
        except Exception as e:
            price = None
        results.append({"exchange": name, "price": price})
    # normalize to USD: Binance is USDT—close enough for a dashboard spread check
    return results
