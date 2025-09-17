#!/usr/bin/env bash
set -euo pipefail

echo "==> Restarting Coinbase Pipeline app..."

# Clean caches
rm -rf .cache __pycache__ .pytest_cache .streamlit/logs

# Ensure venv exists
if [ ! -d ".venv" ]; then
  echo "==> Creating fresh venv..."
  python3 -m venv .venv
fi

source .venv/bin/activate

# Upgrade pip + install deps
pip install --upgrade pip wheel
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi

# Run Streamlit app
exec streamlit run dashboard/simple_app.py --server.port=8501 --server.headless=true
