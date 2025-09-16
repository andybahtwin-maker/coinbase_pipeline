#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
cp -n "$FILE" "${FILE}.bak_indent.$(date +%s)" || true

python - <<'PY'
from pathlib import Path
p = Path("streamlit_app_full.py")
text = p.read_text().replace("\t", "    ")

out = []
skip = False
for line in text.splitlines():
    if "roundtrip_fee" in line and "f_stamp" in line:
        # drop this bad line, we’ll re-insert in the right spot
        skip = True
        continue
    out.append(line)

# Add clean version of the line after the fee columns block
fixed = []
for i, ln in enumerate(out):
    fixed.append(ln)
    if "st.caption(f\"{role} fee" in ln:
        pad = " " * (len(ln) - len(ln.lstrip()))
        fixed.append(pad + "roundtrip_fee = f_stamp + f_finex")

p.write_text("\n".join(fixed) + "\n")
print("Indentation fixed ✅")
PY
