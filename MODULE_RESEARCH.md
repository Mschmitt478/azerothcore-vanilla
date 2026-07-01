# Module Research - World Fullness and Long-Term Growth

Research date: 2026-07-01.

This is a first-pass shortlist. Do not install any of these until dungeon combat and economy baselines are stable.

## Current Installed Modules

| Module | Keep? | Notes |
| --- | --- | --- |
| `mod-autobalance` | Yes | Core of 1-5 player dungeon scaling. Tune carefully and measure reward scaling. |
| `mod-ah-bot` | Yes | Useful, but item mix and pricing need manual economy audit. |
| `mod-aoe-loot` | Yes | Good QoL. Watch gold/hour impact. |
| `mod-individual-progression` | Yes | Strong fit for tiered RPG progression. Needs gate verification. |
| `mod-solo-lfg` | Yes | Required for usability. Needs 1-5 queue testing. |

## Candidate: Playerbots

- Repo: `https://github.com/mod-playerbots/mod-playerbots`
- API snapshot: pushed `2026-06-28`, not archived, 832 stars, 189 open issues.
- Fit: high world-fullness value. Player-like bots can make towns, leveling, and group content feel alive.
- Compatibility: high risk. Current playerbots requires a Playerbot-enabled AzerothCore fork rather than a plain module drop-in.
- Balance risk: very high. Bots can trivialize leveling, dungeons, professions, and economy if they carry players.
- Recommendation: later phase only. Evaluate in a disposable branch/server clone, not on the live progression baseline.
- Test requirement: bot contribution caps, group composition, dungeon clear times, economy effects, server CPU/memory.

## Candidate: NPCBots / Trinity-Bots

- Repo: `https://github.com/trickerer/Trinity-Bots`
- Pre-patched fork: `https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots`
- API snapshot: Trinity-Bots pushed `2026-06-27`, not archived, 558 stars, 13 open issues. Pre-patched fork pushed `2026-06-27`, default branch `npcbots_3.3.5`.
- Fit: strong for companion/hireling gameplay and small-group dungeon support.
- Compatibility: high risk. This is patch/fork-style integration, not a simple module.
- Balance risk: high. Hirelings can erase the danger that AutoBalance is meant to preserve.
- Recommendation: stronger candidate than full playerbots for controlled small-party help, but only after baseline dungeon tuning. Test with strict caps: no free raid carries, limited gear/AI, costs/cooldowns if possible.

## Candidate: `mod-llm-chatter`

- Repo: `https://github.com/Hokken/mod-llm-chatter`
- API snapshot: pushed `2026-06-28`, not archived, 42 stars, 1 open issue.
- Description: AI-powered bot conversations for AzerothCore WotLK 3.3.5a, for `mod-playerbots`.
- Fit: good for long-term living-world feel.
- Compatibility: depends on playerbots, so it inherits playerbots fork risk.
- Balance risk: low for combat if it only affects dialogue; performance/privacy risk if external APIs are used.
- Recommendation: good later experiment if playerbots are adopted. Prefer local Ollama-only mode for privacy and cost control.

## Candidate: `mod-ollama-chat`

- Repo: `https://github.com/DustinHendrickson/mod-ollama-chat`
- API snapshot: pushed `2026-04-26`, not archived, 100 stars, 10 open issues.
- Description: integrates Ollama LLM support with Player Bots.
- Fit: good local-first AI chatter option.
- Compatibility: depends on playerbots.
- Balance risk: low for combat, medium for performance.
- Recommendation: defer until playerbots decision. Compare against `mod-llm-chatter`; choose one, not both.

## Candidate: `mod-changeablespawnrates`

- Repo: `https://github.com/justin-kaufmann/mod-changeablespawnrates`
- API snapshot: pushed `2024-09-12`, not archived, 6 stars, 0 open issues.
- Description: changes spawn times based on configured or player-based factors.
- Fit: useful for low-population world pacing if spawn bottlenecks are bad.
- Compatibility: likely easier than bot forks, but must be built/tested.
- Balance risk: medium. Faster respawns can improve questing but also increase material/gold farming.
- Recommendation: possible Phase 5 QoL module after measuring spawn pain. Do not install just to make the world feel busy.

## Candidate: `mod-dynamic-xp`

- Repo: `https://github.com/azerothcore/mod-dynamic-xp`
- API snapshot: pushed `2025-11-02`, not archived, 19 stars, 1 open issue.
- Description: dynamic XP per level range.
- Fit: useful if current flat `1.5x` XP is too blunt.
- Compatibility: likely simple module.
- Balance risk: low to medium.
- Recommendation: possible Phase 4 pacing tool. Do not add before combat tuning.

## Dynamic Events

No prominent maintained AzerothCore module was found that cleanly provides scalable 1-5 player dynamic world events. The likely path is custom C++/SQL after baseline systems are stable.

Recommendation:

1. Use existing `game_event`, creature spawns, SmartAI, and SQL first.
2. Prototype one zone-scale event manually.
3. Only then create `mod-dynamic-world-events`.

## Priority Recommendation

1. Stabilize current stack first.
2. Audit AHBot economy and AutoBalance reward scaling.
3. Consider `mod-dynamic-xp` only if pacing needs more nuance.
4. Consider NPCBots in a separate branch/server clone.
5. Consider playerbots only if Matt wants a larger fork commitment.
6. Add LLM chatter only after the bot substrate is chosen.

