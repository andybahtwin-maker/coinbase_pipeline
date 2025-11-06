# Coinbase Pipeline — Trading Control Panel

A lightweight data pipeline and dashboard that tracks live crypto metrics from Coinbase and Binance, simulates trading, and visualizes account performance in real time.

---

## 🧭 Overview

This tool connects to the Coinbase API (and optionally Binance) to display live price data, account balances, spreads, and simulated trading performance — all in a single control panel.

**Core features:**
- 📊 **Hero Metrics:**  
  Real-time *Total USD balance*, *BTC/USD @ Coinbase*, and *Spread vs Binance* (both $ and %)
- 📈 **Live Candlestick Chart:**  
  Displays price movement on Coinbase in near-real-time
- 💰 **Balances Table:**  
  Shows top 10 holdings, formatted for readability
- 🧩 **Interactive Tabs:**  
  - **Balances:** Asset summary and value tracking  
  - **Trade (Simulated):** Sandbox for testing buy/sell logic  
  - **Arbitrage & Fees:** View exchange spreads and fee calculations  
  - **AI Summary:** Optional GPT summary of performance trends  
  - **Env Health:** Quick check of API connections and data freshness  
  - **Notion Snapshot:** Integrates portfolio notes from a Notion page

---

## ⚙️ Quick Start

Clone the repo and launch all services with:
```bash
./run_all.sh

Keep your environment variables secure:

secrets/.env

(Never commit secrets to GitHub.)
🧠 Tech Stack

    Python — for data fetching, ETL, and simulation logic

    Streamlit — for interactive dashboard UI

    Pandas / NumPy — for data processing

    Coinbase + Binance APIs — for live market data

    OpenAI (optional) — for AI summaries

    Notion API — for pulling notes/snapshots

    Shell scripts (.sh) — to orchestrate services and keep local setup one-command simple

🚀 Future Extensions

    ✅ Real trade execution (paper trading or sandbox mode)

    ✅ Alert system for spread thresholds

    ✅ Multi-exchange support (Kraken, KuCoin)

    ✅ Historical performance tracking

🔒 Security

This project is designed for local use only.
Always store credentials in secrets/.env, never in public repos.
📄 License

MIT License – free to use, fork, and modify.


---

## 💬 Plain-English Talking Points (for Non-Coders)

**What this project does:**  
It’s a personal trading dashboard that connects to Coinbase and Binance to show live crypto prices, balances, and differences between exchanges. It’s like a *command center* for your crypto — showing what you have, what things are worth, and where you could trade smarter.

**Why it matters:**  
It shows how you can combine real-time APIs, automation, and AI into a single tool. This kind of setup is common in fintech, data engineering, and AI-assisted trading.

**How it works:**  
You run one command (`./run_all.sh`), and the system:
1. Pulls data from Coinbase and Binance  
2. Cleans and formats it using Python  
3. Displays it in a Streamlit web app  
4. Lets you switch between panels for balance tracking, simulated trades, and performance summaries  

**Who it’s for:**  
Anyone learning about APIs, crypto data pipelines, or how to visualize live financial data in an easy-to-use dashboard.
