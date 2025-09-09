#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
( crontab -l 2>/dev/null | grep -v send_snapshot_now.sh; echo "0 9 * * * cd $DIR && ./send_snapshot_now.sh >> cron.log 2>&1" ) | crontab -
echo "Installed: daily snapshot at 09:00 local time. Log: $DIR/cron.log"
