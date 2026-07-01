# AzerothCore Server Audit - 2026-07-01

Phase: 1 - audit and backup only. No tuning changes were made.

## Repository

- Local repo: `/home/matt/source/repos/azerothcore-wotlk-master`
- Audit branch: `openclaw/azeroth-progression-audit-2026-07-01`
- Current commit: `ea58e0f8697f244824be59d4965e08b425bc38a9`
- Commit subject: `EMBER-25 prepare Route 53 hosted zone`
- Base branch at audit start: `openclaw/EMBER-25-account-portal-https`
- Remotes:
  - `origin`: `git@github_personal:Mschmitt478/azerothcore-wotlk.git`
  - `upstream`: `git@github.com:azerothcore/azerothcore-wotlk.git`
  - `fork`: `git@github.com:Mschmitt478/azerothcore-vanilla.git`
- Repo status before docs: clean.

## Live Host

- Host: `100.57.50.42`
- SSH key that worked: `/home/matt/.ssh/teamspeak6-admin.pem`
- SSH key that failed: `/home/matt/.ssh/github_personal`
- Runtime root: `/srv/azerothcore`
- Container status at audit:
  - `ac-database`: `mysql:8.4`, healthy, up 9 days
  - `ac-authserver`: `warwid-azerothcore:master-authserver`, up 8 days
  - `ac-worldserver`: `warwid-azerothcore:master-worldserver`, up 8 days
- Public ports:
  - Auth: `3724`
  - World: `8085`
  - SOAP: bound to `127.0.0.1:7878`

## Fresh Audit Backup

Created before any tuning work:

- `/srv/azerothcore/backups/2026-07-01-204201-pre-progression-audit`
- Contents:
  - `etc.tgz` - current persistent configs and rendered Compose files
  - `acore_auth.sql.gz`
  - `acore_characters.sql.gz`
  - `acore_world.sql.gz`

Existing daily backups are also present through `2026-07-01-070011`.

## Installed Modules

| Module | Remote | Commit | Branch | Live binary evidence |
| --- | --- | --- | --- | --- |
| `mod-ah-bot` | `git@github.com:azerothcore/mod-ah-bot.git` | `a680cc1` | `master` | `FOUND:AddAHBotScripts`, `FOUND:AHBot_WorldScript` |
| `mod-aoe-loot` | `git@github.com:azerothcore/mod-aoe-loot.git` | `2ddf6ff` | `master` | `FOUND:Addmod_aoe_lootScripts`, `FOUND:AOELootPlayer` |
| `mod-autobalance` | `git@github.com:azerothcore/mod-autobalance.git` | `73d4ad3` | `master` | `FOUND:AddAutoBalanceScripts`, `FOUND:AutoBalance_CommandScript` |
| `mod-individual-progression` | `git@github.com:ZhengPeiRu21/mod-individual-progression.git` | `98565fe` | `master` | `FOUND:Addmod_individual_progressionScripts`, `FOUND:individualProgression_commandscript` |
| `mod-solo-lfg` | `git@github.com:azerothcore/mod-solo-lfg.git` | `3821fe1` | `master` | `FOUND:Addmod_solo_lfgScripts`, `FOUND:lfg_solo` |

Conclusion: all five installed modules are compiled into the live `worldserver` binary.

## Relevant Config Files

Repo source/config files:

- `src/server/apps/worldserver/worldserver.conf.dist`
- `src/server/apps/authserver/authserver.conf.dist`
- `src/tools/dbimport/dbimport.conf.dist`
- `modules/mod-ah-bot/conf/mod_ahbot.conf.dist`
- `modules/mod-aoe-loot/conf/mod_aoe_loot.conf.dist`
- `modules/mod-autobalance/conf/AutoBalance.conf.dist`
- `modules/mod-individual-progression/conf/individualProgression.conf.dist`
- `modules/mod-solo-lfg/conf/SoloLfg.conf.dist`
- `apps/docker/apply-warwid-small-group-config.sh`
- `infra/aws-docker/user_data.sh.tpl`
- `infra/aws-docker/scripts/build-and-push-images.sh`

Live persistent config files:

- `/srv/azerothcore/etc/worldserver.conf`
- `/srv/azerothcore/etc/authserver.conf`
- `/srv/azerothcore/etc/dbimport.conf`
- `/srv/azerothcore/etc/modules/AutoBalance.conf`
- `/srv/azerothcore/etc/modules/SoloLfg.conf`
- `/srv/azerothcore/etc/modules/individualProgression.conf`
- `/srv/azerothcore/etc/modules/mod_ahbot.conf`
- `/srv/azerothcore/etc/modules/mod_aoe_loot.conf`

## Current Core Rates

| Key | Current | Upstream dist default | Note |
| --- | ---: | ---: | --- |
| `Rate.XP.Kill` | `1.5` | `1` | Conservative acceleration already active. |
| `Rate.XP.Quest` | `1.5` | `1` | Conservative acceleration already active. |
| `Rate.XP.Quest.DF` | `1.0` | `1` | Dungeon finder quest XP remains blizzlike. |
| `Rate.Reputation.Gain` | `1.5` | `1` | Conservative acceleration already active. |
| `Rate.Drop.Money` | `1` | `1` | Important: no global money inflation. |
| `Rate.RewardQuestMoney` | `1` | `1` | Important: no quest money inflation. |
| `Rate.Drop.Item.*` | `1` | `1` | Script keeps all item-quality drop rates blizzlike. |

## Current Module Settings

### AutoBalance

- Enabled globally.
- Enabled for normal, heroic, and raid map categories.
- `AutoBalance.MinPlayers = 1`
- `AutoBalance.MinPlayers.Heroic = 1`
- `AutoBalance.MinPlayers.Raid = 1`
- `AutoBalance.MinPlayers.RaidHeroic = 1`
- `AutoBalance.playerCountDifficultyOffset = 0`
- Dungeon inflection: `0.5`
- Heroic dungeon inflection: `0.5`
- Raid inflection: `0.4`; 25/40-player raid variants are `0.35`.
- Reward scaling:
  - `AutoBalance.RewardScaling.Method = "dynamic"`
  - `AutoBalance.RewardScaling.XP = 1`
  - `AutoBalance.RewardScaling.Money = 1`
  - `AutoBalance.reward.enable = 0`

Risk: dynamic AutoBalance money scaling changes raw coin from adjusted creatures. This may be acceptable if it scales down with reduced difficulty, but it must be measured in the dungeon economy test plan before any claim of economic safety.

Commands available from source:

- `.ab mapstat`
- `.ab creaturestat`
- `.ab setoffset`
- `.ab getoffset`
- `.reload config`

### AHBot

- Seller enabled: `1`
- Buyer enabled: `1`
- Account: `1`
- Character GUID: `2`
- Character: `Ahbot`, level 1, account `ADMIN`
- Live bot-owned auctions at audit: `241`
- Total live auctions at audit: `241`
- `AuctionHouseBot.ItemsPerCycle = 100`
- `AuctionHouseBot.ConsiderOnlyBotAuctions = 1`
- `AuctionHouseBot.DuplicatesCount = 3`
- `AuctionHouseBot.ProfessionItems = 1`
- `AuctionHouseBot.UseMarketPriceForSeller = 1`

Risk: AHBot has broad item pools available, including blue/purple item categories in its loaded candidate pool. The actual auction mix and prices need manual sampling before calling the economy safe.

### Solo LFG

- `SoloLFG.Enable = 1`
- `SoloLFG.Announce = 0`
- `SoloLFG.FixedXP = 1`
- `SoloLFG.FixedXPRate = 0.5`

Source behavior:

- Toggles LFG testing mode when enabled.
- Allows queueing below normal 5-player group size.
- Forces dungeon kill XP rate to `FixedXPRate`.

Needs client/runtime testing for 1, 2, 3, 4, and 5 players. No static file can prove queue outcomes or role behavior.

### Individual Progression

- `IndividualProgression.Enable = 1`
- `IndividualProgression.EnforceGroupRules = 1`
- `IndividualProgression.ProgressionLimit = 0`
- `IndividualProgression.StartingProgression = 0`
- Death Knights unlock/start at progression `13`.
- Progression tracking uses hidden rewarded quests `66001-66018`, not a `player_progression` table.
- Live DB evidence:
  - `18` hidden progression quest templates exist.
  - `2381` conditions reference progression quest IDs.
  - Commands installed: `.ip get`, `.ip set`, `.ip setbot`, `.ip setrep`, `.ip tele`, `.ip attune`, `.ip pvp`.

Risk: gates are installed, but intended phase behavior still needs in-game verification at boundaries: Vanilla, TBC, WotLK, DK unlock, RDF access, and group rule enforcement.

### AoE Loot

- `AOELoot.Enable = 1`
- `AOELoot.Message = 0`
- `AOELoot.Range = 30.0`
- `AOELoot.Group = 1`

Source behavior merges nearby corpse loot into one loot interaction. It does not create new loot, but it can make farming more efficient by reducing looting time. Economy tests should record time-to-clear and loot-per-hour, not only loot-per-run.

## Logs

Live log files:

- `/srv/azerothcore/logs/Auth.log`
- `/srv/azerothcore/logs/DBImport.log`
- `/srv/azerothcore/logs/Server.log`
- `/srv/azerothcore/logs/Errors.log`

Findings:

- `Errors.log` is empty.
- `Server.log` contains AutoBalance config load evidence.
- `Server.log` contains AHBot startup pool loading and repeated AHBot update cycles.
- One non-fatal runtime message appears: `Can't set process priority class, error: Permission denied`.

## Verification Gaps

These were not proven during Phase 1:

- Solo LFG queue completion for 1, 2, 3, 4, and 5 players.
- AutoBalance `.ab mapstat` and `.ab creaturestat` output from live characters.
- Individual Progression gate behavior from actual player accounts at each content phase.
- AHBot price sanity and item mix by level bracket.
- Dungeon reward output by group size.
- Actual combat difficulty in open world, normal dungeons, heroic dungeons, or raids.

