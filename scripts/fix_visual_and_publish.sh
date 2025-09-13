#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-$HOME/projects/coinbase_pipeline}"
cd "$REPO"

# 1) ensure visual_display.py exists (create if missing)
if [[ ! -f visual_display.py ]]; then
  cat <<'PY' > visual_display.py
from typing import Dict, Tuple
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.columns import Columns
except Exception:
    # minimal fallback so imports don't break in Notion-only flows
    def display_metrics(metrics: Dict[str, Tuple[float, bool]]) -> None:
        for k, (v, is_fee) in metrics.items():
            print(f"{k}: {v} ({'fee' if is_fee else 'val'})")
    raise SystemExit(
        "visual_display.py: 'rich' is missing. Install it or ignore if you're only publishing to Notion."
    )

def _color_for(value: float, is_fee: bool) -> str:
    if is_fee:
        return "blue"
    return "green" if value >= 0 else "red"

def make_box(label: str, value: float, is_fee: bool = False) -> "Panel":
    color = _color_for(value, is_fee)
    text = f"[bold {color}]{value:.6f}[/bold {color}]"
    return Panel(text, title=label, border_style=color, padding=(1, 2))

def display_metrics(metrics: Dict[str, Tuple[float, bool]]) -> None:
    console = Console()
    panels = [make_box(label, val, fee) for label, (val, fee) in metrics.items()]
    console.print(Columns(panels))
PY
fi

# 2) deps
grep -qi '^rich' requirements.txt 2>/dev/null || echo 'rich>=13.7' >> requirements.txt
grep -qi '^pyyaml' requirements.txt 2>/dev/null || echo 'pyyaml>=6.0' >> requirements.txt

if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt
fi

# 3) run your existing Notion publisher via the bridge
./scripts/publish_via_existing_notion.sh
