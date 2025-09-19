#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/projects/coinbase_pipeline"
cd "$DIR"

# 0) venv + deps (idempotent)
if [ ! -d .venv ]; then python3 -m venv .venv; fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools >/dev/null
if [ -f requirements.txt ]; then pip install -r requirements.txt >/dev/null; fi

# 1) Build a sorted list of candidate env files (oldest -> newest)
ENV_LIST="$DIR/all_env_files_sorted.txt"
: > "$ENV_LIST"
if [ -f "$DIR/all_env_files.txt" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] && stat -c '%Y\t%n' "$f" || true
  done < "$DIR/all_env_files.txt" | sort -n | cut -f2- > "$ENV_LIST"
fi

# Always include these at the end (highest priority)
printf '%s\n' "$HOME/.env" ".env" ".env.bak" >> "$ENV_LIST"

# 2) Extract latest values for Coinbase keys (support CB_* and COINBASE_* names)
CB_API_KEY=""
CB_API_SECRET=""
CB_API_PASSPHRASE=""

grab() {
  local k1="$1" k2="$2" file
  # read oldest->newest; newest wins by overwriting each pass
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # exact KEY=VALUE lines only
    v="$(grep -h -m1 -E "^${k1}=" "$file" | tail -n1 | cut -d'=' -f2- || true)"
    [ -z "$v" ] && v="$(grep -h -m1 -E "^${k2}=" "$file" | tail -n1 | cut -d'=' -f2- || true)"
    [ -n "${v:-}" ] && printf '%s' "$v"
  done < "$ENV_LIST"
}

CB_API_KEY="$(grab CB_API_KEY COINBASE_API_KEY || true)"
CB_API_SECRET="$(grab CB_API_SECRET COINBASE_API_SECRET || true)"
CB_API_PASSPHRASE="$(grab CB_API_PASSPHRASE COINBASE_API_PASSPHRASE || true)"

# If still empty but exported in current shell, take those
CB_API_KEY="${CB_API_KEY:-${CB_API_KEY:-${COINBASE_API_KEY:-}}}"
CB_API_SECRET="${CB_API_SECRET:-${CB_API_SECRET:-${COINBASE_API_SECRET:-}}}"
CB_API_PASSPHRASE="${CB_API_PASSPHRASE:-${CB_API_PASSPHRASE:-${COINBASE_API_PASSPHRASE:-}}}"

# 3) Write a clean .env (KEY=VALUE only) and matching JSON for libraries that prefer it
mv .env .env.bak 2>/dev/null || true
{
  echo "CB_API_KEY=${CB_API_KEY}"
  echo "CB_API_SECRET=${CB_API_SECRET}"
  echo "CB_API_PASSPHRASE=${CB_API_PASSPHRASE}"
  echo "COINBASE_API_BASE=${COINBASE_API_BASE:-https://api.coinbase.com}"
  echo "LOG_LEVEL=${LOG_LEVEL:-INFO}"
} | grep -E '^[A-Za-z_][A-Za-z0-9_]*=.*$' > .env

cat > cdp_api_key.json <<JSON
{
  "apiKey": "${CB_API_KEY}",
  "apiSecret": "${CB_API_SECRET}",
  "apiPassphrase": "${CB_API_PASSPHRASE}"
}
JSON

# 4) Export vars safely (no xargs; preserve special chars)
set -a
. .env
set +a

# 5) Make sure Python can import project packages
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"

# 6) Launch Streamlit dashboard
exec streamlit run dashboard/simple_app.py
