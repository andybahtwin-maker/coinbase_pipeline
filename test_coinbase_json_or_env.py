from coinbase_helpers import load_coinbase_creds, get_coinbase_balances
print("Auth path:", load_coinbase_creds())
rows, err = get_coinbase_balances()
if err:
    print("ERROR:", err)
else:
    print("OK. Example:", rows[:3])
