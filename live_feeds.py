from __future__ import annotations
import os, time
import httpx

# ---- Config ----
DEFAULT_TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "5"))
RETRIES = int(os.getenv("HTTP_RETRIES", "2"))

# Normalize symbols (UI may pass "BTC-USD" or "BTCUSD")
def _norm(symbol: str) -> str:
    s = symbol.replace("-", "").upper()
    if s.endswith("USDT"):  # keep USDT as-is
        return s
    # assume USD if not specified second asset
    if s.endswith("USD"): return s
    if s.endswith("USDC"): return s
    if s.endswith("EUR"): return s
    return s + "USD"

def _bitstamp_pair(symbol: str) -> str:
    # Bitstamp uses lowercase like 'btcusd'
    return _norm(symbol).lower()

def _bitfinex_pair(symbol: str) -> str:
    # Bitfinex v2 ticker likes 'tBTCUSD'
    return "t" + _norm(symbol)

def _get(client: httpx.Client, url: str) -> httpx.Response:
    last_ex = None
    for _ in range(RETRIES + 1):
        try:
            return client.get(url, timeout=DEFAULT_TIMEOUT)
        except Exception as ex:
            last_ex = ex
            time.sleep(0.25)
    raise last_ex

def fetch_bitstamp_price(client: httpx.Client, symbol: str) -> float:
    pair = _bitstamp_pair(symbol)
    # https://www.bitstamp.net/api/v2/ticker/btcusd
    r = _get(client, f"https://www.bitstamp.net/api/v2/ticker/{pair}")
    r.raise_for_status()
    data = r.json()
    # 'last' is a string, e.g. "61234.12"
    return float(data["last"])

def fetch_bitfinex_price(client: httpx.Client, symbol: str) -> float:
    pair = _bitfinex_pair(symbol)
    # https://api-pub.bitfinex.com/v2/ticker/tBTCUSD
    r = _get(client, f"https://api-pub.bitfinex.com/v2/ticker/{pair}")
    r.raise_for_status()
    arr = r.json()
    # arr[6] == last price (Bid, BidSize, Ask, AskSize, DailyChange, DailyChangePerc, LastPrice, Volume, High, Low)
    return float(arr[6])

def fetch_prices(symbol: str) -> dict:
    """Return dict with live prices for Bitstamp and Bitfinex."""
    symbol = _norm(symbol)
    out = {"symbol": symbol, "sources": {}, "ts": time.time()}
    with httpx.Client(headers={"User-Agent": "coinbase_pipeline/streamlit"}) as client:
        bs = fetch_bitstamp_price(client, symbol)
        bf = fetch_bitfinex_price(client, symbol)
        out["sources"]["bitstamp"] = bs
        out["sources"]["bitfinex"] = bf
    # Spread (+ means Bitfinex > Bitstamp)
    diff = out["sources"]["bitfinex"] - out["sources"]["bitstamp"]
    mid = (out["sources"]["bitfinex"] + out["sources"]["bitstamp"]) / 2.0
    pct = (diff / mid) * 100 if mid else 0.0
    out["diff_abs"] = diff
    out["diff_pct"] = pct
    return out

def est_fees(price: float, trade_usd: float, role: str, taker_bps: float, maker_bps: float) -> dict:
    """
    Estimate one-leg fee in USD for given price/size.
    taker_bps/maker_bps are in % (e.g. 0.19 for 0.19%).
    """
    bps = taker_bps if role == "taker" else maker_bps
    fee_rate = max(0.0, bps) / 100.0
    qty = trade_usd / price if price > 0 else 0.0
    fee_usd = qty * price * fee_rate
    return {"fee_rate": fee_rate, "qty": qty, "fee_usd": fee_usd}
