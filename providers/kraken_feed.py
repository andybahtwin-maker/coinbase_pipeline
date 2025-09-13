from typing import Dict, List
def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    return {s: 59980.0 if s.startswith("BTC") else 2502.0 if s.startswith("ETH") else 0.51 for s in symbols}
