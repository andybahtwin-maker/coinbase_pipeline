#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/projects/coinbase_pipeline"
SECRETS="$DIR/secrets"
mkdir -p "$SECRETS"

# hard-wire your Coinbase API creds here
cat > "$SECRETS/.env" <<'ENV'
CB_API_KEY=AwEHoUQDQgAE+2pdYPg+pS4A3DdeDL5G9VQnm4L/BUXcpzq4c19olOy0KFXsnWQW
CB_API_SECRET=your_real_secret_here
CB_API_PASSPHRASE=your_real_passphrase_here
COINBASE_API_BASE=https://api.coinbase.com
LOG_LEVEL=INFO
ENV

cat > "$SECRETS/cdp_api_key.json" <<'JSON'
{
  "apiKey": "AwEHoUQDQgAE+2pdYPg+pS4A3DdeDL5G9VQnm4L/BUXcpzq4c19olOy0KFXsnWQW",
  "apiSecret": "your_real_secret_here",
  "apiPassphrase": "your_real_passphrase_here"
}
JSON

# overwrite main .env with symlink → secrets
ln -sf "$SECRETS/.env" "$DIR/.env"

# recreate runner that always sources from secrets
cat > "$DIR/run_coinbase_pipeline.sh" <<'RUN'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# activate venv
source .venv/bin/activate

# load .env from secrets
set -a
. secrets/.env
set +a

# ensure PYTHONPATH
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"

# launch Streamlit
exec streamlit run dashboard/simple_app.py
RUN
chmod +x "$DIR/run_coinbase_pipeline.sh"

echo "✅ Coinbase credentials locked in $SECRETS"
echo "👉 Run with: ./run_coinbase_pipeline.sh"
