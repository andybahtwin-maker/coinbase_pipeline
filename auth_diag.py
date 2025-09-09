import base64, hashlib, hmac, json, time, os
import httpx

KEY    = os.getenv("COINBASE_API_KEY","").strip()
SECRET = os.getenv("COINBASE_API_SECRET","").strip()
PASS   = os.getenv("COINBASE_API_PASSPHRASE","").strip()

def sign(secret_b64: str, ts: str, method: str, path: str, body: str=""):
    try:
        secret = base64.b64decode(secret_b64)
    except Exception:
        secret = secret_b64.encode()
    prehash = f"{ts}{method.upper()}{path}{body}".encode()
    sig = hmac.new(secret, prehash, hashlib.sha256).digest()
    return base64.b64encode(sig).decode()

def try_call(base, path, body=""):
    ts = str(int(time.time()))
    headers = {
        "CB-ACCESS-KEY": KEY,
        "CB-ACCESS-PASSPHRASE": PASS,
        "CB-ACCESS-TIMESTAMP": ts,
        "CB-ACCESS-SIGN": sign(SECRET, ts, "GET", path, body),
        "User-Agent": "rafael-coinbase-pipeline",
        "Accept": "application/json",
    }
    try:
        with httpx.Client(timeout=20) as c:
            r = c.get(base+path, headers=headers)
        out = {
            "base": base,
            "path": path,
            "status": r.status_code,
            "www-authenticate": r.headers.get("WWW-Authenticate",""),
        }
        try:
            j = r.json()
            out["json_keys"] = list(j.keys())
            out["message"] = j.get("message") or j.get("reason") or j.get("error") or ""
        except Exception:
            out["text"] = r.text[:200]
        return out
    except Exception as e:
        return {"base": base, "path": path, "error": str(e)}

def server_time():
    # Exchange has a /time endpoint we can use to measure skew
    try:
        with httpx.Client(timeout=10) as c:
            r = c.get("https://api.exchange.coinbase.com/time")
        j = r.json()
        return float(j["epoch"])
    except Exception:
        return None

def main():
    # 0) sanity on env
    print("Have key:", bool(KEY), "secret:", bool(SECRET), "passphrase:", bool(PASS))

    # 1) clock skew
    srv = server_time()
    if srv is None:
        print("Server time: unavailable")
    else:
        skew = abs(srv - time.time())
        print(f"Clock skew vs Coinbase: {skew:.1f}s")

    tests = [
        ("https://api.coinbase.com", "/api/v3/brokerage/accounts"),
        ("https://api.exchange.coinbase.com", "/accounts"),
    ]
    for base, path in tests:
        res = try_call(base, path)
        print(json.dumps(res, indent=2))

if __name__ == "__main__":
    main()
