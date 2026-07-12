#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODULE_DIR="${1:-$ROOT_DIR/modules/mod-playerbots}"
PATCH_DIR="$ROOT_DIR/patches/warwid/playerbots-proof"
AUTOMATED_PATCH="$ROOT_DIR/modules/mod-playerbots-automated-testing/patches/warwid/playerbots-proof/0011-Add-proof-combat-state-markers.patch"

die() {
    printf 'playerbots-qa patches: %s\n' "$*" >&2
    exit 1
}

[[ -d "$MODULE_DIR" ]] || die "missing mod-playerbots checkout: $MODULE_DIR"

if grep -q 'missing_engaged_targets=' "$MODULE_DIR/src/Bot/RandomPlayerbotMgr.cpp" &&
   grep -q 'proofCrawlRunStates' "$MODULE_DIR/src/Bot/RandomPlayerbotMgr.h"; then
    printf 'Playerbots QA patch stack is already applied.\n'
    exit 0
fi

if git -C "$MODULE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$MODULE_DIR" diff --quiet || die "mod-playerbots has uncommitted changes; use a clean pinned checkout"
fi

apply_patch_once() {
    local patch="$1"
    [[ -f "$patch" ]] || die "missing patch: $patch"

    (
        cd "$MODULE_DIR"
        patch --dry-run --batch --forward -p1 < "$patch" >/dev/null || die "patch does not apply cleanly: $patch"
        patch --batch --forward -p1 < "$patch"
    )
    printf 'Applied: %s\n' "$(basename -- "$patch")"
}

for patch in \
    "$PATCH_DIR/0001-Add-proof-dungeon-harness-for-playerbots.patch" \
    "$PATCH_DIR/0002-Use-LFG-teleport-for-proof-dungeon-placement.patch" \
    "$PATCH_DIR/0003-Add-proof-dungeon-reset-command.patch" \
    "$PATCH_DIR/0004-Add-proof-crawl-target-outcome-logging.patch" \
    "$PATCH_DIR/0005-Add-proof-combat-baseline-markers.patch"; do
    apply_patch_once "$patch"
done

# The packaged 0011 patch was generated after the proof branch already had the
# explicit ObjectAccessor include and ProofCrawlRunState declaration. Patch
# 0005 now carries those two prerequisites, so remove only those duplicate
# hunks while preserving every combat-state implementation hunk from 0011.
sanitized_patch="$(mktemp)"
trap 'rm -f "$sanitized_patch"' EXIT
awk '
    /^diff --git a\/src\/Bot\/RandomPlayerbotMgr\.h / { exit }
    /^@@ -37,6 \+37,7/ { skip = 1; next }
    skip && /^@@ / { skip = 0 }
    !skip { print }
' "$AUTOMATED_PATCH" > "$sanitized_patch"

(
    cd "$MODULE_DIR"
    patch --dry-run --batch --forward -p1 < "$sanitized_patch" >/dev/null || die "sanitized 0011 patch does not apply cleanly"
    patch --batch --forward -p1 < "$sanitized_patch"
)
printf 'Applied: 0011-Add-proof-combat-state-markers.patch (deduplicated)\n'

grep -q 'AiPlayerbot\.ProofDungeonCommand = 0' "$MODULE_DIR/conf/playerbots.conf.dist" || die "proof command default is not disabled"
grep -q 'PLAYERBOTS_PROOF_CRAWL pull_observe' "$MODULE_DIR/src/Bot/RandomPlayerbotMgr.cpp" || die "combat evidence markers are missing"
grep -q 'proofCrawlRunStates' "$MODULE_DIR/src/Bot/RandomPlayerbotMgr.h" || die "proof crawl state is missing"

printf 'Playerbots QA patch stack is ready.\n'
