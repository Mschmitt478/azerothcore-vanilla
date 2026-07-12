# Warwid Playerbots QA Branch

This branch is a disposable QA stack for measuring Warwid dungeon behavior
with one through five Playerbots. It is deliberately separate from production:

- Core base: `mod-playerbots/azerothcore-wotlk` Playerbot-compatible history.
- `mod-playerbots`: pinned to `049f35906ed0b66ea5fcdd7fdc9f12ca2ab480ca`.
- Automated harness: pinned to
  `529ecc8d65927b3c2eca792c58dad11921032cce`.
- Databases: `acore_auth_pb`, `acore_world_pb`, `acore_characters_pb`, and
  `acore_playerbots_pb` only.
- Host bindings: MySQL `127.0.0.1:13306`, authserver `127.0.0.1:13724`, and
  worldserver `127.0.0.1:18085`.
- Playerbots proof commands are disabled in module defaults and enabled only by
  the explicit QA runtime.

Do not deploy this branch with the production Terraform state or against the
production EBS volume.

## First Checkout

```bash
git checkout qa/playerbots-automated
git submodule sync --recursive
git submodule update --init --recursive
tools/warwid/playerbots-qa/qa.sh preflight
```

The preflight refuses non-QA branches, rejects unexpected Playerbots module
revisions, and refuses `/srv/azerothcore`, the production host path.

## Recommended Docker Workflow

Docker is the easiest repeatable path on a Linux workstation, WSL environment,
or dedicated QA EC2 host:

```bash
tools/warwid/playerbots-qa/qa.sh docker-up
tools/warwid/playerbots-qa/qa.sh docker-status
tools/warwid/playerbots-qa/qa.sh dry-run deadmines
tools/warwid/playerbots-qa/qa.sh run deadmines full
tools/warwid/playerbots-qa/qa.sh run ragefire full
tools/warwid/playerbots-qa/qa.sh docker-down
```

`docker-up` creates a private random database password under ignored `var/`
state, builds the QA-only images, creates the four `_pb` databases, applies
module SQL updates, starts the isolated auth/world services, and exposes a
local FIFO for the gate runner. `docker-down` stops containers but preserves
the named QA database and client-data volumes for the next session.

The Docker stack does not publish SOAP, SSH, the Playerbots command server, or
any service on a public interface. AHBot stays disabled so its account state
does not interfere with Playerbots evidence.

## Native Proof Runtime

For a non-Docker Linux build:

```bash
tools/warwid/playerbots-qa/qa.sh patch
tools/warwid/playerbots-qa/qa.sh build
tools/warwid/playerbots-qa/qa.sh profile
tools/warwid/playerbots-qa/qa.sh start
tools/warwid/playerbots-qa/qa.sh run deadmines full
tools/warwid/playerbots-qa/qa.sh stop
```

The native runtime uses the dependency and MySQL layout documented in
`modules/mod-playerbots-automated-testing/tools/playerbots-proof/README.md`.
Use Docker unless that local proof dependency tree is already installed.

## What the Matrix Measures

Each full matrix creates parties of:

1. Warrior
2. Warrior and priest
3. Warrior, priest, and mage
4. Warrior, priest, mage, and rogue
5. Warrior, priest, mage, rogue, and hunter

The gate records placement, logins, deaths, minimum party health, pull timing,
engaged-target count, pack size, combat duration, and an explicit clear
outcome. Results are written beneath:

```text
var/reports/playerbots-proof-gate/
```

The Warwid small-group profile is applied to the QA worldserver, including:

- AutoBalance enabled with a one-player minimum.
- Existing Warwid dungeon and raid inflection points.
- Individual Progression enabled.
- `^RNDBOT.*` accounts explicitly treated as bot accounts.
- AoE Loot and Solo LFG settings matching production.
- AHBot disabled for proof runs.

## Initial Dungeon Coverage

The deterministic crawl coordinates currently verified by the proof core are:

- Ragefire Chasm: `ragefire` or `rfc`
- The Deadmines: `deadmines`

Shadowfang Keep and the Stockade appear in the packaged harness documentation,
but the proof core does not yet contain verified crawl paths for them. Add and
validate those coordinates before enabling them in `qa.sh`; do not treat them
as automated coverage yet.

## AWS Boundary

Run this stack only on a separate QA EC2 instance or disposable runner. A later
AWS phase can build QA-tagged ECR images from this branch and start/stop that
instance on demand. It must use a separate Terraform state, name prefix,
security group, data volume, and backup policy from `play.warwid.com`.
