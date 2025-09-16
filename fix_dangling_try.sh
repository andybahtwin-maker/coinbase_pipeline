#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_tryfix.$(date +%s)" || true

python - <<'PY'
from pathlib import Path

p = Path("streamlit_app_full.py")
lines = p.read_text().splitlines()
out = []
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == "try:":
        # Look ahead: is there a body?
        j = i + 1
        while j < len(lines) and lines[j].strip() in ("", "#"):
            j += 1
        if j >= len(lines) or lines[j].startswith((" ", "\t")) is False:
            # No valid body → comment out
            indent = len(line) - len(line.lstrip())
            out.append(" " * indent + "# [FIXED] removed dangling try:")
            continue
    out.append(line)

p.write_text("\n".join(out))
print("Removed dangling try: statements ✅")
PY
