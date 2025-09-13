#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-$HOME/projects/coinbase_pipeline}"
cd "$REPO"

mkdir -p providers analytics scripts config logs/feeds snapshots
: > providers/__init__.py
: > analytics/__init__.py

# ---------------- requirements ----------------
grep -qi '^httpx' requirements.txt 2>/dev/null || cat >> requirements.txt <<'REQ'
httpx>=0.27
rich>=13.7
pyyaml>=6.0
python-dotenv>=1.0
pandas>=2.2
matplotlib>=3.9
plotext>=5.2
REQ

# ---------------- config ----------------
cat > config/feeds.yaml <<'YML'
symbols: ["BTC-USD", "XRP-USD"]
providers:
  coinbase:
    enabled: true
    module: "providers.coinbase_adv"
    fn: "fetch_prices"
  kraken:
    enabled: true
    module: "providers.kraken_pub"
    fn: "fetch_prices"
  binance:
    enabled: true
    module: "providers.binance_pub"
    fn: "fetch_prices"
  coingecko:
    enabled: true
    module: "providers.coingecko_pub"
    fn: "fetch_prices"
fees:
  # default % fees (can be exchange-specific in fees.yaml too)
  taker_pct_default: 0.004   # 0.40%
  maker_pct_default: 0.001   # 0.10%
  gas_overhead_usd:
    BTC-USD: 2.50
    XRP-USD: 0.01
render:
  decimals: 6
  history_points: 120    # how many points to keep for ASCII sparkline / PNG
  refresh_seconds: 30    # for the live loop (script below)
YML

# Optional per-exchange fee overrides
cat > config/fees.yaml <<'YML'
exchanges:
  coinbase:
    taker_pct: 0.006
    maker_pct: 0.002
  kraken:
    taker_pct: 0.0026
    maker_pct: 0.0016
  binance:
    taker_pct: 0.001
    maker_pct: 0.001
YML

# ---------------- providers ----------------
# Coinbase (public ticker endpoint; API key optional)
cat > providers/coinbase_adv.py <<'PY'
import os, httpx
from typing import Dict, List

def _cb_symbol(sym: str) -> str:
    return sym  # e.g., "BTC-USD"

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    out = {}
    headers = {}
    # If you want, set COINBASE_API_KEY in .env; not required for public tickers
    api_key = os.getenv("COINBASE_API_KEY") or os.getenv("CB_API_KEY")
    if api_key:
        headers["CB-ACCESS-KEY"] = api_key
    with httpx.Client(timeout=10) as s:
        for sym in symbols:
            p = _cb_symbol(sym)
            r = s.get(f"https://api.exchange.coinbase.com/products/{p}/ticker", headers=headers)
            if r.status_code == 200:
                data = r.json()
                out[sym] = float(data["price"])
    return out
PY

# Kraken
cat > providers/kraken_pub.py <<'PY'
import httpx
from typing import Dict, List

_MAP = {
    "BTC-USD": "XXBTZUSD",
    "XRP-USD": "XRPUSD",
}

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    pairs = ",".join(_MAP[s] for s in symbols if s in _MAP)
    if not pairs:
        return {}
    r = httpx.get(f"https://api.kraken.com/0/public/Ticker?pair={pairs}", timeout=10)
    r.raise_for_status()
    j = r.json()["result"]
    rev = {v:k for k,v in _MAP.items()}
    out = {}
    for k, v in j.items():
        sym = rev.get(k)
        if not sym: continue
        out[sym] = float(v["c"][0])
    return out
PY

# Binance (uses USDT; treat ~USD)
cat > providers/binance_pub.py <<'PY'
import httpx
from typing import Dict, List

def _bn_symbol(sym: str) -> str:
    if sym.endswith("-USD"):
        base = sym.split("-")[0]
        return f"{base}USDT"
    return sym.replace("-", "")

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    out = {}
    with httpx.Client(timeout=10) as s:
        for sym in symbols:
            b = _bn_symbol(sym)
            r = s.get("https://api.binance.com/api/v3/ticker/price", params={"symbol": b})
            if r.status_code == 200:
                out[sym] = float(r.json()["price"])
    return out
PY

# CoinGecko
cat > providers/coingecko_pub.py <<'PY'
import httpx
from typing import Dict, List

_MAP = {
    "BTC-USD": "bitcoin",
    "XRP-USD": "ripple",
}

def fetch_prices(symbols: List[str]) -> Dict[str, float]:
    ids = ",".join(_MAP[s] for s in symbols if s in _MAP)
    if not ids:
        return {}
    r = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                  params={"ids": ids, "vs_currencies": "usd"}, timeout=10)
    r.raise_for_status()
    j = r.json()
    out = {}
    for s in symbols:
        cid = _MAP.get(s)
        if cid and cid in j and "usd" in j[cid]:
            out[s] = float(j[cid]["usd"])
    return out
PY

# ---------------- fees (network + maker/taker) ----------------
cat > analytics/fees.py <<'PY'
import os, httpx, yaml
from typing import Dict

def load_fee_overrides() -> Dict:
    try:
        with open("config/fees.yaml","r",encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {}

def exchange_fee_pct(name: str, taker: bool=True) -> float:
    ovr = load_fee_overrides().get("exchanges",{}).get(name.lower(),{})
    key = "taker_pct" if taker else "maker_pct"
    if key in ovr:
        return float(ovr[key])
    # fallback to defaults
    import yaml
    base = yaml.safe_load(open("config/feeds.yaml","r",encoding="utf-8").read())
    dflt = float(base.get("fees",{}).get("taker_pct_default" if taker else "maker_pct_default", 0.002))
    return dflt

def gas_overhead_usd(sym: str) -> float:
    import yaml
    base = yaml.safe_load(open("config/feeds.yaml","r",encoding="utf-8").read())
    return float(base.get("fees",{}).get("gas_overhead_usd",{}).get(sym, 0.0))

def network_fee_estimates() -> Dict[str, float]:
    """
    Returns rough network fee in USD for BTC/XRP (best-effort).
    """
    out = {}
    try:
        r = httpx.get("https://mempool.space/api/v1/fees/recommended", timeout=10)
        if r.status_code == 200:
            sats_vb = r.json().get("halfHourFee") or r.json().get("fastestFee")
            # crude tx size 140 vB, BTCUSD ~ via coingecko
            px = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                           params={"ids":"bitcoin","vs_currencies":"usd"}, timeout=10).json()["bitcoin"]["usd"]
            fee_btc = (sats_vb * 140) / 1e8
            out["BTC-USD"] = float(fee_btc * px)
    except Exception:
        pass
    try:
        # XRP network fee (drops), say 12 drops baseline; fetch from rippled public
        r = httpx.get("https://s1.ripple.com:51234/", json={"method":"fee","params":[{}]}, timeout=10)
        if r.status_code == 200:
            d = r.json()["result"]["drops"]["open_ledger_fee"]
            # 1 XRP = 1,000,000 drops; price via gecko
            px = httpx.get("https://api.coingecko.com/api/v3/simple/price",
                           params={"ids":"ripple","vs_currencies":"usd"}, timeout=10).json()["ripple"]["usd"]
            xrp = int(d)/1_000_000
            out["XRP-USD"] = float(xrp * px)
    except Exception:
        pass
    return out
PY

# ---------------- arbitrage core ----------------
cat > analytics/arbitrage.py <<'PY'
from __future__ import annotations
import importlib, time, json
from typing import Dict, List, Tuple
from pathlib import Path
import yaml
from analytics.fees import exchange_fee_pct, gas_overhead_usd, network_fee_estimates

def load_config(path="config/feeds.yaml") -> dict:
    with open(path,"r",encoding="utf-8") as f:
        return yaml.safe_load(f)

def _load_fn(module_path: str, fn_name: str):
    mod = importlib.import_module(module_path)
    return getattr(mod, fn_name)

def collect_all_prices(symbols: List[str], providers_cfg: dict) -> Dict[str, Dict[str, float]]:
    book: Dict[str, Dict[str, float]] = {}
    for name, meta in providers_cfg.items():
        if not meta.get("enabled", False):
            continue
        fn = _load_fn(meta["module"], meta["fn"])
        prices = fn(symbols)
        if prices:
            book[name] = prices
    return book

def effective_price(raw: float, ex_name: str, sym: str, taker=True) -> float:
    pct = exchange_fee_pct(ex_name, taker=taker)
    gas = gas_overhead_usd(sym)
    # buy: pay price * (1+pct) + gas_per_unit; sell: receive price * (1-pct) - gas_per_unit
    # we'll return a tuple in caller
    return pct, gas

def analyze(symbols: List[str], providers_cfg: dict, notional=10_000.0):
    prices = collect_all_prices(symbols, providers_cfg)
    gas_live = network_fee_estimates()  # override gas if available
    metrics: Dict[str, Tuple[float,bool]] = {}
    tables = {}  # per-symbol breakdown

    for sym in symbols:
        # build per-provider effective buy/sell
        rows = []
        for ex, mapping in prices.items():
            if sym not in mapping: continue
            raw = mapping[sym]
            pct_taker = exchange_fee_pct(ex, taker=True)
            pct_maker = exchange_fee_pct(ex, taker=False)
            gas = gas_live.get(sym, gas_overhead_usd(sym))
            buy_eff  = raw * (1 + pct_taker) + gas  # assume taker buy
            sell_eff = raw * (1 - pct_taker) - gas  # assume taker sell
            rows.append({
                "exchange": ex,
                "raw": raw,
                "buy_eff": buy_eff,
                "sell_eff": sell_eff,
                "pct_taker": pct_taker,
                "gas_usd": gas,
            })

        if len(rows) < 2:
            continue

        # best route
        best_buy  = min(rows, key=lambda r: r["buy_eff"])
        best_sell = max(rows, key=lambda r: r["sell_eff"])
        spread_abs = best_sell["sell_eff"] - best_buy["buy_eff"]
        spread_pct = spread_abs / best_buy["buy_eff"] if best_buy["buy_eff"] else 0.0
        gross = notional * spread_pct
        net   = gross  # already fee-adjusted by using effective prices
        metrics[f"{sym} Net Spread % (fees incl)"] = (spread_pct, False)
        metrics[f"{sym} Est Profit @${int(notional)} (fees incl)"] = (net, False)
        metrics[f"{sym} Gas Fee (USD)"] = (best_buy["gas_usd"], True)

        tables[sym] = {
            "best_buy_ex": best_buy["exchange"],
            "best_sell_ex": best_sell["exchange"],
            "rows": rows,
            "spread_abs": spread_abs,
            "spread_pct": spread_pct,
        }

    # persist history for plots
    tdir = Path("logs/feeds"); tdir.mkdir(parents=True, exist_ok=True)
    Path("logs/feeds/last_prices.json").write_text(json.dumps(prices, indent=2), encoding="utf-8")
    Path("logs/feeds/last_tables.json").write_text(json.dumps(tables, indent=2), encoding="utf-8")
    return metrics, tables
PY

# ---------------- visual display (Rich) ----------------
cat > visual_display.py <<'PY'
from typing import Dict, Tuple, List
from rich.console import Console
from rich.panel import Panel
from rich.columns import Columns
from rich.table import Table
from rich.layout import Layout
import plotext as plt
from pathlib import Path
import json, time

def _color(value: float, fee: bool) -> str:
    return "blue" if fee else ("green" if value >= 0 else "red")

def make_box(label: str, value: float, fee=False) -> Panel:
    color = _color(value, fee)
    txt = f"[bold {color}]{value:.6f}[/bold {color}]"
    title = label
    return Panel(txt, title=title, border_style=color, padding=(1,2))

def make_boxes(metrics: Dict[str, Tuple[float,bool]]) -> Columns:
    panels = [make_box(k, v, fee) for k,(v,fee) in metrics.items()]
    return Columns(panels, equal=True, expand=True)

def render_table(sym: str, table_info: dict) -> Table:
    t = Table(title=f"{sym} (fees included in buy/sell)", expand=True)
    t.add_column("Exchange"); t.add_column("Raw"); t.add_column("BuyEff"); t.add_column("SellEff"); t.add_column("Taker%"); t.add_column("GasUSD")
    for r in table_info["rows"]:
        t.add_row(
            r["exchange"],
            f"{r['raw']:.6f}",
            f"[bold]{r['buy_eff']:.6f}[/bold]",
            f"[bold]{r['sell_eff']:.6f}[/bold]",
            f"{r['pct_taker']*100:.2f}%",
            f"[blue]{r['gas_usd']:.4f}[/blue]",
        )
    return t

def sparkline(sym: str, key: str):
    # key e.g. "spread_pct"
    hist_file = Path(f"logs/feeds/history_{sym.replace('-','_')}.json")
    if not hist_file.exists(): return None
    arr = json.loads(hist_file.read_text())[-120:]
    ys = [x.get(key,0) for x in arr]
    plt.clear_figure()
    plt.title(f"{sym} {key} (last {len(ys)})")
    plt.plot(ys)
    plt.canvas_color('default'); plt.axes_color('default')
    plt.ticks_color('default')
    plt.show()

def append_history(sym: str, spread_pct: float, spread_abs: float):
    hist_file = Path(f"logs/feeds/history_{sym.replace('-','_')}.json")
    arr = []
    if hist_file.exists():
        try:
            arr = json.loads(hist_file.read_text())
        except Exception:
            arr = []
    arr.append({"ts": time.time(), "spread_pct": spread_pct, "spread_abs": spread_abs})
    hist_file.write_text(json.dumps(arr, indent=0), encoding="utf-8")
PY

# ---------------- graphs (PNG) ----------------
cat > analytics/graphs.py <<'PY'
from pathlib import Path
import json, matplotlib.pyplot as plt

def save_spread_png(sym: str, window: int = 200):
    p = Path(f"logs/feeds/history_{sym.replace('-','_')}.json")
    if not p.exists(): return None
    arr = json.loads(p.read_text())[-window:]
    if not arr: return None
    xs = [a["ts"] for a in arr]
    ys = [a["spread_pct"]*100 for a in arr]
    plt.figure()
    plt.plot(xs, ys)
    plt.xlabel("time"); plt.ylabel("spread %")
    png = Path(f"snapshots/{sym.replace('-','_')}_spread.png")
    plt.savefig(png, bbox_inches="tight")
    plt.close()
    return str(png)
PY

# ---------------- orchestrator ----------------
cat > orchestrate_arbitrage.py <<'PY'
import os, json, time
from pathlib import Path
from typing import Dict, Tuple
import yaml
from analytics.arbitrage import load_config, analyze
from visual_display import make_boxes, render_table, append_history, sparkline
from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel

def console_view(metrics: Dict[str, Tuple[float,bool]], tables: dict):
    con = Console()
    layout = Layout()
    layout.split(
        Layout(name="top", size=7),
        Layout(name="bottom"),
    )
    layout["top"].update(Panel(make_boxes(metrics), title="Arbitrage Snapshot (fees incl)", border_style="white"))
    # bottom: tables per symbol
    inner = []
    for sym, info in tables.items():
        inner.append(render_table(sym, info))
        append_history(sym, info["spread_pct"], info["spread_abs"])
    con.print(layout)
    for w in inner:
        con.print(w)
    # ascii sparkline under each
    for sym in tables.keys():
        sparkline(sym, "spread_pct")

def main_once():
    cfg = load_config()
    symbols = cfg["symbols"]
    providers_cfg = cfg["providers"]
    metrics, tables = analyze(symbols, providers_cfg, notional=10_000.0)
    # include fee values in metric titles already; boxes will show blue for "Gas Fee"
    console_view(metrics, tables)
    Path("logs/feeds/last_metrics.json").write_text(json.dumps({k:[v,fee] for k,(v,fee) in metrics.items()}, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main_once()
PY

# ---------------- richer Notion publish (fees in titles) ----------------
python3 - <<'PY'
from pathlib import Path
p = Path("notion_publish.py")
if not p.exists():
    # create minimal shell if user didn't have one
    p.write_text("def main():\n    pass\n", encoding="utf-8")
s = p.read_text(encoding="utf-8")
snippet = r'''
def publish_boxes_colored(metrics: dict):
    """
    Richer layout: heading + 3 columns with colored numbers.
    Includes fee values in the titles.
    """
    import os, requests
    from datetime import datetime
    NOTION_API="https://api.notion.com/v1"; NOTION_VER="2022-06-28"
    token = os.environ.get("NOTION_TOKEN") or os.environ.get("NOTION_API_KEY")
    parent = os.environ.get("NOTION_PARENT_PAGE_ID") or os.environ.get("NOTION_PAGE_ID")
    if not token or not parent: raise RuntimeError("Notion env missing")
    def H(): return {"Authorization": f"Bearer {token}","Content-Type":"application/json","Notion-Version":NOTION_VER}
    prefix = os.environ.get("NOTION_TITLE_PREFIX","Arb Dashboard")
    title = f"{prefix} · {datetime.now().strftime('%Y-%m-%d %H:%M')}"
    pg = requests.post(f"{NOTION_API}/pages", headers=H(),
        json={"parent":{"type":"page_id","page_id":parent},"properties":{"title":[{"type":"text","text":{"content":title}}]}},
        timeout=30).json()
    page_id = pg["id"]
    # partition + fee title
    spreads, others, fees = [], [], []
    fee_title_bits=[]
    for k,(v,is_fee) in metrics.items():
        if is_fee:
            fees.append((k,v)); fee_title_bits.append(f"{k}={v:.4f}")
        elif "spread" in k.lower(): spreads.append((k,v))
        else: others.append((k,v))
    # heading with fee summary
    blocks=[{"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"Market Snapshot"}}]}}]
    if fee_title_bits:
        blocks.append({"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"Fees: "+", ".join(fee_title_bits)}}],"color":"blue"}})
    def colored(label, val, fee=False):
        color = "blue" if fee else ("green" if val>=0 else "red")
        return {"type":"paragraph","paragraph":{"rich_text":[
            {"type":"text","text":{"content":label+": "}},
            {"type":"text","text":{"content":f"{val:.6f}"},"annotations":{"bold":True,"color":color}}
        ]}}
    def col(title, arr, fee=False):
        children=[{"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":title}}]}}]
        if not arr: children.append({"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"(no data)"}}]}})
        else:
            for k,v in arr: children.append(colored(k,v,fee))
        return {"object":"block","type":"column","column":{"children":children}}
    col_list={"object":"block","type":"column_list","column_list":{"children":[
        col("Spreads (fees incl)", spreads, False),
        col("Metrics", others, False),
        col("Fees", fees, True),
    ]}}
    blocks.append(col_list)
    requests.patch(f"{NOTION_API}/blocks/{page_id}/children", headers=H(), json={"children":blocks}, timeout=30)
    return page_id
'''
if "def publish_boxes_colored(" not in s:
    p.write_text(s.rstrip()+"\n\n"+snippet, encoding="utf-8")
PY

# ---------------- runner scripts ----------------
cat > scripts/run_once.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d .venv ]]; then ./.venv/bin/pip install -q -r requirements.txt; ./.venv/bin/python orchestrate_arbitrage.py
else python3 -m pip install -q -r requirements.txt; python3 orchestrate_arbitrage.py; fi
SH
chmod +x scripts/run_once.sh

cat > scripts/live_loop.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
REFRESH="$(python3 - <<'PY'
import yaml; print(yaml.safe_load(open("config/feeds.yaml"))["render"]["refresh_seconds"])
PY
)"
while true; do
  clear
  date
  if [[ -d .venv ]]; then ./.venv/bin/python orchestrate_arbitrage.py; else python3 orchestrate_arbitrage.py; fi
  sleep "${REFRESH:-30}"
done
SH
chmod +x scripts/live_loop.sh

cat > scripts/publish_notion_colored.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# env compat
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"
export NOTION_PARENT_PAGE_ID="${NOTION_PARENT_PAGE_ID:-${NOTION_PAGE_ID:-}}"
# deps + run
if [[ -d .venv ]]; then ./.venv/bin/pip install -q -r requirements.txt; else python3 -m pip install -q -r requirements.txt; fi
python3 - <<'PY'
from analytics.arbitrage import load_config, analyze
from notion_publish import publish_boxes_colored
cfg=load_config(); syms=cfg["symbols"]; prov=cfg["providers"]
metrics,tables = analyze(syms, prov, notional=10_000.0)
publish_boxes_colored(metrics)
print("✅ published to notion (colored, fees in title)")
PY
SH
chmod +x scripts/publish_notion_colored.sh

# install deps once
if [[ -d .venv ]]; then ./.venv/bin/pip install -q -r requirements.txt; else python3 -m pip install -q -r requirements.txt; fi

echo "✅ Arbitrage suite installed."
echo "Run once in terminal UI:   scripts/run_once.sh"
echo "Live loop refresh:         scripts/live_loop.sh"
echo "Publish Notion colored:    scripts/publish_notion_colored.sh"
