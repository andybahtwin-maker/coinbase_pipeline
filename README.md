# Coinbase Pipeline — Trading Control Panel

**What it shows (portfolio-ready):**
- Hero metrics: **Total USD balance**, **BTC/USD @ Coinbase**, **Spread vs Binance ($ / %)**  
- Live **candlestick** (Coinbase)  
- **Balances** table (top 10, formatted)  
- Tabs: **Balances**, **Trade** (simulated by default), **Arbitrage/Fees**, **AI Summary**, **Env Health**, **Notion Snapshot**

## Quick Start
```bash
./run_all.sh
```

## Configure (local only — never commit real secrets)
Create `.env` (or `secrets/.env`) with:
```bash
CB_API_KEY=...
CB_API_SECRET=...
CB_API_PASSPHRASE=...
ALLOW_LIVE_TRADES=no
DEMO_MODE=no
LOG_LEVEL=INFO
```
See `.env.example` for the full list.

## Safety
- Secrets are ignored by `.gitignore` (and optional pre-commit guard).
- Trading is **SIMULATED** by default; set `ALLOW_LIVE_TRADES=yes` to enable live orders.
