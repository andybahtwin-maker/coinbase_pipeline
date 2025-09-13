#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

# Ensure required deps are listed
need() { grep -qi "^$1" requirements.txt 2>/dev/null || echo "$1" >> requirements.txt; }
touch requirements.txt
need "httpx>=0.27"
need "rich>=13.7"
need "pyyaml>=6.0"
need "python-dotenv>=1.0"
need "pandas>=2.2"
need "matplotlib>=3.9"
need "plotext>=5.2"
need "requests>=2.32"

# Install deps
if [[ -d .venv ]]; then
  ./.venv/bin/pip install -q -r requirements.txt
else
  echo "ℹ️ No .venv — using system python."
  python3 -m pip install -q -r requirements.txt
fi

# Run the verbose Notion publish (this also loads .env and logs)
./scripts/publish_notion_colored_verbose.sh
