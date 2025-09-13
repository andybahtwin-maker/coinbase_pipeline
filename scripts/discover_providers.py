#!/usr/bin/env python3
import ast, json, sys, re
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
CANDIDATE_FN_PAT = re.compile(r"^(fetch|get|quote)[a-zA-Z0-9_]*$")

def scan_file(p: Path):
    text = p.read_text(encoding="utf-8", errors="ignore")
    try:
        tree = ast.parse(text, filename=str(p))
    except SyntaxError:
        return []
    found = []
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            name = node.name
            if CANDIDATE_FN_PAT.match(name):
                args = [a.arg for a in node.args.args]
                found.append({"type":"func","name":name,"args":args,"module":str(p.with_suffix("")).replace("/","."), "file":str(p)})
    return found

def main():
    files = list(ROOT.rglob("*.py"))
    hits = []
    for f in files:
        if f.name.startswith((".venv","_")): 
            continue
        if any(seg in f.parts for seg in (".venv","node_modules","__pycache__","snapshots","logs","tests",".git")):
            continue
        hits.extend(scan_file(f))
    # heuristic provider grouping by filename
    providers = {}
    for h in hits:
        file_l = h["file"].lower()
        tag = None
        for key in ("coinbase","coingecko","kraken","binance","kucoin","gemini","bybit","feed","provider"):
            if key in file_l:
                tag = key
                break
        key = tag or "misc"
        providers.setdefault(key, []).append(h)

    manifest = {"root": str(ROOT.resolve()), "discovered": providers}
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
