import os, time, random
from typing import List, Dict, Any, Tuple
from notion_client import Client
from notion_client.errors import APIResponseError

# ---------- Rich text helpers ----------
def _span(text: str, color: str = "default", bold: bool = False) -> Dict[str, Any]:
    return {
        "type": "text",
        "text": {"content": text},
        "annotations": {"bold": bool(bold), "color": color},
    }

def _rt(text: str, bold: bool = False, color: str = "default"):
    return [_span(text, color=color, bold=bold)]

def _p(text: str, bold: bool = False, color: str = "default"):
    return {"object":"block","type":"paragraph","paragraph":{"rich_text": _rt(text, bold=bold, color=color)}}

def _p_spans(spans: List[Tuple[str, str, bool]]):
    return {"object":"block","type":"paragraph","paragraph":{"rich_text":[_span(t,c,b) for (t,c,b) in spans]}}

def _h(text: str, level: int = 2, color: str = "default"):
    key = f"heading_{level}"
    return {"object":"block","type":key, key:{"rich_text": _rt(text, bold=True, color=color)}}

def _divider():
    return {"object":"block","type":"divider","divider":{}}

def _bulleted_spans(spans: List[Tuple[str, str, bool]]):
    return {"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[_span(t,c,b) for (t,c,b) in spans]}}

def _callout_spans(spans: List[Tuple[str,str,bool]], emoji: str = "🚀"):
    return {"object":"block","type":"callout","callout":{"icon":{"emoji":emoji},"rich_text":[_span(t,c,b) for (t,c,b) in spans], "color":"default"}}

def _kpi_card(title: str, value_line: str, sub_line: str | None = None, emoji: str = "📊"):
    lines = title + "\n" + value_line + (("\n" + sub_line) if sub_line else "")
    return {"object":"block","type":"callout","callout":{"icon":{"emoji":emoji},"rich_text": _rt(lines),"color":"default"}}

def _embed(url: str):
    return {"object":"block","type":"embed","embed":{"url":url}}

# ---------- Retry helpers ----------
def _status_from_err(e: Exception) -> int | None:
    if isinstance(e, APIResponseError):
        try:
            return int(e.response.status_code)  # httpx.Response
        except Exception:
            return None
    return None

def _jitter_delay(attempt: int) -> float:
    # 0.25, 0.5, 1, 2, 3s (capped), with small jitter
    base = min(0.25 * (2 ** attempt), 3.0)
    return base + random.random() * 0.2

def _with_retry(callable_, *args, **kwargs):
    last = None
    for attempt in range(6):
        try:
            return callable_(*args, **kwargs)
        except Exception as e:
            status = _status_from_err(e)
            # Retry on transient statuses (409 conflict, 429 rate limit, 5xx)
            if status in (409, 429, 500, 502, 503, 504):
                time.sleep(_jitter_delay(attempt))
                last = e
                continue
            # Occasionally Notion returns None-ish conflicts; still retry a couple of times
            if status is None and attempt < 2:
                time.sleep(_jitter_delay(attempt))
                last = e
                continue
            raise
    if last:
        raise last

# ---------- Append helpers ----------
def _append(n: Client, parent_id: str, blocks: List[Dict[str, Any]]):
    # small pacing + retries for each batch
    for i in range(0, len(blocks), 50):
        _with_retry(n.blocks.children.append, block_id=parent_id, children=blocks[i:i+50])
        time.sleep(0.1)

def _clear_all_children(n: Client, parent_id: str):
    # list + delete with pagination, gentle pacing to avoid 409s
    while True:
        res = _with_retry(n.blocks.children.list, block_id=parent_id, page_size=100)
        results = res.get("results", [])
        if not results:
            break
        for child in results:
            _with_retry(n.blocks.delete, block_id=child["id"])
            time.sleep(0.08)
    # give Notion a brief moment before re-append
    time.sleep(0.25)

def _append_columns_strict(n: Client, parent_id: str, col_children_lists: List[List[Dict[str,Any]]]) -> str:
    nested_columns = []
    for kids in col_children_lists:
        nested_columns.append({
            "object":"block",
            "type":"column",
            "column": { "children": (kids if kids else []) }
        })
    res = _with_retry(
        n.blocks.children.append,
        block_id=parent_id,
        children=[{
            "object":"block",
            "type":"column_list",
            "column_list": { "children": nested_columns }
        }]
    )
    # pacing helps reduce 409s before adding more after columns
    time.sleep(0.15)
    return res["results"][0]["id"]

# ---------- Publisher ----------
def publish_dashboard(
    title_main: str,
    title_date: str | None,
    kpis,
    best_trade_spans,         # list of (text,color,bold)
    bullets_spans,            # list of lists of (text,color,bold)
    embed_urls=None,
    spotlight_big=None,
    spotlight_sub=None,
    best_of_tiles=None,       # [left_blocks, right_blocks]
    after_best_of_images=None,# list of image blocks
    replace_mode=True,
    embed_row_first=True
):
    api=os.environ["NOTION_API_KEY"]; pid=os.environ["NOTION_PAGE_ID"]
    n=Client(auth=api)

    # Replace: clear page
    if replace_mode:
        _clear_all_children(n, pid)

    # Header (biggest), then date smaller
    if title_main:
        _append(n, pid, [_h(title_main, level=1)])
    if title_date:
        _append(n, pid, [_h(title_date, level=2)])
    _append(n, pid, [_divider()])

    # Embeds row under header (side-by-side)
    if embed_row_first and embed_urls:
        urls = [u for u in embed_urls if u]
        if urls:
            cols = [[ _embed(u) ] for u in urls[:2]]
            _append_columns_strict(n, pid, cols)
            _append(n, pid, [_divider()])

    # KPI row
    if kpis:
        kpi_cols = [[ _kpi_card(t, v, s, emoji=e) ] for (t,v,s,e) in kpis[:3]]
        _append_columns_strict(n, pid, kpi_cols)

    # Best-of BTC/XRP row
    if best_of_tiles and isinstance(best_of_tiles, list) and len(best_of_tiles)==2:
        _append(n, pid, [_divider(), _h("Best Of: BTC & XRP", level=3)])
        left, right = best_of_tiles
        _append_columns_strict(n, pid, [left, right])

    # Optional images
    if after_best_of_images:
        _append(n, pid, after_best_of_images)

    # Best trade callout (spans)
    if best_trade_spans:
        _append(n, pid, [_divider(), _h("Best Trade Right Now", level=3), _callout_spans(best_trade_spans, emoji="🚀")])

    # Bulleted spans
    if bullets_spans:
        _append(n, pid, [_h("Top Opportunities", level=3)])
        # append in small batches to reduce conflicts
        bullets_blocks = [_bulleted_spans(sp) for sp in bullets_spans]
        for i in range(0, len(bullets_blocks), 20):
            _append(n, pid, bullets_blocks[i:i+20])

    # Embeds at bottom (if not shown first)
    if (not embed_row_first) and embed_urls:
        urls = [u for u in embed_urls if u]
        if urls:
            _append(n, pid, [_divider(), _h("Live Charts", level=3)])
            cols = [[ _embed(u) ] for u in urls[:2]]
            _append_columns_strict(n, pid, cols)
