from typing import Dict, Any, List

def _color_for(key: str, value):
    k = (key or "").lower()
    is_num = isinstance(value, (int, float))
    if any(t in k for t in ("fee", "tax", "commission", "gas", "maker", "taker", "spread")):
        return "blue"
    if is_num:
        if value is None:
            return None
        if value > 0:
            return "green"
        if value < 0:
            return "red"
    return None

def display_metrics(rows: List[Dict[str, Any]]) -> None:
    """
    Accepts a list of per-pair dicts and prints a Rich table with colors:
    - Positive numbers = green
    - Negative numbers = red
    - Fees/spread = blue
    """
    try:
        from rich.console import Console
        from rich.table import Table
        from rich import box

        console = Console()
        table = Table(title="Coinbase Live Metrics", box=box.MINIMAL_DOUBLE_HEAD)
        cols = ["pair","spot","24h_low","24h_high","best_bid","best_ask","spread_pct","fee_buy_pct","fee_sell_pct","effective_buy","effective_sell","edge_after_fees_pct"]
        for c in cols:
            table.add_column(c, justify="right" if c!="pair" else "left", no_wrap=True)

        for r in rows:
            row_out = []
            for c in cols:
                v = r.get(c)
                s = "" if v is None else (f"{v:,.6f}" if isinstance(v, float) else str(v))
                color = _color_for(c, v)
                row_out.append(f"[{color}]{s}[/{color}]" if color else s)
            table.add_row(*row_out)

        console.print(table)
    except Exception:
        # Fallback plain text
        for r in rows:
            print("----")
            for k, v in r.items():
                color = _color_for(k, v)
                tag = {"green":"[+]", "red":"[-]", "blue":"[fee]"}.get(color, "[ ]")
                print(f"{tag} {k}: {v}")
