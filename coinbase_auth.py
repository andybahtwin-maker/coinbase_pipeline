import os, json, time, hmac, hashlib, base64
from pathlib import Path
from dotenv import load_dotenv

PROJECT_DIR = Path(__file__).resolve().parent
JSON_PATH = PROJECT_DIR / "cdp-api-key.json"

def _load_from_json():
    if JSON_PATH.exists():
        data = json.loads(JSON_PATH.read_text())
        # common Coinbase export keys
        k = data.get("key") or data.get("apiKey") or data.get("api_key")
        s = data.get("secret") or data.get("apiSecret") or data.get("api_secret")
        p = data.get("passphrase") or data.get("apiPassphrase") or data.get("pass")
        if k and s and p:
            return k.strip(), s.strip(), p.strip()
    return None

def _load_from_env():
    load_dotenv()  # will pick up .env if present
    k = os.getenv("COINBASE_API_KEY", "").strip()
    s = os.getenv("COINBASE_API_SECRET", "").strip()
    p = os.getenv("COINBASE_API_PASSPHRASE", "").strip()
    if k and s and p:
        return k, s, p
    return None

def get_coinbase_creds():
    """Prefer cdp-api-key.json; fallback to .env. Return (key, secret, passphrase) or (None,...)."""
    j = _load_from_json()
    if j: return j
    e = _load_from_env()
    if e: return e
    return (None, None, None)

def sign_advanced_trade(secret_b64: str, timestamp: str, method: str, path: str, body: str=""):
    """
    Coinbase Advanced Trade signature:
      signature = base64( HMAC_SHA256( base64_decode(secret), timestamp + method + path + body ) )
    Accepts raw secret too (if user pasted non-b64).
    """
    try:
        secret = base64.b64decode(secret_b64)
    except Exception:
        secret = (secret_b64 or "").encode()
    msg = f"{timestamp}{method.upper()}{path}{body}".encode()
    return base64.b64encode(hmac.new(secret, msg, hashlib.sha256).digest()).decode()
