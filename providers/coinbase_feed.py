from typing import Dict, List
# TODO: replace with your real Coinbase call
def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    return {s: 60000.0 if s.startswith("BTC") else 2500.0 if s.startswith("ETH") else 0.50 for s in symbols}
