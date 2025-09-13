#!/usr/bin/env bash
set -euo pipefail
DIR=$(dirname "$0")
cd "$DIR"
python3 generate_metrics.py || true
# simple server
PORT=${PORT:-8080}
( python3 -m http.server "$PORT" >/dev/null 2>&1 & echo $! > .server.pid )
SERVER_PID=$(cat .server.pid)
trap 'kill $SERVER_PID 2>/dev/null || true; rm -f .server.pid' EXIT

printf "\n  ▶ Dashboard at: http://localhost:%s/dashboard/\n\n" "$PORT"
# Basic file watcher loop (polling)
while true; do
  python3 generate_metrics.py || true
  sleep 5
done
