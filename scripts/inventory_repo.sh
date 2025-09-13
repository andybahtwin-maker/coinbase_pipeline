#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$PWD}"
cd "$ROOT"

echo "=== repo root: $ROOT ==="
echo
echo "## git status:"
git status -s || true
echo

echo "## python files (count by directory):"
find . -type f -name '*.py' | sed 's|/[^/]*$|/|g' | sort | uniq -c | sort -nr
echo

echo "## likely provider modules (names containing exchange / feed / price):"
grep -RIl --include='*.py' -E 'coinbase|coingecko|kraken|binance|kucoin|gemini|bybit|feed|price|quotes' | sed 's|^\./||' | sort
echo

echo "## functions that look like fetchers:"
grep -RIn --include='*.py' -E 'def\s+(fetch|get|quote)[a-zA-Z0-9_]*\(' | sed 's|^\./||' | sort | head -n 200
echo

echo "## references to http clients (httpx/requests/websocket):"
grep -RIn --include='*.py' -E 'httpx|requests|websocket|wss://' | sed 's|^\./||' | sort | head -n 200
echo

echo "## top 20 largest tracked files:"
git ls-files -z | xargs -0 du -h | sort -hr | head -n 20 || true
echo

echo "## potential duplicates by hash (top offenders):"
tmpfile="$(mktemp)"
find . -type f -name '*.py' -print0 | xargs -0 -I{} sh -c 'sha1sum "{}"' > "$tmpfile"
cut -d' ' -f1 "$tmpfile" | sort | uniq -cd | sort -nr | head -n 20
rm -f "$tmpfile" || true
