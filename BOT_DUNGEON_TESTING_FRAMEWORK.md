# Bot Dungeon Testing Framework Design

Date: 2026-07-02

Status: design-first plan. No implementation or tuning changes have been made.

## Goal

Create a repeatable test framework for WarwidCore/AzerothCore that can run or guide bot-assisted dungeon scenarios after config/module changes, then report whether the server still feels challenging but fair for 1-5 players.

The framework must answer:

- Can 1, 2, 3, 4, or 5 players complete a dungeon?
- How long did the run take?
- How many deaths and wipes occurred?
- Which bosses were killed?
- How much raw gold, XP, and item value dropped?
- Did total dungeon reward stay reasonable compared to a normal 5-player run?
- Did AutoBalance make the run too easy or too hard?
- Did Individual Progression locks and Solo LFG behavior work correctly?

This framework is measurement infrastructure, not tuning. Tuning changes should happen only after repeatable evidence exists.

## Current Server Assumptions Verified

The current repo contains these modules under `modules/`:

- `mod-ah-bot`
- `mod-aoe-loot`
- `mod-autobalance`
- `mod-individual-progression`
- `mod-solo-lfg`

No playerbot/NPCBot module is currently present in this repo. Do not plan implementation as if one already exists.

Existing baseline docs to preserve:

- `BALANCE_BASELINE.md`
- `TEST_PLAN.md`
- `MODULE_RESEARCH.md`
- `PHASE2_BASELINE_VALIDATION.md`
- `PHASE2_RUNTIME_VALIDATION_RUNBOOK.md`
- `TUNING_LOG.md`

Existing test framework:

- `apps/test-framework/` supports bash and AzerothCore core tests.
- It does not currently provide live dungeon scenario orchestration, bot party setup, instance metrics, or reward accounting.

## Bot Substrate Research Summary

### Playerbots

Repo: `https://github.com/mod-playerbots/mod-playerbots`

Current public docs state that all `mod-playerbots` installations require the custom `mod-playerbots/azerothcore-wotlk` Playerbot branch; standard AzerothCore will not work. Playerbots support altbots, random bots, party/raid behavior, chat commands, and large bot populations.

Verification on 2026-07-02:

- `mod-playerbots/mod-playerbots` was active with a latest push on 2026-07-02.
- The required Playerbot core branch is diverged from upstream AzerothCore; GitHub compare showed it hundreds of commits ahead and behind upstream.
- This confirms Playerbots is an integration project, not a normal module install.

Fit:

- Best match for repeatable player-like dungeon groups.
- Strongest long-term path for living-world behavior.
- Best candidate for automation through bot accounts, party commands, and scenario-controlled characters.
- Strongest command surface for a test harness: documented commands include `.playerbots bot add`, `.playerbots bot addaccount`, `.playerbots bot addclass`, `maintenance`, `autogear`, `talents`, `lfg`, strategy toggles, and random-bot management.

Risk:

- Requires a core fork migration, not a simple module add.
- Must be tested in a disposable branch/server clone first.
- Could affect compatibility with current modules and future AzerothCore updates.
- Can trivialize combat/economy if bots carry the player too well.
- There is no documented bot-specific REST API. Live orchestration should be GM-command driven, ideally through a deliberately secured command transport or in-game GM session.

Recommendation:

- Use Playerbots as the primary research/integration target for automated dungeon testing.
- Do not add it to the live baseline until a branch build and disposable database/server validation succeed.

### NPCBots / Trinity-Bots

Repos:

- `https://github.com/trickerer/Trinity-Bots`
- `https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots`

NPCBots are hireable pet-like helpers. The project describes dungeon finder and raid support, but also warns that dungeon behavior can be limited. This is closer to companion testing than true player-party testing.

Verification on 2026-07-02:

- `trickerer/Trinity-Bots` and `trickerer/AzerothCore-wotlk-with-NPCBots` were active with latest pushes on 2026-06-27.
- The NPCBots AzerothCore fork uses `npcbots_3.3.5` as its default branch.
- GitHub compare against its `3.3.5` base showed the NPCBots branch far ahead of the base branch, confirming a substantial patched-core integration.

Fit:

- Good candidate for controlled small-party companion tests.
- Potentially simpler for 1-player-plus-assist gameplay experiments.
- Command surface includes spawning, ownership, follow/standstill/stop, recall/teleport, ordering, and deletion commands.

Risk:

- Also uses a patched/pre-patched core path.
- NPC-style helpers may not behave like real players for reward, tagging, group accounting, or LFG behavior.
- Less ideal for measuring "1-5 players" if the bot is not a real player character.
- More suitable for GM-assisted QA than unattended player-party dungeon regression.

Recommendation:

- Keep as a fallback or comparison track.
- Do not use NPCBots as the primary metric baseline unless Playerbots proves infeasible.

## Architecture

The framework should have five layers.

### 1. Scenario Config

Location:

- `tools/warwid/bot-tests/scenarios/*.yaml`

Purpose:

- Define dungeon, faction, level bracket, party size, class/spec composition, expected progression state, and pass/fail thresholds.

Example fields:

- `scenario_id`
- `dungeon_name`
- `map_id`
- `entrance_location`
- `party_size`
- `faction`
- `level`
- `composition`
- `progression_state`
- `autobalance_profile`
- `lfg_mode`
- `timeout_minutes`
- `success_thresholds`
- `reward_thresholds`

Rollback:

- Delete or revert scenario YAML files.
- No DB/server change.

How to test:

- Add a config validation command that checks required fields, valid party sizes, unique IDs, and known dungeon aliases.

### 2. Test Runner

Location:

- `tools/warwid/bot-tests/run-scenario.sh`
- `tools/warwid/bot-tests/run-matrix.sh`

Purpose:

- Run one scenario or a group-size matrix.
- Snapshot server/version/config state.
- Start the party setup flow.
- Mark run start/end.
- Pull metrics into result files.

Runner modes:

- `dry-run`: validate config and show planned commands only.
- `manual-assisted`: print exact GM/bot commands and collect DB/log metrics after the human executes them.
- `command-driven`: use SOAP/RA/local command transport if deliberately enabled and secured.
- `bot-driven`: use Playerbots commands when the bot substrate exists.

Rollback:

- Remove runner scripts and generated output.
- No live config change unless command transport is later enabled.

How to test:

- `shellcheck` scripts where available.
- `dry-run` against every scenario config.
- Run against a non-live clone before live use.

### 3. Bot Party Setup Adapter

Location:

- `tools/warwid/bot-tests/adapters/`

Purpose:

- Abstract the bot substrate so the rest of the framework is not tied to Playerbots or NPCBots internals.

Initial adapters:

- `manual-adapter`: documents human/GM steps and marks the run for metrics capture.
- `playerbots-adapter`: later creates/logs in bot accounts, adds bots to group, sets talents/gear/roles, and starts movement/combat commands.
- `npcbots-adapter`: optional fallback for companion-style tests.

Playerbots likely setup actions:

- Create or reuse named test accounts/characters.
- Set level, gear, spells, talents, and progression state.
- Add bots to party.
- Teleport group to dungeon entrance or use LFG path.
- Issue bot strategy/role commands.

Rollback:

- Delete generated test accounts/characters only in disposable test DBs.
- In live DB, prefer disabling/reusing test accounts rather than destructive deletion.
- Keep any DB mutation behind explicit `--write-db` or `--allow-live-writes` flags.

How to test:

- Start with manual adapter.
- Add Playerbots adapter only after branch build proves the module works.
- Validate that adapter output does not require changing live tuning.

### 4. Metrics Capture

Location:

- `tools/warwid/bot-tests/sql/`
- `tools/warwid/bot-tests/parsers/`
- `tools/warwid/bot-tests/results/`

Purpose:

- Capture objective metrics before, during, and after each run.

Metrics:

- Dungeon name/map ID
- Scenario ID
- Party size
- Bot classes/specs/roles
- Character levels
- AutoBalance settings snapshot
- Start/end timestamps
- Completion duration
- Boss kills
- Trash kills
- Deaths
- Wipes
- Raw gold looted
- Item count
- Item quality distribution
- XP gained
- Progression state before/after
- LFG queue/teleport behavior
- Success/failure and failure reason

Keep evidence categories separate:

- Combat evidence: clear time, deaths, wipes, boss kills, trash kills, and AutoBalance output.
- Economy evidence: raw coin, item count, item quality distribution, vendor value, total value, value per player, and value per hour.
- Progression evidence: `.ip get`, locked-entry attempts, allowed-entry attempts, and mixed-progression behavior.
- LFG evidence: queue behavior, role selection, instance entry, completion, and XP behavior.

Capture methods, in priority order:

1. Dedicated custom module hooks for reliable combat/loot/instance events.
2. Read-only DB snapshots around known test characters.
3. Server logs with a structured test-run marker.
4. GM command output captured into evidence files.
5. Manual notes only when no better source exists.

Likely custom hook module later:

- `modules/mod-warwid-test-metrics/`

The module should be small and disabled by default. It should write to dedicated tables or structured logs only when a test run is active.

Rollback:

- Disable the module in config.
- Drop only dedicated `warwid_test_*` tables if they were created.
- Remove result artifacts.

How to test:

- Unit-build the module.
- Run a no-op test marker start/end.
- Kill one creature and verify exactly one metric event appears.
- Confirm no metrics are written when tests are inactive.

### 5. Result Evaluation

Location:

- `tools/warwid/bot-tests/evaluate-results.sh`
- `tools/warwid/bot-tests/reports/`
- `tools/warwid/bot-tests/results/<timestamp>-<scenario-id>/`

Purpose:

- Compare each run against thresholds and prior baselines.
- Produce markdown/CSV summaries that can be attached to Jira/Confluence.

Suggested per-run result folder:

- `scenario.yaml`
- `run-metadata.json`
- `gm-command-output.md`
- `metrics.json`
- `metrics.csv`
- `economy.csv`
- `autobalance.md`
- `progression.csv`
- `logs/`
- `screenshots/` for manually captured evidence

Do not store secrets, connection strings, account passwords, or private keys in result folders.

Pass/fail dimensions:

- Completion success within timeout.
- Death/wipe ceiling.
- Boss kill coverage.
- Reward ceiling compared to 5-player baseline.
- Gold/hour exploit risk.
- XP/hour exploit risk.
- AutoBalance difficulty target.
- Progression lock correctness.
- Solo LFG behavior correctness.

Reward rule:

- A 1-player dungeon must not generate more total reward than a normal 5-player run.
- Compare total raw coin/items/XP per run and per hour against the 5-player baseline.
- Flag solo/small-party runs that exceed baseline total reward or produce clearly superior farm value.

Rollback:

- Remove report/evaluator scripts.
- No server/DB change.

How to test:

- Feed synthetic result JSON/CSV fixtures into the evaluator.
- Verify pass/fail output for easy, hard, exploit, and blocked cases.

## Initial Scenario Matrix

Start small and expand after the capture format is stable.

### Phase A: Low-Level Dungeon Baseline

- Ragefire Chasm: 1, 2, 3, 4, 5 players
- Deadmines: 1, 2, 3, 4, 5 players

### Phase B: Mid-Level Dungeon Baseline

- Scarlet Monastery Graveyard: 1, 2, 3, 4, 5 players
- Scarlet Monastery Library: 1, 2, 3, 4, 5 players
- Scarlet Monastery Armory: 1, 2, 3, 4, 5 players
- Scarlet Monastery Cathedral: 1, 2, 3, 4, 5 players

### Phase C: Scaling Stress Test

- One level 80 normal dungeon.
- One level 80 heroic later, only after low/mid brackets are stable.

## Staged Implementation Plan

### Step 1: Design and Tracking Artifacts

Files/config/tables changed:

- Add this markdown design document.
- Create Jira epic and child-ticket outline.
- Create Confluence design page.

Why:

- Locks the architecture before code.
- Gives Matt a durable planning page and ticket hierarchy.

Rollback:

- Revert the design doc commit.
- Close/archive Jira/Confluence artifacts if needed.

How to test:

- Review document for scope, risks, and phase order.
- Confirm no server or DB changes occurred.

### Step 2: Config-Only Scenario Skeleton

Files/config/tables changed:

- Add `tools/warwid/bot-tests/scenarios/`.
- Add initial YAML scenarios for Ragefire Chasm and Deadmines group sizes.
- Add `tools/warwid/bot-tests/schema/` or a validation script.

Why:

- Makes test intent repeatable before automation exists.

Rollback:

- Remove scenario files.

How to test:

- Run dry validation for every scenario.
- Confirm no live commands are issued.

### Step 3: Manual-Assisted Runner

Files/config/tables changed:

- Add runner scripts.
- Add results directory README and sample output.
- Add timestamped result-folder generation.

Why:

- Provides immediate value before Playerbots/NPCBots is integrated.
- Lets Matt run real client/GM tests and still collect consistent evidence.

Rollback:

- Remove scripts and generated results.

How to test:

- Run `dry-run`.
- Run a fake/manual scenario that writes a result skeleton.
- Confirm the generated result folder contains no secrets.

### Step 4: Read-Only Metrics SQL

Files/config/tables changed:

- Add read-only SQL under `tools/warwid/bot-tests/sql/`.
- Add wrapper scripts modeled after existing `tools/warwid/run-live-*.sh`.

Why:

- Captures account/character/loot/progression snapshots without live DB mutation.

Rollback:

- Remove SQL/wrapper scripts.

How to test:

- Run against live DB in read-only mode only.
- Confirm no `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `ALTER`, or `DROP` statements exist in the read-only scripts.

### Step 5: Bot Substrate Spike Branch

Files/config/tables changed:

- Create a disposable branch/server clone for Playerbots.
- Do not change live `master` until the spike proves compatibility.

Why:

- Playerbots requires a custom AzerothCore fork; integration risk is too high for live baseline.

Rollback:

- Delete disposable branch/clone.
- Restore database snapshot if a test DB was used.

How to test:

- Build Playerbot fork with current required Warwid modules.
- Boot disposable auth/world/database.
- Create test bots.
- Run one low-level dungeon setup manually.

### Step 6: Playerbots Adapter

Files/config/tables changed:

- Add `playerbots-adapter` scripts/config.
- Add documentation for required Playerbots conf values.

Why:

- Automates party setup and command repeatability once the bot substrate is proven.

Rollback:

- Disable adapter selection.
- Keep manual adapter as fallback.

How to test:

- Run one Ragefire Chasm scenario with 1 player + bots in disposable environment.
- Verify result metrics line up with visible in-game outcome.

### Step 7: Custom Metrics Module

Files/config/tables changed:

- Add `modules/mod-warwid-test-metrics/`.
- Add optional SQL for dedicated `warwid_test_*` metrics tables.
- Add disabled-by-default config file.

Why:

- DB snapshots/log parsing will not reliably capture all wipes, boss state, loot ownership, or run boundaries.
- A small hook module gives durable structured data.

Rollback:

- Disable config and rebuild without the module.
- Drop dedicated metrics tables only after backup.

How to test:

- Build with module disabled and confirm no behavior change.
- Enable in disposable environment.
- Start/end a test run and verify event rows/logs.

### Step 8: Always-Running Test Loop

Files/config/tables changed:

- Add scheduler/cron wrapper only after manual and bot-driven runs are stable.
- Store reports under timestamped result folders.

Why:

- Creates the long-term feedback loop: change config, run bot matrix, compare difficulty/reward deltas.

Rollback:

- Disable cron/systemd/timer.
- Leave one-shot runner intact.

How to test:

- Run once per day in disposable environment.
- Promote to live/off-hours only after resource impact is measured.

## Jira Epic Draft

Epic summary:

- `Bot-driven dungeon testing framework for 1-5 player progression tuning`

Epic description:

- Build a repeatable testing framework for WarwidCore/AzerothCore that uses verified bot/playerbot support where available, command/database/log capture where possible, and optional custom module hooks where needed. The goal is to measure dungeon completion, difficulty, reward output, AutoBalance behavior, Individual Progression gates, and Solo LFG correctness across 1-5 player scenarios without blind tuning.

Proposed child tickets:

- Research and verify AzerothCore bot substrate options.
- Add bot-test scenario config skeleton.
- Add manual-assisted bot dungeon test runner.
- Add read-only metrics SQL and evidence capture wrappers.
- Spike Playerbots integration in a disposable branch/server clone.
- Add Playerbots party setup adapter after spike approval.
- Add result evaluator and reward/difficulty thresholds.
- Add optional `mod-warwid-test-metrics` hook module.
- Add always-running/off-hours bot test loop after stability approval.

## First Implementation Slice

After the design/Jira/Confluence artifacts are in place, the first code slice should stay completely non-invasive:

1. Add scenario schema and initial Ragefire Chasm/Deadmines configs for group sizes `1-5`.
2. Add a dry-run validator that checks required fields, unique scenario IDs, valid group sizes, and known dungeon aliases.
3. Add a manual-assisted runner that creates timestamped result folders and emits GM/player steps plus blank evidence templates.

This slice must not:

- Add Playerbots or NPCBots.
- Enable SOAP or RA.
- Mutate the live database.
- Change AutoBalance, reward, XP, AHBot, Individual Progression, or Solo LFG tuning.
- Restart the live server.

## Open Questions

- Should Playerbots be accepted as a fork-level dependency if the spike succeeds?
- Should the first implementation stop at manual-assisted tests until Phase 2 in-game validation is complete?
- Should bot tests run only in a disposable clone, or eventually during off-hours on live with isolated test accounts?
- Which account/character names should be reserved for test bots?

## Sources

- Playerbots module: `https://github.com/mod-playerbots/mod-playerbots`
- Playerbots installation guide: `https://github.com/mod-playerbots/mod-playerbots/wiki/Installation-Guide`
- Playerbot commands: `https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Commands`
- Trinity-Bots/NPCBots: `https://github.com/trickerer/Trinity-Bots`
- AzerothCore with NPCBots fork: `https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots`
