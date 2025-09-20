#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# prefer demo page so portfolio never renders blank
if [ -f "ui/portfolio_demo.py" ]; then
  if python -c "import importlib.util as i; exit(0 if i.find_spec('streamlit') else 1)" >/dev/null 2>&1; then
    exec python -m streamlit run ui/portfolio_demo.py --server.headless true
  else
    echo "[i] Installing minimal demo deps (streamlit, pandas, plotly)…"
    python -m pip install --upgrade pip >/dev/null 2>&1 || true
    python -m pip install streamlit pandas plotly >/dev/null 2>&1 || true
    exec python -m streamlit run ui/portfolio_demo.py --server.headless true
  fi
fi

# fallback: launch any other entry if present
for f in app.py visual_display.py dashboard.py streamlit_app.py src/app.py ui/app.py; do
  [ -f "$f" ] && { ENTRY="$f"; break; }
done
if [ -n "${ENTRY:-}" ]; then
  if python -c "import importlib.util as i; exit(0 if i.find_spec('streamlit') else 1)" >/dev/null 2>&1; then
    exec python -m streamlit run "$ENTRY" --server.headless true
  else
    exec python "$ENTRY"
  fi
fi

echo "[!] No UI entry found. Expected ui/portfolio_demo.py or app.py."
exit 1
