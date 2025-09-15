import os
import json
import time
from typing import List, Dict, Any, Tuple

def to_markdown(rows: List[Dict[str, Any]]) -> str:
    cols = ["pair","spot","24h_low","24h_high","best_bid","best_ask","spread_pct","fee_buy_pct","fee_sell_pct","effective_buy","effective_sell","edge_after_fees_pct"]
    header = "| " + " | ".join(cols) + " |"
    sep = "| " + " | ".join(["---"]*len(cols)) + " |"
    lines = [header, sep]
    for r in rows:
        vals = []
        for c in cols:
            v = r.get(c)
            if isinstance(v, float):
                vals.append(f"{v:,.6f}")
            elif v is None:
                vals.append("")
            else:
                vals.append(str(v))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)

def _notion_headers(token: str) -> Dict[str,str]:
    return {
        "Authorization": f"Bearer {token}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    }

def _mk_paragraph(text: str) -> Dict[str, Any]:
    return {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
            "rich_text": [{"type":"text","text":{"content": text}}]
        }
    }

def _mk_md_block(md: str) -> List[Dict[str, Any]]:
    # We’ll just dump as a code block for fidelity.
    return [{
        "object":"block",
        "type":"code",
        "code": {
            "rich_text":[{"type":"text","text":{"content": md}}],
            "language":"markdown"
        }
    }]

def publish_to_notion(page_id: str, rows: List[Dict[str, Any]]) -> Tuple[bool, str]:
    token = os.getenv("NOTION_TOKEN") or os.getenv("NOTION_SECRET") or os.getenv("NOTION_API_KEY")
    if not token:
        return False, "No NOTION_TOKEN/NOTION_SECRET found; skipping Notion publish."

    import httpx
    md = to_markdown(rows)
    blocks = [_mk_paragraph(f"Updated: {time.strftime('%Y-%m-%d %H:%M:%S')}"), *_mk_md_block(md)]

    # Append blocks
    url = "https://api.notion.com/v1/blocks/" + page_id + "/children"
    try:
        with httpx.Client(timeout=20.0) as c:
            r = c.patch(url, headers=_notion_headers(token), json={"children": blocks})
            r.raise_for_status()
        return True, "Published to Notion."
    except Exception as e:
        return False, f"Notion error: {e}"

if __name__ == "__main__":
    # Ad-hoc test run: pull orchestrator, print markdown
    from orchestrate_feeds import collect_metrics
    rows = collect_metrics()
    print(to_markdown(rows))
