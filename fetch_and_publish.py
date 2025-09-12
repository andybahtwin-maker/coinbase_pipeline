import os
from datetime import datetime, timezone
import numpy as np
import urllib.parse
import pandas as pd
from pathlib import Path

# Load .env
if os.path.exists(".env"):
    for line in open(".env"):
        if "=" in line and not line.strip().startswith("#"):
            k,v=line.strip().split("=",1); os.environ.setdefault(k,v)

from exchange_prices import fetch_tickers, calc_spreads
from notion_publish import publish_dashboard, _p_spans
from coinbase_balance import get_btc_balance
from fees import get_fees

def fmt_usd(x, dec=2):
    if x is None or (isinstance(x,float) and (np.isnan(x) or np.isinf(x))):
        return "—"
    return f"${x:,.{dec}f}"

def price_decimals(symbol): return 6 if symbol.upper().startswith("XRP/") else 2
def usd_decimals(symbol):   return 4 if symbol.upper().startswith("XRP/") else 2
def fmt_price(symbol,x):    return "—" if (x is None or (isinstance(x,float) and (np.isnan(x) or np.isinf(x)))) else f"{x:.{price_decimals(symbol)}f}"
def fmt_usd_for(symbol,x):  return "—" if (x is None or (isinstance(x,float) and (np.isnan(x) or np.isinf(x)))) else f"${x:,.{usd_decimals(symbol)}f}"
def color_for(v):           return "green" if (isinstance(v,(int,float)) and v>=0) else "red"

def tradingview_widgetembed(symbol_mkt, interval="60"):
    base="https://s.tradingview.com/widgetembed/"
    q={
        "symbol": symbol_mkt, "interval": interval,
        "hidesidetoolbar":"true","symboledit":"false","hideideas":"true",
        "toolbarbg":"rgba(0,0,0,0)","studies":"","theme":"light","style":"1",
        "withdateranges":"true","hidevolume":"false",
    }
    return base + "?" + urllib.parse.urlencode(q)

def compute_net_for_pair(symbol, buy_ex, buy_px, sell_ex, sell_px):
    gross_usd = float(sell_px - buy_px)
    taker_buy, wd_coin = get_fees(buy_ex, symbol)
    taker_sell, _      = get_fees(sell_ex, symbol)
    taker_buy_usd  = buy_px  * taker_buy
    taker_sell_usd = sell_px * taker_sell
    withdraw_usd   = wd_coin * sell_px
    fees_usd = taker_buy_usd + taker_sell_usd + withdraw_usd
    net_usd = gross_usd - fees_usd
    gross_pct = (gross_usd / buy_px) * 100 if buy_px else np.nan
    net_pct   = (net_usd   / buy_px) * 100 if buy_px else np.nan
    return {
        "gross_usd": gross_usd, "gross_pct": gross_pct,
        "fees_usd": fees_usd,   "net_usd": net_usd, "net_pct": net_pct,
        "taker_buy": taker_buy, "taker_sell": taker_sell, "withdraw_coin": wd_coin,
        "taker_buy_usd": taker_buy_usd, "taker_sell_usd": taker_sell_usd, "withdraw_usd": withdraw_usd,
    }

def make_fee_spans(symbol, taker_buy, taker_buy_usd, taker_sell, taker_sell_usd, withdraw_coin, withdraw_usd):
    base = symbol.split("/")[0]
    return [
        ("Fees: ", "default", False),
        ("taker_buy ", "default", False),
        (f"{taker_buy*100:.2f}%", "blue", False),
        (f" (~{fmt_usd_for(symbol, taker_buy_usd)})", "blue", False),
        (", ", "default", False),

        ("taker_sell ", "default", False),
        (f"{taker_sell*100:.2f}%", "blue", False),
        (f" (~{fmt_usd_for(symbol, taker_sell_usd)})", "blue", False),
        (", ", "default", False),

        ("withdraw ", "default", False),
        (f"{withdraw_coin:.8f} {base}", "blue", False),
        (f" (~{fmt_usd_for(symbol, withdraw_usd)})", "blue", False),
    ]

def make_route_spans(symbol, buy_ex, buy, sell_ex, sell):
    return [
        ("Route: ", "default", False),
        (f"buy {buy_ex} @ {fmt_price(symbol, buy)} → sell {sell_ex} @ {fmt_price(symbol, sell)}", "default", False)
    ]

def make_net_spans(symbol, net_usd, net_pct):
    sign = "+" if net_usd>=0 else "-"
    return [("NET: ", "default", False),
            (f"{sign}{fmt_usd_for(symbol, abs(net_usd))} ({net_pct:.2f}%)", color_for(net_usd), True)]

def append_history(ts_iso, pair_detail, sym_summary):
    Path("data").mkdir(exist_ok=True)
    rows=[]
    for sym in sym_summary["symbol"].dropna().unique().tolist():
        sub = pair_detail[pair_detail["symbol"]==sym].sort_values("edge_pct", ascending=False).head(1)
        if sub.empty: continue
        r=sub.iloc[0]
        calc = compute_net_for_pair(sym, r["buy_ex"], float(r["buy"]), r["sell_ex"], float(r["sell"]))
        rows.append({
            "timestamp": ts_iso,
            "symbol": sym,
            "buy_ex": r["buy_ex"], "buy": float(r["buy"]),
            "sell_ex": r["sell_ex"], "sell": float(r["sell"]),
            "gross_spread_usd": calc["gross_usd"],
            "gross_spread_pct": calc["gross_pct"],
            "fees_usd": calc["fees_usd"],
            "net_spread_usd": calc["net_usd"],
            "net_spread_pct": calc["net_pct"],
        })
    if rows:
        f1="data/best_edges.csv"; hdr = not Path(f1).exists()
        pd.DataFrame(rows).to_csv(f1, mode="a", index=False, header=hdr)

    sym = sym_summary.copy()
    sym.insert(0, "timestamp", ts_iso)
    f2="data/sym_summary.csv"; hdr2 = not Path(f2).exists()
    sym.to_csv(f2, mode="a", index=False, header=hdr2)

def run():
    df = fetch_tickers()
    pivot, sym_summary, pair_detail = calc_spreads(df)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # Titles split: big header + date on next line
    title_main = "Daily Crypto Arbitrage"
    title_date = now

    # Build augmented pair dataframe with fee breakdowns
    pd2 = pair_detail.copy()
    if not pd2.empty:
        net_fields = pd2.apply(
            lambda r: compute_net_for_pair(r["symbol"], r["buy_ex"], float(r["buy"]), r["sell_ex"], float(r["sell"])),
            axis=1
        )
        pd2 = pd.concat([pd2.reset_index(drop=True), pd.DataFrame(list(net_fields))], axis=1)
        best_net = pd2.sort_values(["net_pct"], ascending=False).head(1)
    else:
        best_net = pd.DataFrame()

    # Spotlight/Best trade (as spans so we can color)
    best_trade_spans = None
    if not best_net.empty and np.isfinite(best_net.iloc[0]["gross_usd"]):
        b = best_net.iloc[0]
        sym = b["symbol"]
        gross_s = fmt_usd_for(sym, b["gross_usd"])
        best_trade_spans = [
            ("Best right now — ", "default", False),
            ("GROSS ", "default", True),
            (f"+{gross_s} ", "green", True),
            (f"({b['gross_pct']:.2f}%)  ", "green", False),
            ("| NET ", "default", True),
            (("+" if b["net_usd"]>=0 else "-") + fmt_usd_for(sym, abs(b["net_usd"])) + f" ({b['net_pct']:.2f}%)", color_for(b["net_usd"]), True),
            ("  |  ", "default", False),
            (f"buy {b['buy_ex']} @ {fmt_price(sym, b['buy'])} → sell {b['sell_ex']} @ {fmt_price(sym, b['sell'])}", "default", False),
        ]

    # Bulleted “Top Opportunities” as spans (fees in blue)
    bullets_spans = []
    if not pd2.empty:
        for p in pd2.sort_values(["gross_usd"], ascending=False).head(8).itertuples():
            sym = p.symbol
            items = [
                # GROSS first in green
                ("GROSS ", "default", True),
                ("+" if p.gross_usd>=0 else "-", color_for(p.gross_usd), True),
                (fmt_usd_for(sym, abs(p.gross_usd)) + f" ({p.gross_pct:.2f}%)  ", color_for(p.gross_usd), True),
                ("| ", "default", False),
                # Route
                (f"buy {p.buy_ex} @ {fmt_price(sym, p.buy)} → sell {p.sell_ex} @ {fmt_price(sym, p.sell)}  | ", "default", False),
            ]
            # Fees (always blue)
            items += make_fee_spans(sym, p.taker_buy, p.taker_buy_usd, p.taker_sell, p.taker_sell_usd, p.withdraw_coin, p.withdraw_usd)
            items += [("  | NET ", "default", True),
                      (("+" if p.net_usd>=0 else "-") + fmt_usd_for(sym, abs(p.net_usd)) + f" ({p.net_pct:.2f}%)", color_for(p.net_usd), True)]
            bullets_spans.append(items)

    # KPIs (unchanged except formatting)
    btc_free, btc_total = get_btc_balance()
    btc_row = sym_summary[sym_summary["symbol"]=="BTC/USD"].head(1)
    if not btc_row.empty:
        rr=btc_row.iloc[0]
        btc_spread_pct=float(rr["spread_pct"]); btc_spread_abs=float(rr["spread_abs"])
    else:
        btc_spread_pct=btc_spread_abs=np.nan

    kpis=[
        ("BTC Balance", f"{btc_free:.8f} BTC", f"Total: {btc_total:.8f} BTC", "💰"),
        ("BTC Spread", f"gross {fmt_usd_for('BTC/USD', btc_spread_abs)} • {('—' if np.isnan(btc_spread_pct) else f'{btc_spread_pct:.2f}%')}", "", "📐"),
        ("Top Net Edge", (f"{fmt_usd_for(best_net.iloc[0]['symbol'], float(best_net.iloc[0]['net_usd']))}  •  {best_net.iloc[0]['net_pct']:.2f}%") if not best_net.empty else "—",
         "After fees across all symbols", "⚡"),
    ]

    # Best of BTC & XRP tiles (keep your existing tile code — they’ll remain colored as built)

    # Live charts
    tv_urls=[tradingview_widgetembed("COINBASE:BTCUSD"), tradingview_widgetembed("COINBASE:XRPUSD")]

    # Write history
    now_iso = datetime.now(timezone.utc).isoformat()
    append_history(now_iso, pd2, sym_summary)

    publish_dashboard(
        kpis=kpis,
        best_trade_spans=None,      # using spans instead
        bullets_spans=None,              # using spans instead
        embed_urls=tv_urls,
        spotlight_big=None,
        spotlight_sub=None,
        best_of_tiles=None,
        after_best_of_images=None,
        replace_mode=True,
        embed_row_first=True,
        title_main="Daily Crypto Arbitrage",
        title_date=now,
    )
    print("Published Notion dashboard (fees in blue).")

if __name__=="__main__":
    run()