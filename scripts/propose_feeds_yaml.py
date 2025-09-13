#!/usr/bin/env python3
import json, sys, re
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
manifest_json = sys.stdin.read()
data = json.loads(manifest_json)
discovered = data.get("discovered", {})

preferred_order = [
  "fetch_prices","fetch_quotes","get_prices","get_quotes",
  "fetch_ticker","get_ticker","fetch","get"
]

def choose_fn(entries):
  # score by preferred names & simplest args
  best = None
  best_score = 1e9
  for e in entries:
    if e["type"] != "func": 
      continue
    name = e["name"]
    args = e["args"]
    # cost = name rank + arg count
    try:
      name_score = preferred_order.index(name)
    except ValueError:
      name_score = len(preferred_order) + 5
    score = name_score*10 + len(args)
    if score < best_score:
      best = e; best_score = score
  return best

providers = {}
for group, entries in discovered.items():
  if group == "misc":
    continue
  pick = choose_fn(entries)
  if pick:
    providers[group] = {
      "enabled": True,
      "module": pick["module"],
      "fn":     pick["name"]
    }

symbols = ["BTC-USD","ETH-USD","XRP-USD"]
yaml_lines = []
yaml_lines.append("symbols: [" + ", ".join(f'"{s}"' for s in symbols) + "]")
yaml_lines.append("providers:")
for name, meta in providers.items():
  yaml_lines.append(f"  {name}:")
  yaml_lines.append(f"    enabled: true")
  yaml_lines.append(f'    module: "{meta["module"]}"')
  yaml_lines.append(f'    fn: "{meta["fn"]}"')
yaml_lines.append("fees:")
yaml_lines.append("  gas_fee_usd: 0.85")
yaml_lines.append("render:")
yaml_lines.append("  show_boxes: true")
yaml_lines.append("  decimals: 6")

outpath = ROOT / "config" / "feeds.yaml.proposed"
outpath.parent.mkdir(parents=True, exist_ok=True)
outpath.write_text("\n".join(yaml_lines) + "\n", encoding="utf-8")
print(f"wrote proposal: {outpath}")
