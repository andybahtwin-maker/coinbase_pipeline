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
