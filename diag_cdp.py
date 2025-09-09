#!/usr/bin/env python3
from coinbase_helpers import get_coinbase_balances
rows, err = get_coinbase_balances()
print("OK" if not err else "ERROR", "-"*8)
if err:
    print(err)
else:
    print(rows[:3])
