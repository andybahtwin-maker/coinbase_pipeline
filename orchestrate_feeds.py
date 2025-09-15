import os
from typing import List, Dict, Any
from feeds.coinbase_public import assemble_pair_metrics
from visual_display import display_metrics

def _pairs() -> List[str]:
    raw = os.getenv("PAIRS", "BTC-USD,ETH-USD,XRP-USD")
    return [p.strip().upper() for p in raw.split(",") if p.strip()]

def _fee(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except Exception:
        return default

def collect_metrics() -> List[Dict[str, Any]]:
    fee_buy = _fee("FEE_BUY_TAKER", 0.006)   # 0.6% default (retail-ish)
    fee_sell = _fee("FEE_SELL_TAKER", 0.006) # 0.6% default
    out = []
    for pair in _pairs():
        out.append(assemble_pair_metrics(pair, fee_buy, fee_sell))
    return out

def main():
    rows = collect_metrics()
    display_metrics(rows)

if __name__ == "__main__":
    main()
