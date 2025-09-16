#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "🔎 Searching for Notion references..."
rg -n --hidden -S "(notion|NOTION_|notion\.client|notion_client|notion-sdk)" || true

echo
echo "🔎 Looking for runnable scripts (has __main__):"
rg -n --hidden -S "__name__\s*==\s*['\"]__main__['\"]" || true

echo
echo "💡 If you see something like notion_publish.py or similar, that is your Notion pipeline entry point."
