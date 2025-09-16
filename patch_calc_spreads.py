from pathlib import Path
import pandas as pd

# Patch the calc_spreads function inside exchange_prices.py
target = Path("exchange_prices.py")
text = target.read_text().splitlines()
out = []
inside = False
for line in text:
    if line.strip().startswith("def calc_spreads"):
        inside = True
    if inside and "pair_detail=pd.DataFrame" in line:
        out.append("    pair_detail = pd.DataFrame(pairs)")
        out.append("    # Ensure expected columns exist")
        out.append("    if 'symbol' not in pair_detail.columns:")
        out.append("        pair_detail['symbol'] = 'UNKNOWN'")
        out.append("    if 'edge_pct' not in pair_detail.columns:")
        out.append("        pair_detail['edge_pct'] = 0.0")
        out.append("    pair_detail = pair_detail.sort_values(['symbol','edge_pct'], ascending=False)")
        continue
    out.append(line)

target.write_text("\n".join(out))
print("✅ Patched exchange_prices.py to handle missing symbol/edge_pct columns.")
