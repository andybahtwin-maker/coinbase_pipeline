import time, httpx
from coinbase_auth import get_coinbase_creds, sign_advanced_trade

key, secret, passphrase = get_coinbase_creds()
assert key and secret and passphrase, "Missing creds (cdp-api-key.json or .env)"
base="https://api.coinbase.com"; path="/api/v3/brokerage/accounts"; ts=str(int(time.time()))
h={"CB-ACCESS-KEY":key,"CB-ACCESS-PASSPHRASE":passphrase,"CB-ACCESS-TIMESTAMP":ts,"CB-ACCESS-SIGN":sign_advanced_trade(secret,ts,"GET",path,""),"User-Agent":"rafael-coinbase-pipeline"}
with httpx.Client(timeout=20, headers=h) as c:
    r=c.get(base+path)
    print("HTTP", r.status_code)
    print((r.text or "")[:300])
