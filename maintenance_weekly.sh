#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data/archive
ts="$(date -u +'%Y%m%d-%H%M%S')"

for f in data/best_edges.csv data/sym_summary.csv; do
  [ -f "$f" ] || continue
  # copy current to timestamped, compress the copy, keep current growing
  cp "$f" "data/archive/$(basename "$f" .csv)-$ts.csv"
  gzip -f "data/archive/$(basename "$f" .csv)-$ts.csv"
done
echo "Archived snapshots @ $ts"
