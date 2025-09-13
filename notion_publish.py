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

def publish_metrics(metrics: dict):
    """
    Safe wrapper to accept orchestrator metrics and forward to existing publisher(s).
    Expected: metrics = {label: (value: float, is_fee: bool)}
    """
    # Try common entrypoints in this module
    _candidates = [
        'publish_metrics',
        'publish',
        'publish_boxes',
        'update_page',
        'upsert_database',
    ]
    # remove self-reference to avoid recursion
    _self = publish_metrics
    for _name in _candidates:
        _fn = globals().get(_name)
        if callable(_fn) and _fn is not _self:
            try:
                return _fn(metrics)  # prefer passing metrics
            except TypeError:
                return _fn()         # fallback: no-arg
    _main = globals().get('main')
    if callable(_main):
        return _main()
    raise RuntimeError("No suitable publisher function found in notion_publish.py")
# --- minimal Notion publisher entrypoint (added by setup) ---
import os, requests
from datetime import datetime

_NOTION_API = "https://api.notion.com/v1"
_NOTION_VER = "2022-06-28"

def _np_headers(token: str):
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Notion-Version": _NOTION_VER,
    }

def _np_color(value: float, is_fee: bool) -> str:
    if is_fee: return "blue_background"
    return "green_background" if value >= 0 else "red_background"

def _np_emoji(value: float, is_fee: bool) -> str:
    if is_fee: return "🧾"
    return "🟢" if value >= 0 else "🔴"

def _np_create_page(token: str, parent_page_id: str, title: str) -> str:
    payload = {
        "parent": { "type": "page_id", "page_id": parent_page_id },
        "properties": { "title": [{ "type": "text", "text": {"content": title} }] }
    }
    r = requests.post(f"{_NOTION_API}/pages", headers=_np_headers(token), json=payload, timeout=30)
    r.raise_for_status()
    return r.json()["id"]

def _np_callout(label: str, value: float, is_fee: bool) -> dict:
    return {
        "object": "block",
        "type": "callout",
        "callout": {
            "icon": { "emoji": _np_emoji(value, is_fee) },
            "rich_text": [{
                "type": "text",
                "text": {"content": f"{label}: {value:.6f}"},
                "annotations": { "bold": True }
            }],
            "color": _np_color(value, is_fee)
        }
    }

def publish(metrics: dict):
    """
    Minimal entrypoint used by the bridge. Expects:
      metrics = { label: (value: float, is_fee: bool), ... }
    Uses env: NOTION_TOKEN, NOTION_PARENT_PAGE_ID, NOTION_TITLE_PREFIX (optional)
    """
    token = os.environ.get("NOTION_TOKEN") or os.environ.get("NOTION_API_KEY")
    parent = os.environ.get("NOTION_PARENT_PAGE_ID") or os.environ.get("NOTION_PAGE_ID")
    if not token or not parent:
        raise RuntimeError("NOTION_TOKEN / NOTION_PARENT_PAGE_ID not set")

    prefix = os.environ.get("NOTION_TITLE_PREFIX", "Coinbase Pipeline")
    title = f"{prefix} · {datetime.now().strftime('%Y-%m-%d %H:%M')}"

    page_id = _np_create_page(token, parent, title)

    normals = [(k, v) for k, v in metrics.items() if not v[1]]
    fees    = [(k, v) for k, v in metrics.items() if v[1]]

    blocks = []
    for k, (val, fee) in normals:
        blocks.append(_np_callout(k, float(val), fee))
    if fees:
        blocks.append({ "object": "block", "type": "divider", "divider": {} })
        for k, (val, fee) in fees:
            blocks.append(_np_callout(k, float(val), fee))

    r = requests.patch(
        f"{_NOTION_API}/blocks/{page_id}/children",
        headers=_np_headers(token),
        json={ "children": blocks },
        timeout=30
    )
    r.raise_for_status()
    return page_id
# --- end minimal Notion publisher ---


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
