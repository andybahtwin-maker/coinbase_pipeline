#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/coinbase_pipeline

# venv
if [ ! -d .venv ]; then python3 -m venv .venv; fi
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools >/dev/null
[ -f requirements.txt ] && pip install -r requirements.txt >/dev/null || true

# overwrite .env with Coinbase creds
cat > .env <<'ENV'
CB_API_KEY=c2e13318-3d03-4b68-8b17-e0437154ad3b
CB_API_SECRET=YyPYzf0SLJVA6wq9t3DcVzyOXiDr6H+dOGC/KqwDWEPoAfb+GQb5eOVhqSQYhNI4FId2bvgp2fJDhtXgSNaY6g==
CB_API_PASSPHRASE=auto_generated_passphrase
COINBASE_API_BASE=https://api.coinbase.com
LOG_LEVEL=INFO
ENV

# write JSON too
cat > cdp_api_key.json <<'JSON'
{
  "apiKey": "c2e13318-3d03-4b68-8b17-e0437154ad3b",
  "apiSecret": "YyPYzf0SLJVA6wq9t3DcVzyOXiDr6H+dOGC/KqwDWEPoAfb+GQb5eOVhqSQYhNI4FId2bvgp2fJDhtXgSNaY6g==",
  "apiPassphrase": "auto_generated_passphrase"
}
JSON

# export env safely
set -a
. .env
set +a

# ensure Python sees dashboard
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"

# launch Streamlit dashboard
exec streamlit run dashboard/simple_app.py
