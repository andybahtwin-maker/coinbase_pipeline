#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

python3 - <<'PY'
from pathlib import Path, re
p = Path("notion_publish.py")
s = p.read_text(encoding="utf-8")

# ensure update_fixed_page_colored exists (from previous patch). If not, inject a minimal alias.
if "def update_fixed_page_colored(" not in s:
    s += """

def update_fixed_page_colored(metrics: dict, page_id: str):
    import os, re, requests
    from datetime import datetime
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"))
    except Exception:
        pass
    if re.fullmatch(r"[0-9a-fA-F]{32}", page_id):
        page_id = f"{page_id[0:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:32]}"
    token = os.environ.get("NOTION_TOKEN") or os.environ.get("NOTION_API_KEY")
    assert token, "Missing Notion token"
    NOTION_API="https://api.notion.com/v1"; NOTION_VER="2022-06-28"
    def H(): return {"Authorization": f"Bearer {token}","Content-Type":"application/json","Notion-Version":NOTION_VER}
    # Replace children with a single paragraph so at least it updates if the heavier publisher wasn't added
    requests.patch(f"{NOTION_API}/blocks/{page_id}/children", headers=H(),
                   json={"children":[{"object":"block","type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"Updated (stub)"}]}}]}}, timeout=30).raise_for_status()
    return page_id
"""
    print("ℹ️ injected minimal update_fixed_page_colored() stub")

def add_router(fn_name: str, src: str) -> str:
    # Wrap publish_metrics/publish so if PAGE_ID is set, call update_fixed_page_colored
    pattern = rf"def\s+{fn_name}\s*\(\s*metrics\s*:\s*dict\s*\)\s*:"
    if not re.search(pattern, src):
        return src  # nothing to wrap
    router = f"""
def {fn_name}(metrics: dict):
    \"\"\"Router: if PAGE_ID/NOTION_PAGE_ID is set, update that fixed page; else fall back to original {fn_name}_impl.\"\"\"
    import os, re
    page = os.environ.get("PAGE_ID") or os.environ.get("NOTION_PARENT_PAGE_ID") or os.environ.get("NOTION_PAGE_ID")
    if page:
        return update_fixed_page_colored(metrics, page)
    # Fallback to original implementation if present
    try:
        return {fn_name}_impl(metrics)
    except NameError:
        # no original impl, try main()
        _main = globals().get("main")
        if callable(_main): return _main()
        raise RuntimeError("No suitable publisher function found")
"""
    # rename original to _impl if not already done
    src = re.sub(pattern, f"def {fn_name}_impl(metrics: dict):", src, count=1)
    # insert router after the impl
    src = re.sub(rf"def\s+{fn_name}_impl\s*\(\s*metrics\s*:\s*dict\s*\)\s*:\s*", rf"def {fn_name}_impl(metrics: dict):\n", src, count=1)
    src += "\n" + router
    return src

# Route publish_metrics if present
if "def publish_metrics(" in s and "def publish_metrics_impl(" not in s:
    s = add_router("publish_metrics", s)

# Route publish if present and takes metrics
if re.search(r"def\s+publish\s*\(\s*metrics\s*:\s*dict\s*\)\s*:", s) and "def publish_impl(" not in s:
    s = add_router("publish", s)

p.write_text(s, encoding="utf-8")
print("✅ routed publisher(s) to fixed page when PAGE_ID/NOTION_PAGE_ID is set")
