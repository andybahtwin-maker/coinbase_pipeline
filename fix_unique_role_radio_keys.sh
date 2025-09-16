#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/coinbase_pipeline

FILE="streamlit_app_full.py"
BACKUP="${FILE}.bak_rolekeys.$(date +%s)"
cp "$FILE" "$BACKUP"

python - <<'PY'
import re
from pathlib import Path

p = Path("streamlit_app_full.py")
s = p.read_text()

def find_call_span(src, start_idx):
    """Return (start, end) indices for the full call parentheses starting at 'st.radio('."""
    # Find the first '(' after the matched 'st.radio'
    i = src.find('(', start_idx)
    if i == -1:
        return None
    depth = 0
    j = i
    while j < len(src):
        c = src[j]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return (i, j+1)
        j += 1
    return None

# Find all st.radio("Role", ...) occurrences (allow single/double quotes, spaces)
pattern = re.compile(r'st\.radio\(\s*[\'"]Role[\'"]', re.M)
positions = [m.start() for m in pattern.finditer(s)]

if not positions:
    print("No Role radios found; nothing to do.")
else:
    new_s = []
    last = 0
    count = 0
    for pos in positions:
        # append chunk before the call
        new_s.append(s[last:pos])
        # find full call span
        span = find_call_span(s, pos)
        if not span:
            # If we can't parse safely, just keep original and continue
            new_s.append(s[pos:])
            last = len(s)
            break
        call_start, call_end = span
        call = s[pos:call_end]
        count += 1
        key_val = f'role_select_{count}'

        # If there is already a key=... inside, replace it with our unique key
        # We match key = "..." or key='...'
        if re.search(r'\bkey\s*=\s*[\'"][^\'"]*[\'"]', call):
            call = re.sub(r'\bkey\s*=\s*[\'"][^\'"]*[\'"]', f'key="{key_val}"', call, count=1)
        else:
            # Insert key just after the label argument (after "Role",)
            # We look for the first comma after the opening parenthesis content.
            # Simpler: add at the end before the closing ')', ensuring comma.
            # But preserve trailing ) and possible whitespace.
            inner = call[:-1]  # drop final ')'
            # If there are already arguments, ensure a comma before appending key
            if inner.rstrip().endswith('('):
                # no args beyond label (unlikely), but be safe
                inner = inner + f'key="{key_val}"'
            else:
                inner = inner + f', key="{key_val}"'
            call = inner + ')'

        new_s.append(call)
        last = call_end

    new_s.append(s[last:])
    s = ''.join(new_s)
    p.write_text(s)
    print(f"Updated {len(positions)} Role radios with unique keys: role_select_1..role_select_{len(positions)} ✅")
PY

echo "Now relaunch:"
echo "  cd ~/projects/coinbase_pipeline && . .venv/bin/activate && streamlit run streamlit_app_full.py"
