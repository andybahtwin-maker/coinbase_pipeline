import os, sys
from orchestrate_feeds import collect_metrics
from visual_display import display_metrics
from notion_publish import publish_to_notion

def main():
    page_id = os.getenv("PAGE_ID", "").strip()
    rows = collect_metrics()
    display_metrics(rows)
    if page_id:
        ok, msg = publish_to_notion(page_id, rows)
        print(("✅ " if ok else "⚠️ ") + msg)
    else:
        print("ℹ️ PAGE_ID not set; rendered to terminal only.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
