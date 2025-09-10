import os
from notion_client import Client

def _rt(text, bold=False):
    return [{
        "type": "text",
        "text": {"content": text},
        "annotations": {"bold": bool(bold)}
    }]

def _p(text, bold=False):
    return {"object":"block","type":"paragraph","paragraph":{"rich_text": _rt(text, bold=bold)}}

def _h(text, level=2):
    key = f"heading_{level}"
    return {"object":"block","type":key, key:{"rich_text": _rt(text, bold=True)}}

def _divider(): return {"object":"block","type":"divider","divider":{}}

def _bulleted(text):
    return {"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text": _rt(text)}}

def _callout(text, emoji="🛩️"):
    return {"object":"block","type":"callout","callout":{"icon":{"emoji":emoji},"rich_text": _rt(text),"color":"default"}}

def _kpi_card(title, value_line, sub_line=None, emoji="📊"):
    lines = title + "\n" + value_line + (("\n" + sub_line) if sub_line else "")
    return _callout(lines, emoji=emoji)

def _embed(url): return {"object":"block","type":"embed","embed":{"url":url}}

def _columns(col_children_lists):
    cols=[]
    for kids in col_children_lists:
        cols.append({"object":"block","type":"column","column":{"children": kids if kids else []}})
    return {"object":"block","type":"column_list","column_list":{"children": cols}}

def clear_children(page_id: str, n: Client):
    """Archive (delete) all child blocks under the page to avoid cascading growth."""
    start=None
    while True:
        resp = n.blocks.children.list(block_id=page_id, start_cursor=start)  # list children
        for blk in resp.get("results", []):
            try:
                n.blocks.delete(block_id=blk["id"])  # archive
            except Exception:
                # Some blocks might be locked or fail; skip so the run continues
                pass
        if not resp.get("has_more"): break
        start = resp.get("next_cursor")

def publish_dashboard(
    title,
    kpis,
    best_trade_text,
    bullets,
    embed_urls=None,         # list[str]
    spotlight_big=None,
    spotlight_sub=None,
    best_of_tiles=None,      # [left_blocks, right_blocks]
    after_best_of_images=None,  # unused here but kept for API compat
    replace_mode=True,       # << NEW: clear page first
    embed_row_first=True     # << NEW: put live charts under heading
):
    api=os.environ["NOTION_API_KEY"]; pid=os.environ["NOTION_PAGE_ID"]
    n=Client(auth=api)

    if replace_mode:
        clear_children(pid, n)

    blocks=[]

    # Title
    if title:
        blocks.append(_h(title, level=2))

    # Live charts right under heading (side-by-side)
    if embed_urls:
        row = _columns([[ _embed(embed_urls[0]) ]] + ([[ _embed(embed_urls[1]) ]] if len(embed_urls)>1 else []))
        blocks.append(row)
        blocks.append(_divider())

    # Spotlight
    if spotlight_big:
        blocks += [_h("Arbitrage Spotlight", level=3), _h(spotlight_big, level=1)]
        if spotlight_sub: blocks.append(_p(spotlight_sub))
        blocks.append(_divider())

    # KPI row
    if kpis:
        blocks.append(_columns([[ _kpi_card(t, v, s, emoji=e) ] for (t,v,s,e) in kpis[:3]]))

    # Best-of (BTC & XRP) row
    if best_of_tiles and len(best_of_tiles)==2:
        left, right = best_of_tiles
        blocks.append(_divider())
        blocks.append(_h("Best Of: BTC & XRP", level=3))
        blocks.append(_columns([left, right]))

    # Best trade + bullets
    blocks += [_divider(), _h("Best Trade Right Now", level=3), _callout(best_trade_text, emoji="🚀")]
    if bullets:
        blocks.append(_h("Top Opportunities", level=3))
        for b in bullets: blocks.append(_bulleted(b))

    # Append in batches
    for i in range(0, len(blocks), 50):
        n.blocks.children.append(block_id=pid, children=blocks[i:i+50])
