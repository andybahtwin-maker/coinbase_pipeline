import json
from pathlib import Path
from typing import Dict, List, Tuple
import importlib

try:
    import yaml  # pyyaml
except ImportError:
    raise SystemExit("Missing PyYAML. Install with: .venv/bin/pip install pyyaml")

from visual_display import display_metrics

def load_config(path: str = "config/feeds.yaml") -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def load_provider(module_path: str, fn_name: str):
    import importlib, importlib.util, sys, os
    module_path = (module_path or "").strip()
    # strip accidental leading dots
    while module_path.startswith("."):
        module_path = module_path[1:]
    # try file-location import if looks like a path
    if os.path.sep in module_path and os.path.exists(module_path):
        spec = importlib.util.spec_from_file_location("dynamic_provider", module_path)
        mod = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(mod)
    else:
        # ensure repo root is on sys.path for 'providers.*'
        if os.getcwd() not in sys.path:
            sys.path.insert(0, os.getcwd())
        # collapse accidental long prefixes like home.user.repo.providers.x
        parts = module_path.replace("/", ".").split(".")
        if "providers" in parts:
            i = parts.index("providers")
            module_path = ".".join(parts[i:i+2]) if len(parts) >= i+2 else "providers"
        # strip .py suffix if present
        if module_path.endswith(".py"):
            module_path = module_path[:-3]
        mod = importlib.import_module(module_path)
    fn = getattr(mod, fn_name)
    return fn

def collect_prices(symbols: List[str], providers_cfg: dict) -> Dict[str, Dict[str, float]]:
    out: Dict[str, Dict[str, float]] = {}
    for name, meta in providers_cfg.items():
        if not meta.get("enabled", False):
            continue
        fn = load_provider(meta["module"], meta["fn"])
        prices = fn(symbols)
        out[name] = prices
    return out

def compute_spreads(symbols: List[str], provider_prices: Dict[str, Dict[str, float]]) -> Dict[str, Tuple[float, bool]]:
    metrics: Dict[str, Tuple[float, bool]] = {}
    for sym in symbols:
        quotes = []
        for prov, mapping in provider_prices.items():
            if sym in mapping:
                quotes.append((prov, mapping[sym]))
        if len(quotes) < 2:
            continue
        prices = [p for _, p in quotes]
        best_buy = min(prices)
        best_sell = max(prices)
        spread_pct = (best_sell - best_buy) / best_buy if best_buy else 0.0
        label = f"{sym} Spread %"
        metrics[label] = (spread_pct, False)
    return metrics

def compute_net_profit_usd(spreads: Dict[str, Tuple[float, bool]], gas_fee_usd: float) -> float:
    if not spreads:
        return -gas_fee_usd
    max_spread = max(v for (v, is_fee) in spreads.values() if not is_fee) if spreads else 0.0
    notional = 10000.0  # adjust to your model
    gross = notional * max_spread
    return gross - gas_fee_usd

def main():
    cfg = load_config()
    symbols = cfg.get("symbols", [])
    providers_cfg = cfg.get("providers", {})
    gas_fee_usd = float(cfg.get("fees", {}).get("gas_fee_usd", 0.0))

    provider_prices = collect_prices(symbols, providers_cfg)

    Path("logs/feeds").mkdir(parents=True, exist_ok=True)
    Path("logs/feeds/last_provider_prices.json").write_text(
        json.dumps(provider_prices, indent=2), encoding="utf-8"
    )

    spreads = compute_spreads(symbols, provider_prices)

    metrics = dict(spreads)
    metrics["Gas Fee (USD)"] = (gas_fee_usd, True)
    net_profit = compute_net_profit_usd(spreads, gas_fee_usd)
    metrics["Net Profit (USD)"] = (net_profit, False)

    display_metrics(metrics)

if __name__ == "__main__":
    main()
