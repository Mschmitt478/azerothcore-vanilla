# Phase 2 Stable Baseline Validation

Phase: 2 - verify the live small-group stack before combat or economy tuning.

No gameplay tuning changes were made in this phase entry.

## Ticket Scope

| Ticket | Status | Scope |
| --- | --- | --- |
| `EMBER-35` | In progress | Phase 2 stable baseline validation umbrella. |
| `EMBER-36` | Partially validated | Validate AutoBalance live command output. |
| `EMBER-37` | Blocked on 1-5 player client test | Validate Solo LFG for 1-5 players. |
| `EMBER-38` | Partially validated | Validate Individual Progression gates. |
| `EMBER-39` | Partially validated | Audit AHBot item mix and prices. |
| `EMBER-62` | Live fix validated | Fix AutoBalance console command crash. |

## Live Access Findings

Observed 2026-07-01.

- `ac-worldserver`, `ac-authserver`, and `ac-database` are running.
- `ac-worldserver` exposes world port `8085` publicly.
- Host port `7878` maps to the worldserver container, but `SOAP.Enabled = 0` in `/srv/azerothcore/etc/worldserver.conf`.
- `Ra.Enable = 0`.
- `Console.Enable = 1`, but `docker attach` cannot be used non-interactively because the container has a TTY-enabled stdin.

Impact:

- `.ab mapstat`, `.ab creaturestat`, `.ab getoffset`, and `.ip get` still need an in-game GM character or a deliberate admin-command transport change.
- Do not enable SOAP or RA casually on the public host. If remote command automation is needed, bind it to localhost/private admin access, create a backup first, and document the config delta.

## AutoBalance Console Command Defect

Observed 2026-07-01.

Commands attempted through a real pseudo-TTY SSH attach to `ac-worldserver`:

| Command | Result |
| --- | --- |
| `server info` | Succeeded. Reported AzerothCore `d15f74f18e94+`, 0 connected players, uptime 8 days 21 hours. |
| `.ab getoffset` | Closed the attach session and restarted `ac-worldserver`. |

Post-check:

- `ac-worldserver` restarted once and returned to running state.
- Docker `RestartCount` became `1`.
- Tailed logs showed normal startup completion after the restart.

Interpretation:

- Do not run AutoBalance commands from the bare worldserver console until this is understood.
- The likely safe path for `EMBER-36` is an in-game GM character/session or a deliberately secured SOAP/RA command path, not direct console execution.
- This should be tracked as a defect because AutoBalance command availability was part of the requested validation scope.
- A candidate source patch is preserved at `patches/warwid/mod-autobalance-console-null-session.patch`. Because `mod-autobalance` is a submodule that points at upstream `azerothcore/mod-autobalance`, the parent repo does not update the submodule pointer to a local-only commit.
- The Warwid Docker build applies the patch before CMake configures modules, so rebuilt Warwid images can include the fix without forking the module immediately.

## AutoBalance Console Fix Live Validation

Observed 2026-07-01 after deploying merged `master` commit `bfed8ec04af8+`.

Deployment evidence:

- Pre-deploy live backup: `/srv/azerothcore/backups/2026-07-01-220619-pre-ember-62-deploy`
- Deployed worldserver image ID: `sha256:fba595dcd527847bc1053856dd065078c8d1e70e7315ef9590364a803ed82e12`
- Live worldserver revision: `bfed8ec04af8+ 2026-07-01 18:03:03 -0400 (master branch)`
- Database importer applied upstream updates before the server recreate:
  - Auth database: already up to date
  - Character database: `2026_06_24_00.sql`
  - World database: `2026_06_25_00.sql` through `2026_06_30_06.sql`

Commands attempted through a real pseudo-TTY SSH attach to `ac-worldserver`:

| Command | Result |
| --- | --- |
| `server info` | Succeeded. Reported AzerothCore `bfed8ec04af8+`, 0 connected players, uptime 1 minute. |
| `.ab getoffset` | Succeeded. Returned `Current Player Difficulty Offset = 0.` |
| `.ab mapstat` | Failed safely outside player context. Returned `This command can only be used in a dungeon or raid.` |
| `.ab creaturestat` | Failed safely outside player context. Returned `You should select a creature.` |

Post-check:

- `ac-worldserver` remained running.
- Docker `RestartCount` remained `0`.
- Tailed logs showed the command output and no restart loop.

Interpretation:

- The preserved AutoBalance console null-session fix is present in the live Warwid image.
- `.ab getoffset`, `.ab mapstat`, and `.ab creaturestat` are now safe from the bare server console on the deployed image.
- `.ab mapstat` and `.ab creaturestat` still need in-game dungeon context from a GM character because meaningful output depends on an active map/selected creature.

## Read-Only Audit Script

Added:

- `tools/warwid/phase2_readonly_audit.sql`
- `tools/warwid/run-live-phase2-readonly-audit.sh`

Run from the repo root:

```bash
tools/warwid/run-live-phase2-readonly-audit.sh
```

The script uses SSH and the live database container's existing `MYSQL_ROOT_PASSWORD` environment variable. It does not print or store the password.

## AHBot Baseline

Observed with the read-only audit on 2026-07-01 before the live image update.

| Metric | Result |
| --- | ---: |
| Bot owner GUID | `2` |
| Bot-owned auctions | `250` |
| Total bot buyout value | `286.13g` |
| Quality `1` auctions | `250` |
| Quality `2+` auctions | `0` |
| Vendor-resale candidates | `0` |

Interpretation:

- Current AHBot output is conservative in the sampled live state.
- No blue, purple, or raid-equivalent auctions were present in the current sample.
- No current auction had a buyout below its vendor value.
- This does not finish AH economy validation; it only establishes the first measured baseline. Continue sampling at level brackets `10`, `20`, `40`, `60`, `70`, and `80`.

Observed with the read-only audit on 2026-07-01 after deploying `bfed8ec04af8+`.

| Metric | Result |
| --- | ---: |
| Bot owner GUID | `2` |
| Bot-owned auctions | `250` |
| Total bot buyout value | `298.11g` |
| Quality `1` auctions | `250` |
| Quality `2+` auctions | `0` |
| Vendor-resale candidates | `0` |

Interpretation:

- The live AHBot state remained conservative after the image/database update.
- Auction value changed slightly from normal AHBot cycling, not from a config change.

## Individual Progression Baseline

Observed with the read-only audit on 2026-07-01.

| Metric | Result |
| --- | ---: |
| Hidden progression quests `66001-66018` | `18` |
| Conditions referencing progression quests | `2381` |

Interpretation:

- The progression data layer is installed.
- Runtime gate behavior still needs client-side testing at Vanilla, TBC, WotLK, RDF, DK unlock, and mixed-progression group boundaries.

## AutoBalance Baseline

Static/live config confirms:

- `AutoBalance.Enable.Global = 1`
- `AutoBalance.MinPlayers = 1`
- `AutoBalance.MinPlayers.Heroic = 1`
- `AutoBalance.MinPlayers.Raid = 1`
- `AutoBalance.MinPlayers.RaidHeroic = 1`
- `AutoBalance.playerCountDifficultyOffset = 0`
- `AutoBalance.RewardScaling.Method = "dynamic"`
- `AutoBalance.RewardScaling.XP = 1`
- `AutoBalance.RewardScaling.Money = 1`
- `AutoBalance.reward.enable = 0`

Runtime command output status:

- `.ab getoffset`: validated from the live console after `EMBER-62`.
- `.ab mapstat`: validated crash-safe from the live console without player context; representative dungeon output still required.
- `.ab creaturestat`: validated crash-safe from the live console without selected creature context; representative trash and boss output still required.

Collect map and creature stats through an in-game GM session inside representative instances.

## Solo LFG Baseline

Static/live config confirms:

- `SoloLFG.Enable = 1`
- `SoloLFG.FixedXP = 1`
- `SoloLFG.FixedXPRate = 0.5`

Runtime tests still required:

- Queue behavior for group sizes `1`, `2`, `3`, `4`, and `5`.
- Role handling.
- Dungeon entry/completion.
- Interaction with AutoBalance player count.
- Interaction with Individual Progression gates.

## Open Decisions

1. Leave SOAP and RA disabled until there is a clear admin-command automation need.
2. Keep combat and reward tuning frozen until Phase 2 runtime tests are completed.
3. Continue AHBot sampling over time before tightening item pools.
4. Treat AutoBalance dynamic money scaling as unresolved until dungeon reward tests measure raw coin by group size.
