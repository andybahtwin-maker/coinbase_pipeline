#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="\${1:-$PWD}"
cd "\$REPO_DIR"

if [[ ! -d .git ]]; then
  echo "❌ Not a git repo: \$REPO_DIR"; exit 1
fi

STAMP="$(date +%F-%H%M%S)"
BACKUP="coinbase_pipeline-backup-\$STAMP.tar.gz"
echo "🧷 Creating backup: \$BACKUP"
tar -czf "\$BACKUP" .

git rev-parse --abbrev-ref HEAD >/dev/null 2>&1 || { echo "❌ Not on a branch"; exit 1; }
git checkout -b chore/cleanup-visual-display 2>/dev/null || git checkout chore/cleanup-visual-display

mkdir -p scripts examples integrations

if [[ ! -f requirements.txt ]]; then
  printf "httpx<0.28\nrich>=13.7\npython-dotenv>=1.0\n" > requirements.txt
else
  grep -Ei '^\s*rich([<>=]|$)' requirements.txt >/dev/null || echo "rich>=13.7" >> requirements.txt
  grep -Ei '^\s*python-dotenv([<>=]|$)' requirements.txt >/dev/null || echo "python-dotenv>=1.0" >> requirements.txt
fi

cat <<'PY' > visual_display.py
from typing import Dict, Tuple
from rich.console import Console
from rich.panel import Panel
from rich.columns import Columns

def _color_for(value: float, is_fee: bool) -> str:
    if is_fee:
        return "blue"
    return "green" if value >= 0 else "red"

def make_box(label: str, value: float, is_fee: bool = False) -> Panel:
    color = _color_for(value, is_fee)
    text = f"[bold {color}]{value:.6f}[/bold {color}]"
    return Panel(text, title=label, border_style=color, padding=(1, 2))

def display_metrics(metrics: Dict[str, Tuple[float, bool]]) -> None:
    console = Console()
    panels = [make_box(label, val, fee) for label, (val, fee) in metrics.items()]
    console.print(Columns(panels))
PY

cat <<'PY' > show_metrics.py
import json, sys
from visual_display import display_metrics

def main(path: str):
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    metrics = {}
    for k, v in raw.items():
        if isinstance(v, list) and len(v) == 2:
            value, is_fee = v
            metrics[k] = (float(value), bool(is_fee))
        elif isinstance(v, dict) and "value" in v and "is_fee" in v:
            metrics[k] = (float(v["value"]), bool(v["is_fee"]))
        else:
            raise ValueError(f"Bad metric format for {k}: {v}")
    display_metrics(metrics)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: .venv/bin/python show_metrics.py examples/sample_metrics.json")
        sys.exit(1)
    main(sys.argv[1])
PY

cat <<'JSON' > examples/sample_metrics.json
{
  "BTC Spread %": [0.0213, false],
  "XRP Spread %": [-0.0127, false],
  "Gas Fee (USD)": [0.82, true],
  "Net Profit (USD)": [4.91, false]
}
JSON

cat <<'SH' > scripts/show_metrics.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d "$ROOT/.venv" ]]; then
  "$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
  "$ROOT/.venv/bin/python" "$ROOT/show_metrics.py" "$ROOT/examples/sample_metrics.json"
else
  echo "⚠️ .venv not found — using system python."
  python3 -m pip install -q -r "$ROOT/requirements.txt"
  python3 "$ROOT/show_metrics.py" "$ROOT/examples/sample_metrics.json"
fi
SH
chmod +x scripts/show_metrics.sh

cat <<'PY' > scripts/fix_duplicate_kwarg.py
from pathlib import Path
TARGET = "bullets_spans="

def fix_file(p: Path) -> bool:
    text = p.read_text(encoding="utf-8")
    lines = text.splitlines()
    seen = False
    out = []
    changed = False
    for ln in lines:
        if TARGET in ln:
            if seen:
                changed = True
                continue
            seen = True
        out.append(ln)
    if changed:
        p.with_suffix(p.suffix + ".bak").write_text(text, encoding="utf-8")
        p.write_text("\n".join(out), encoding="utf-8")
    return changed

def main():
    root = Path(".")
    any_changed = False
    for p in root.rglob("*.py"):
        if p.name == "fix_duplicate_kwarg.py":
            continue
        try:
            if p.read_text(encoding="utf-8").count(TARGET) > 1:
                print("Fixing:", p)
                if fix_file(p):
                    print("  ✅ fixed (backup saved)")
                    any_changed = True
        except Exception as e:
            print("  ❌ error:", p, e)
    if not any_changed:
        print("No duplicate keyword occurrences found.")

if __name__ == "__main__":
    main()
PY

cat <<'PY' > integrations/visual_hook.py
from typing import Optional
from visual_display import display_metrics

def display_from_numbers(
    btc_spread_pct: Optional[float],
    xrp_spread_pct: Optional[float],
    gas_fee_usd: Optional[float],
    net_profit_usd: Optional[float],
):
    metrics = {}
    if btc_spread_pct is not None:
        metrics["BTC Spread %"] = (btc_spread_pct, False)
    if xrp_spread_pct is not None:
        metrics["XRP Spread %"] = (xrp_spread_pct, False)
    if gas_fee_usd is not None:
        metrics["Gas Fee (USD)"] = (gas_fee_usd, True)
    if net_profit_usd is not None:
        metrics["Net Profit (USD)"] = (net_profit_usd, False)
    if metrics:
        display_metrics(metrics)
PY

if [[ -d .venv ]]; then
  ./.venv/bin/pip install -r requirements.txt
else
  echo "ℹ️ No .venv found. Create with: python3 -m venv .venv && . .venv/bin/activate"
  python3 -m pip install -r requirements.txt
fi

git add .
git commit -m "chore: visual box UI, JSON demo, dupe-kwarg fixer, tidy structure" || true
echo "✅ Cleanup & visual layer added."
