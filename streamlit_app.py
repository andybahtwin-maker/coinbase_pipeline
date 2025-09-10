import os, time
import numpy as np
import pandas as pd
import altair as alt
import streamlit as st

from exchange_prices import fetch_tickers, calc_spreads

REFRESH_SECS = int(os.getenv("REFRESH_SECS", "30"))
SYMBOLS = [s.strip() for s in os.getenv("SYMBOLS","BTC/USD,ETH/USD,XRP/USD").split(",")]

st.set_page_config(page_title="Crypto Arbitrage Radar", page_icon="📈", layout="wide")

# ---- minimal CSS polish ----
st.markdown("""
<style>
.big-num { font-size: 2.2rem; font-weight: 700; line-height: 1.1; }
.kpi { padding: 14px; border-radius: 16px; box-shadow: 0 2px 12px rgba(0,0,0,.06); }
.card { padding: 16px; border-radius: 20px; box-shadow: 0 6px 22px rgba(0,0,0,.08); }
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace; }
.badge { padding: 2px 8px; border-radius: 999px; font-size: 0.8rem; background: rgba(0,0,0,.05); }
</style>
""", unsafe_allow_html=True)

st.title("🎛️ Crypto Arbitrage Radar")
st.caption("Gross spreads across exchanges (ignoring fees & slippage) • Auto-refreshes")

with st.sidebar:
    st.header("Controls")
    symbols_text = st.text_input("Symbols (comma-separated)", ",".join(SYMBOLS))
    REFRESH_SECS = st.slider("Auto-refresh (seconds)", 10, 120, REFRESH_SECS, step=5)
    st.markdown(f"<span class='badge mono'>Refresh: {REFRESH_SECS}s</span>", unsafe_allow_html=True)
    run_btn = st.button("🔄 Refresh now")

SYMBOLS = [s.strip() for s in symbols_text.split(",") if s.strip()]

# Fetch data
df = fetch_tickers(symbols=SYMBOLS, exchanges=None)
pivot, sym_summary, pair_detail = calc_spreads(df)

# --- KPIs (top 3 spreads) ---
st.subheader("Top Spread Opportunities")
kpi_cols = st.columns(3) if not sym_summary.empty else st.columns(1)
for i, (_, r) in enumerate(sym_summary.head(3).iterrows()):
    with kpi_cols[i if i < 3 else 2]:
        st.markdown("<div class='kpi'>", unsafe_allow_html=True)
        st.markdown(f"**{r['symbol']}**")
        st.markdown(f"<div class='big-num'>{r['spread_pct']:.2f}%</div>", unsafe_allow_html=True)
        st.caption(f"Buy {r['min_ex']} @ {r['min_price']:.2f} → Sell {r['max_ex']} @ {r['max_price']:.2f}")
        st.markdown("</div>", unsafe_allow_html=True)

# --- Heatmap of prices per exchange ---
if not pivot.empty:
    plot_df = pivot.reset_index().melt(id_vars="symbol", var_name="exchange", value_name="price")
    heat = (
        alt.Chart(plot_df)
        .mark_rect()
        .encode(
            x=alt.X("exchange:N", title="Exchange"),
            y=alt.Y("symbol:N", title="Symbol"),
            color=alt.Color("price:Q", title="Price"),
            tooltip=["symbol","exchange",alt.Tooltip("price:Q", format=",.2f")]
        )
        .properties(height=220)
    )
    st.subheader("Price Heatmap")
    st.altair_chart(heat, use_container_width=True)

# --- Edge matrix chart (best buy/sell pair per symbol) ---
if not pair_detail.empty:
    best_edges = (
        pair_detail.sort_values(["symbol","edge_pct"], ascending=[True,False])
        .groupby("symbol").head(1)
    )
    st.subheader("Best Buy/Sell Pair per Symbol")
    edge_bar = (
        alt.Chart(best_edges)
        .mark_bar()
        .encode(
            y=alt.Y("symbol:N", title=""),
            x=alt.X("edge_pct:Q", title="Edge %"),
            tooltip=[
                "symbol",
                alt.Tooltip("edge_pct:Q", title="Edge %", format=".2f"),
                "buy_ex","sell_ex",
                alt.Tooltip("buy:Q", title="Buy", format=",.2f"),
                alt.Tooltip("sell:Q", title="Sell", format=",.2f"),
            ],
        )
        .properties(height=140)
    )
    st.altair_chart(edge_bar, use_container_width=True)

# --- Detailed table (pretty) ---
if not pair_detail.empty:
    st.subheader("Top Pairs (per symbol)")
    show = (
        pair_detail.sort_values(["symbol","edge_pct"], ascending=[True,False])
        .groupby("symbol").head(8)
        .rename(columns={
            "buy_ex":"Buy @ Exchange", "buy":"Buy",
            "sell_ex":"Sell @ Exchange", "sell":"Sell",
            "edge_pct":"Edge %"
        })
    )
    st.dataframe(
        show.style.format({"Buy":"{:.2f}","Sell":"{:.2f}","Edge %":"{:.2f}"}),
        use_container_width=True,
        hide_index=True
    )

# Footer + auto-refresh
st.caption("Data from multiple exchanges via CCXT. Gross edges shown; consider fees, funding, KYC, and transfer delays.")
if not run_btn:
    st.experimental_rerun() if st.runtime.scriptrunner.script_run_context.add_script_run_ctx \
        and REFRESH_SECS == 0 else time.sleep(REFRESH_SECS)
