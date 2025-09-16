#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
grep -q '^streamlit\b' requirements.txt 2>/dev/null || echo "streamlit" >> requirements.txt
grep -q '^pandas\b' requirements.txt 2>/dev/null || echo "pandas>=2.0" >> requirements.txt
grep -q '^altair\b' requirements.txt 2>/dev/null || echo "altair>=5.0" >> requirements.txt
pip install -r requirements.txt
streamlit run streamlit_app_full.py
