#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/projects/coinbase_pipeline"
GH_USER="andybahtwin-maker"
GH_REPO="coinbase_pipeline"
SSH_REMOTE="git@github.com:${GH_USER}/${GH_REPO}.git"

cd "$REPO_DIR"

# Ensure SSH remote (avoid HTTPS prompts forever)
git remote set-url origin "$SSH_REMOTE" 2>/dev/null || git remote add origin "$SSH_REMOTE"
git config --local url."git@github.com:".insteadOf https://github.com/

# Create and/or switch to stabilize branch
git fetch origin || true
git checkout -B stabilize

# Harden .gitignore (idempotent)
cat > .gitignore <<'GIT'
# Secrets
.env
*.env
cdp_api_key*.json
*.pem
*.key

# Python cruft
.venv/
__pycache__/
*.py[cod]
*.egg-info/
.cache/

# Local data/outputs
data/
snapshots/*.csv
!snapshots/.gitkeep

# Editors
.vscode/
.idea/
.DS_Store
GIT

mkdir -p snapshots
touch snapshots/.gitkeep

# Ops verify script (diagnostics, no secrets printed)
mkdir -p scripts
cat > scripts/ops_verify.sh <<'PYEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv >/dev/null 2>&1 || true
source .venv/bin/activate
pip -q install -U pip >/dev/null
pip -q install -r requirements.txt >/dev/null

python - <<'PY'
import time, pandas as pd
from coinbase_helpers import get_coinbase_balances
from exchanges import fetch_all_prices

print("== Coinbase balances ==")
rows, err = get_coinbase_balances()
if err:
    print("UNAVAILABLE ->", err)
else:
    btc = [r for r in rows if (r.get("asset","") or "").upper()=="BTC"]
    amt = sum(float(r.get("available",0) or 0) for r in btc) if btc else 0.0
    print(f"OK -> BTC available: {amt}")

print("\n== Public BTC prices ==")
prices = fetch_all_prices()
ok = [p for p in prices if p.get("price") is not None]
print(f"Got {len(ok)} prices")
ts = time.strftime("%Y%m%d-%H%M%S")
pd.DataFrame(prices).to_csv(f"snapshots/btc_prices_{ts}.csv", index=False)
print(f"Wrote snapshots/btc_prices_{ts}.csv")
PY
PYEOF
chmod +x scripts/ops_verify.sh

# Pin SSH push helper
cat > scripts/pin_ssh_remote.sh <<'SHEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"
git remote set-url origin git@github.com:andybahtwin-maker/coinbase_pipeline.git
git config --local url."git@github.com:".insteadOf https://github.com/
git remote -v
SHEOF
chmod +x scripts/pin_ssh_remote.sh

# Commit and push
git add .gitignore snapshots/.gitkeep scripts
git commit -m "stabilize: add ops_verify, pin SSH, harden .gitignore" || true
git push -u origin stabilize

echo
echo "✅ Branch 'stabilize' pushed to $SSH_REMOTE"
echo "Run diagnostics:  scripts/ops_verify.sh"
