# Test Plan - 1-5 Player Progression

## Method

Record data before changing tuning. Run one variable change at a time. Keep combat, economy, and progression results separate.

Use these commands during instance tests:

- `.ab mapstat`
- `.ab creaturestat` while targeting representative trash and bosses
- `.ab getoffset`
- `.ip get`

## Test Characters

| Character | Purpose | Minimum setup |
| --- | --- | --- |
| Fresh level 10 | Early open world and low dungeon entry | Quest greens, no heirlooms |
| Level 20 | Deadmines/Wailing Caverns bracket | Quest/dungeon mix |
| Level 40 | Scarlet Monastery/Zul'Farrak bracket | Level-appropriate gear |
| Level 60 pre-raid | Vanilla dungeon/endgame gate test | Dungeon blues, no raid gear |
| Level 70 pre-raid | TBC dungeon/heroic gate test | Quest/dungeon blues |
| Level 80 normal dungeon geared | WotLK normal and early heroic | Normal dungeon gear |
| Level 80 heroic dungeon geared | Heroic farm and entry raid check | Heroic blues/epics |
| Level 80 pre-raid BiS | Upper small-group baseline | Pre-raid BiS |

## Class/Spec Coverage

- Warrior or Paladin tank
- Priest or Druid healer
- Mage or Warlock caster DPS
- Hunter or Rogue physical DPS
- Paladin, Druid, or Death Knight hybrid solo class

## Group Sizes

- 1 player
- 2 players
- 3 players
- 4 players
- 5 players

## Content Matrix

Start with these. Add more only after the measurement sheet is stable.

| Bracket | Open world | Dungeon | Heroic/Raid |
| --- | --- | --- | --- |
| 10 | Starting zone + first elite/group quest | Ragefire Chasm or Deadmines entrance check | N/A |
| 20 | Westfall/Barrens group quests | Deadmines, Wailing Caverns, Shadowfang Keep | N/A |
| 40 | STV/Arathi elites | Scarlet Monastery wings, Razorfen Downs | N/A |
| 60 | EPL/WPL elites, outdoor rares | Stratholme, Scholomance, LBRS/UBRS | Molten Core entry only |
| 70 | Nagrand/Shadowmoon elites | Shattered Halls, Shadow Labyrinth | Heroic Ramparts |
| 80 normal | Icecrown/Storm Peaks group quests | Utgarde Pinnacle, Halls of Lightning | Heroic Utgarde Keep |
| 80 heroic | Daily heroic candidates | Halls of Reflection later | Naxx/OS entry only after dungeons |

## Combat Metrics

Record every run:

- Date
- Core commit/image tag
- Config backup path
- Character/account
- Class/spec
- Level
- Gear summary and average item level if available
- Content
- Group size
- Roles present
- AutoBalance `.ab mapstat`
- AutoBalance `.ab creaturestat` for at least one trash mob and each boss
- Clear time
- Death count
- Wipes
- Bosses failed
- Bosses killed
- Largest safe pull size
- Consumables used
- Repair cost
- Subjective difficulty `1-10`
- Notes on mechanics ignored vs respected

## Dungeon Economy Metrics

For each test dungeon, record:

- Group size
- Total raw coin looted
- Vendor value of trash
- Number of poor/common/uncommon/rare/epic items
- Cloth/material drops
- Boss loot count
- BoE count
- Recipe count
- Disenchant value if applicable
- Total estimated gold value
- Gold value per player
- Time to clear
- Gold value per hour
- Whether repeat farming is exploitable

Success criteria:

- Solo clear is useful for progression, not a gold printer.
- 2-3 player clears feel rewarding but not economically superior.
- 5-player clear remains the baseline reference.

## Solo LFG Tests

For each group size `1`, `2`, `3`, `4`, `5`:

- Queue for a level-appropriate random dungeon.
- Record selected roles and whether the queue pops.
- Record whether the party can enter.
- Record whether AutoBalance detects the actual party size.
- Record dungeon completion XP and kill XP.
- Verify LFG does not bypass Individual Progression gates.

## Individual Progression Gate Tests

For each phase:

- Run `.ip get`.
- Try to enter phase-locked dungeons/raids.
- Try to see/buy gated vendor items.
- Try to receive gated drops.
- Try mixed-progression grouping with `IndividualProgression.EnforceGroupRules = 1`.
- Verify DK creation/unlock behavior at progression `13`.

Initial progression phase documentation target:

| Progression | Theme | Expected unlock check |
| ---: | --- | --- |
| 0 | Fresh/early Vanilla | Leveling world, early dungeons |
| 1-7 | Vanilla raid tiers/events | MC, Onyxia, BWL, AQ, Naxx40 flow |
| 8 | Pre-TBC | TBC prep boundary |
| 9-13 | TBC tiers | TBC dungeons/raids through T5 |
| 14-18 | WotLK tiers | WotLK tiers through T5 |

Confirm exact names in `modules/mod-individual-progression/src/IndividualProgression.h` before publishing player-facing docs.

## Difficulty Targets

- Open world normal questing: `4/10`
- Open world elite/group quests solo: `7/10`
- Solo dungeon trash: `6/10`
- Solo dungeon bosses: `7-8/10`
- 2-3 player dungeon: `6-7/10`
- 5-player dungeon: `5-6/10` if playing correctly, `8/10` if playing badly
- Heroic dungeons solo: `8-9/10` or impossible until geared
- Heroic dungeons 2-3 player: `7-8/10`
- Raids: separate pass

## AHBot Economy Tests

At levels `10`, `20`, `40`, `60`, `70`, `80`:

- Search core profession materials.
- Search consumables.
- Search level-appropriate green/blue gear.
- Search rare recipes.
- Search epic/raid-equivalent items.
- Record low/median/high prices.
- Record whether vendor resale loops exist.
- Record whether AHBot floods best-in-slot or raid-equivalent gear.

