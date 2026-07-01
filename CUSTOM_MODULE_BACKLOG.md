# Custom Module Backlog

Do not start custom modules until config, SQL, and maintained public modules are exhausted.

## `mod-solo-challenge-director`

Goal: add optional challenge without invisibly inflating player power.

MVP:

- Track recent deaths, group size, level, map, and optional challenge opt-in.
- Spawn optional elite patrols or bonus objectives in selected zones/dungeons.
- Reward cosmetics, utility currency, or titles, not raw power.

Likely files:

- `modules/mod-solo-challenge-director/src/*`
- `modules/mod-solo-challenge-director/conf/mod_solo_challenge_director.conf.dist`
- `modules/mod-solo-challenge-director/data/sql/world/base/*`

DB needs:

- Challenge state table.
- Reward claim table.
- Optional spawn templates/conditions.

Risks:

- Invisible difficulty manipulation can feel unfair.
- Rewards can become mandatory if too strong.
- Extra spawns can break quests/pathing.

## `mod-bounty-board`

Goal: repeatable solo/co-op objectives that encourage the world, rares, elites, and dungeon bosses.

MVP:

- Daily/weekly bounty list.
- Targets: rares, elites, dungeon bosses, zone objectives.
- Group-size-aware completion credit.
- Rewards: gold-light utility/cosmetic currency.

DB needs:

- Bounty definitions.
- Character/account completion state.
- Vendor/currency reward definitions.

Risks:

- Can become optimal farming route.
- Must respect Individual Progression gates.

## `mod-ai-town-life`

Goal: ambient town dialogue and companion flavor through local LLM integration.

MVP:

- Selected safe NPCs only.
- Local Ollama endpoint.
- Cooldowns and low-frequency ambient chatter.
- Lore/style prompt locked per zone/faction.
- No quest-critical generated text.

DB needs:

- NPC persona registry.
- Optional memory snippets.

Risks:

- Performance.
- Lore drift.
- Prompt injection through player chat if interactive.

## `mod-companion-reputation`

Goal: long-term companion/hireling progression without replacing player skill.

MVP:

- Works only after a bot/companion substrate is selected.
- Companion reputation from completed content.
- Unlocks cosmetics, emotes, utility, not major combat power.

DB needs:

- Account/character companion reputation.
- Unlock table.

Risks:

- If tied to combat power, companions become mandatory.
- Bot module compatibility may dominate design.

## `mod-dynamic-world-events`

Goal: scalable world activity for 1-5 players.

MVP:

- One test zone.
- Timed invasion/patrol event.
- Scaling creature packs based on nearby players.
- Clear start/end world states.
- Rewards controlled by Individual Progression phase.

DB needs:

- Event definition table.
- Spawn groups.
- Reward definitions.
- Cooldown/completion tracking.

Risks:

- Spawn conflicts.
- Farming loops.
- Event fatigue.
- Progression bypass through rewards.

## `mod-dungeon-economy-guard`

Goal: measure and, only if required, constrain solo/small-group dungeon reward output.

MVP:

- Passive logging first: instance ID, group size, raw coin, item quality counts, vendor value estimate.
- No reward modification in MVP.
- Export records to database for analysis.

DB needs:

- Dungeon run summary table.
- Loot summary table.

Risks:

- Loot hooks can be invasive.
- Reward intervention can feel punitive.

Recommendation: build this only if manual test logs become too tedious or inconclusive.

