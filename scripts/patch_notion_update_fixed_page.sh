#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"

PAGE_ID_COMPACT="${1:-26a9c46ac8fd80f7bd52c712ef50c4ca}"

python3 - <<'PY'
from pathlib import Path, re
p = Path("notion_publish.py")
s = p.read_text(encoding="utf-8")

block = r'''
def update_fixed_page_colored(metrics: dict, page_id: str):
    """
    Update ONE fixed page (replace children) with:
      - Heading + fee subtitle
      - Three columns (Spreads, Metrics, Fees)
      - Colored numbers: green (pos), red (neg), blue (fees)
    Loads .env, maps NOTION_API_KEY/PAGE_ID -> NOTION_TOKEN/PARENT_PAGE_ID for compatibility.
    """
    import os, re, requests
    from datetime import datetime
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=os.path.join(os.getcwd(), ".env"))
    except Exception:
        pass

    # accept both hyphenated and compact page ids
    if re.fullmatch(r"[0-9a-fA-F]{32}", page_id):
        page_id = f"{page_id[0:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:32]}"

    token = os.environ.get("NOTION_TOKEN") or os.environ.get("NOTION_API_KEY")
    if not token:
        raise RuntimeError("Notion token missing (NOTION_TOKEN or NOTION_API_KEY)")
    NOTION_API="https://api.notion.com/v1"; NOTION_VER="2022-06-28"
    def H(): return {"Authorization": f"Bearer {token}","Content-Type":"application/json","Notion-Version":NOTION_VER}

    # partition metrics & collect fee subtitle
    spreads, others, fees = [], [], []
    fee_title_bits=[]
    for k,(v,is_fee) in metrics.items():
        if is_fee:
            fees.append((k,v)); fee_title_bits.append(f"{k}={v:.4f}")
        elif "spread" in k.lower():
            spreads.append((k,v))
        else:
            others.append((k,v))

    # helpers
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

    # build new children
    prefix = os.environ.get("NOTION_TITLE_PREFIX","Arb Dashboard")
    title_line = {"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":f"{prefix} · {datetime.now().strftime('%Y-%m-%d %H:%M')}"}}]}}  # noqa
    children = [ title_line ]
    if fee_title_bits:
        children.append({"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"Fees: "+", ".join(fee_title_bits)}}],"color":"blue"}})

    col_list={"object":"block","type":"column_list","column_list":{"children":[
        col("Spreads (fees incl)", spreads, False),
        col("Metrics", others, False),
        col("Fees", fees, True),
    ]}}
    children.append(col_list)

    # fetch existing children, archive them, then append new
    # 1) list children
    cur = requests.get(f"{NOTION_API}/blocks/{page_id}/children?page_size=100", headers=H(), timeout=30)
    if not cur.ok:
        print("❌ list children failed", cur.status_code, cur.text); cur.raise_for_status()
    for block in cur.json().get("results", []):
        bid = block["id"]
        # archive (soft delete)
        r = requests.patch(f"{NOTION_API}/blocks/{bid}", headers=H(), json={"archived": True}, timeout=30)
        if not r.ok:
            print("❌ archive child failed", r.status_code, r.text); r.raise_for_status()

    # 2) append new children
    resp = requests.patch(f"{NOTION_API}/blocks/{page_id}/children", headers=H(), json={"children": children}, timeout=30)
    if not resp.ok:
        print("❌ append blocks failed", resp.status_code, resp.text); resp.raise_for_status()
    print("✅ fixed page updated:", page_id)
    return page_id
'''.lstrip()

if "def update_fixed_page_colored(" in s:
    s = re.sub(r"def\s+update_fixed_page_colored\s*\(.*?\)\s*:[\s\S]*?return\s+page_id", block.strip().rstrip(), s, flags=re.S)
else:
    s = s.rstrip()+"\n\n"+block

p.write_text(s, encoding="utf-8")
print("✅ notion_publish.update_fixed_page_colored installed")
PY

# runner that always updates the fixed page id
cat <<'SH2' > scripts/publish_notion_fixed_page.sh
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PAGE_ID="${PAGE_ID:-26a9c46ac8fd80f7bd52c712ef50c4ca}"

# pick python (prefer venv)
if [[ -x ".venv/bin/python" ]]; then
  PY=".venv/bin/python"; PIP=".venv/bin/pip"
else
  PY="python3"; PIP="python3 -m pip"
fi

# load env & map names
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export NOTION_TOKEN="${NOTION_TOKEN:-${NOTION_API_KEY:-}}"

# deps
grep -qi '^python-dotenv' requirements.txt 2>/dev/null || echo 'python-dotenv>=1.0' >> requirements.txt
$PIP install -q -r requirements.txt

# analyze and update fixed page
$PY - <<PY2
from analytics.arbitrage import load_config, analyze
from notion_publish import update_fixed_page_colored
import os, re
cfg=load_config(); syms=cfg["symbols"]; prov=cfg["providers"]
metrics,tables = analyze(syms, prov, notional=10_000.0)

page_id=os.environ.get("PAGE_ID") or "${PAGE_ID}"
# normalize just to log
if re.fullmatch(r"[0-9a-fA-F]{32}", page_id):
    page_id=f"{page_id[0:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:32]}"
print("📄 Target page:", page_id)
update_fixed_page_colored(metrics, page_id)
PY2
SH2
chmod +x scripts/publish_notion_fixed_page.sh

echo "Done. Use: scripts/publish_notion_fixed_page.sh"
