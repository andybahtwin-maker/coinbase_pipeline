import os
from notion_client import Client

# Load env
for line in open(".env"):
    if "=" in line and not line.strip().startswith("#"):
        k,v=line.strip().split("=",1); os.environ.setdefault(k,v)

notion = Client(auth=os.environ["NOTION_API_KEY"])
page_id = os.environ["NOTION_PAGE_ID"]

block = {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
        "rich_text": [
            {"type": "text", "text": {"content": "Fee: "}},
            {"type": "text", "text": {"content": "$12.34"}, "annotations": {"color": "blue"}}
        ]
    }
}

notion.blocks.children.append(block_id=page_id, children=[block])
print("Pushed test block with fee in blue.")
