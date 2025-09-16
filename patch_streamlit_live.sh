#!/bin/bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

# backup once
cp -n streamlit_app_full.py streamlit_app_full.py.bak_live || true

python - <<'PY'
from pathlib import Path, re
p = Path("streamlit_app_full.py")
s = p.read_text()

# Ensure imports
if not re.search(r'^\s*import\s+streamlit\s+as\s+st\b', s, flags=re.M):
    s = "import streamlit as st\n" + s
if not re.search(r'^\s*import\s+os\b', s, flags=re.M):
    s = s.replace("import streamlit as st", "import streamlit as st\nimport os", 1)
if "from live_feeds import fetch_prices, est_fees" not in s:
    s = s.replace("import os", "import os\nfrom live_feeds import fetch_prices, est_fees")

# Clean any stray literal "\1" lines from earlier bad regex patches
s = re.sub(r'^\s*\\1\s*$', "", s, flags=re.M)

# Provide robust refresh helpers (no crashing)
if "_quick_auto_refresh(" not in s:
    s += """

def _quick_auto_refresh(seconds: int = 300):
    # Always show manual refresh
    try:
        if st.sidebar.button("↻ Refresh now"):
            try:
                st.rerun()
            except Exception:
                st.experimental_rerun()
        # Determine auto interval: env or argument (default 300s)
        auto = seconds
        envv = os.getenv("AUTO_SEC", "").strip()
        if envv.isdigit():
            auto = int(envv)
        if auto > 0:
            import time
            time.sleep(auto)
            try:
                st.rerun()
            except Exception:
                st.experimental_rerun()
    except Exception:
        pass

def _safe_autorefresh(*, seconds=None, interval=None, key=None, help=None):
    # Accept old st_autorefresh signature: interval in ms
    if interval is not None:
        try:
            seconds = int(float(interval)/1000.0)
        except Exception:
            seconds = seconds or 300
    if seconds is None:
        seconds = int(os.getenv("AUTO_SEC", "300"))
    return _quick_auto_refresh(seconds=seconds)
"""

# Replace any legacy calls to st.autorefresh / st_autorefresh with our safe shim
s = re.sub(r'\bst\.autorefresh\s*\(', r'_safe_autorefresh(', s)
s = re.sub(r'\bst_autorefresh\s*\(', r'_safe_autorefresh(', s)

# ---- Inject / patch the UI block for LIVE data (idempotent) ----
# Add a marker section (insert once)
if "# === LIVE DATA SECTION ===" not in s:
    # Try to place after a line that looks like a page title or header
    anchor = re.search(r'^\s*st\.(title|header)\(.*?\)\s*$', s, flags=re.M)
    insert_at = anchor.end() if anchor else len(s)
    live_block = """
# === LIVE DATA SECTION ===
with st.sidebar:
    st.subheader("Controls")
    symbols_input = st.text_input("Symbols (comma-separated)", value=os.getenv("SYMBOLS", "BTC-USD,ETH-USD"))
    auto_sec = st.number_input("Auto-refresh (seconds)", min_value=0, max_value=3600, value=int(os.getenv("AUTO_SEC","300")), step=5)
    trade_usd = st.number_input("Trade size (USD)", min_value=10, max_value=1000000, value=int(os.getenv("TRADE_USD","1000")), step=10)
    role = st.radio("Role", options=["taker","maker"], horizontal=True, index=0 if os.getenv("ROLE","taker")=="taker" else 1)
    st.caption("Safe demo off — pulling LIVE prices.")
    # set env override for our refresher
    os.environ["AUTO_SEC"] = str(int(auto_sec))

st.markdown("### Live Prices & Spreads")

def _parse_syms(raw: str):
    return [x.strip() for x in raw.split(",") if x.strip()]

syms = _parse_syms(symbols_input)
if not syms:
    st.info("Enter at least one symbol, e.g., BTC-USD")
else:
    for sym in syms:
        try:
            data = fetch_prices(sym)
            stamp = data["sources"]["bitstamp"]
            finex = data["sources"]["bitfinex"]
            diff_abs = data["diff_abs"]
            diff_pct = data["diff_pct"]

            # fee assumptions (editable via inputs below)
            taker_pct = float(os.getenv("TAKER_PCT", "0.19"))
            maker_pct = float(os.getenv("MAKER_PCT", "0.10"))

            # taker/maker fee estimates on each venue
            f_stamp = est_fees(stamp, trade_usd, role, taker_pct, maker_pct)
            f_finex = est_fees(finex, trade_usd, role, taker_pct, maker_pct)

            col1, col2, col3, col4 = st.columns([1.4,1.4,1.2,1.6])
            with col1:
                st.metric(f"{sym} — Bitstamp", f"${stamp:,.2f}")
                st.caption(f"{role} fee @ { (taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_stamp['fee_usd']:.2f}")
            with col2:
                st.metric(f"{sym} — Bitfinex", f"${finex:,.2f}")
                st.caption(f"{role} fee @ { (taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_finex['fee_usd']:.2f}")
            with col3:
                st.metric("Spread ($)", f"{diff_abs:+,.2f}")
                st.caption(f"Spread (%) {diff_pct:+.4f}%")
            with col4:
                roundtrip_fee = f_stamp['fee_usd'] + f_finex['fee_usd']
                st.metric("2-leg fee est.", f"${roundtrip_fee:,.2f}")
                st.caption("Sum of fees across both venues, one leg each")

        except Exception as ex:
            st.error(f"{sym}: {ex}")

# Run auto-refresh safely (defaults to 5 minutes unless user changed sidebar)
_safe_autorefresh(seconds=int(os.getenv("AUTO_SEC","300")))
"""
    s = s[:insert_at] + "\n" + live_block + "\n" + s[insert_at:]

Path("streamlit_app_full.py").write_text(s)
print("Patched for LIVE data ✅")
PY

# Ensure httpx present
if [ -f requirements.txt ]; then
  if ! grep -qi '^httpx' requirements.txt; then
    printf '\nhttpx>=0.27\n' >> requirements.txt
  fi
fi
. .venv/bin/activate 2>/dev/null || true
pip install -q httpx>=0.27 || true
echo "All set."
