import os, httpx, yaml
from typing import Dict

def load_fee_overrides() -> Dict:
    try:
        with open("config/fees.yaml","r",encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {}

def exchange_fee_pct(name: str, taker: bool=True) -> float:
    ovr = load_fee_overrides().get("exchanges",{}).get(name.lower(),{})
    key = "taker_pct" if taker else "maker_pct"
    if key in ovr:
        return float(ovr[key])
    # fallback to defaults
    import yaml
    base = yaml.safe_load(open("config/feeds.yaml","r",encoding="utf-8").read())
    dflt = float(base.get("fees",{}).get("taker_pct_default" if taker else "maker_pct_default", 0.002))
    return dflt

def gas_overhead_usd(sym: str) -> float:
    import yaml
    base = yaml.safe_load(open("config/feeds.yaml","r",encoding="utf-8").read())
    return float(base.get("fees",{}).get("gas_overhead_usd",{}).get(sym, 0.0))

def network_fee_estimates() -> Dict[str, float]:
    """
    Returns rough network fee in USD for BTC/XRP (best-effort).
    """
    out = {}
    try:
        r = httpx.get("https://mempool.space/api/v1/fees/recommended", timeout=10)
        if r.status_code == 200:
            sats_vb = r.json().get("halfHourFee") or r.json().get("fastestFee")
            # crude tx size 140 vB, BTCUSD ~ via coingecko
            px = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                           params={"ids":"bitcoin","vs_currencies":"usd"}, timeout=10).json()["bitcoin"]["usd"]
            fee_btc = (sats_vb * 140) / 1e8
            out["BTC-USD"] = float(fee_btc * px)
    except Exception:
        pass
    try:
        # XRP network fee (drops), say 12 drops baseline; fetch from rippled public
        r = httpx.get("https://s1.ripple.com:51234/", json={"method":"fee","params":[{}]}, timeout=10)
        if r.status_code == 200:
            d = r.json()["result"]["drops"]["open_ledger_fee"]
            # 1 XRP = 1,000,000 drops; price via gecko
            px = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                           params={"ids":"ripple","vs_currencies":"usd"}, timeout=10).json()["ripple"]["usd"]
            xrp = int(d)/1_000_000
            out["XRP-USD"] = float(xrp * px)
    except Exception:
        pass
    return out
