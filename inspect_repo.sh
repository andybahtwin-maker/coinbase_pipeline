#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/projects/coinbase_pipeline"
echo "Inspecting: $DIR"
cd "$DIR" || { echo "ERROR: repo not found at $DIR"; exit 2; }

echo
echo "=== Git status / current branch / last 5 commits ==="
git rev-parse --abbrev-ref HEAD 2>/dev/null || true
git status --porcelain 2>/dev/null || true
git log --oneline -n 5 2>/dev/null || true

echo
echo "=== Top-level files ==="
ls -la --color=auto

echo
echo "=== Dashboard directory tree (if exists) ==="
if [ -d dashboard ]; then
  find dashboard -maxdepth 3 -type d -print -exec ls -1 {} \; | sed 's/^/  /'
else
  echo "  -> dashboard/ directory NOT FOUND"
fi

echo
echo "=== Python files list (top-level and dashboard) ==="
find . -maxdepth 3 -type f -name '*.py' -print | sed 's/^/  /'

echo
echo "=== .env summary (first 200 lines; only KEY=VALUE lines shown) ==="
if [ -f .env ]; then
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env | sed -n '1,200p' || true
else
  echo "  -> No .env file found"
fi

echo
echo "=== Quick compile check for Python syntax errors ==="
python -m compileall -q . || echo "  -> compileall reported errors above (if any)"

echo
echo "=== Attempting to import dashboard.* modules and reporting errors ==="
python - <<'PY'
import os, pkgutil, importlib, traceback, sys
pkg_name = "dashboard"
root = os.getcwd()
if not os.path.isdir(os.path.join(root, pkg_name)):
    print(f"[IMPORT CHECK] package '{pkg_name}' NOT FOUND in {root}")
    sys.exit(0)

found = []
for finder, name, ispkg in pkgutil.walk_packages([os.path.join(root, pkg_name)], prefix=pkg_name + "."):
    found.append(name)
print(f"[IMPORT CHECK] Found {len(found)} modules under '{pkg_name}':")
for n in sorted(found):
    print("  -", n)
print()
errs = []
for n in sorted(found):
    try:
        importlib.import_module(n)
    except Exception as e:
        errs.append((n, traceback.format_exc()))
if not errs:
    print("[IMPORT CHECK] All dashboard modules imported successfully.")
else:
    print(f"[IMPORT CHECK] {len(errs)} modules failed to import:")
    for mod, tb in errs:
        print("----")
        print("Module:", mod)
        print("Error:")
        print(tb)
PY

echo
echo "=== Search for missing sidebar_status / tab_env_health references ==="
grep -R --line-number -nE "sidebar_status|tab_env_health" || true

echo
echo "=== Files staged/modified since last upstream (if any) ==="
git status --porcelain -uno || true

echo
echo "=== END OF INSPECTION ==="
