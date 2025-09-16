#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

VENV=".venv/bin/activate"
[ -f "$VENV" ] && . "$VENV" || true

CMD="${1:-web}"   # web | notion | both
APP="${APP_FILE:-streamlit_app_full.py}"
NOTION_ENTRY="${NOTION_ENTRY:-notion_publish.py}"

case "$CMD" in
  web)
    exec streamlit run "$APP"
    ;;
  notion)
    if [ ! -f "$NOTION_ENTRY" ]; then
      echo "❌ Notion entry script not found at $NOTION_ENTRY"
      echo "   Set NOTION_ENTRY=path/to/your_script.py and re-run."
      exit 1
    fi
    : "${NOTION_TOKEN:?Set NOTION_TOKEN in env}"
    : "${NOTION_PAGE_ID:?Set NOTION_PAGE_ID in env}"
    python "$NOTION_ENTRY"
    ;;
  both)
    # Run notion once, then launch web
    "$0" notion
    exec "$0" web
    ;;
  *)
    echo "Usage: ./run.sh [web|notion|both]"
    exit 2
    ;;
esac
