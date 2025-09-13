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
