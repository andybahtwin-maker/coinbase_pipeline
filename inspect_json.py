import json, pathlib
p = pathlib.Path("cdp_api_key.json")
if not p.exists():
    print("No cdp_api_key.json found here")
else:
    data = json.load(p.open())
    print("Top-level keys:", list(data.keys()))
    for k,v in data.items():
        if isinstance(v, dict):
            print(f"{k}: dict with keys {list(v.keys())}")
        else:
            print(f"{k}: {str(v)[:60]}")
