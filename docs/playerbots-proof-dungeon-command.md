# Playerbots Proof Dungeon Command

This proof branch adds a disabled-by-default, test-only worldserver console command:

```text
playerbots rndbot proofdungeon <dungeon|lfgId|mapId|name> <groupSize> [run=<id>] [class ...]
playerbots rndbot proofcrawl <dungeon|lfgId|mapId|name> [run=<id>] <status|pull|steps>
```

Enable it only in this disposable proof tree:

```ini
AiPlayerbot.ProofDungeonCommand = 1
```

The command selects same-faction RNDbots from the in-memory random bot account lists loaded by Playerbots, requests login for selected offline bots, prepares selected online bots to the target dungeon level with the RNDbot factory, resets stale proof LFG groups and temporary instance binds for the selected bots, creates or reuses a normal group for multi-bot placement, teleports the leader into the dungeon, binds the selected cohort to the leader's created instance save, teleports the remaining bots to the LFG dungeon entrance coordinates, verifies the group landed in one shared instance, then marks/tags the group as LFG evidence through the public LFG API. It also temporarily holds normal RNDbot randomize/teleport/strategy timers for 30 minutes, blocks proof-selected bots from the random teleport path while the proof event is active, and writes `PLAYERBOTS_PROOF_DUNGEON` evidence lines to the `playerbots` log channel.

Bot login is asynchronous. If the first run reports pending logins, wait for the bot login lines, then run the same command again. Offline bots are prepared after they finish logging in and the command is re-run.

## Build

From the repo root:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF
cmake --build build --target worldserver -j"$(nproc)"
```

Use the existing proof DB/config flow for this branch. Do not import this into live deploy defaults.

If the `modules/mod-playerbots` submodule commit is not available from a remote yet, apply the parent-repo patch artifacts to a clean `mod-playerbots` checkout:

```bash
git -C modules/mod-playerbots am ../../patches/warwid/playerbots-proof/*.patch
```

## Run Examples

From the `worldserver` console, without a client session:

```text
playerbots rndbot proofdungeon rfc 1
playerbots rndbot proofdungeon rfc 5
playerbots rndbot proofdungeon deadmines 1
playerbots rndbot proofdungeon deadmines 5
```

Numeric forms also work:

```text
playerbots rndbot proofdungeon 389 5
playerbots rndbot proofdungeon 36 5
```

`rfc` resolves by map id `389` and `deadmines` resolves by map id `36`. Numeric `36` and `389` are treated as those map ids; other numeric tokens are tried as LFG dungeon ids first, then map ids.

For class/composition matrix tests, provide a numeric proof run id and one class token per requested group member:

```text
playerbots rndbot proofdungeon deadmines 1 run=101 warrior
playerbots rndbot proofdungeon deadmines 2 run=201 warrior priest
playerbots rndbot proofdungeon deadmines 3 run=301 warrior priest mage
playerbots rndbot proofdungeon deadmines 5 run=501 warrior priest mage rogue hunter

playerbots rndbot proofreset all
playerbots rndbot proofreset run=501

playerbots rndbot proofcrawl deadmines run=101 status
playerbots rndbot proofcrawl deadmines run=201 2
playerbots rndbot proofcrawl deadmines run=501 3
playerbots rndbot proofcrawl deadmines run=501 pull
```

## Evidence To Capture

Log marker:

```bash
rg "PLAYERBOTS_PROOF_DUNGEON" var/logs logs build/bin/logs
```

Useful SQL checks:

```sql
SELECT bot, event, value, data, time, validIn
FROM acore_playerbots_pb.playerbots_random_bots
WHERE event IN ('proof_dungeon', 'proof_run', 'add')
ORDER BY time DESC, bot;

SELECT guid, name, level, race, class, online, map, position_x, position_y, position_z
FROM acore_characters_pb.characters
WHERE online = 1
ORDER BY guid;

SELECT guid, memberGuid, memberFlags, subgroup, roles
FROM acore_characters_pb.group_member
ORDER BY guid, memberGuid;
```

Expected log sequence:

```text
PLAYERBOTS_PROOF_DUNGEON login_requested ...
PLAYERBOTS_PROOF_DUNGEON pending ...
PLAYERBOTS_PROOF_DUNGEON prepared ... old_level=... target_level=... new_level=... level_adjusted=yes|no
PLAYERBOTS_PROOF_DUNGEON group_reset ...
PLAYERBOTS_PROOF_DUNGEON lfg_candidate_seeded ...
PLAYERBOTS_PROOF_DUNGEON placed ...
PLAYERBOTS_PROOF_DUNGEON ready ...
```

For already-online selected bots, the command may skip the login/pending lines and continue through `prepared`, `placed`, and `ready`.
`group_reset` appears only when a selected bot was still in a previous proof LFG group.
`placement_failed` means at least one selected bot failed teleport or a multi-bot proof group did not land in one shared instance. Treat that run as invalid evidence and rerun after fixing the placement issue.

## Crawl Driver

After a party is staged with `proofdungeon`, run a crawl step:

```text
playerbots rndbot proofcrawl deadmines 1
playerbots rndbot proofcrawl deadmines status
playerbots rndbot proofcrawl deadmines run=501 1
playerbots rndbot proofcrawl deadmines run=501 status
```

`proofcrawl` uses hard-coded proof waypoints for RFC and Deadmines. It does not try to solve the whole dungeon yet; it moves the currently staged proof bots toward nearby early pulls and logs `PLAYERBOTS_PROOF_CRAWL` evidence with live instance id, position, class, level, combat, death, health state, and selected target outcome.

When `run=<id>` is supplied, `proofcrawl` only moves or reports bots staged with that same run id. This allows multiple proof groups with different sizes and class compositions to be staged in the same disposable world and advanced independently.

`proofreset` clears proof-only reservations between matrix passes:

```text
playerbots rndbot proofreset all
playerbots rndbot proofreset run=501
```

Use it before starting a fresh matrix. Proof reservations intentionally hold selected bots for 30 minutes so evidence capture is stable; without a reset, later class-specific runs can fail with `insufficient_candidates` because the desired class is still reserved by another proof run.

Supported first-pass step range is `1-5` for RFC and `1-10` for Deadmines. Run `status` after each step settles.

The `pull` action searches for the nearest valid hostile target around any bot in the staged run, selects that same target for the run, switches each bot into combat AI, issues a normal attack start where possible, and logs the target and bot instance ids:

```text
PLAYERBOTS_PROOF_CRAWL pull_target ...
PLAYERBOTS_PROOF_CRAWL pull_issued ...
PLAYERBOTS_PROOF_CRAWL pull ...
```

After a pull, run `status` again. Status logs include target outcome fields:

```text
target_visible=yes|no target_entry=... target_name='...' target_alive=yes|no target_health_pct=... target_distance=...
```

For the current proof harness, `target_visible=no` after a pull is useful evidence, but it is not by itself a guaranteed kill confirmation. The next hardening step is to add explicit kill/credit tracking from combat events or creature death hooks.

Use `pull` after moving a group near an early pack:

```text
playerbots rndbot proofcrawl deadmines run=301 2
playerbots rndbot proofcrawl deadmines run=301 pull
sleep 10
playerbots rndbot proofcrawl deadmines run=301 status
```

## Notes

- The command is gated by `AiPlayerbot.ProofDungeonCommand = 0` by default.
- It only selects RNDbots, not `.bot addclass` characters.
- It selects deterministically by faction and character GUID from the RNDbot account pool; current bot level is not used as a selection filter.
- It keeps all selected bots on one faction. If either faction has enough RNDbot characters for the requested group size, the command can prepare a 1-5 bot proof group for the resolved dungeon.
- It can select a specific composition with bare class tokens: `warrior`, `paladin`, `hunter`, `rogue`, `priest`, `dk`, `shaman`, `mage`, `warlock`, and `druid`.
- It can tag independent cohorts with `run=<id>`. Bots already reserved by a different active proof run are skipped during selection.
- It uses the dungeon's configured max level as `target_level` and rebuilds selected online bots through `PlayerbotFactory::Randomize(false)` when their current level differs.
- It temporarily suppresses normal RNDbot randomize/teleport/strategy timers and blocks the random teleport path for selected bots so evidence capture is stable.
- It resets old proof LFG groups before each all-online placement pass so repeated `1` and `5` size tests do not inherit stale members.
- It requires `lfg_dungeon_template` coordinates for the resolved dungeon.
- It is intentionally idempotent for repeatable testing: re-running the same command can finish placement after asynchronous logins complete.
