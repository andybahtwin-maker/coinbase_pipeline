# Coinbase Pipeline — Trading Control Panel

A lightweight data pipeline and dashboard that tracks live crypto metrics from Coinbase and Binance, simulates trading, and visualizes account performance in real time.

---

## 🧭 Overview

This project connects to the **Coinbase API** (and optionally **Binance**) to show live prices, account balances, spreads, and simulated trades — all in one control panel.

### Core Features
- **Hero Metrics:** Total USD balance, BTC/USD @ Coinbase, Spread vs Binance ($ / %)
- **Live Candlestick Chart:** Real-time Coinbase price feed
- **Balances Table:** Top 10 assets with clean formatting
- **Interactive Tabs:**
  - *Balances* – Portfolio overview  
  - *Trade (Simulated)* – Sandbox for testing strategies  
  - *Arbitrage & Fees* – Spread and fee calculations  
  - *AI Summary* – GPT-based performance commentary  
  - *Env Health* – Checks API connectivity and data freshness  
  - *Notion Snapshot* – Pulls portfolio notes from Notion

---

## ⚙️ Quick Start

Clone the repo and run everything with one command:
```bash
./run_all.sh

    ⚠️ Keep your real .env file in secrets/.env — never commit secrets.

🧠 Tech Stack

    Python — data fetching, ETL, and trade simulation

    Streamlit — interactive dashboard interface

    Pandas / NumPy — data transformation

    Coinbase + Binance APIs — live market data

    OpenAI (optional) — AI-driven portfolio summaries

    Notion API — pull portfolio notes or snapshots

    Shell scripts — orchestrate local startup

🔒 Security

For local use only — store all credentials securely in secrets/.env.
Do not commit secrets to version control.
📄 License

Licensed under the MIT License.
