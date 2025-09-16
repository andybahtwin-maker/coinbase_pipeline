#!/bin/bash
set -e

cd ~/projects/coinbase_pipeline

# Back up the current file
cp -n streamlit_app_full.py streamlit_app_full.py.bak_cleanup

# Remove any lines that are just "\1"
sed -i '/^\\1$/d' streamlit_app_full.py

echo "Cleaned up stray \\1 ✅"
echo "Now run:"
echo "  . .venv/bin/activate && streamlit run streamlit_app_full.py"
