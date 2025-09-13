#!/usr/bin/env python3
import json, math, time, os, sys
from datetime import datetime, timezone
from pathlib import Path

# ---- Configure your data sources here ----
# Try common locations used in coinbase_pipeline; feel free to adjust.
CANDIDATES = [
    Path('data/trades.csv'),
    Path('artifacts/trades.csv'),
    Path('outputs/trades.csv'),
]
OUT = Path(__file__).resolve().parent / 'metrics.json'

# Default fee/slippage params if missing in source rows
MAKER_FEE_BPS = float(os.getenv('MAKER_FEE_BPS', '2.5'))   # 0.025%
TAKER_FEE_BPS = float(os.getenv('TAKER_FEE_BPS', '5.0'))   # 0.05%
DEFAULT_SLIPPAGE = float(os.getenv('DEFAULT_SLIPPAGE', '0.0000'))

# ---- Utils ----
def parse_csv(p: Path):
    import csv
    rows = []
    if not p.exists():
        return rows
    with p.open() as f:
        r = csv.DictReader(f)
        for i,row in enumerate(r, start=1):
            try:
                t = row.get('t') or row.get('time') or row.get('timestamp')
                if t and t.isdigit():
                    # assume ms epoch
                    ts = datetime.fromtimestamp(int(t)/1000, tz=timezone.utc).isoformat()
                else:
                    ts = datetime.fromisoformat(t.replace('Z','+00:00')).astimezone(timezone.utc).isoformat()
            except Exception:
                ts = datetime.now(timezone.utc).isoformat()
            pair = row.get('pair','BTC-USD')
            side = row.get('side','long')
            qty = float(row.get('qty') or row.get('quantity') or 0)
            spread_bps = float(row.get('spread_bps') or 0)
            gross_pnl = float(row.get('gross_pnl') or 0)
            fees = row.get('fees_total')
            if fees is None:
                # fallback fee model
                fee_bps = TAKER_FEE_BPS if side in ('taker','sell','short') else MAKER_FEE_BPS
                notional = float(row.get('notional') or row.get('price',0)) * qty
                fees = (fee_bps/10000.0) * notional
            fees = float(fees)
            slippage = float(row.get('slippage') or DEFAULT_SLIPPAGE)
            net_pnl = gross_pnl - fees - slippage
            hold_ms = int(row.get('hold_ms') or 0)
            rows.append({
                'id': i,
                't': ts,
                'pair': pair,
                'side': side,
                'qty': qty,
                'spread_bps': spread_bps,
                'gross_pnl': gross_pnl,
                'fees_total': fees,
                'slippage': slippage,
                'net_pnl': net_pnl,
                'hold_ms': hold_ms,
            })
    return rows

# Rolling volatility (simple): std of last N net_pnl
from collections import deque

def compute_series(trades):
    series = []
    cum = 0.0
    window = deque(maxlen=30)
    peak = 0.0
    max_dd = 0.0
    max_dd_start = None
    max_dd_end = None
    for tr in trades:
        cum += tr['net_pnl']
        window.append(tr['net_pnl'])
        if len(window) > 1:
            avg = sum(window)/len(window)
            var = sum((x-avg)**2 for x in window)/ (len(window)-1)
            roll_vol = var**0.5
        else:
            roll_vol = 0.0
        # drawdown vs running peak
        peak = max(peak, cum)
        dd = cum - peak  # negative or zero
        series.append({
            't': tr['t'],
            'spread_bps': tr.get('spread_bps',0.0),
            'net_pnl': tr['net_pnl'],
            'cum_pnl': cum,
            'roll_vol': roll_vol,
            'drawdown': dd,
        })
        if dd < max_dd:
            max_dd = dd; max_dd_end = tr['t']
            # naive start: when we last updated peak
    return series, cum, max_dd, (max_dd_end or 0)

def sharpe_naive(trades):
    # daily-ish: treat each trade as a period; this is illustrative only
    r = [t['net_pnl'] for t in trades]
    if len(r) < 2:
        return 0.0, 0.0
    avg = sum(r)/len(r)
    var = sum((x-avg)**2 for x in r)/(len(r)-1)
    vol = var**0.5
    return (avg/vol if vol else 0.0), vol


def main():
    src = None
    for c in CANDIDATES:
        if c.exists():
            src = c; break
    trades = parse_csv(src) if src else []

    # basic KPIs
    wins = sum(1 for t in trades if t['net_pnl'] > 0)
    sharpe, vol = sharpe_naive(trades)
    series, cum, max_dd, max_dd_end = compute_series(trades)
    avg_spread = (sum(t.get('spread_bps',0.0) for t in trades)/len(trades)) if trades else 0.0
    fees_total = sum(t['fees_total'] for t in trades)

    out = {
        'updated_at': datetime.now(timezone.utc).isoformat(),
        'kpi': {
            'net_pnl': round(cum, 6),
            'fees_total': round(fees_total, 6),
            'win_rate': round(wins/len(trades), 4) if trades else 0.0,
            'avg_spread_bps': round(avg_spread, 4),
            'trades': len(trades),
            'realized_vol': round(vol, 6),
            'sharpe': round(sharpe, 4),
            'max_drawdown': round(max_dd, 6),
            'max_dd_duration': 0
        },
        'series': series,
        'trades': trades[-1000:],
    }
    OUT.write_text(json.dumps(out, indent=2))
    print(f"Wrote {OUT}")

if __name__ == '__main__':
    main()
