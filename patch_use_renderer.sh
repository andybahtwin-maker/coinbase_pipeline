#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_use_renderer.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
p = Path("streamlit_app_full.py")
text = p.read_text()

# 1) Normalize tabs and remove any stray "\1" lines that break parsing
text = text.replace("\t","    ")
text = "\n".join([ln for ln in text.splitlines() if ln.strip() != r"\1"])

# 2) Ensure import for the external renderer
if "from symbol_renderer import render_symbol" not in text:
    # put after the streamlit/os imports
    if "import os" in text:
        text = text.replace("import os", "import os\nfrom symbol_renderer import render_symbol", 1)
    else:
        text = text.replace("import streamlit as st", "import streamlit as st\nimport os\nfrom symbol_renderer import render_symbol", 1)

# 3) Replace the entire body of `for sym in syms:` with a minimal, clean body.
lines = text.splitlines()
start = None
base = 0
for i, ln in enumerate(lines):
    if "for sym in syms:" in ln:
        start = i
        base = len(ln) - len(ln.lstrip())
        break

if start is not None:
    j = start + 1
    while j < len(lines):
        stripped = lines[j].strip()
        if stripped and not stripped.startswith("#"):
            indent = len(lines[j]) - len(lines[j].lstrip())
            if indent <= base:
                break
        j += 1
    end = j  # exclusive

    pad = " " * (base + 4)
    new_body = [
        pad + "data = fetch_prices(sym)",
        pad + "taker_pct = float(os.getenv('TAKER_PCT', '0.19'))",
        pad + "maker_pct = float(os.getenv('MAKER_PCT', '0.10'))",
        pad + "render_symbol(sym, data, trade_usd, role, taker_pct, maker_pct)",
    ]
    lines = lines[:start+1] + new_body + lines[end:]

# 4) Write back
p.write_text("\n".join(lines) + "\n")
print("Patched to use external renderer ✅")
PY
