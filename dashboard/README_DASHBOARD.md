# Arbitrage Control Room (Zero‑Build Dashboard)

This folder provides a no‑npm, zero‑build dashboard for **live visual monitoring** of your arbitrage engine.

**Color rules:**
- Positive numbers → **green**
- Negative numbers → **blue**
- Fees → **blue** (displayed explicitly and in charts)

## What it shows
- Spread (bps) vs **Net P&L** (after fees) over time
- **Cumulative P&L** (after fees)
- **Fees + Slippage** per trade (stacked bars)
- **Rolling volatility** and **drawdown**
- Recent trades with quantities, sides, holding time
- KPIs: win rate, average spread, Sharpe (naive), realized volatility, max drawdown

## How to run
```bash
bash dashboard/run_dashboard.sh
```
This auto‑generates `metrics.json` and serves `dashboard/` locally at `http://localhost:8080/dashboard/`.

## Plug in your data
Point `dashboard/generate_metrics.py` to your CSV (default probes `data/`, `artifacts/`, `outputs/`). Expected columns (best‑effort auto‑mapped):

| column           | notes                                               |
|------------------|-----------------------------------------------------|
| `t`/`time`       | ISO8601 or epoch ms                                 |
| `pair`           | e.g., `BTC-USD`                                     |
| `side`           | `long`/`short` or `buy`/`sell`                      |
| `qty`            | trade quantity                                      |
| `spread_bps`     | raw spread in basis points (optional)               |
| `gross_pnl`      | before fees/slippage                                |
| `fees_total`     | total fees in quote currency (fallback model used)  |
| `slippage`       | per‑trade slippage                                  |
| `hold_ms`        | holding time in milliseconds                        |

If your feed lacks `fees_total`, the script will synthesize fees using envs:
```
export MAKER_FEE_BPS=2.5
export TAKER_FEE_BPS=5.0
export DEFAULT_SLIPPAGE=0.00
```

## Ship‑ready visuals
Works without Node/Vite. Uses CDN React + Recharts + Tailwind. Embed in Notion via **public URL or screenshot/GIF**.

