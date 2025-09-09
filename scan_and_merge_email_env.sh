#!/usr/bin/env bash
set -euo pipefail

# load our config (ENV_DIR/OUTPUT_DIR may already exist here)
if [[ -f source.env ]]; then
  # shellcheck disable=SC1091
  source source.env
fi

: "${APPLY_ENV_DIR:="/home/andhe001/Desktop/applypilot_total(2.0)"}"

# where we merge to
TARGET_ENV="./.env"
BACKUP="./.env.bak.$(date +%s)"

echo "🔎 Scanning for .env in: $APPLY_ENV_DIR"
mapfile -t CANDIDATES < <(find "$APPLY_ENV_DIR" -type f \
  \( -name ".env" -o -name "*.env" -o -iname "*email*" -o -iname "*smtp*" -o -iname "*gmail*" \) \
  -printf "%T@ %p\n" | sort -nr | awk '{ $1=""; sub(/^ /,""); print }')

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No .env-like files found under: $APPLY_ENV_DIR"
  exit 0
fi

echo "Found candidate env files (newest first):"
printf '  - %s\n' "${CANDIDATES[@]}"
BEST="${CANDIDATES[0]}"
echo
read -r -p "Use newest candidate above? [Y/n] " YN
if [[ "${YN:-Y}" =~ ^[Yy]$ ]]; then
  PICK="$BEST"
else
  echo "Paste the full path of the one you want:"
  read -r PICK
fi

if [[ ! -f "$PICK" ]]; then
  echo "Selected file does not exist: $PICK"
  exit 1
fi

echo
echo "🔐 Preview (masked) of email/Gmail/SMTP keys in: $PICK"
# show only likely email keys, mask values
grep -E '^(SMTP_|MAIL_|EMAIL_|GMAIL_|SENDER_|RECIPIENT_|FROM_|TO_)[A-Z0-9_]*=' "$PICK" \
  | sed 's/=.*/=********/' || true

# extract only relevant keys (edit patterns if your names differ)
TMP_EXTRACT="$(mktemp)"
grep -E '^(SMTP_|MAIL_|EMAIL_|GMAIL_|SENDER_|RECIPIENT_|FROM_|TO_)[A-Z0-9_]*=' "$PICK" > "$TMP_EXTRACT" || true

if [[ ! -s "$TMP_EXTRACT" ]]; then
  echo "No email/Gmail/SMTP env vars detected in that file."
  rm -f "$TMP_EXTRACT"
  exit 0
fi

# ensure a target .env exists (could be empty)
touch "$TARGET_ENV"

# backup current .env
cp -f "$TARGET_ENV" "$BACKUP"
echo "🧾 Backed up existing .env -> $BACKUP"

# merge: for each KEY=VAL in TMP_EXTRACT
while IFS='=' read -r K V; do
  [[ -z "${K:-}" ]] && continue
  # remove any existing line that starts with KEY=
  sed -i "/^${K}=.*/d" "$TARGET_ENV"
  # append the new KEY=VAL
  echo "${K}=${V}" >> "$TARGET_ENV"
done < "$TMP_EXTRACT"

chmod 600 "$TARGET_ENV"
rm -f "$TMP_EXTRACT"

echo "✅ Merged email variables into $TARGET_ENV"
echo "Open to review/edit:"
echo "  gedit $TARGET_ENV &"
