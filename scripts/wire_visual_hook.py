"""
Safely wires the visual display into fetch_and_publish.py.
Creates a .bak, adds import if missing, appends a guarded call.
"""
from pathlib import Path

TARGET = Path("fetch_and_publish.py")
IMPORT_LINE = "from integrations.visual_hook import display_from_numbers"
CALL_BLOCK = """
# === Visual summary (safe/optional) ===
try:
    display_from_numbers(
        btc_spread_pct=(globals().get("btc_spread_pct") or globals().get("btc_spread")),
        xrp_spread_pct=(globals().get("xrp_spread_pct") or globals().get("xrp_spread")),
        gas_fee_usd=(globals().get("gas_fee_usd") or globals().get("gas_fee")),
        net_profit_usd=(globals().get("net_profit_usd") or globals().get("net_profit")),
    )
except Exception as _e:
    # keep non-fatal
    pass
# === /Visual summary ===
"""

def main():
    if not TARGET.exists():
        print(f"❌ {TARGET} not found in current directory.")
        return
    src = TARGET.read_text(encoding="utf-8")
    bak = TARGET.with_suffix(TARGET.suffix + ".bak")
    bak.write_text(src, encoding="utf-8")

    if IMPORT_LINE not in src:
        lines = src.splitlines()
        insert_at = 0
        for i, ln in enumerate(lines[:100]):
            if ln.strip().startswith(("from ", "import ")):
                insert_at = i + 1
        lines.insert(insert_at, IMPORT_LINE)
        src = "\\n".join(lines)

    if "display_from_numbers(" not in src:
        if not src.endswith("\\n"):
            src += "\\n"
        src += CALL_BLOCK

    TARGET.write_text(src, encoding="utf-8")
    print(f"✅ Wired visual hook into {TARGET} (backup at {bak.name})")

if __name__ == "__main__":
    main()
