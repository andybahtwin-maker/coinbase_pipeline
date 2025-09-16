import os, json, time
from pathlib import Path
import streamlit as st
import pandas as pd
import numpy as np

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from dotenv import load_dotenv
load_dotenv()

APP_TITLE = os.getenv("APP_TITLE", "Coinbase Pipeline – BTC Multi-Exchange Monitor")
DEMO = os.getenv("APP_DEMO_FALLBACK", "true").lower() == "true"

st.set_page_config(page_title=APP_TITLE, layout="wide")
st.title(APP_TITLE)

with st.sidebar:
    st.markdown("### Controls")
    auto_refresh = st.checkbox("Auto-refresh", value=True, help="Reload automatically")
    interval = st.number_input("Refresh interval (seconds)", min_value=5, max_value=120, value=15, step=5)
    st.caption("If APIs stall, data still renders with timeouts.")

    st.markdown("### Diagnostics")
    diag_box = st.empty()

def fetch_prices(timeout_ms=5000):
    import ccxt
    pairs = {
        "coinbase": "BTC/USD",
        "kraken":   "BTC/USD",
        "binance":  "BTC/USDT",
        "bitstamp": "BTC/USD",
        "bitfinex": "BTC/USD",
    }
    rows = []
    for ex_name, symbol in pairs.items():
        try:
            diag_box.write(f"Fetching {symbol} from **{ex_name}** (timeout {timeout_ms} ms)…")
            ex = getattr(ccxt, ex_name)({"timeout": timeout_ms, "enableRateLimit": True})
            t = ex.fetch_ticker(symbol)
            last = float(t["last"])
            bid = float(t.get("bid") or last)
            ask = float(t.get("ask") or last)
            rows.append({"exchange": ex_name, "symbol": symbol, "last": last, "bid": bid, "ask": ask, "timestamp": t.get("datetime") or ""})
        except Exception as e:
            rows.append({"exchange": ex_name, "symbol": symbol, "last": np.nan, "bid": np.nan, "ask": np.nan, "timestamp": "", "error": str(e)[:160]})
    return pd.DataFrame(rows)

def est_fees():
    try:
        import fees
        if hasattr(fees, "get_fees"):
            return pd.DataFrame(fees.get_fees())
    except Exception:
        pass
    return pd.DataFrame([
        {"exchange":"coinbase", "bps": 19.0},
        {"exchange":"kraken",   "bps": 16.0},
        {"exchange":"binance",  "bps": 10.0},
        {"exchange":"bitstamp", "bps": 15.0},
        {"exchange":"bitfinex", "bps": 20.0},
    ])

def fee_usd(px, bps):
    try:
        return float(px) * (float(bps)/10000.0)
    except Exception:
        return np.nan

def color_html(val, pos="green", neg="blue"):
    if pd.isna(val): return ""
    color = pos if val > 0 else (neg if val < 0 else None)
    s = f"{val:,.2f}"
    return f"<span style='color:{color}'>{s}</span>" if color else s

def metric_card(label, value, help_txt=None):
    color = "green" if (isinstance(value,(int,float)) and value>0) else ("blue" if (isinstance(value,(int,float)) and value<0) else "inherit")
    val_str = "—"
    try:
        val_str = f"{float(value):,.2f}"
    except:
        pass
    html = f"""
    <div style="
        background: rgba(255,255,255,0.03);
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 16px; padding: 14px 16px; height: 100%;
    ">
      <div style="font-size: 12px; opacity: 0.75;">{label}</div>
      <div style="font-size: 24px; font-weight: 700; color:{color};">{val_str}</div>
      {"<div style='font-size:11px; opacity:.6'>"+help_txt+"</div>" if help_txt else ""}
    </div>
    """
    st.markdown(html, unsafe_allow_html=True)

# Main data fetch and UI
with st.spinner("Pulling prices…"):
    prices_df = fetch_prices(timeout_ms=5000)
fees_df = est_fees()
fees_map = {r.exchange: r.bps for r in fees_df.itertuples() if not pd.isna(r.bps)}

valid = prices_df.dropna(subset=["bid","ask","last"]).copy()
if not valid.empty:
    best_bid = valid.loc[valid["bid"].idxmax()]
    best_ask = valid.loc[valid["ask"].idxmin()]
    raw_spread = best_bid["bid"] - best_ask["ask"]
    pct = (raw_spread / best_ask["ask"]) * 100 if best_ask["ask"] else np.nan
    est_buy_fee  = fee_usd(best_ask["ask"], fees_map.get(best_ask["exchange"], 15.0))
    est_sell_fee = fee_usd(best_bid["bid"], fees_map.get(best_bid["exchange"], 15.0))
    roundtrip_fee = est_buy_fee + est_sell_fee
    net_edge = raw_spread - roundtrip_fee
else:
    best_bid = best_ask = None
    raw_spread = pct = est_buy_fee = est_sell_fee = roundtrip_fee = net_edge = np.nan

c1, c2, c3 = st.columns(3)
with c1: metric_card("Best BID (where to sell)", best_bid["bid"] if best_bid is not None else np.nan, help_txt=(best_bid['exchange'] if best_bid is not None else None))
with c2: metric_card("Best ASK (where to buy)", best_ask["ask"] if best_ask is not None else np.nan, help_txt=(best_ask['exchange'] if best_ask is not None else None))
with c3: metric_card("Raw Spread $", raw_spread)

c4, c5, c6 = st.columns(3)
with c4: metric_card("2-leg fee est. $", roundtrip_fee)
with c5: metric_card("Spread %", pct if not pd.isna(pct) else np.nan)
with c6: metric_card("Net edge after fees $", net_edge)

st.divider()

tab_prices, tab_spreads, tab_bal, tab_snapshot, tab_about = st.tabs([
    "Prices", "Spreads Table", "Coinbase Balances", "Snapshot / Export", "About"
])

with tab_prices:
    st.subheader("Live BTC across top venues")
    st.dataframe(prices_df, use_container_width=True)
    if not valid.empty:
        fig = plt.figure()
        xs = np.arange(len(valid)); ys = valid["last"].values
        plt.plot(xs, ys, marker="o")
        plt.title("BTC Last Price (snapshot)")
        plt.xlabel("Exchange index"); plt.ylabel("Price (USD/USDT)")
        st.pyplot(fig, use_container_width=True)

with tab_spreads:
    if not valid.empty:
        rows = []
        for sell in valid.itertuples():
            for buy in valid.itertuples():
                if sell.exchange == buy.exchange: continue
                gross = sell.bid - buy.ask
                f = fee_usd(buy.ask, fees_map.get(buy.exchange, 15.0)) + fee_usd(sell.bid, fees_map.get(sell.exchange, 15.0))
                rows.append({
                    "sell@": sell.exchange,
                    "buy@": buy.exchange,
                    "gross_spread_fmt": color_html(gross),
                    "fees_fmt": f"<span style='color:blue'>{f:,.2f}</span>",
                    "net_fmt": color_html(gross - f),
                })
        opp = pd.DataFrame(rows)
        html = opp[["sell@","buy@","gross_spread_fmt","fees_fmt","net_fmt"]].to_html(escape=False, index=False)
        st.write(html, unsafe_allow_html=True)
    else:
        st.info("No valid price data yet.")

with tab_bal:
    bal = coinbase_balances_df() if 'coinbase_balances_df' in globals() else pd.DataFrame()
    st.subheader("Coinbase Balances")
    if bal.empty:
        st.info("No balances. Add your key.")
    else:
        st.dataframe(bal, use_container_width=True, hide_index=True)
        st.metric("Total USD (approx)", f"{bal['usd_value'].fillna(0).sum():,.2f}")

with tab_snapshot:
    st.write("Export CSVs (prices & balances). Email/Notion optional if configured.")
    ts = int(time.time())
    data_dir = Path("data"); data_dir.mkdir(parents=True, exist_ok=True)
    prices_path = data_dir / f"prices_{ts}.csv"
    prices_df.to_csv(prices_path, index=False)
    st.success(f"Saved {prices_path}")
    bal = coinbase_balances_df() if 'coinbase_balances_df' in globals() else pd.DataFrame()
    bal_path = None
    if not bal.empty:
        bal_path = data_dir / f"balances_{ts}.csv"
        bal.to_csv(bal_path, index=False)
        st.success(f"Saved {bal_path}")
    col1, col2 = st.columns(2)
    with col1:
        if st.button("Email snapshot (if EMAIL_* set)"):
            try:
                import emailer
                emailer.send_snapshot(str(prices_path), str(bal_path) if bal_path else None)
                st.success("Email sent.")
            except Exception as e:
                st.warning(f"Email not sent: {e}")
    with col2:
        if st.button("Publish to Notion (if NOTION_* set)"):
            try:
                import notion_publish
                notion_publish.publish_latest(str(prices_path), str(bal_path) if bal_path else None)
                st.success("Published.")
            except Exception as e:
                st.warning(f"Publish failed: {e}")

with tab_about:
    st.markdown("""
**About:**
- Live-price data (five major exchanges, with timeouts).
- Fee-aware spread / net-edge calculation.
- Metrics show colored numbers.
- Secrets are never committed.

""")
