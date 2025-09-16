#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

cp -n streamlit_app_full.py streamlit_app_full.py.bak_unclosed || true

python - <<'PY'
from pathlib import Path
import re

p = Path("streamlit_app_full.py")
s = p.read_text().splitlines()

out = []
for i, line in enumerate(s, start=1):
    # If this is the suspect layout line, check if previous line was a bare "try:"
    if "top_left, top_right = st.columns" in line:
        if out and out[-1].strip() == "try:":
            # insert a placeholder except before continuing
            out.append("    pass  # body of try was empty, avoid SyntaxError")
            out.append("except Exception as e:")
            out.append("    st.error(f'Error before layout: {e}')")
        out.append(line)
    else:
        out.append(line)

p.write_text("\n".join(out))
print("Patched: inserted missing except for dangling try ✅")
PY
