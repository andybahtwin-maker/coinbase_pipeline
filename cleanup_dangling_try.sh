#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_dangling_try.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
lines = Path("streamlit_app_full.py").read_text().splitlines()
out = []
for i, line in enumerate(lines):
    if line.strip() == "try:":
        # Look ahead for real body
        j = i + 1
        has_body = False
        while j < len(lines):
            nxt = lines[j]
            if nxt.strip() == "" or nxt.strip().startswith("#"):
                j += 1
                continue
            if (len(nxt) - len(nxt.lstrip())) > (len(line) - len(line.lstrip())):
                has_body = True
            break
        if not has_body:
            indent = len(line) - len(line.lstrip())
            out.append(" " * indent + "# removed empty try: (caused SyntaxError)")
            continue
    out.append(line)
Path("streamlit_app_full.py").write_text("\n".join(out))
print("Dangling try: lines removed ✅")
PY
