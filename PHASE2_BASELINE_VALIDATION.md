# Phase 2 Stable Baseline Validation

Phase: 2 - verify the live small-group stack before combat or economy tuning.

No gameplay tuning changes were made in this phase entry.

## Ticket Scope

| Ticket | Status | Scope |
| --- | --- | --- |
| `EMBER-35` | In progress | Phase 2 stable baseline validation umbrella. |
| `EMBER-36` | Blocked by console crash risk | Validate AutoBalance live command output. |
| `EMBER-37` | Blocked on 1-5 player client test | Validate Solo LFG for 1-5 players. |
| `EMBER-38` | Partially validated | Validate Individual Progression gates. |
| `EMBER-39` | Partially validated | Audit AHBot item mix and prices. |

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

Observed with the read-only audit on 2026-07-01.

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

Runtime command output still required:

- `.ab getoffset`
- `.ab mapstat` inside representative dungeons
- `.ab creaturestat` on representative trash and bosses

Do not collect these through the bare server console unless the console crash defect is fixed or proven harmless in a disposable environment.

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
