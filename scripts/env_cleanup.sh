#!/usr/bin/env bash
set -euo pipefail

SRC="$HOME/projects/coinbase_pipeline/.env.master"
OUT="$HOME/projects/coinbase_pipeline/.env.clean"

awk -F= '
  /^[[:space:]]*#/ {next}      # drop comments
  /^[[:space:]]*$/ {next}      # drop blanks
  {
    key=$1
    val=$2
    sub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    if (key != "") {
      last[key]=$0
    }
  }
  END {
    for (k in last) {
      print last[k]
    }
  }
' "$SRC" | sort > "$OUT"

echo "==> Cleaned env written to $OUT"
echo "To activate: cp $OUT $HOME/projects/coinbase_pipeline/.env"
