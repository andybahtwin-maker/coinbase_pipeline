import json, sys
from coinbase_helpers import _headers_for, _choose_creds

BASE = "https://api.coinbase.com"
PATH = "/api/v3/brokerage/accounts"

creds = _choose_creds()
if creds["type"] == "none":
    print("No JSON key found. Put cdp_api_key.json in project root.")
    sys.exit(1)

import httpx
try:
    h = _headers_for(creds, "GET", PATH, "")
    with httpx.Client(timeout=20, headers=h) as c:
        r = c.get(BASE + PATH)
        print("HTTP", r.status_code)
        # print server reason so we know _why_ it's 401
        print("Body:", r.text[:1000])
        # headers helpful if it's an allowlist/portfolio thing
        print("Response headers:", dict(r.headers))
except Exception as e:
    print("ERROR:", e)
