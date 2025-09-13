from pathlib import Path
import json, matplotlib.pyplot as plt

def save_spread_png(sym: str, window: int = 200):
    p = Path(f"logs/feeds/history_{sym.replace('-','_')}.json")
    if not p.exists(): return None
    arr = json.loads(p.read_text())[-window:]
    if not arr: return None
    xs = [a["ts"] for a in arr]
    ys = [a["spread_pct"]*100 for a in arr]
    plt.figure()
    plt.plot(xs, ys)
    plt.xlabel("time"); plt.ylabel("spread %")
    png = Path(f"snapshots/{sym.replace('-','_')}_spread.png")
    plt.savefig(png, bbox_inches="tight")
    plt.close()
    return str(png)
