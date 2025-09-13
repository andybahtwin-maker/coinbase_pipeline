#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

python3 - <<'PY'
from pathlib import Path, re
p = Path("notion_publish.py")
s = p.read_text(encoding="utf-8")

def upsert_block(s: str) -> str:
    # replace or insert publish_boxes_colored with a hardened version
    new_fn = r'''
def publish_boxes_colored(metrics: dict):
    """
    Hardened: loads .env via python-dotenv, maps env names,
    normalizes parent ID, logs status/errors, fees in title, colored numbers.
    """
    import os, re, requests
    from datetime import datetime
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"))
    except Exception:
        pass

    # Map legacy names
    token = os.environ.get("NOTION_TOKEN") or os.environ.get("NOTION_API_KEY")
    parent = os.environ.get("NOTION_PARENT_PAGE_ID") or os.environ.get("NOTION_PAGE_ID")
    if not token or not parent:
        raise RuntimeError("Notion env missing: need NOTION_TOKEN/NOTION_API_KEY and NOTION_PARENT_PAGE_ID/NOTION_PAGE_ID")

    # Normalize parent: add hyphens if it's the 32-char compact UUID
    m = re.fullmatch(r"[0-9a-fA-F]{32}", parent or "")
    if m:
        parent = f"{parent[0:8]}-{parent[8:12]}-{parent[12:16]}-{parent[16:20]}-{parent[20:32]}"

    NOTION_API="https://api.notion.com/v1"; NOTION_VER="2022-06-28"
    def H(): return {"Authorization": f"Bearer {token}","Content-Type":"application/json","Notion-Version":NOTION_VER}

    prefix = os.environ.get("NOTION_TITLE_PREFIX","Arb Dashboard")
    title = f"{prefix} · {datetime.now().strftime('%Y-%m-%d %H:%M')}"

    debug_token = token[:6] + "…" if token else "None"
    print(f"🔐 Notion token prefix: {debug_token}")
    print(f"📄 Parent page id: {parent}")

    # Create page
    resp = requests.post(f"{NOTION_API}/pages", headers=H(), json={
        "parent": {"type":"page_id","page_id": parent},
        "properties": {"title": [{"type":"text","text":{"content": title}}]}
    }, timeout=30)
    if not resp.ok:
        print("❌ create page failed:", resp.status_code, resp.text)
        resp.raise_for_status()
    page_id = resp.json()["id"]

    # Partition + collect fees for title subtitle
    spreads, others, fees = [], [], []
    fee_title_bits=[]
    for k,(v,is_fee) in metrics.items():
        if is_fee:
            fees.append((k,v)); fee_title_bits.append(f"{k}={v:.4f}")
        elif "spread" in k.lower():
            spreads.append((k,v))
        else:
            others.append((k,v))

    # build blocks (heading + optional fee line)
    blocks=[{"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"Market Snapshot"}}]}}]
    if fee_title_bits:
        blocks.append({"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"Fees: "+", ".join(fee_title_bits)}}],"color":"blue"}})

    def colored(label, val, fee=False):
        color = "blue" if fee else ("green" if val>=0 else "red")
        return {"type":"paragraph","paragraph":{"rich_text":[
            {"type":"text","text":{"content":label+": "}},
            {"type":"text","text":{"content":f"{val:.6f}"},"annotations":{"bold":True,"color":color}}
        ]}}

    def col(title, arr, fee=False):
        children=[{"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":title}}]}}]
        if not arr:
            children.append({"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"(no data)"}}]}})
        else:
            for k,v in arr:
                children.append(colored(k, float(v), fee))
        return {"object":"block","type":"column","column":{"children":children}}

    col_list={"object":"block","type":"column_list","column_list":{"children":[
        col("Spreads (fees incl)", spreads, False),
        col("Metrics", others, False),
        col("Fees", fees, True),
    ]}}
    blocks.append(col_list)

    resp = requests.patch(f"{NOTION_API}/blocks/{page_id}/children", headers=H(), json={"children":blocks}, timeout=30)
    if not resp.ok:
        print("❌ append blocks failed:", resp.status_code, resp.text)
        resp.raise_for_status()
    print("✅ Notion colored page updated.")
    return page_id
'''.lstrip()

    if "def publish_boxes_colored(" in s:
        s = re.sub(r"def\s+publish_boxes_colored\s*\(.*?\)\s*:[\s\S]*?return\s+page_id", new_fn.strip().rstrip(), s, flags=re.S)
    else:
        s = s.rstrip()+"\n\n"+new_fn
    return s

s2 = upsert_block(s)
if s2 != s:
    p.write_text(s2, encoding="utf-8")
    print("✅ notion_publish.py hardened")
else:
    print("ℹ️ notion_publish.py already hardened")
