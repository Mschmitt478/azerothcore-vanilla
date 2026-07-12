#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
QA_DIR="$ROOT_DIR/tools/warwid/playerbots-qa"
HARNESS_DIR="$ROOT_DIR/modules/mod-playerbots-automated-testing/tools/playerbots-proof"
INSTALL_DIR="${PROOF_INSTALL_DIR:-$ROOT_DIR/var/install/playerbots-proof}"
BUILD_DIR="${PROOF_BUILD_DIR:-$ROOT_DIR/var/build/playerbots-proof}"
BOT_PREFIX="${PROOF_BOT_ACCOUNT_PREFIX:-rndbot}"
COMPOSE_FILE="$ROOT_DIR/docker-compose.playerbots-qa.yml"
DOCKER_ENV_FILE="$ROOT_DIR/var/runtime/playerbots-proof/docker.env"

usage() {
    cat <<'USAGE'
Usage: tools/warwid/playerbots-qa/qa.sh <command> [arguments]

Commands:
  preflight                 Verify QA branch, pinned modules, and isolation.
  build                     Configure and build the disposable proof install.
  profile                   Render _pb configs and apply Warwid 1-5 tuning.
  start|stop|status         Control the local disposable proof runtime.
  docker-up                 Build and start the isolated Docker QA stack.
  docker-down               Stop containers; preserve QA database volumes.
  docker-status             Show QA container and health status.
  docker-logs               Follow auth/world/database logs.
  dry-run <dungeon>         Render a 1-5 test matrix without running it.
  run <dungeon> [1-5|full] Run one party size or the full 1-5 matrix.
  run-all                   Run full matrices for RFC and Deadmines.

Initial automated crawl coverage is intentionally limited to:
  ragefire (Ragefire Chasm) and deadmines (The Deadmines)

The proof runtime binds MySQL to 127.0.0.1:13306, worldserver to
127.0.0.1:18085, and uses only acore_*_pb databases.
USAGE
}

die() {
    printf 'playerbots-qa: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_qa_branch() {
    local branch
    branch="$(git -C "$ROOT_DIR" branch --show-current)"
    case "$branch" in
        qa/*|warwid/playerbots-proof) ;;
        *) die "refusing to run from non-QA branch '$branch'" ;;
    esac
}

require_harness() {
    [[ -x "$HARNESS_DIR/proof-gate-runner.sh" ]] || die "testing submodule is not initialized"
}

validate_dungeon() {
    case "$1" in
        ragefire|rfc|deadmines) ;;
        *) die "unsupported automated crawl '$1'; use ragefire, rfc, or deadmines" ;;
    esac
}

preflight() {
    require_qa_branch
    require_command git
    require_command grep
    require_harness

    local playerbots_sha testing_sha
    playerbots_sha="$(git -C "$ROOT_DIR/modules/mod-playerbots" rev-parse HEAD)"
    testing_sha="$(git -C "$ROOT_DIR/modules/mod-playerbots-automated-testing" rev-parse HEAD)"
    [[ "$playerbots_sha" == "049f35906ed0b66ea5fcdd7fdc9f12ca2ab480ca" ]] ||
        die "unexpected mod-playerbots revision: $playerbots_sha"
    [[ "$testing_sha" == "bb6bb144a2b52241b45d2af5ae1c20904a7c3d64" ]] ||
        die "unexpected automated-testing revision: $testing_sha"

    [[ -z "$(git -C "$ROOT_DIR/modules/mod-playerbots" status --short)" ]] ||
        die "mod-playerbots has local changes; the QA extension must not patch it"

    [[ "$ROOT_DIR" != /srv/azerothcore* ]] || die "refusing to use the production /srv/azerothcore tree"
    printf 'QA branch and pinned module revisions are valid.\n'
}

build_proof() {
    preflight
    require_command cmake
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
    cmake -S "$ROOT_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DTOOLS_BUILD=db-only \
        -DSCRIPTS=static \
        -DMODULES=static \
        -DNOJEM=1 \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
    cmake --build "$BUILD_DIR" --target install -- -j"$(nproc)"
}

render_profile() {
    preflight
    [[ -f "$INSTALL_DIR/etc/worldserver.conf.dist" ]] || die "proof install is missing; run build first"

    "$HARNESS_DIR/apply-validation-profile.sh" \
        --enable-proof-command \
        --bot-prefix "$BOT_PREFIX"
    CONF_DIR="$INSTALL_DIR/etc" "$ROOT_DIR/apps/docker/apply-warwid-small-group-config.sh"

    grep -Eq 'LoginDatabaseInfo.*acore_auth_pb' "$INSTALL_DIR/etc/authserver.conf" || die "auth DB is not isolated"
    grep -Eq 'WorldDatabaseInfo.*acore_world_pb' "$INSTALL_DIR/etc/worldserver.conf" || die "world DB is not isolated"
    grep -Eq 'CharacterDatabaseInfo.*acore_characters_pb' "$INSTALL_DIR/etc/worldserver.conf" || die "character DB is not isolated"
    grep -Eq 'PlayerbotsDatabaseInfo.*acore_playerbots_pb' "$INSTALL_DIR/etc/modules/playerbots.conf" || die "playerbots DB is not isolated"
    grep -Eq 'PlayerbotsAutomatedTesting\.Enable[[:space:]]*=[[:space:]]*1' "$INSTALL_DIR/etc/modules/playerbots-automated-testing.conf" || die "QA extension is not enabled"
    grep -Eq 'WorldServerPort[[:space:]]*=[[:space:]]*18085' "$INSTALL_DIR/etc/worldserver.conf" || die "world port is not isolated"
    grep -Eq 'AutoBalance.MinPlayers[[:space:]]*=[[:space:]]*1' "$INSTALL_DIR/etc/modules/AutoBalance.conf" || die "AutoBalance 1-player floor is missing"
    grep -Eq 'IndividualProgression.BotAccountsRegex[[:space:]]*=[[:space:]]*"\^RNDBOT\.\*"' "$INSTALL_DIR/etc/modules/individualProgression.conf" || die "RNDBOT progression exclusion is missing"

    printf 'Isolated _pb profile and Warwid 1-5 tuning are ready.\n'
}

run_gate() {
    local dungeon="$1"
    local matrix="${2:-full}"
    validate_dungeon "$dungeon"
    require_harness

    local args=(--dungeon "$dungeon" --bot-prefix "$BOT_PREFIX" --pull-poll-seconds 3 --pull-timeout-seconds 180)
    if [[ "$matrix" == "full" ]]; then
        args+=(--matrix full)
    elif [[ "$matrix" =~ ^[1-5]$ ]]; then
        args+=(--players "$matrix")
    else
        die "party size must be 1-5 or full"
    fi

    PROOF_WORLDSERVER_CONSOLE="$HARNESS_DIR/send-fifo-worldserver-command.sh" \
        "$HARNESS_DIR/proof-gate-runner.sh" "${args[@]}"
}

ensure_docker_environment() {
    require_command docker
    require_command openssl
    mkdir -p "$ROOT_DIR/var/runtime/playerbots-proof/logs" "$ROOT_DIR/var/runtime/playerbots-proof/run"

    if [[ ! -f "$DOCKER_ENV_FILE" ]]; then
        umask 077
        printf 'QA_DB_ROOT_PASSWORD=%s\n' "$(openssl rand -hex 32)" > "$DOCKER_ENV_FILE"
    fi

    grep -Eq '^QA_DB_ROOT_PASSWORD=.{32,}$' "$DOCKER_ENV_FILE" || die "invalid Docker QA environment file"
}

docker_compose() {
    docker compose --env-file "$DOCKER_ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

command_name="${1:-}"
case "$command_name" in
    preflight)
        preflight
        ;;
    build)
        build_proof
        ;;
    profile)
        render_profile
        ;;
    start|stop|status)
        preflight
        "$HARNESS_DIR/proof-runtime.sh" "$command_name"
        ;;
    docker-up)
        preflight
        ensure_docker_environment
        docker_compose config --quiet
        docker_compose up -d --build
        docker_compose ps
        ;;
    docker-down)
        preflight
        ensure_docker_environment
        docker_compose down
        ;;
    docker-status)
        preflight
        ensure_docker_environment
        docker_compose ps
        ;;
    docker-logs)
        preflight
        ensure_docker_environment
        docker_compose logs -f qa-database qa-db-import qa-authserver qa-worldserver
        ;;
    dry-run)
        dungeon="${2:-deadmines}"
        validate_dungeon "$dungeon"
        require_harness
        "$HARNESS_DIR/proof-gate-runner.sh" --dry-run --dungeon "$dungeon" --matrix full --bot-prefix "$BOT_PREFIX"
        ;;
    run)
        preflight
        run_gate "${2:-deadmines}" "${3:-full}"
        ;;
    run-all)
        preflight
        run_gate ragefire full
        run_gate deadmines full
        ;;
    -h|--help|help|'')
        usage
        ;;
    *)
        usage >&2
        die "unknown command: $command_name"
        ;;
esac
