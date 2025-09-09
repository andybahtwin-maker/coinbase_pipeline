#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv >/dev/null 2>&1 || true
source .venv/bin/activate
pip -q install -U pip >/dev/null
pip -q install -r requirements.txt >/dev/null

python - <<'PY'
import time, pandas as pd
from coinbase_helpers import get_coinbase_balances
from exchanges import fetch_all_prices

print("== Coinbase balances ==")
rows, err = get_coinbase_balances()
if err:
    print("UNAVAILABLE ->", err)
else:
    btc = [r for r in rows if (r.get("asset","") or "").upper()=="BTC"]
    amt = sum(float(r.get("available",0) or 0) for r in btc) if btc else 0.0
    print(f"OK -> BTC available: {amt}")

print("\n== Public BTC prices ==")
prices = fetch_all_prices()
ok = [p for p in prices if p.get("price") is not None]
print(f"Got {len(ok)} prices")
ts = time.strftime("%Y%m%d-%H%M%S")
pd.DataFrame(prices).to_csv(f"snapshots/btc_prices_{ts}.csv", index=False)
print(f"Wrote snapshots/btc_prices_{ts}.csv")
PY
