from __future__ import annotations
import importlib, time, json
from typing import Dict, List, Tuple
from pathlib import Path
import yaml
from analytics.fees import exchange_fee_pct, gas_overhead_usd, network_fee_estimates

def load_config(path="config/feeds.yaml") -> dict:
    with open(path,"r",encoding="utf-8") as f:
        return yaml.safe_load(f)

def _load_fn(module_path: str, fn_name: str):
    mod = importlib.import_module(module_path)
    return getattr(mod, fn_name)

def collect_all_prices(symbols: List[str], providers_cfg: dict) -> Dict[str, Dict[str, float]]:
    book: Dict[str, Dict[str, float]] = {}
    for name, meta in providers_cfg.items():
        if not meta.get("enabled", False):
            continue
        fn = _load_fn(meta["module"], meta["fn"])
        prices = fn(symbols)
        if prices:
            book[name] = prices
    return book

def effective_price(raw: float, ex_name: str, sym: str, taker=True) -> float:
    pct = exchange_fee_pct(ex_name, taker=taker)
    gas = gas_overhead_usd(sym)
    # buy: pay price * (1+pct) + gas_per_unit; sell: receive price * (1-pct) - gas_per_unit
    # we'll return a tuple in caller
    return pct, gas

def analyze(symbols: List[str], providers_cfg: dict, notional=10_000.0):
    prices = collect_all_prices(symbols, providers_cfg)
    gas_live = network_fee_estimates()  # override gas if available
    metrics: Dict[str, Tuple[float,bool]] = {}
    tables = {}  # per-symbol breakdown

    for sym in symbols:
        # build per-provider effective buy/sell
        rows = []
        for ex, mapping in prices.items():
            if sym not in mapping: continue
            raw = mapping[sym]
            pct_taker = exchange_fee_pct(ex, taker=True)
            pct_maker = exchange_fee_pct(ex, taker=False)
            gas = gas_live.get(sym, gas_overhead_usd(sym))
            buy_eff  = raw * (1 + pct_taker) + gas  # assume taker buy
            sell_eff = raw * (1 - pct_taker) - gas  # assume taker sell
            rows.append({
                "exchange": ex,
                "raw": raw,
                "buy_eff": buy_eff,
                "sell_eff": sell_eff,
                "pct_taker": pct_taker,
                "gas_usd": gas,
            })

        if len(rows) < 2:
            continue

        # best route
        best_buy  = min(rows, key=lambda r: r["buy_eff"])
        best_sell = max(rows, key=lambda r: r["sell_eff"])
        spread_abs = best_sell["sell_eff"] - best_buy["buy_eff"]
        spread_pct = spread_abs / best_buy["buy_eff"] if best_buy["buy_eff"] else 0.0
        gross = notional * spread_pct
        net   = gross  # already fee-adjusted by using effective prices
        metrics[f"{sym} Net Spread % (fees incl)"] = (spread_pct, False)
        metrics[f"{sym} Est Profit @${int(notional)} (fees incl)"] = (net, False)
        metrics[f"{sym} Gas Fee (USD)"] = (best_buy["gas_usd"], True)

        tables[sym] = {
            "best_buy_ex": best_buy["exchange"],
            "best_sell_ex": best_sell["exchange"],
            "rows": rows,
            "spread_abs": spread_abs,
            "spread_pct": spread_pct,
        }

    # persist history for plots
    tdir = Path("logs/feeds"); tdir.mkdir(parents=True, exist_ok=True)
    Path("logs/feeds/last_prices.json").write_text(json.dumps(prices, indent=2), encoding="utf-8")
    Path("logs/feeds/last_tables.json").write_text(json.dumps(tables, indent=2), encoding="utf-8")
    return metrics, tables
