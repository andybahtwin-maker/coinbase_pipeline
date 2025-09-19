#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$HOME/projects}"
TARGET_DIR="$HOME/projects/coinbase_pipeline"
TARGET_ENV="$TARGET_DIR/.env"
BACKUP="$TARGET_DIR/.env.backup.$(date +%s)"
REPORT_DIR="$TARGET_DIR/.local_secrets"
REPORT_MASKED="$REPORT_DIR/secrets_report_masked.txt"
RAW_COPY="$REPORT_DIR/.env.merged.raw"
TMP_ENV="$REPORT_DIR/.env.merged.tmp"

mkdir -p "$REPORT_DIR"
chmod 700 "$REPORT_DIR"

echo "==> Backing up existing target env (if exists)..."
if [ -f "$TARGET_ENV" ]; then
  cp -a "$TARGET_ENV" "$BACKUP"
  echo "    backed up: $BACKUP"
fi

# Ensure .local_secrets is ignored by git
if [ -f "$TARGET_DIR/.gitignore" ] && ! grep -q "^.local_secrets/" "$TARGET_DIR/.gitignore"; then
  echo ".local_secrets/" >> "$TARGET_DIR/.gitignore"
fi

# Keys of interest
KEYS=(
GROQ_API_KEY OPENAI_API_KEY OPENAI_MODEL
CDP_API_KEY_FILE CB_API_KEY CB_API_SECRET CB_API_PASSPHRASE
EMAIL_TO EMAIL_FROM SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS GMAIL_APP_PASSWORD
NOTION_TOKEN NOTION_PAGE_ID NOTION_API_KEY
AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
GOOGLE_API_KEY GCP_SERVICE_ACCOUNT_JSON
SLACK_BOT_TOKEN DISCORD_TOKEN TELEGRAM_BOT_TOKEN
SENDGRID_API_KEY MAILGUN_API_KEY
DB_URL DATABASE_URL CLIENT_ID CLIENT_SECRET
)

KEY_REGEX="$(IFS='|'; echo "${KEYS[*]}")"

echo "==> Scanning $ROOT for candidate files..."
mapfile -t CANDIDATES < <(find "$ROOT" \
  -path '*/.venv/*' -prune -o \
  -path '*/venv/*' -prune -o \
  -path '*/node_modules/*' -prune -o \
  -path '*/.git/*' -prune -o \
  -type f \( -name '.env' -o -name '.env.*' -o -name '*.env' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.ini' -o -name '*.toml' \) -print 2>/dev/null)

declare -A src_file
declare -A src_val
declare -A src_mtime

clean_val() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  # strip trailing comments
  v="$(sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+\/\/.*$//;' <<<"$v")"
  # trim
  v="$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//;' <<<"$v")"
  printf "%s" "$v"
}

is_placeholder() {
  # avoid bash [[ regex ]] with '<' — use simple checks instead
  local v="$1"
  case "$v" in
    ""|"CHANGEME"|"CHANGE_ME"|REPLACE*|"<"*|*">") return 0 ;;
    *) return 1 ;;
  esac
}

# Extract values
for f in "${CANDIDATES[@]}"; do
  # only text files
  file -b --mime "$f" | grep -q text || continue
  while IFS= read -r raw || [ -n "$raw" ]; do
    key=""; val=""
    if [[ "$raw" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*[:=][[:space:]]*(.+)$ ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    elif [[ "$raw" =~ \"([A-Za-z0-9_]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    else
      continue
    fi
    key="$(echo "$key" | tr '[:lower:]' '[:upper:]')"
    # keep only interesting keys (explicit list OR contains typical secret words)
    if ! grep -qE "^(?:${KEY_REGEX})$" <<<"$key"; then
      echo "$key" | grep -qE 'API|TOKEN|KEY|SECRET|PASS|DB|CREDENTIAL|CLIENT' || continue
    fi
    val="$(clean_val "$val")"
    is_placeholder "$val" && continue

    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    prev="${src_mtime[$key]:-0}"
    if [ -z "${src_val[$key]:-}" ] || [ "$mtime" -ge "$prev" ]; then
      src_val["$key"]="$val"
      src_file["$key"]="$f"
      src_mtime["$key"]="$mtime"
    fi
  done < "$f"
done

# Build merged env
echo "# Coinbase Pipeline merged .env (generated $(date))" > "$TMP_ENV"
echo "# DO NOT COMMIT. See masked report at: $REPORT_MASKED" >> "$TMP_ENV"
for k in "${KEYS[@]}"; do
  echo "${k}=${src_val[$k]:-}" >> "$TMP_ENV"
done

# Include extra discovered keys not in list
for k in "${!src_val[@]}"; do
  match=false
  for std in "${KEYS[@]}"; do
    [ "$k" = "$std" ] && { match=true; break; }
  done
  $match || echo "${k}=${src_val[$k]}" >> "$TMP_ENV"
done

# Masked report
{
  echo "Masked secrets report — $(date)"
  echo "Target env: $TARGET_ENV"
  echo
  printf "%-30s %-42s %s\n" "KEY" "SOURCE FILE" "VALUE (masked)"
  echo "-----------------------------------------------------------------------------------------"
  for k in "${!src_val[@]}"; do
    v="${src_val[$k]}"; n=${#v}
    if (( n <= 6 )); then m="***"
    else m="${v:0:4}…${v: -2}"; fi
    printf "%-30s %-42s %s\n" "$k" "${src_file[$k]}" "$m"
  done
} > "$REPORT_MASKED"

# Install merged env with strict perms + keep a raw copy (locked down)
cp "$TMP_ENV" "$TARGET_ENV"
chmod 600 "$TARGET_ENV"
cp "$TMP_ENV" "$RAW_COPY"
chmod 600 "$RAW_COPY"

echo "==> Merged .env written to: $TARGET_ENV"
echo "==> Masked report: $REPORT_MASKED"
command -v gedit >/dev/null 2>&1 && gedit "$REPORT_MASKED" >/dev/null 2>&1 &

echo "Done. If anything looks wrong, restore backup:"
echo "cp \"$BACKUP\" \"$TARGET_ENV\""
