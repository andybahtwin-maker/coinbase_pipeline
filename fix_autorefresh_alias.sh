#!/bin/bash
set -euo pipefail

FILE="streamlit_app_full.py"
BACKUP="${FILE}.bak.$(date +%s)"

echo "📦 Backing up $FILE -> $BACKUP"
cp "$FILE" "$BACKUP"

# Insert a new shim or update the existing one
awk '
BEGIN {patched=0}
{
  if ($0 ~ /^def _safe_autorefresh/) {
    print "def _safe_autorefresh(*, seconds=None, interval=None, key=None, help=None):"
    print "    \"\"\"Shim: allow both seconds= and interval= (ms).\"\"\""
    print "    if interval is not None:"
    print "        try:"
    print "            ms = int(interval)"
    print "            seconds = ms // 1000"
    print "        except Exception:"
    print "            seconds = None"
    print "    if seconds is None:"
    print "        seconds = int(os.getenv(\"AUTO_SEC\", \"300\"))"
    print "    _quick_auto_refresh(seconds=seconds)"
    print "    return True"
    patched=1
    next
  }
}
{print}
END {
  if (patched==0) {
    print ""
    print "def _safe_autorefresh(*, seconds=None, interval=None, key=None, help=None):"
    print "    \"\"\"Shim: allow both seconds= and interval= (ms).\"\"\""
    print "    if interval is not None:"
    print "        try:"
    print "            ms = int(interval)"
    print "            seconds = ms // 1000"
    print "        except Exception:"
    print "            seconds = None"
    print "    if seconds is None:"
    print "        seconds = int(os.getenv(\"AUTO_SEC\", \"300\"))"
    print "    _quick_auto_refresh(seconds=seconds)"
    print "    return True"
  }
}
' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

echo "✅ Patched $FILE with interval→seconds support"
