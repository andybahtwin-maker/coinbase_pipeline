#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Prevent overlap (if a run is still going, skip)
exec /usr/bin/flock -n /tmp/coinbase_pipeline.lock bash -c '
  . .venv/bin/activate
  python fetch_and_publish.py >> logs/run.log 2>&1
'
