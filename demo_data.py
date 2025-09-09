from datetime import datetime, timedelta
import random

random.seed(42)

EXCHANGES = ["Coinbase", "Kraken", "Binance", "Bitstamp", "Bitfinex"]

def fake_prices():
    base = 55000.0
    out = []
    for ex in EXCHANGES:
        jitter = random.uniform(-800, 800)
        out.append({"exchange": ex, "symbol": "BTC-USD", "price": round(base + jitter, 2)})
    return out

def fake_balances():
    assets = [
        {"asset": "BTC", "amount": 0.12345678},
        {"asset": "USDC", "amount": 1500.0},
        {"asset": "ETH", "amount": 2.5},
    ]
    return assets

def fake_price_series(points=50):
    base = 55000.0
    now = datetime.utcnow()
    data = []
    val = base
    for i in range(points):
        val += random.uniform(-150, 150)
        data.append({"t": (now - timedelta(minutes=(points-i))).isoformat(), "price": round(val, 2)})
    return data
