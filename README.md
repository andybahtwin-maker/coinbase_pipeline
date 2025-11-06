# 💹 Coinbase Pipeline — Trading Control Panel

Coinbase Pipeline is a **lightweight data pipeline and dashboard** that tracks live crypto metrics from **Coinbase** and **Binance**, simulates trading, and visualizes account performance in real time.

It’s designed as a **personal trading analytics suite**, integrating your local scripts, APIs, and AI commentary into a single control panel that runs anywhere — locally or in the cloud.

---

## 🚀 Quick Overview

```plain text
Coinbase Pipeline is not just a dashboard.
It’s a real-time analytics engine for crypto data — fetching, transforming, visualizing, and simulating trades automatically.

Think of it as a self-hosted Bloomberg Terminal for Coinbase power users.

📁 Project Structure

coinbase_pipeline/
├── README.md                 # Documentation (this file)
├── .gitignore                # Ignore data, secrets, caches
├── run_all.sh                # Orchestrate the full pipeline
├── app.py                    # Streamlit dashboard entrypoint
├── fetch_data.py             # API connection + data fetching
├── process_data.py           # Data cleaning + ETL transformations
├── simulate_trades.py        # Trading logic + sandbox simulation
├── notion_sync.py            # Optional Notion integration
├── utils/                    # Helper modules and formatting
│   ├── api_utils.py
│   ├── chart_utils.py
│   ├── formatters.py
│   └── secrets_loader.py
├── data/                     # Local cache and historical data
│   └── prices.csv
├── secrets/                  # Store .env and API keys (excluded from git)
│   └── .env
└── assets/                   # Logos, icons, or example charts

⚙️ Installation
1. Clone the repo

git clone https://github.com/your-username/coinbase_pipeline.git
cd coinbase_pipeline

2. Set up your environment

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

3. Add your secrets

Create a file at secrets/.env:

COINBASE_API_KEY=your_key_here
COINBASE_API_SECRET=your_secret_here
BINANCE_API_KEY=optional_key_here
OPENAI_API_KEY=optional_key_here
NOTION_API_KEY=optional_key_here

(This file is ignored by Git — keep it private.)
4. Run everything

chmod +x run_all.sh
./run_all.sh

This starts the Streamlit dashboard and begins pulling live market data.
🧠 How It Works
Stage	Description
1. Data Fetching	fetch_data.py pulls live prices, balances, and order book data from Coinbase & Binance APIs
2. ETL Processing	process_data.py cleans and formats data for analytics
3. Simulation Engine	simulate_trades.py models trades, spread, and slippage in real time
4. Visualization	app.py (Streamlit) displays charts, metrics, and tables
5. AI Commentary	(Optional) GPT API analyzes and summarizes performance
6. Sync & Storage	Data snapshots saved to /data, logs to /logs, and notes synced to Notion
🪄 Features

    📈 Live Crypto Dashboard – Auto-updating prices from Coinbase & Binance

    💰 Hero Metrics – Total USD balance, BTC/USD price, spread vs Binance

    🪙 Balances Table – Clean portfolio overview (top 10 assets)

    🧮 Simulated Trading – Sandbox for strategy testing

    🔁 Arbitrage Analysis – Real-time spread & fee tracking

    🧠 AI Summary – GPT commentary on performance and risk

    🩺 Env Health Checks – Monitor data freshness & API connectivity

    🗒️ Notion Integration – Optional notes sync and daily snapshots

🧰 Example Usage

# Launch full dashboard
./run_all.sh

# Or run Streamlit directly
streamlit run app.py

# Refresh data manually
python fetch_data.py

🧩 Integrations

    Coinbase API — Live trading and balance data

    Binance API — Price comparison and spread tracking

    OpenAI API — Optional AI summaries

    Notion API — Pull or push portfolio snapshots

    Streamlit — Dashboard interface

Each integration is optional — activate what you need via .env.
💡 Example Scenarios

    Portfolio Overview: Monitor all crypto holdings and live prices in one place.

    Trade Simulation: Backtest strategies and visualize hypothetical outcomes.

    Arbitrage Tracking: Identify spreads between Coinbase and Binance in real time.

    AI Reporting: Let GPT summarize daily wins/losses and performance factors.

    Notion Sync: Keep personal notes or trade logs in sync automatically.

🧑‍💻 Development Notes

    Language: Python 3.11+

    Frameworks: Streamlit + Pandas + NumPy

    Logging: Local CSV and timestamped logs

    Secrets: Stored safely in secrets/.env

    AI: Optional GPT/OpenAI integration

    Visualization: Real-time Streamlit dashboard

🔗 Related Projects

    Jarvis

    — AI-powered terminal automation framework powering this data pipeline’s orchestration layer.

🤝 Contributing

Contributions are welcome!
Fork the repo, extend a module, or add new API integrations under /utils.
🪪 License

MIT License — free to modify, extend, and deploy.
✨ Tip

Coinbase Pipeline turns your trading data into an interactive intelligence layer — not just numbers, but insights.
Pair it with Jarvis
to automate your market research end-to-end.
