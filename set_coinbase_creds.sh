#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/coinbase_pipeline

# activate venv
source .venv/bin/activate

# overwrite .env with correct keys
cat > .env <<'ENV'
CB_API_KEY=c2e13318-3d03-4b68-8b17-e0437154ad3b
CB_API_SECRET=YyPYzf0SLJVA6wq9t3DcVzyOXiDr6H+dOGC/KqwDWEPoAfb+GQb5eOVhqSQYhNI4FId2bvgp2fJDhtXgSNaY6g==
CB_API_PASSPHRASE=your_passphrase_here
COINBASE_API_BASE=https://api.coinbase.com
LOG_LEVEL=INFO
ENV

# also write JSON for Coinbase SDKs that want it
cat > cdp_api_key.json <<'JSON'
{
  "apiKey": "c2e13318-3d03-4b68-8b17-e0437154ad3b",
  "apiSecret": "YyPYzf0SLJVA6wq9t3DcVzyOXiDr6H+dOGC/KqwDWEPoAfb+GQb5eOVhqSQYhNI4FId2bvgp2fJDhtXgSNaY6g==",
  "apiPassphrase": "your_passphrase_here"
}
JSON

# reload env vars into shell
set -a
. .env
set +a

# make sure Python can import dashboard
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"

# restart Streamlit
exec streamlit run dashboard/simple_app.py
