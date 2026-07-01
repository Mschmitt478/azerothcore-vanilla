# Balance Baseline - 2026-07-01

Phase: design baseline only. No tuning changes were made.

## North Star

Build a solo/co-op Azeroth RPG, not an easy solo sandbox.

- 1 player can progress, but bad pulls, weak gear, and ignored mechanics should kill them.
- 2-3 players should feel like the natural co-op sweet spot.
- 4-5 players should feel close to authentic WotLK dungeon play.
- Combat may scale for low player counts.
- Dungeon rewards must not inflate for low player counts.

## Current Starting Point

The server is already running a conservative small-group profile:

- AutoBalance enabled for dungeons, heroics, and raids.
- XP and reputation are currently `1.5x`.
- Item drops, money drops, and quest money are currently `1.0x`.
- AHBot is active with account `1` and character GUID `2`.
- Individual Progression is active and uses hidden progression quests.
- Solo LFG is active and sets dungeon kill XP to `0.5x`.
- AoE Loot is active with a 30-yard range.

## Current Values To Preserve During Combat Testing

Do not change these during the first combat tuning pass:

- `Rate.XP.Kill = 1.5`
- `Rate.XP.Quest = 1.5`
- `Rate.Reputation.Gain = 1.5`
- `Rate.Drop.Item.* = 1`
- `Rate.Drop.Money = 1`
- `Rate.RewardQuestMoney = 1`
- `AuctionHouseBot.*`

Reason: combat difficulty must be understood before changing pacing or economy.

## Initial Combat Tuning Philosophy

Prefer enemy scaling over player stat inflation.

Recommended order:

1. Use `.ab mapstat` and `.ab creaturestat` to record current scaling in representative dungeons.
2. Test 1, 2, 3, and 5 player runs before changing anything.
3. If solo dungeons are too easy, start with `AutoBalance.playerCountDifficultyOffset`, not global player buffs.
4. Adjust one variable at a time.
5. Keep raids out of the first tuning pass except to verify they are not accidentally trivial.

Potential first tuning lever if testing proves dungeons too easy:

- `AutoBalance.playerCountDifficultyOffset`
- Current: `0`
- Candidate: `0.25` or `0.5`
- Reason: make instances scale as if slightly more players are present.
- Expected effect: harder solo/small-group dungeons without changing loot or open-world rates.
- Risk: can over-punish weak solo classes; test with tank, healer, caster, physical DPS, and hybrid solo specs.
- Rollback: restore `0` and `.reload config` or restart worldserver.

Do not tune raids with this same pass. Raid scaling needs separate target profiles.

## Dungeon Economy Rule

Total dungeon output should approximate a normal 5-player run, regardless of group size.

Target model:

- 1 player: roughly one player's share of a normal run, not the whole 5-player economy.
- 2 players: roughly `1/5` to `1/4` each.
- 3 players: roughly `1/4` to `1/3` each.
- 4 players: close to normal group value.
- 5 players: baseline.

Current economy risk points:

- AutoBalance dynamic money scaling is enabled. It probably scales raw coin with stat scaling, but it must be measured.
- AoE Loot reduces friction and can increase gold/hour even if loot/run is unchanged.
- AHBot may expose too much blue/purple gear if price filters are loose.
- Solo LFG fixed XP changes dungeon leveling pace and must be tested with dungeon spam.

## Current Config Deltas From Dist Defaults

These are existing deltas, not new changes made by this audit.

| Area | Key | Dist default | Current | Reason in current profile | Expected gameplay effect | Test |
| --- | --- | ---: | ---: | --- | --- | --- |
| XP | `Rate.XP.Kill` | `1` | `1.5` | Reduce private-server repetition. | Faster leveling from kills. | Compare level 10-20 quest route time. |
| XP | `Rate.XP.Quest` | `1` | `1.5` | Reduce private-server repetition. | Faster quest progression. | Compare quest hub completion levels. |
| Rep | `Rate.Reputation.Gain` | `1` | `1.5` | Soften single-player rep grinds. | Faster reputation gains. | Measure early and max-level rep grinds. |
| Drops | `Rate.Drop.Item.*` | `1` | `1` | Preserve item economy. | Blizzlike gear/material drops. | Dungeon/open-world loot logs. |
| Money | `Rate.Drop.Money` | `1` | `1` | Prevent gold inflation. | Blizzlike raw coin. | Dungeon economy test. |
| LFG XP | `SoloLFG.FixedXPRate` | `0.2` | `0.5` | Less punitive solo/small dungeon XP. | Dungeon kills award more than full-party split. | Dungeon spam XP/hour test. |
| AutoBalance | `AutoBalance.MinPlayers*` | `1` | `1` | Permit solo scaling. | Instances can scale down to one player. | `.ab mapstat` by group size. |
| AutoBalance | `AutoBalance.playerCountDifficultyOffset` | `0` | `0` | Neutral starting difficulty. | No extra virtual players. | Dungeon test baseline. |
| AHBot | `AuctionHouseBot.EnableSeller` | `0` | `1` | Populate AH. | Bot-owned auctions appear. | AH category/price audit. |
| AHBot | `AuctionHouseBot.EnableBuyer` | `0` | `1` | Simulate market movement. | Bot can buy player auctions. | Post test auctions. |
| AoE Loot | `AOELoot.Range` | `55` | `30` | QoL without huge vacuum range. | Faster looting, less extreme. | Pull/loot exploit test. |
| Progression | `IndividualProgression.EnforceGroupRules` | `0` | `1` | Prevent bypass via grouping. | Groups respect progression. | Mixed-progression party tests. |

## Proposed Target Rates

Keep current rates until combat and economy testing says otherwise.

- XP: current `1.5x` is the upper end of the recommended starting range. If progression feels too fast after combat tuning, reduce to `1.25x` or `1.0x`.
- Reputation: current `1.5x` is acceptable for low-population play, but watch for trivialized faction gates.
- Skill rates: currently not explicitly tuned. Leave at default until professions are tested.
- Drops: keep `1.0x`.
- Gold: keep `1.0x`.
- Dungeon loot: keep blizzlike.
- Raid loot: defer.

