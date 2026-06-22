# AzerothCore on AWS with Docker

This Terraform stack launches a single Ubuntu EC2 host that runs AzerothCore images pulled from ECR. It is intentionally boring: one instance, one Elastic IP, one encrypted EBS data volume, one ECR repository, security group rules for the WoW auth/world ports, and a cloud-init bootstrap that installs Docker and starts the server.

## What It Creates

- EC2 instance running Ubuntu 24.04.
- ECR repository for AzerothCore runtime images.
- Elastic IP for stable DNS.
- Encrypted gp3 root volume.
- Encrypted gp3 data volume mounted at `/srv/azerothcore`.
- Security group:
  - `3724/tcp` open publicly for authserver.
  - `8085/tcp` open publicly for worldserver.
  - `22/tcp` only from `admin_cidrs`, when configured.
  - `7878/tcp` SOAP only from `admin_cidrs` when `enable_public_soap = true`.
- Optional AWS DLM daily snapshots of the data volume.
- Optional local daily MySQL dumps under `/srv/azerothcore/backups`.

## First Deploy From PowerShell

From PowerShell:

```powershell
cd \\wsl.localhost\Ubuntu\home\matt\source\repos\azerothcore-wotlk-master\infra\aws-docker
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init
terraform apply
```

The EC2 bootstrap waits up to `image_pull_wait_minutes` for images to appear in ECR. After Terraform prints `ecr_repository_url`, build and push the images from the repo root.

From WSL or Linux:

```bash
cd /home/matt/source/repos/azerothcore-wotlk-master
git submodule update --init --recursive
infra/aws-docker/scripts/build-and-push-images.sh -r us-east-1 -t master
```

From PowerShell, the equivalent manual flow is:

```powershell
cd \\wsl.localhost\Ubuntu\home\matt\source\repos\azerothcore-wotlk-master
$Region = "us-east-1"
$RepoUri = terraform -chdir=infra\aws-docker output -raw ecr_repository_url
$Registry = $RepoUri.Split('/')[0]

aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry

docker build -f apps/docker/Dockerfile --target authserver   -t "${RepoUri}:master-authserver" .
docker build -f apps/docker/Dockerfile --target worldserver  -t "${RepoUri}:master-worldserver" .
docker build -f apps/docker/Dockerfile --target db-import    -t "${RepoUri}:master-db-import" .
docker build -f apps/docker/Dockerfile --target client-data  -t "${RepoUri}:master-client-data" .

docker push "${RepoUri}:master-authserver"
docker push "${RepoUri}:master-worldserver"
docker push "${RepoUri}:master-db-import"
docker push "${RepoUri}:master-client-data"
```

If the instance timed out before the push finished, push the images and replace only the EC2 instance. The persistent data volume is separate:

```powershell
terraform -chdir=infra\aws-docker apply -replace=aws_instance.azerothcore
```

## Squarespace DNS

Use the `squarespace_dns_record` output to create an A record in Squarespace. With the defaults, create:

```text
play.warwid.com  A  <terraform public_ip output>
```

Then set the WoW client realmlist to:

```text
set realmlist play.warwid.com
```

## Local Terraform Setup

For reference, these are the Terraform files:

```powershell
cd \\wsl.localhost\Ubuntu\home\matt\source\repos\azerothcore-wotlk-master\infra\aws-docker
cp terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init
terraform plan
```

## Watch Bootstrap

SSH to the instance and watch cloud-init and Docker:

```bash
sudo cloud-init status --long
cd /srv/azerothcore/runtime
sudo docker compose ps
sudo docker compose logs -f ac-db-import ac-authserver ac-worldserver
```

The first run pulls the ECR images, downloads client data, imports the database, and then starts auth/world. Expect this to take a while. The generated Compose file is validated during bootstrap and copied to `/srv/azerothcore/runtime/docker-compose.rendered.yml` for inspection.

## Create the First Account

Attach to the worldserver console:

```bash
cd /srv/azerothcore/runtime
sudo docker attach ac-worldserver
```

Create an account:

```text
account create <username> <password>
account set gmlevel <username> 3 -1
```

Detach with `Ctrl-p` then `Ctrl-q`. Do not use `Ctrl-c`; it stops the worldserver.

## Small-Group Module Stack

The runtime images include pinned Git submodules for:

- Individual Progression
- AutoBalance
- AHBot
- AoE Loot
- Solo LFG

The worldserver image applies the `warwid-small-group` profile at startup. The
profile updates the persistent configuration under `/srv/azerothcore/etc`
without replacing database connection settings or unrelated administrator
changes.

The initial profile enables:

- AutoBalance for one through six players, including raid scaling.
- Individual Progression with Vanilla/TBC power corrections and selected
  small-group raid mechanics.
- AoE Loot with a 30-yard radius.
- Solo LFG with a reduced dungeon XP multiplier.
- Cross-faction groups, guilds, chat, channels, calendar, and auction house.
- 1.5x kill/quest XP and reputation with 1x equipment drops.

AHBot is installed and configured, but it remains disabled until it has a
dedicated account or character. After creating the AHBot account and character,
add their numeric IDs to the `ac-worldserver` environment in
`/srv/azerothcore/runtime/docker-compose.yml`:

```yaml
environment:
  AC_AHBOT_ACCOUNT_ID: "<account id>"
  AC_AHBOT_CHARACTER_GUID: "<character guid>"
```

Then recreate the worldserver:

```bash
cd /srv/azerothcore/runtime
sudo docker compose up -d --force-recreate ac-worldserver
```

The startup profile enables both the AHBot seller and buyer only when at least
one of these IDs is nonzero.

## Deploy a Module Upgrade

Build and push the new images, then update the existing Docker host without
replacing its persistent EBS volume:

```bash
cd /srv/azerothcore/runtime
sudo docker compose pull
sudo docker compose run --rm ac-db-import
sudo docker compose up -d --force-recreate ac-authserver ac-worldserver
sudo docker compose logs --tail=200 ac-worldserver
```

Running `ac-db-import` before recreating the worldserver applies module database
updates from the new image.

## Useful Maintenance

```bash
cd /srv/azerothcore/runtime
sudo docker compose restart
sudo docker compose pull
sudo docker compose up -d
sudo systemctl start azerothcore-set-realmlist
sudo systemctl start azerothcore-backup
sudo cat /srv/azerothcore/secrets/db-root-password
```

## Notes

- Leave `db_root_password = null` unless you are comfortable storing that password in Terraform state. The default generates it on the EC2 host.
- MySQL is bound to `127.0.0.1` on the instance. Use SSH tunneling for direct DB maintenance.
- Initialize the pinned module set with `git submodule update --init --recursive`
  before building and pushing ECR images.
- If your module has SQL files, put them under the matching `data/sql/custom/...` path before building the `db-import` image.
- EC2 pulls ECR tags based on `image_tag`; with the default `master`, it expects `master-authserver`, `master-worldserver`, `master-db-import`, and `master-client-data`.
