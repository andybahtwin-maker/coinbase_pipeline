set -euo pipefail
pkill -f "streamlit run" 2>/dev/null || true
rm -rf ~/.cache/streamlit ~/.streamlit/logs 2>/dev/null || true
echo "Streamlit reset done."
