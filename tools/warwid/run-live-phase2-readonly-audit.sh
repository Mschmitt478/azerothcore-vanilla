#!/usr/bin/env bash
set -euo pipefail

LIVE_HOST="${LIVE_HOST:-100.57.50.42}"
LIVE_USER="${LIVE_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-/home/matt/.ssh/teamspeak6-admin.pem}"
SQL_FILE="${SQL_FILE:-tools/warwid/phase2_readonly_audit.sql}"

if [[ ! -f "$SQL_FILE" ]]; then
    echo "SQL file not found: $SQL_FILE" >&2
    exit 1
fi

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$LIVE_USER@$LIVE_HOST" \
    'sudo docker exec -i ac-database sh -lc '\''mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --table'\''' \
    <"$SQL_FILE"
