import json, os, sys
from coinbase_helpers import get_coinbase_balances
from exchanges import fetch_all_prices

def main():
    print("[2/5] Checking Coinbase balances…")
    rows, err = get_coinbase_balances()
    if err:
        print("    Coinbase: UNAVAILABLE ->", err)
    else:
        btc = [r for r in rows if r.get("asset","").upper()=="BTC"]
        amt = sum(float(r.get("available",0) or 0) for r in btc) if btc else 0.0
        print(f"    Coinbase: OK -> BTC available: {amt}")

    print("[3/5] Fetching public BTC prices…")
    prices = fetch_all_prices()
    ok = [p for p in prices if p.get("price") is not None]
    print(f"    Prices: {len(ok)} exchanges returned a price")

    # Save a CSV snapshot (no email, just local file)
    import pandas as pd, time, io, pathlib
    ts = time.strftime("%Y%m%d-%H%M%S")
    out = pathlib.Path("snapshots"); out.mkdir(exist_ok=True)
    pd.DataFrame(prices).to_csv(out/f"btc_prices_{ts}.csv", index=False)
    print(f"[4/5] Wrote CSV snapshot -> snapshots/btc_prices_{ts}.csv")

    print("[5/5] DONE. If balances say UNAVAILABLE, it’s an auth/permission/portfolio issue, not code.")
if __name__ == "__main__":
    main()
