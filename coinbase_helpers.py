import os, math
from dotenv import load_dotenv

# We will try the official SDK first (JWT/ECDSA for Advanced Trade v3).
# Fallbacks (old HMAC/ed25519 code paths) removed for clarity to stop 401 thrash.

def get_coinbase_balances(timeout=20.0):
    """
    Returns (list[{'asset': 'BTC', 'available': float}], error|None) using
    Coinbase Advanced API via official SDK (coinbase-advanced-py).
    """
    load_dotenv()

    try:
        from coinbase.rest import RESTClient
    except Exception as e:
        return [], f"Missing coinbase-advanced-py: {e}"

    api_key = os.getenv("COINBASE_CDP_API_KEY")
    secret_file = os.getenv("COINBASE_CDP_API_SECRET_FILE")

    if not api_key:
        return [], "COINBASE_CDP_API_KEY not set"
    if not secret_file or not os.path.exists(secret_file):
        return [], f"Secret PEM not found at {secret_file or '(unset)'}"

    try:
        with open(secret_file, "r") as f:
            api_secret = f.read()
    except Exception as e:
        return [], f"Cannot read PEM: {e}"

    try:
        client = RESTClient(api_key=api_key, api_secret=api_secret, timeout=timeout)
        # SDK handles JWT; we just call the accounts endpoint
        resp = client.get_accounts()
    except Exception as e:
        return [], f"Coinbase SDK error: {e}"

    # Normalize to [{'asset': 'BTC', 'available': float}, ...]
    rows = []
    data = getattr(resp, "accounts", None) or getattr(resp, "data", None) or []
    # If SDK returns a dataclass-like object, convert it
    try:
        # Some versions have to_dict(); otherwise treat as plain dict
        d = resp.to_dict() if hasattr(resp, "to_dict") else resp
        data = d.get("accounts", data) if isinstance(d, dict) else data
    except Exception:
        pass

    for a in data:
        if hasattr(a, "to_dict"):
            a = a.to_dict()
        cur = (a.get("currency") or a.get("asset") or a.get("account_currency") or "").upper()
        bal = a.get("available_balance")
        if isinstance(bal, dict):
            bal = bal.get("value")
        try:
            val = float(bal or 0.0)
        except Exception:
            val = 0.0
        rows.append({"asset": cur, "available": val})

    return rows, None
