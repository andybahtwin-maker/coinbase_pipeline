#!/usr/bin/env bash
set -euo pipefail
source ./source.env

echo "🔎 Scanning: $ENV_DIR"
mapfile -t CANDIDATES < <(find "$ENV_DIR" -type f \( -name ".env" -o -name "*.env" -o -iname "*coinbase*" -o -iname "*api*" \) -printf "%T@ %p\n" | sort -nr | awk '{ $1=""; sub(/^ /,""); print }')

if [ ${#CANDIDATES[@]} -eq 0 ]; then
  echo "No .env/API-looking files found in $ENV_DIR."
  exit 0
fi

echo "Found candidate secret files (newest first):"
printf '  - %s\n' "${CANDIDATES[@]}"

BEST="${CANDIDATES[0]}"
read -r -p "Copy newest candidate into ./ .env ? [y/N] " YN
if [[ "${YN:-N}" =~ ^[Yy]$ ]]; then
  cp -f "$BEST" ./.env
  chmod 600 ./.env
  echo "✅ Copied: $BEST -> ./.env"
else
  echo "Skipped copy. You can open candidates with: gedit ${CANDIDATES[*]} &"
fi

echo
echo "🔐 Grepping keys (masked lines):"
grep -R --line-number -E "(COINBASE|API|SECRET|PASSPHRASE|KEY)=" "$ENV_DIR" | sed 's/=.*/=********/'

echo "Done."
