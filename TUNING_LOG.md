# Tuning Log

## 2026-07-01 - Phase 1 Audit

No gameplay tuning changes were made.

Actions:

- Created audit branch `openclaw/azeroth-progression-audit-2026-07-01`.
- Created live backup `/srv/azerothcore/backups/2026-07-01-204201-pre-progression-audit`.
- Inspected local repository state.
- Inspected live containers, configs, logs, module binary linkage, and selected database state.
- Wrote baseline documentation.

Rollback:

- No gameplay rollback required.
- To remove this audit doc pass, revert the documentation commit once created.

## 2026-07-01 - Phase 2 Read-Only Validation

No gameplay tuning changes were made.

Actions:

- Added a read-only live validation script at `tools/warwid/run-live-phase2-readonly-audit.sh`.
- Ran the script against the live database.
- Recorded AHBot baseline: `250` bot-owned auctions, all quality `1`, total buyout `286.13g`, `0` vendor-resale candidates.
- Recorded Individual Progression baseline: `18` hidden progression quests and `2381` condition rows.
- Confirmed `SOAP.Enabled = 0`, `Ra.Enable = 0`, and `Console.Enable = 1`.
- Confirmed pseudo-TTY console attach works for `server info`.
- Attempted `.ab getoffset` from the bare worldserver console. This restarted `ac-worldserver`; the container returned to running state with Docker `RestartCount = 1`.

Rollback:

- No config or database rollback required.
- No live files were intentionally changed.
- Do not run AutoBalance commands from the bare console again until the defect is isolated.

## 2026-07-01 - EMBER-62 Docker Build Patch Application

No live gameplay tuning changes were made.

Actions:

- Updated `apps/docker/Dockerfile` to copy `patches/` into the build stage.
- Applied `patches/warwid/mod-autobalance-console-null-session.patch` during the Docker build before CMake configures modules.
- Verified the patch applies cleanly with `git -C modules/mod-autobalance apply --check ../../patches/warwid/mod-autobalance-console-null-session.patch`.
- Built Docker target `build` successfully with:
  - `DOCKER_CONFIG=<temporary empty config> docker build -f apps/docker/Dockerfile --target build -t warwidcore-autobalance-console-fix:build .`
- Build result: CMake configured all five Warwid modules, compiled patched `mod-autobalance/src/ABCommandScript.cpp`, linked `worldserver`, and exported image `warwidcore-autobalance-console-fix:build`.

Rollback:

- Revert the Dockerfile patch-application step.
- The preserved patch file can remain as documentation, or be removed if a module fork/upstream fix replaces it.

## Existing Small-Group Profile Values

These values existed before this audit. They are recorded here so future tuning has a baseline.

| Key | Original/dist value | Current value | Reason | Expected effect | How to test | Revert |
| --- | ---: | ---: | --- | --- | --- | --- |
| `Rate.XP.Kill` | `1` | `1.5` | Reduce leveling repetition on low-pop server. | Faster kill leveling. | Level 10-20 route timing. | Set to `1`. |
| `Rate.XP.Quest` | `1` | `1.5` | Reduce questing repetition on low-pop server. | Faster quest leveling. | Quest hub completion level/time. | Set to `1`. |
| `Rate.XP.Quest.DF` | `1` | `1.0` | Keep dungeon finder quest XP blizzlike. | No bonus LFG quest XP. | Compare quest reward tooltip/actual. | Already default. |
| `Rate.Reputation.Gain` | `1` | `1.5` | Soften solo rep grinds. | Faster faction progress. | Measure representative rep grind. | Set to `1`. |
| `Rate.Drop.Item.*` | `1` | `1` | Preserve loot economy. | Blizzlike item drops. | Loot log per dungeon. | Already default. |
| `Rate.Drop.Money` | `1` | `1` | Prevent raw gold inflation. | Blizzlike money. | Dungeon raw coin test. | Already default. |
| `Rate.RewardQuestMoney` | `1` | `1` | Prevent quest gold inflation. | Blizzlike quest money. | Quest reward audit. | Already default. |
| `AutoBalance.Enable.Global` | `1` | `1` | Enable low-player instance scaling. | Dungeons/raids scale. | `.ab mapstat`. | Set to `0`. |
| `AutoBalance.MinPlayers` | `1` | `1` | Solo dungeon support. | 1-player scaling floor. | Solo dungeon `.ab mapstat`. | Raise to desired floor. |
| `AutoBalance.MinPlayers.Heroic` | `1` | `1` | Solo heroic testing support. | Heroics can scale to 1. | Heroic `.ab mapstat`. | Raise to desired floor. |
| `AutoBalance.MinPlayers.Raid` | `1` | `1` | Early raid experimentation. | Raids can scale to 1. | Raid `.ab mapstat`. | Raise during raid pass. |
| `AutoBalance.playerCountDifficultyOffset` | `0` | `0` | Neutral baseline. | No extra virtual players. | `.ab getoffset`. | Already default. |
| `AutoBalance.RewardScaling.XP` | `1` | `1` | Scale XP with adjusted difficulty. | Dungeon XP follows scaling. | Dungeon kill XP log. | Set to `0` if needed. |
| `AutoBalance.RewardScaling.Money` | `1` | `1` | Scale money with adjusted difficulty. | Raw coin follows scaling. | Dungeon raw coin test. | Set to `0` only if evidence supports. |
| `AutoBalance.reward.enable` | `0` | `0` | Avoid bonus token rewards. | No extra reward currency. | Boss kill inventory check. | Already safe. |
| `AuctionHouseBot.EnableSeller` | `0` | `1` | Populate AH. | Bot auctions appear. | AH count and category sampling. | Set to `0`. |
| `AuctionHouseBot.EnableBuyer` | `0` | `1` | Simulate AH demand. | Bot can bid/buy. | Post controlled auction. | Set to `0`. |
| `AuctionHouseBot.Account` | `0` | `1` | Use dedicated bot account/character. | Bot identity valid. | DB account/character check. | Set to `0` with seller/buyer off. |
| `AuctionHouseBot.GUID` | `0` | `2` | Use `Ahbot` character. | Bot-owned auctions have owner. | DB auction owner check. | Set to `0` with seller/buyer off. |
| `AuctionHouseBot.ItemsPerCycle` | `200` | `100` | Reduce churn. | Slower AH population cycles. | Auction count over time. | Set to `200`. |
| `AuctionHouseBot.DuplicatesCount` | `0` | `3` | Keep limited duplicate availability. | More useful AH with cap. | Item duplicate sample. | Set to `0`. |
| `AuctionHouseBot.ProfessionItems` | `0` | `1` | Make professions viable. | More profession materials. | Profession shopping tests. | Set to `0`. |
| `AOELoot.Message` | `1` | `0` | Avoid login spam. | No login announcement. | Login test. | Set to `1`. |
| `AOELoot.Range` | `55` | `30` | QoL without huge range. | Faster looting in modest radius. | Corpse merge/range test. | Set to `55` or lower. |
| `SoloLFG.Announce` | `1` | `0` | Avoid login spam. | No login announcement. | Login test. | Set to `1`. |
| `SoloLFG.FixedXPRate` | `0.2` | `0.5` | Less punitive small dungeon XP. | Higher dungeon kill XP. | Dungeon XP/hour test. | Set to `0.2`. |
| `IndividualProgression.EnforceGroupRules` | `0` | `1` | Prevent progression bypass in groups. | Mixed-progression restrictions. | Mixed-party gate test. | Set to `0` only if it blocks valid play. |
| `IndividualProgression.VanillaPowerAdjustment` | `1` | `0.6` | Reduce WotLK power in Vanilla content. | Old content less trivial. | Vanilla dungeon/raid tests. | Set to `1`. |
| `IndividualProgression.VanillaHealingAdjustment` | `1` | `0.5` | Reduce WotLK healing in Vanilla content. | Old content less trivial. | Vanilla group/solo tests. | Set to `1`. |
| `IndividualProgression.TBCPowerAdjustment` | `1` | `0.6` | Reduce WotLK power in TBC content. | TBC content less trivial. | TBC dungeon tests. | Set to `1`. |
| `IndividualProgression.TBCHealingAdjustment` | `1` | `0.6` | Reduce WotLK healing in TBC content. | TBC content less trivial. | TBC dungeon tests. | Set to `1`. |

## Next Tuning Entry Template

- Date:
- Backup path:
- File:
- Key:
- Original:
- New:
- Reason:
- Expected gameplay effect:
- Test performed:
- Result:
- Rollback:
