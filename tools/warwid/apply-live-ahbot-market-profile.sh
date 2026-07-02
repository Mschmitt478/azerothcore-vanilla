#!/usr/bin/env bash
set -euo pipefail

LIVE_HOST="${LIVE_HOST:-100.57.50.42}"
LIVE_USER="${LIVE_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-/home/matt/.ssh/teamspeak6-admin.pem}"
SQL_FILE="${SQL_FILE:-tools/warwid/ahbot_live_server_market_profile.sql}"
RESTART_WORLDSERVER="${RESTART_WORLDSERVER:-1}"
RESET_AHBOT_AUCTIONS="${RESET_AHBOT_AUCTIONS:-0}"

if [[ ! -f "$SQL_FILE" ]]; then
    echo "SQL file not found: $SQL_FILE" >&2
    exit 1
fi

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$LIVE_USER@$LIVE_HOST" \
    "RESTART_WORLDSERVER='$RESTART_WORLDSERVER' bash -s" <<'REMOTE'
set -euo pipefail

stamp="$(date -u +%F-%H%M%S)"
backup_dir="/srv/azerothcore/backups/${stamp}-pre-ahbot-live-server-market-profile"
mkdir -p "$backup_dir"

db_password="$(sudo cat /srv/azerothcore/secrets/db-root-password)"

for db in acore_auth acore_characters acore_world; do
    sudo docker exec ac-database mysqldump -uroot -p"$db_password" "$db" | gzip -9 | sudo tee "$backup_dir/$db.sql.gz" >/dev/null
done

sudo cp -a /srv/azerothcore/etc/modules/mod_ahbot.conf "$backup_dir/mod_ahbot.conf"

set_config_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local escaped_key

    escaped_key="$(printf '%s' "$key" | sed 's/[][\/.^$*+?{}()|]/\\&/g')"

    if sudo grep -Eq "^[[:space:]]*${escaped_key}[[:space:]]*=" "$file"; then
        sudo sed -i -E "s|^[[:space:]]*${escaped_key}[[:space:]]*=.*$|${key} = ${value}|" "$file"
    else
        printf '\n%s = %s\n' "$key" "$value" | sudo tee -a "$file" >/dev/null
    fi
}

ahbot_conf="/srv/azerothcore/etc/modules/mod_ahbot.conf"
set_config_value "$ahbot_conf" "AuctionHouseBot.ItemsPerCycle" "150"
set_config_value "$ahbot_conf" "AuctionHouseBot.DuplicatesCount" "2"
set_config_value "$ahbot_conf" "AuctionHouseBot.DivisibleStacks" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.VendorItems" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.VendorTradeGoods" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.OtherItems" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.OtherTradeGoods" "0"
set_config_value "$ahbot_conf" "AuctionHouseBot.ProfessionItems" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableConjured" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableMoneyLoot" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableLootable" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableKeys" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableDuration" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableBOP_Or_Quest_NoReqLevel" "1"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableItemsBelowLevel" "2"
set_config_value "$ahbot_conf" "AuctionHouseBot.DisableItemsAboveLevel" "187"

echo "$backup_dir"
REMOTE

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$LIVE_USER@$LIVE_HOST" \
    'sudo docker exec -i ac-database sh -lc '\''mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --table'\''' \
    <"$SQL_FILE"

if [[ "$RESET_AHBOT_AUCTIONS" == "1" ]]; then
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$LIVE_USER@$LIVE_HOST" \
        'sudo docker exec -i ac-database sh -lc '\''mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --table'\''' \
        <"tools/warwid/ahbot_clear_bot_owned_auctions.sql"
fi

if [[ "$RESTART_WORLDSERVER" == "1" ]]; then
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$LIVE_USER@$LIVE_HOST" \
        'cd /srv/azerothcore/runtime && sudo docker compose up -d --force-recreate ac-worldserver && sudo docker compose ps ac-worldserver'
fi
