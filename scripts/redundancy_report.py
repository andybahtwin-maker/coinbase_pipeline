#!/usr/bin/env python3
import os, sys, hashlib, ast, re
from pathlib import Path
from collections import defaultdict

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
skip_dirs = {".git",".venv","node_modules","__pycache__","logs","snapshots","tests"}
files = []
for p in ROOT.rglob("*.py"):
    if any(s in p.parts for s in skip_dirs):
        continue
    files.append(p)

def sha1(p: Path) -> str:
    h = hashlib.sha1()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1<<20), b""):
            h.update(chunk)
    return h.hexdigest()

# exact duplicates
by_hash = defaultdict(list)
for f in files:
    try:
        by_hash[sha1(f)].append(f)
    except Exception:
        pass

# near dup by size/name
by_size = defaultdict(list)
for f in files:
    try:
        by_size[f.stat().st_size].append(f)
    except Exception:
        pass

def simil(a,b):
    a,b = a.lower(), b.lower()
    return sum(1 for x,y in zip(a,b) if x==y) / max(len(a),len(b),1)

print("## Exact duplicates (same hash):")
for h, group in by_hash.items():
    if len(group) > 1:
        print(f"- {h[:10]}:", *map(str, group), sep="\n  ")

print("\n## Near duplicates (size ±5% and name similarity >=0.7):")
sizes = sorted(by_size.keys())
visited = set()
for s in sizes:
    group = by_size[s]
    for f in group:
        for d in range(-int(s*0.05), int(s*0.05)+1):
            g2 = by_size.get(s+d)
            if not g2: continue
            for f2 in g2:
                if f2 == f: continue
                key = tuple(sorted((str(f),str(f2))))
                if key in visited: continue
                visited.add(key)
                if simil(f.name, f2.name) >= 0.7:
                    print(f"- {f}  ~  {f2}")

# import graph (very rough)
imports = defaultdict(set)
all_mods = set()
for f in files:
    rel_mod = str(f.with_suffix("")).replace("/",".").lstrip(".")
    all_mods.add(rel_mod)
    try:
        tree = ast.parse(f.read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        continue
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for n in node.names:
                imports[rel_mod].add(n.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imports[rel_mod].add(node.module.split(".")[0])

used = set()
for src, dsts in imports.items():
    used |= dsts

unused = [m for m in all_mods if m.split(".")[0] not in used and not m.endswith("__init__")]
print("\n## Possibly unused modules (not imported elsewhere):")
for m in sorted(unused):
    print("-", m)
