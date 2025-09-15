import httpx
from typing import Dict, Any

# We support Coinbase Retail v2 for spot + Coinbase Exchange (Advanced) for stats/orderbook.
# Multiple fallbacks to survive minor API changes.

TIMEOUT = 10.0

def _get_json(url: str, headers: Dict[str, str] | None = None) -> Any:
    with httpx.Client(timeout=TIMEOUT) as client:
        r = client.get(url, headers=headers or {})
        r.raise_for_status()
        return r.json()

def get_spot(pair: str) -> float | None:
    # Retail v2
    try:
        j = _get_json(f"https://api.coinbase.com/v2/prices/{pair}/spot")
        return float(j["data"]["amount"])
    except Exception:
        pass
    # Advanced (exchange) ticker
    for base in ("https://api.exchange.coinbase.com", "https://api.pro.coinbase.com"):
        try:
            j = _get_json(f"{base}/products/{pair}/ticker")
            return float(j.get("price") or j.get("last"))
        except Exception:
            continue
    return None

def get_24h_stats(pair: str) -> Dict[str, float] | None:
    for base in ("https://api.exchange.coinbase.com", "https://api.pro.coinbase.com"):
        try:
            j = _get_json(f"{base}/products/{pair}/stats")
            return {
                "open": float(j.get("open", 0.0)),
                "high": float(j.get("high", 0.0)),
                "low":  float(j.get("low", 0.0)),
                "volume": float(j.get("volume", 0.0)),
                "last": float(j.get("last", 0.0)) if j.get("last") else None,
            }
        except Exception:
            continue
    return None

def get_top_of_book(pair: str) -> Dict[str, float] | None:
    for base in ("https://api.exchange.coinbase.com", "https://api.pro.coinbase.com"):
        try:
            j = _get_json(f"{base}/products/{pair}/book?level=1")
            bids = j.get("bids") or []
            asks = j.get("asks") or []
            best_bid = float(bids[0][0]) if bids else None
            best_ask = float(asks[0][0]) if asks else None
            return {"best_bid": best_bid, "best_ask": best_ask}
        except Exception:
            continue
    return None

def assemble_pair_metrics(pair: str, fee_buy: float, fee_sell: float) -> Dict[str, Any]:
    spot = get_spot(pair)
    stats = get_24h_stats(pair) or {}
    tob = get_top_of_book(pair) or {}

    low = stats.get("low")
    high = stats.get("high")
    best_bid = tob.get("best_bid")
    best_ask = tob.get("best_ask")

    spread = None
    if best_bid and best_ask and best_ask != 0:
        spread = (best_ask - best_bid) / best_ask

    # Effective prices if you hit market (approx): apply taker fees
    effective_buy = best_ask * (1 + fee_buy) if best_ask else (spot * (1 + fee_buy) if spot else None)
    effective_sell = best_bid * (1 - fee_sell) if best_bid else (spot * (1 - fee_sell) if spot else None)

    return {
        "pair": pair,
        "spot": spot,
        "24h_low": low,
        "24h_high": high,
        "best_bid": best_bid,
        "best_ask": best_ask,
        "spread_pct": spread * 100 if spread is not None else None,
        "fee_buy_pct": fee_buy * 100,
        "fee_sell_pct": fee_sell * 100,
        "effective_buy": effective_buy,
        "effective_sell": effective_sell,
        "edge_after_fees_pct": ((effective_sell - effective_buy) / effective_buy * 100) if (effective_buy and effective_sell) else None
    }
