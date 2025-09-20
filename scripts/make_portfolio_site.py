import json, pathlib as pl, pandas as pd
from datetime import datetime
import plotly.express as px

fees = json.loads((pl.Path("demo_data")/"fees_config.json").read_text())
df = pd.read_csv(pl.Path("demo_data")/"sample_ticks.csv", parse_dates=["timestamp"])
cb = df[df.exchange=="coinbase"].iloc[-1]["price"]
bn = df[df.exchange=="binance"].iloc[-1]["price"]
cb_fee = fees["coinbase"]["taker_bps"]/10000
bn_fee = fees["binance"]["taker_bps"]/10000
gross = cb - bn
net = cb*(1 - cb_fee) - bn*(1 + bn_fee)
mid = (cb + bn)/2
net_pct = (net/mid)*100

fig = px.line(df, x="timestamp", y="price", color="exchange", title="Coinbase vs Binance (demo ticks)")
html_chart = fig.to_html(full_html=False, include_plotlyjs='cdn')

html = f"""<!doctype html>
<html lang="en"><meta charset="utf-8">
<title>🟠 Bitcoin Portfolio Demo (Static)</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<style>
body {{ font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, 'Helvetica Neue', Arial, 'Noto Sans', 'Apple Color Emoji', 'Segoe UI Emoji'; margin: 24px; }}
h1 {{ margin: 0 0 8px; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap: 12px; margin: 16px 0; }}
.card {{ border:1px solid #e6e6e6; border-radius:12px; padding:14px; box-shadow:0 1px 2px rgba(0,0,0,0.04); }}
.k {{ color:#6b7280; font-size:12px; text-transform:uppercase; letter-spacing:.08em; }}
.v {{ font-size:22px; font-weight:700; margin-top:4px; }}
footer {{ color:#6b7280; font-size:12px; margin-top:20px; }}
</style>
<h1>🟠 Bitcoin Portfolio Demo (Static)</h1>
<p>This page is generated from committed demo data. It will render on GitHub Pages without any server.</p>
<div class="grid">
  <div class="card"><div class="k">Coinbase (USD)</div><div class="v">${cb:,.2f}</div></div>
  <div class="card"><div class="k">Binance (USDT~USD)</div><div class="v">${bn:,.2f}</div></div>
  <div class="card"><div class="k">Gross Spread</div><div class="v">${gross:,.2f}</div></div>
  <div class="card"><div class="k">Net Spread (after fees)</div><div class="v">${net:,.2f} ({net_pct:.3f}%)</div></div>
</div>
<div class="card">{html_chart}</div>
<footer>Generated {datetime.utcnow().isoformat()}Z · Demo data is bundled for reliability.</footer>
</html>"""
out = pl.Path("docs")/"index.html"
out.write_text(html)
print(f"[✓] wrote {out}")
