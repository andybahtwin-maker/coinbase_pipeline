# Coinbase Pipeline Dashboard

A single, clean dashboard that shows **live BTC prices across major venues**, **fee-aware spreads**, **net edge after two legs**, and **(optional) Coinbase balances** — with one-click CSV export and Notion/Email hooks.

## Why it matters
- **Traders/Investors:** See cross-exchange edge after fees at a glance.
- **Hiring Managers:** Demonstrates API integration, error handling, caching, and a responsive UI.
- **Reliability:** Hard timeouts + caching ensure the app never “freezes”.

## Quick start
\`\`\`bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip -r requirements.txt
./run_simple.sh
\`\`\`

Optional: put your Coinbase key JSON at \`./cdp_api_key.json\` or set \`CB_API_KEY/CB_API_SECRET/CB_API_PASSPHRASE\` in \`.env\`.

## Notes
- Secrets are loaded from \`.env\` or \`cdp_api_key.json\` (never committed).
- Repo kept lean via \`scripts/repo_prune_safe.sh\` and \`.gitignore\`.
