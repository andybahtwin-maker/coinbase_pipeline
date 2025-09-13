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
