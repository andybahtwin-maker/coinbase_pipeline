import os
from datetime import datetime, timezone
import numpy as np
import urllib.parse
import pandas as pd
from pathlib import Path

# Load .env manually
if os.path.exists(".env"):
    for line in open(".env"):
        if "=" in line and not line.strip().startswith("#"):
            k,v=line.strip().split("=",1); os.environ.setdefault(k,v)

from exchange_prices import fetch_tickers, calc_spreads
from notion_publish import publish_dashboard
from coinbase_balance import get_btc_balance

PRIMARYS = [s.strip() for s in os.getenv("PRIMARY_SYMBOLS","BTC/USD,XRP/USD").split(",")]
TV_INTERVAL = os.getenv("EMBED_INTERVAL","60")  # 1,5,15,60,240,D,W

def format_pct(x):
    return "—" if (x is None or (isinstance(x,float) and (np.isnan(x) or np.isinf(x)))) else f"{x:.2f}%"

def format_usd(x):
    return "—" if (x is None or (isinstance(x,float) and (np.isnan(x) or np.isinf(x)))) else f"${x:,.2f}"

def tradingview_widgetembed(symbol_mkt):
    # s.tradingview.com/widgetembed renders inline in Notion and appears side-by-side via columns
    base="https://s.tradingview.com/widgetembed/"
    q={
        "symbol": symbol_mkt,
        "interval": TV_INTERVAL,
        "hidesidetoolbar": "true",
        "symboledit": "false",
        "hideideas": "true",
        "toolbarbg": "rgba(0,0,0,0)",
        "studies": "",
        "theme": "light",
        "style": "1",
        "withdateranges": "true",
        "hidevolume": "false",
    }
    return base + "?" + urllib.parse.urlencode(q)

def best_for_symbol(pair_detail, sym):
    sub = pair_detail[pair_detail["symbol"]==sym].sort_values("edge_pct", ascending=False).head(1)
    if sub.empty: return None
    r=sub.iloc[0]
    dollar=float(r["sell"]-r["buy"])
    return {
        "symbol": sym,
        "buy_ex": r["buy_ex"], "buy": float(r["buy"]),
        "sell_ex": r["sell_ex"], "sell": float(r["sell"]),
        "edge_pct": float(r["edge_pct"]),
        "edge_usd": dollar
    }

def append_history(ts_iso, pair_detail, sym_summary):
    Path("data").mkdir(exist_ok=True)
    # Best edge per symbol -> data/best_edges.csv
    best = (pair_detail.sort_values(["symbol","edge_pct"], ascending=[True,False])
                     .groupby("symbol").head(1).copy())
    best.insert(0, "timestamp", ts_iso)
    f1="data/best_edges.csv"; hdr = not Path(f1).exists()
    best.to_csv(f1, mode="a", index=False, header=hdr)

    # Sym summary (min/max per symbol) -> data/sym_summary.csv
    sym = sym_summary.copy()
    sym.insert(0, "timestamp", ts_iso)
    f2="data/sym_summary.csv"; hdr2 = not Path(f2).exists()
    sym.to_csv(f2, mode="a", index=False, header=hdr2)

def run():
    df = fetch_tickers()
    pivot, sym_summary, pair_detail = calc_spreads(df)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    now_iso = datetime.now(timezone.utc).isoformat()
    title = f"Daily Crypto Arbitrage — {now}"

    # Best overall trade (for the callout + spotlight)
    best = pair_detail.sort_values(["edge_pct"], ascending=False).head(1)
    if not best.empty:
        b = best.iloc[0]
        best_trade = f"{b['symbol']}: BUY {b['buy_ex']} @ {b['buy']:.2f} → SELL {b['sell_ex']} @ {b['sell']:.2f}  (+{format_usd(b['sell']-b['buy'])} / {b['edge_pct']:.2f}%)"
        spotlight_big = f"+{format_usd(b['sell']-b['buy'])} ({b['edge_pct']:.2f}%) — {b['symbol']}"
        spotlight_sub = f"Buy {b['buy_ex']} @ {b['buy']:.2f} → Sell {b['sell_ex']} @ {b['sell']:.2f}"
    else:
        best_trade="No reliable edge at this moment."
        spotlight_big=spotlight_sub=None

    # Top bullets (8)
    bullets=[]
    for p in pair_detail.sort_values(["edge_pct"], ascending=False).head(8).itertuples():
        bullets.append(f"{p.symbol}: +{format_usd(p.sell-p.buy)}  ({p.edge_pct:.2f}%)  | buy {p.buy_ex} {p.buy:.2f} → sell {p.sell_ex} {p.sell:.2f}")

    # BTC balance
    btc_free, btc_total = get_btc_balance()

    # BTC spread row for KPI
    btc_row = sym_summary[sym_summary["symbol"]=="BTC/USD"].head(1)
    if not btc_row.empty:
        rr=btc_row.iloc[0]
        btc_spread_pct=float(rr["spread_pct"]); btc_spread_abs=float(rr["spread_abs"])
        btc_min_ex, btc_min_px = rr["min_ex"], float(rr["min_price"])
        btc_max_ex, btc_max_px = rr["max_ex"], float(rr["max_price"])
    else:
        btc_spread_pct=btc_spread_abs=np.nan
        btc_min_ex=btc_max_ex="-"; btc_min_px=btc_max_px=float("nan")

    # KPI trio
    kpis=[
        ("BTC Balance", f"{btc_free:.8f} BTC", f"Total: {btc_total:.8f} BTC", "💰"),
        ("BTC Spread (gross)", f"{format_usd(btc_spread_abs)}  •  {format_pct(btc_spread_pct)}",
         f"Low {btc_min_ex} {btc_min_px:.2f} → High {btc_max_ex} {btc_max_px:.2f}", "📐"),
        ("Top Edge", (f"{format_usd(float(best.iloc[0]['sell']-best.iloc[0]['buy']))}  •  {best.iloc[0]['edge_pct']:.2f}%") if not best.empty else "—",
         "Across all symbols", "⚡"),
    ]

    # Build "Best of BTC & XRP" two-up — BIG line includes $ + % + route (Heading 2)
    tiles=[[],[]]  # left, right
    syms=["BTC/USD","XRP/USD"]
    def best_for_symbol_local(sym):
        sub = pair_detail[pair_detail["symbol"]==sym].sort_values("edge_pct", ascending=False).head(1)
        if sub.empty: return None
        r=sub.iloc[0]; dollar=float(r["sell"]-r["buy"])
        return {
            "symbol": sym, "buy_ex": r["buy_ex"], "buy": float(r["buy"]),
            "sell_ex": r["sell_ex"], "sell": float(r["sell"]),
            "edge_pct": float(r["edge_pct"]), "edge_usd": dollar
        }
    best_items=[best_for_symbol_local(s) for s in syms]
    for idx,item in enumerate(best_items):
        if item:
            big_line = (
                f"{item['symbol']}: +{format_usd(item['edge_usd'])} "
                f"({item['edge_pct']:.2f}%)  "
                f"(buy {item['buy_ex']} @ {item['buy']:.2f} → sell {item['sell_ex']} @ {item['sell']:.2f})"
            )
            tiles[idx].append({
                "object":"block","type":"heading_2",
                "heading_2":{"rich_text":[{"type":"text","text":{"content":big_line},"annotations":{"bold":True}}]}
            })
        else:
            tiles[idx].append({"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":f"{syms[idx]} — no edge"}}]}})

    # Live chart embeds that render inline (side-by-side in columns)
    tv_urls=[tradingview_widgetembed("COINBASE:BTCUSD"), tradingview_widgetembed("COINBASE:XRPUSD")]

    # Write history to CSVs (best_edges + sym_summary)
    append_history(now_iso, pair_detail, sym_summary)

    publish_dashboard(
        title=title,
        kpis=kpis,
        best_trade_text=best_trade,
        bullets=bullets,
        embed_urls=tv_urls,            # goes directly under the title, in two columns
        spotlight_big=spotlight_big,
        spotlight_sub=spotlight_sub,
        best_of_tiles=tiles,
        after_best_of_images=None,
        replace_mode=True,             # << clears old blocks so the page doesn't grow
        embed_row_first=True
    )
    print("Published Notion dashboard.")

if __name__=="__main__":
    run()
