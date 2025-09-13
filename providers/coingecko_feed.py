from typing import Dict, List
# TODO: replace with your real CoinGecko call
def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    return {s: 60010.0 if s.startswith("BTC") else 2498.0 if s.startswith("ETH") else 0.49 for s in symbols}
