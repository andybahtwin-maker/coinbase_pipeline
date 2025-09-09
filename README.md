# Coinbase Pipeline Dashboard

A **Streamlit dashboard** and supporting scripts for monitoring Bitcoin across exchanges and retrieving your **Coinbase Advanced Trade balances**. Designed as a portfolio-quality project to showcase Python, API integration, and workflow automation.

---

## ✨ Features
- 📊 **Live BTC prices** from Coinbase, Kraken, Binance, Bitstamp, and Bitfinex  
- 💰 **Coinbase balances** via Advanced Trade API (ECDSA or HMAC keys)  
- 📧 **One-click email snapshot** with CSV attachments (balances + prices)  
- 🔒 Secure handling of secrets using `.env` or `cdp_api_key.json`  
- 🚀 Deployable Streamlit app with modern, responsive UI  

---

## 🛠️ Setup

### 1. Clone & enter project
```bash
git clone https://github.com/andybahtwin-maker/coinbase_pipeline.git
cd coinbase_pipeline
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
./run_app.sh
