from pathlib import Path

p = Path("streamlit_app.py")
s = p.read_text()

# Idempotent: only append once
marker = "# === FEE-AWARE TOP SPREADS ==="
if marker in s:
    print("Already patched.")
else:
    add = f"""
{marker}
import pandas as pd
import streamlit as st
from fees import FeeBook, TradeLeg, TradeAssumptions, compute_dollars

fb = FeeBook("fees_config.json")
with st.sidebar:
    st.subheader("Calc Options")
    _usd_size = st.number_input("Trade size (USD)", min_value=25.0, max_value=100000.0,
                                value=float(fb.default_usd()), step=25.0)
    _include_fees = st.checkbox("Include trading fees", value=True)
    _role = st.radio("Role", options=["taker","maker"], index=0, horizontal=True)

def _normalize_cols(df: pd.DataFrame) -> pd.DataFrame:
    # accept multiple naming variants from your pipeline
    rename_map = {}
    for a,b in [("buy_ex","buy_exchange"),("sell_ex","sell_exchange"),
                ("buy_px","buy_price"),("sell_px","sell_price"),
                ("edge_pct","edge"),("symbol","pair")]:
        if b in df.columns and a not in df.columns:
            rename_map[b] = a
    if rename_map:
        df = df.rename(columns=rename_map)
    # fill missing pieces to avoid crashes
    for col, default in [("symbol","UNKNOWN"),("edge_pct",0.0),
                         ("buy_ex","?"),("sell_ex","?"),
                         ("buy_px",0.0),("sell_px",0.0)]:
        if col not in df.columns:
            df[col] = default
    return df

def _render_row(row):
    try:
        spread_pct = float(row.get("edge_pct", 0.0))
        asset = str(row.get("symbol","?"))
        buy_ex, sell_ex = str(row.get("buy_ex","?")), str(row.get("sell_ex","?"))
        buy_px, sell_px = float(row.get("buy_px",0.0)), float(row.get("sell_px",0.0))
        buy = TradeLeg(buy_ex, buy_px, _role)
        sell = TradeLeg(sell_ex, sell_px, _role)
        res = compute_dollars(buy, sell, TradeAssumptions(_usd_size, _include_fees, _role))
        fee_txt = (f" | Fees: ${{res['buy_fee_usd']:.2f}} + ${{res['sell_fee_usd']:.2f}}" if _include_fees else "")
        st.caption(
            f"**{asset}** — {spread_pct:.2f}% | "
            f"Buy {buy_ex} @ {buy_px:.4f} → Sell {sell_ex} @ {sell_px:.4f}  \n"
            f"💵 For ${res['usd_size']:,.0f}: Gross ${res['gross_spread_usd']:.2f}{fee_txt} "
            f"→ **Net ${res['net_profit_usd']:.2f}**"
        )
    except Exception as e:
        st.caption(f"⚠️ unable to compute fees for this row: {{e}}")

# try to read your live pair_detail; otherwise show a tiny demo list
try:
    _df = pair_detail.copy()
except NameError:
    _df = pd.DataFrame([
        {"symbol":"ETH/USD","edge_pct":0.19,"buy_ex":"bitstamp","buy_px":4483.40,"sell_ex":"bitfinex","sell_px":4492.10},
        {"symbol":"BTC/USD","edge_pct":0.17,"buy_ex":"kraken","buy_px":114784.00,"sell_ex":"bitfinex","sell_px":114980.00},
        {"symbol":"XRP/USD","edge_pct":0.07,"buy_ex":"kraken","buy_px":3.0000,"sell_ex":"bitfinex","sell_px":3.0100}
    ])

_df = _normalize_cols(_df)
_df = _df.sort_values(["edge_pct"], ascending=False, kind="mergesort").reset_index(drop=True)

st.write("")  # visual spacer right under your existing lines
for _, _row in _df.head(5).iterrows():
    _render_row(_row)
"""
    # Inject right after the line that mentions "Top Spread Opportunities" if present; else append at end.
    if "Top Spread Opportunities" in s:
        idx = s.index("Top Spread Opportunities")
        # find end of that line
        nl = s.find("\n", idx)
        if nl == -1: nl = len(s)
        s = s[:nl] + "\n" + add + "\n" + s[nl:]
    else:
        s = s + "\n\n" + add + "\n"

    p.write_text(s)
    print("✅ Patched streamlit_app.py with fee-aware Top Spreads block.")
