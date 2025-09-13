from typing import Dict, Tuple, Callable, Optional
import importlib

from orchestrate_feeds import (
    load_config,
    collect_prices,
    compute_spreads,
    compute_net_profit_usd,
)

# --- env autoload (dotenv) + compatibility mapping ---
import os
try:
    from dotenv import load_dotenv
    load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"))
except Exception:
    pass
# Map legacy names if canonical ones are missing
if not os.environ.get("NOTION_TOKEN") and os.environ.get("NOTION_API_KEY"):
    os.environ["NOTION_TOKEN"] = os.environ["NOTION_API_KEY"]
if not os.environ.get("NOTION_PARENT_PAGE_ID") and os.environ.get("NOTION_PAGE_ID"):
    os.environ["NOTION_PARENT_PAGE_ID"] = os.environ["NOTION_PAGE_ID"]
# --- end env autoload ---
PUBLISH_FN_CANDIDATES = [
    "publish_metrics",
    "publish",
    "publish_boxes",
    "update_page",
    "upsert_database",
]

def build_metrics() -> Dict[str, Tuple[float, bool]]:
    cfg = load_config()
    symbols = cfg.get("symbols", [])
    providers_cfg = cfg.get("providers", {})
    gas_fee_usd = float(cfg.get("fees", {}).get("gas_fee_usd", 0.0))

    provider_prices = collect_prices(symbols, providers_cfg)
    spreads = compute_spreads(symbols, provider_prices)

    metrics = dict(spreads)
    metrics["Gas Fee (USD)"] = (gas_fee_usd, True)
    metrics["Net Profit (USD)"] = (compute_net_profit_usd(spreads, gas_fee_usd), False)
    return metrics

def run():
    metrics = build_metrics()
    try:
        np = importlib.import_module("notion_publish")
    except Exception as e:
        raise SystemExit(f"❌ Could not import your notion_publish module: {e}")

    # Prefer a function that accepts "metrics"
    for name in PUBLISH_FN_CANDIDATES:
        fn = getattr(np, name, None)
        if callable(fn):
            try:
                fn(metrics)
                print(f"✅ Called notion_publish.{name}(metrics)")
                return
            except TypeError:
                # signature mismatch, try no-arg call
                try:
                    fn()
                    print(f"✅ Called notion_publish.{name}()")
                    return
                except Exception as e:
                    raise SystemExit(f"❌ notion_publish.{name} failed: {e}")

    # Fallback: main()
    main_fn = getattr(np, "main", None)
    if callable(main_fn):
        main_fn()
        print("✅ Called notion_publish.main()")
        return

    raise SystemExit("❌ No suitable publisher found in notion_publish.py.")

if __name__ == "__main__":
    run()