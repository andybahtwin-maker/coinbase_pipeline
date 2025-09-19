#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/projects/coinbase_pipeline"
mkdir -p "$DIR/dashboard"
cd "$DIR"

# 0) Ensure venv + deps (no deletes)
if [ ! -d .venv ]; then python3 -m venv .venv; fi
# shellcheck disable=SC1091
source .venv/bin/activate

# add/merge requirements (append-only)
REQ_TMP="$(mktemp)"
cat > "$REQ_TMP" <<'REQ'
streamlit>=1.35
pandas>=2.2
plotly>=5.22
python-dotenv>=1.0
ccxt>=4.3
REQ
python - "$REQ_TMP" <<'PY'
import sys, pathlib
want = set(x.strip() for x in pathlib.Path(sys.argv[1]).read_text().splitlines() if x.strip())
p = pathlib.Path("requirements.txt")
have = set()
if p.exists():
    have = set(x.strip() for x in p.read_text().splitlines() if x.strip())
p.write_text("\n".join(sorted(have | want)) + "\n")
PY
pip install -r requirements.txt >/dev/null

# 1) Add a Notion snapshot tab (pure add — no delete)
cat > dashboard/tab_notion_snapshot.py <<'PY'
import streamlit as st
import pandas as pd

def _mk_callout(title: str, body: str, emoji: str="ℹ️"):
    st.markdown(
        f"""
<div style="border:1px solid #3333;border-radius:12px;padding:12px;margin-bottom:8px;">
  <div style="font-size:14px;opacity:.7;">{emoji} {title}</div>
  <div style="font-size:20px;font-weight:700;margin-top:4px;">{body}</div>
</div>
        """,
        unsafe_allow_html=True
    )

# Data lifted from your Notion page snapshot (BTC/ETH/XRP rows) on 2025-09-13
# See repo chat for details.
NOTION_TABLE_MD = """pair,spot,24h_low,24h_high,best_bid,best_ask,spread_pct,fee_buy_pct,fee_sell_pct,effective_buy,effective_sell,edge_after_fees_pct
BTC-USD,116303.430000,114774.190000,116833.250000,116285.000000,116285.010000,0.000009,0.600000,0.600000,116982.720060,115587.290000,-1.192851
ETH-USD,4709.305000,4489.470000,4744.750000,4707.870000,4707.880000,0.000212,0.600000,0.600000,4736.127280,4679.622780,-1.193053
XRP-USD,3.104800,3.017600,3.139400,3.104500,3.104600,0.003221,0.600000,0.600000,3.123228,3.085873,-1.196026
"""

def render_notion_snapshot():
    st.header("Daily Crypto Arbitrage — Notion Snapshot")
    st.caption("Static snapshot imported from your Notion page (kept in-app so something real always shows).")

    # Callouts exactly as kept in your Notion block
    _mk_callout("BTC Balance", "0.00000000 BTC • Total: 0.00000000 BTC", "💰")
    _mk_callout("BTC Spread", "gross $144.00 • 0.12%", "📘")
    _mk_callout("Top Net Edge", "$-560.70  •  -0.48%  (after fees across all symbols)", "⚡")

    # Table
    df = pd.read_csv(pd.compat.StringIO(NOTION_TABLE_MD))
    st.dataframe(df, use_container_width=True)

    # Quick highlights
    try:
        worst = df.sort_values("edge_after_fees_pct").iloc[0]
        st.markdown(
            f"**Worst Net Edge in snapshot:** {worst['pair']}  •  {worst['edge_after_fees_pct']:.6f}%"
        )
    except Exception:
        pass
PY

# 2) Wire the tab into your Streamlit app (append-only; no deletion)
# If simple_app.py exists, patch it; otherwise create a minimal one that includes the tab.
if [ -f dashboard/simple_app.py ]; then
  python - <<'PY'
from pathlib import Path
p = Path("dashboard/simple_app.py")
s = p.read_text()
needle = "from dashboard.tab_notion_snapshot import render_notion_snapshot"
if needle not in s:
    # import
    s = s.replace("from dashboard.tab_fees_arbitrage import render_fees_arbitrage",
                  "from dashboard.tab_fees_arbitrage import render_fees_arbitrage\nfrom dashboard.tab_notion_snapshot import render_notion_snapshot")
    # add tab label
    s = s.replace('tabs = st.tabs(["Dashboard", "Balances", "AI Summary", "Arbitrage/Fees", "Env Health Check"])',
                  'tabs = st.tabs(["Dashboard", "Balances", "AI Summary", "Arbitrage/Fees", "Env Health Check", "Daily Arbitrage (Notion)"])')
    # unpack new tab var
    s = s.replace('tab_dash, tab_bal, tab_ai, tab_arb, tab_env = tabs',
                  'tab_dash, tab_bal, tab_ai, tab_arb, tab_env, tab_notion = tabs')
    # render it
    s = s.replace('with tab_env:',
                  'with tab_env:\n    render_env_health()\n\nwith tab_notion:\n    render_notion_snapshot()')
    p.write_text(s)
PY
else
  cat > dashboard/simple_app.py <<'PY'
import os
from dotenv import load_dotenv
load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"), override=False)

import streamlit as st
from dashboard.tab_notion_snapshot import render_notion_snapshot

st.set_page_config(page_title="Coinbase Pipeline", layout="wide")
st.title("Dashboard")

tabs = st.tabs(["Daily Arbitrage (Notion)"])
tab_notion, = tabs

with tab_notion:
    render_notion_snapshot()
PY
fi

# 3) Runner (append-only style; won’t delete your current runner)
cat > run_notion_snapshot.sh <<'RUN'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -d .venv ]; then python3 -m venv .venv; fi
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools >/dev/null
pip install -r requirements.txt >/dev/null
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
exec streamlit run dashboard/simple_app.py
RUN
chmod +x run_notion_snapshot.sh

echo "✅ Notion snapshot added. Launching…"
./run_notion_snapshot.sh
