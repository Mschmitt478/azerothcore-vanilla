#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release openssl unzip default-mysql-client

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

cat >/etc/apt/sources.list.d/docker.list <<'EOF_DOCKER_REPO'
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable
EOF_DOCKER_REPO

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

DATA_DEVICE=""
for _ in $(seq 1 300); do
  for candidate in "${data_volume_device}" /dev/nvme1n1 /dev/xvdf /dev/sdf; do
    if [ -b "$candidate" ]; then
      DATA_DEVICE="$candidate"
      break 2
    fi
  done
  sleep 2
done

if [ -z "$DATA_DEVICE" ]; then
  echo "Timed out waiting for the AzerothCore EBS data volume" >&2
  exit 1
fi

if ! blkid "$DATA_DEVICE"; then
  mkfs.ext4 -F "$DATA_DEVICE"
fi

mkdir -p /srv/azerothcore
UUID="$(blkid -s UUID -o value "$DATA_DEVICE")"
if ! grep -q "$UUID" /etc/fstab; then
  echo "UUID=$UUID /srv/azerothcore ext4 defaults,nofail 0 2" >>/etc/fstab
fi
mount /srv/azerothcore

mkdir -p /srv/azerothcore/{backups,client-data,etc,logs,mysql,runtime,secrets}
chown -R ubuntu:ubuntu /srv/azerothcore

if [ "${swap_size_gb}" -gt 0 ] && [ ! -f /srv/azerothcore/swapfile ]; then
  fallocate -l "${swap_size_gb}G" /srv/azerothcore/swapfile
  chmod 600 /srv/azerothcore/swapfile
  mkswap /srv/azerothcore/swapfile
fi

if [ -f /srv/azerothcore/swapfile ] && ! grep -q "/srv/azerothcore/swapfile" /etc/fstab; then
  echo "/srv/azerothcore/swapfile none swap sw 0 0" >>/etc/fstab
fi
swapon -a

if [ ! -f /srv/azerothcore/secrets/db-root-password ]; then
  if [ -n "${db_root_password}" ]; then
    printf '%s' "${db_root_password}" >/srv/azerothcore/secrets/db-root-password
  else
    openssl rand -base64 36 >/srv/azerothcore/secrets/db-root-password
  fi
  chmod 600 /srv/azerothcore/secrets/db-root-password
fi

aws ecr get-login-password --region "${aws_region}" | docker login --username AWS --password-stdin "${ecr_registry}"

for image in \
  "${ecr_repository_url}:${image_tag}-authserver" \
  "${ecr_repository_url}:${image_tag}-worldserver" \
  "${ecr_repository_url}:${image_tag}-db-import" \
  "${ecr_repository_url}:${image_tag}-client-data"; do
  pulled=0
  for _ in $(seq 1 $(( ${image_pull_wait_minutes} * 2 ))); do
    if docker pull "$image"; then
      pulled=1
      break
    fi
    sleep 30
  done

  if [ "$pulled" -ne 1 ]; then
    echo "Timed out waiting for ECR image $image" >&2
    exit 1
  fi
done

DB_ROOT_PASSWORD="$(cat /srv/azerothcore/secrets/db-root-password)"
cd /srv/azerothcore/runtime

umask 077
cat >docker-compose.yml <<EOF_COMPOSE
services:
  ac-database:
    container_name: ac-database
    image: mysql:8.4
    networks:
      - ac-network
    ports:
      - "127.0.0.1:${db_external_port}:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
    volumes:
      - /srv/azerothcore/mysql:/var/lib/mysql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "mysql --user=root --password=\"\$\$MYSQL_ROOT_PASSWORD\" --execute \"SHOW DATABASES;\""]
      interval: 5s
      timeout: 10s
      retries: 40
      start_period: 30s

  ac-db-import:
    container_name: ac-db-import
    image: ${ecr_repository_url}:${image_tag}-db-import
    networks:
      - ac-network
    environment:
      AC_DATA_DIR: "/azerothcore/env/dist/data"
      AC_LOGS_DIR: "/azerothcore/env/dist/logs"
      AC_LOGIN_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_auth"
      AC_WORLD_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_world"
      AC_CHARACTER_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_characters"
    volumes:
      - /srv/azerothcore/etc:/azerothcore/env/dist/etc
      - /srv/azerothcore/logs:/azerothcore/env/dist/logs

  ac-client-data-init:
    container_name: ac-client-data-init
    image: ${ecr_repository_url}:${image_tag}-client-data
    volumes:
      - /srv/azerothcore/client-data:/azerothcore/env/dist/data
    restart: "no"

  ac-worldserver:
    container_name: ac-worldserver
    image: ${ecr_repository_url}:${image_tag}-worldserver
    networks:
      - ac-network
    stdin_open: true
    tty: true
    restart: unless-stopped
    environment:
      AC_DATA_DIR: "/azerothcore/env/dist/data"
      AC_LOGS_DIR: "/azerothcore/env/dist/logs"
      AC_REALM_ID: "1"
      AC_CLOSE_IDLE_CONNECTIONS: "0"
      AC_LOGIN_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_auth"
      AC_WORLD_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_world"
      AC_CHARACTER_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_characters"
    ports:
      - "${world_port}:8085"
      - "%{ if enable_public_soap }${soap_port}%{ else }127.0.0.1:${soap_port}%{ endif }:7878"
    volumes:
      - /srv/azerothcore/etc:/azerothcore/env/dist/etc
      - /srv/azerothcore/logs:/azerothcore/env/dist/logs
      - /srv/azerothcore/client-data:/azerothcore/env/dist/data:ro
    depends_on:
      ac-database:
        condition: service_healthy

  ac-authserver:
    container_name: ac-authserver
    image: ${ecr_repository_url}:${image_tag}-authserver
    networks:
      - ac-network
    tty: true
    restart: unless-stopped
    environment:
      AC_LOGS_DIR: "/azerothcore/env/dist/logs"
      AC_TEMP_DIR: "/azerothcore/env/dist/temp"
      AC_CLOSE_IDLE_CONNECTIONS: "0"
      AC_LOGIN_DATABASE_INFO: "ac-database;3306;root;$DB_ROOT_PASSWORD;acore_auth"
    volumes:
      - /srv/azerothcore/etc:/azerothcore/env/dist/etc
      - /srv/azerothcore/logs:/azerothcore/env/dist/logs
    ports:
      - "${auth_port}:3724"
    depends_on:
      ac-database:
        condition: service_healthy

networks:
  ac-network:
EOF_COMPOSE
chmod 600 docker-compose.yml

docker compose config >/srv/azerothcore/runtime/docker-compose.rendered.yml
docker compose up -d ac-database

for _ in $(seq 1 120); do
  if [ "$(docker inspect --format '{{.State.Health.Status}}' ac-database)" = "healthy" ]; then
    break
  fi
  sleep 5
done

if [ "$(docker inspect --format '{{.State.Health.Status}}' ac-database)" != "healthy" ]; then
  echo "Timed out waiting for ac-database to become healthy" >&2
  docker compose logs ac-database >&2
  exit 1
fi

docker compose run --rm ac-db-import
docker compose run --rm ac-client-data-init
docker compose up -d ac-authserver ac-worldserver

cat >/usr/local/sbin/azerothcore-set-realmlist.sh <<'EOF_REALMLIST'
#!/usr/bin/env bash
set -euo pipefail

DB_ROOT_PASSWORD="$(cat /srv/azerothcore/secrets/db-root-password)"

for _ in $(seq 1 180); do
  if docker exec ac-database mysql -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1 FROM acore_auth.realmlist LIMIT 1;" >/dev/null 2>&1; then
    docker exec ac-database mysql -uroot -p"$DB_ROOT_PASSWORD" -e "UPDATE acore_auth.realmlist SET name='__REALM_NAME__', address='__REALM_ADDRESS__', port=__WORLD_PORT__, localAddress='127.0.0.1', localSubnetMask='255.255.255.0' WHERE id=1;"
    exit 0
  fi
  sleep 10
done

echo "Timed out waiting for acore_auth.realmlist" >&2
exit 1
EOF_REALMLIST

sed -i \
  -e "s/__REALM_NAME__/${realm_name}/g" \
  -e "s/__REALM_ADDRESS__/${realm_address}/g" \
  -e "s/__WORLD_PORT__/${world_port}/g" \
  /usr/local/sbin/azerothcore-set-realmlist.sh
chmod 755 /usr/local/sbin/azerothcore-set-realmlist.sh

cat >/etc/systemd/system/azerothcore-set-realmlist.service <<'EOF_REALMLIST_SERVICE'
[Unit]
Description=Set AzerothCore public realmlist address
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/azerothcore-set-realmlist.sh

[Install]
WantedBy=multi-user.target
EOF_REALMLIST_SERVICE

systemctl daemon-reload
systemctl enable --now azerothcore-set-realmlist.service

%{ if enable_mysql_backups ~}
cat >/usr/local/sbin/azerothcore-backup.sh <<'EOF_BACKUP'
#!/usr/bin/env bash
set -euo pipefail

stamp="$(date -u +%F-%H%M%S)"
dest="/srv/azerothcore/backups/$stamp"
mkdir -p "$dest"
DB_ROOT_PASSWORD="$(cat /srv/azerothcore/secrets/db-root-password)"

for db in acore_auth acore_characters acore_world; do
  docker exec ac-database mysqldump -uroot -p"$DB_ROOT_PASSWORD" "$db" | gzip -9 >"$dest/$db.sql.gz"
done
EOF_BACKUP
chmod 755 /usr/local/sbin/azerothcore-backup.sh

cat >/etc/systemd/system/azerothcore-backup.service <<'EOF_BACKUP_SERVICE'
[Unit]
Description=Back up AzerothCore MySQL databases
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/azerothcore-backup.sh
EOF_BACKUP_SERVICE

cat >/etc/systemd/system/azerothcore-backup.timer <<EOF_BACKUP_TIMER
[Unit]
Description=Run AzerothCore MySQL backup daily

[Timer]
OnCalendar=*-*-* ${mysql_backup_hour_utc}:00:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
EOF_BACKUP_TIMER

systemctl daemon-reload
systemctl enable --now azerothcore-backup.timer
%{ endif ~}
