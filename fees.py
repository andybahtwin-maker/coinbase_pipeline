import ccxt, functools

DEFAULT_TAKER = 0.001  # 0.10%
DEFAULT_WITHDRAW = {
    "BTC": 0.0005,     # 0.0005 BTC
    "XRP": 0.25,       # 0.25 XRP
}

def _safe_get_withdraw_fee_coin(ex, asset: str) -> float:
    asset = asset.upper()
    fee_coin = None
    try:
        ex.load_markets()
    except Exception:
        pass
    cur = None
    try:
        cur = ex.currencies.get(asset) if hasattr(ex, "currencies") else None
    except Exception:
        cur = None
    if cur and isinstance(cur, dict):
        nets = cur.get("networks") or {}
        if nets:
            preferred_keys = [asset, asset + "-MAIN", "MAIN", "NATIVE"]
            for k in preferred_keys:
                if k in nets and isinstance(nets[k], dict):
                    f = nets[k].get("fee")
                    if isinstance(f, (int, float)) and f >= 0:
                        fee_coin = float(f); break
            if fee_coin is None:
                cand = [n.get("fee") for n in nets.values()
                        if isinstance(n, dict) and isinstance(n.get("fee"), (int, float)) and n.get("fee") >= 0]
                if cand:
                    fee_coin = float(min(cand))
        if fee_coin is None:
            f1 = cur.get("fee")
            if isinstance(f1, (int, float)) and f1 >= 0:
                fee_coin = float(f1)
            else:
                fees = cur.get("fees") or {}
                wd = fees.get("withdraw") if isinstance(fees, dict) else None
                if isinstance(wd, dict):
                    f2 = wd.get("fee")
                    if isinstance(f2, (int, float)) and f2 >= 0:
                        fee_coin = float(f2)
    if fee_coin is None:
        fee_coin = DEFAULT_WITHDRAW.get(asset, 0.0)
    return float(fee_coin)

def _safe_get_taker_fee_pct(ex, symbol: str) -> float:
    try:
        markets = ex.load_markets()
        m = markets.get(symbol)
        if isinstance(m, dict):
            t = m.get("taker")
            if isinstance(t, (int, float)) and t >= 0:
                return float(t)
    except Exception:
        pass
    return float(DEFAULT_TAKER)

@functools.lru_cache(maxsize=128)
def get_fees(exchange_name: str, symbol: str):
    asset = symbol.split("/")[0].upper()
    try:
        cls = getattr(ccxt, exchange_name)
        ex = cls({"enableRateLimit": True})
    except Exception:
        return (DEFAULT_TAKER, DEFAULT_WITHDRAW.get(asset, 0.0))
    taker = _safe_get_taker_fee_pct(ex, symbol)
    withdraw_coin = _safe_get_withdraw_fee_coin(ex, asset)
    return (float(taker), float(withdraw_coin))
