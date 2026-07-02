# Phase 2 Runtime Validation Runbook

Purpose: collect repeatable Phase 2 runtime evidence before combat, reward, economy, or progression tuning.

This runbook covers the active Phase 2 gate for:

- `EMBER-35` Phase 2 umbrella
- `EMBER-36` AutoBalance in-instance command output
- `EMBER-37` Solo LFG 1-5 player runtime tests
- `EMBER-38` Individual Progression runtime gates
- `EMBER-39` AHBot manual shopping validation
- `EMBER-46` dungeon reward economy measurement

Do not make tuning, Docker, Terraform, AWS, or OpenClaw gateway changes while
executing this runbook. Live SSH access is available when the approved EC2 key
is installed locally, but Phase 2 gameplay evidence still requires an in-game
client/GM session.

## Source Docs

- `TEST_PLAN.md` defines the broader test matrix, required characters, command
  list, and target difficulty/economy metrics.
- `PHASE2_BASELINE_VALIDATION.md` records current baseline findings, live
  access constraints, read-only audit outputs, and open decisions.
- `TUNING_LOG.md` records prior changes and must receive future tuning entries
  only after runtime validation is complete.

Use this runbook to execute and record Phase 2 evidence. Do not duplicate large
sections from those source docs into result notes.

## Evidence Location

Use these templates:

| Gate | Template |
| --- | --- |
| Solo LFG 1-5 player tests | `tools/warwid/templates/phase2_solo_lfg_runtime.csv` |
| AutoBalance in-instance output | `tools/warwid/templates/phase2_autobalance_instance_output.md` |
| Individual Progression runtime gates | `tools/warwid/templates/phase2_individual_progression_gates.csv` |
| AHBot manual shopping validation | `tools/warwid/templates/phase2_ahbot_manual_shopping.csv` |
| Dungeon reward economy samples | `tools/warwid/templates/phase2_dungeon_economy_samples.csv` |

Copy templates to a dated evidence file before recording live results, for
example `tools/warwid/evidence/2026-07-01-solo-lfg-runtime.csv`. Keep raw
screenshots, combat logs, and chat logs outside the templates if needed, then
reference their paths in the `evidence_ref` or `notes` column.

## Before Each Session

1. Confirm no tuning work is in progress and no unreviewed config/database changes are being applied.
2. Record the core commit or image tag, test date, realm, character, account, and tester.
3. Confirm the run uses the current baseline from `PHASE2_BASELINE_VALIDATION.md`.
4. Use an in-game GM session for `.ab` and `.ip` command evidence when required.
5. Keep combat difficulty, progression gates, AH economy, and dungeon reward evidence separate.

## Execution Order

Run the gates in this order so later evidence can reference earlier observations:

1. AutoBalance in-instance output for representative normal and heroic instances.
2. Solo LFG queue, entry, completion, XP, and AutoBalance size behavior for group sizes `1` through `5`.
3. Individual Progression gate checks for phase boundaries, mixed-progression
   grouping, RDF/LFG access, vendors, drops, and DK unlock behavior.
4. AHBot manual shopping checks at levels `10`, `20`, `40`, `60`, `70`, and `80`.
5. Dungeon reward economy samples by group size for representative dungeons.

Stop and document blockers rather than changing live config to force a result.

## AutoBalance Gate

Goal: prove AutoBalance command output is meaningful from inside instances, not only crash-safe from the console.

Required capture:

- `.ab getoffset`
- `.ab mapstat`
- `.ab creaturestat` targeting representative trash
- `.ab creaturestat` targeting each tested boss
- Party size and roles present
- Instance, difficulty, player level, and gear summary

Pass condition: output reflects the actual instance context and party size without crashes or obviously stale values.

## Solo LFG Gate

Goal: prove Solo LFG works for group sizes `1`, `2`, `3`, `4`, and `5` without bypassing progression gates.

Required capture:

- Queue role selections
- Queue pop result and wait time
- Dungeon assigned
- Entry result
- Completion result
- Kill XP and completion XP
- AutoBalance detected size from `.ab mapstat`
- Any Individual Progression gate interaction

Pass condition: valid groups can queue, enter, and complete level-appropriate
dungeons; invalid progression states are blocked.

## Individual Progression Gate

Goal: prove runtime gates match the installed progression data and group-rule expectations.

Required capture:

- `.ip get`
- Character progression state
- Attempted dungeon, raid, RDF/LFG action, vendor item, drop, or DK unlock
- Expected result
- Actual result
- Mixed-progression party status when relevant

Pass condition: locked content is blocked, unlocked content is available, and
mixed-progression restrictions prevent bypasses without blocking valid
same-phase play.

## AHBot Manual Shopping Gate

Goal: prove the AHBot sample is useful to players without flooding best-in-slot, raid-equivalent, or vendor-loop items.

Required capture at levels `10`, `20`, `40`, `60`, `70`, and `80`:

- Profession materials
- Consumables
- Level-appropriate green/blue gear
- Rare recipes
- Epic or raid-equivalent searches
- Low, median, and high buyout prices
- Vendor resale risk
- Notes on availability gaps

Pass condition: players can buy practical leveling supplies, vendor resale loops
are absent, and raid-equivalent flooding is absent.

## Dungeon Economy Gate

Goal: measure whether dungeon rewards remain progression-useful without becoming a gold-printing route.

Required capture:

- Group size
- Clear time
- Raw coin
- Vendor trash value
- Item quality counts
- Boss loot count
- BoE, recipe, cloth/material, and disenchant estimates
- Total estimated value, value per player, and value per hour
- Exploit risk notes

Pass condition: solo and 2-3 player clears are useful but not economically superior to intended 5-player play.

## After Each Session

1. Save filled templates with dated names.
2. Add a short result summary to `PHASE2_BASELINE_VALIDATION.md` only when the evidence changes gate status.
3. Do not add a tuning entry to `TUNING_LOG.md` unless a tuning change is actually made later.
4. File defects separately when a runtime failure blocks validation.
5. Keep secrets out of evidence files. Do not paste SSH keys, database
   passwords, session tokens, or private connection strings.

## Phase 2 Exit Criteria

Phase 2 runtime validation is complete when:

- AutoBalance has representative in-instance command output.
- Solo LFG has recorded results for `1`, `2`, `3`, `4`, and `5` players.
- Individual Progression gates have runtime evidence across Vanilla, TBC,
  WotLK, RDF/LFG, DK unlock, and mixed-progression boundaries.
- AHBot manual shopping has bracket evidence for levels `10`, `20`, `40`, `60`, `70`, and `80`.
- Dungeon economy samples include raw coin and estimated value by group size.
- Open blockers are documented before tuning starts.
