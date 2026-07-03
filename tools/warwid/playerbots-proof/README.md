# Warwid Playerbots Disposable Proof

This worktree is a disposable proof for adding Playerbots without touching the
live Warwid server, live databases, or the normal `azerothcore-wotlk` checkout.

## Branch And Module Strategy

- Live checkout: `/home/bnbland/TheMatrix/Projects/azerothcore-wotlk`
- Proof worktree: `/home/bnbland/TheMatrix/Projects/azerothcore-playerbots-proof`
- Proof branch: `warwid/playerbots-proof`
- Core base: `playerbot-core/Playerbot` at `62a991e78`
- Playerbots module: `modules/mod-playerbots` submodule from
  `https://github.com/liyunfan1223/mod-playerbots.git`, branch `master`, at
  `049f3590`

`mod-playerbots` requires the Playerbot AzerothCore fork. Do not try to build it
against the normal Warwid `master` checkout.

## Disposable Build

Use a local build and install path owned by this worktree. The successful
no-sudo proof build used locally extracted dependency packages under
`var/deps/apt-root`, a local Boost build under `var/deps/boost-1.83`, and the
install prefix `var/install/playerbots-proof`.

```bash
cd /home/bnbland/TheMatrix/Projects/azerothcore-playerbots-proof
git submodule update --init --recursive modules/mod-playerbots
mkdir -p var/build/playerbots-proof var/install/playerbots-proof

Boost_ROOT="$PWD/var/deps/boost-1.83" cmake -S . -B var/build/playerbots-proof \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DTOOLS_BUILD=none \
  -DSCRIPTS=static \
  -DMODULES=static \
  -DNOJEM=1 \
  -DCMAKE_INSTALL_PREFIX="$PWD/var/install/playerbots-proof" \
  -DBoost_ROOT="$PWD/var/deps/boost-1.83" \
  -DOPENSSL_ROOT_DIR="$PWD/var/deps/apt-root/usr" \
  -DOPENSSL_INCLUDE_DIR="$PWD/var/deps/apt-root/usr/include" \
  -DOPENSSL_SSL_LIBRARY=/usr/lib/x86_64-linux-gnu/libssl.so.3 \
  -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/x86_64-linux-gnu/libcrypto.so.3 \
  -DZLIB_INCLUDE_DIR="$PWD/var/deps/apt-root/usr/include" \
  -DZLIB_LIBRARY="$PWD/var/deps/apt-root/usr/lib/x86_64-linux-gnu/libz.so" \
  -DREADLINE_INCLUDE_DIR="$PWD/var/deps/apt-root/usr/include" \
  -DREADLINE_LIBRARY="$PWD/var/deps/apt-root/usr/lib/x86_64-linux-gnu/libreadline.so" \
  -DMYSQL_INCLUDE_DIR="$PWD/var/deps/apt-root/usr/include/mysql" \
  -DMYSQL_LIBRARY="$PWD/var/deps/apt-root/usr/lib/x86_64-linux-gnu/libmysqlclient.so"

cmake --build var/build/playerbots-proof --target install -- -j"$(nproc)"
```

With GCC 15, this fork's bundled jemalloc needs
`deps/jemalloc/include/jemalloc/internal/safety_check.h` to declare
`safety_check_set_abort(void (*abort_fn)(const char *))`, matching the existing
source definition. `-DNOJEM=1` is accepted by CMake but does not keep jemalloc
out of the build in this tree.

Local Docker is not available in this shell because the current process does not
have the active `docker` group. Use a fresh group session or an explicitly
approved sudo path before attempting a Docker proof.

## Disposable Database

Use isolated DB names or a disposable MySQL container. Do not import these into
the live Warwid databases.

```sql
CREATE DATABASE IF NOT EXISTS acore_auth_pb;
CREATE DATABASE IF NOT EXISTS acore_characters_pb;
CREATE DATABASE IF NOT EXISTS acore_world_pb;
CREATE DATABASE IF NOT EXISTS acore_playerbots_pb;
GRANT ALL PRIVILEGES ON acore_auth_pb.* TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON acore_characters_pb.* TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON acore_world_pb.* TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON acore_playerbots_pb.* TO 'acore'@'localhost';
FLUSH PRIVILEGES;
```

Configure `authserver.conf`, `worldserver.conf`, and `playerbots.conf` to use
the `_pb` database names. The Playerbots module has its own connection:

```conf
PlayerbotsDatabaseInfo = "127.0.0.1;3306;acore;acore;acore_playerbots_pb"
Playerbots.Updates.EnableDatabases = 1
```

If the module SQL is not picked up by the updater on first boot, import the base
files manually into the disposable databases:

```bash
for f in modules/mod-playerbots/data/sql/characters/base/*.sql; do
  mysql -u acore -p acore_characters_pb < "$f"
done

for f in modules/mod-playerbots/data/sql/world/base/*.sql; do
  mysql -u acore -p acore_world_pb < "$f"
done

mysql -u acore -p acore_playerbots_pb \
  < modules/mod-playerbots/data/sql/playerbots/base/updates.sql
```

## Low-Bot Proof Config

Copy the installed module config and keep both `.dist` and `.conf` present:

```bash
cp var/install/playerbots-proof/etc/modules/playerbots.conf.dist \
   var/install/playerbots-proof/etc/modules/playerbots.conf
```

Use a small proof population instead of the module defaults:

```conf
AiPlayerbot.Enabled = 1
AiPlayerbot.RandomBotAutologin = 1
AiPlayerbot.MinRandomBots = 5
AiPlayerbot.MaxRandomBots = 10
AiPlayerbot.AddClassAccountPoolSize = 2
AiPlayerbot.DisabledWithoutRealPlayer = 0
AiPlayerbot.AddClassCommand = 1
AiPlayerbot.SummonWhenGroup = 1
AiPlayerbot.RandomBotJoinLfg = 0
AiPlayerbot.RandomBotJoinBG = 0
AiPlayerbot.RandomBotAutoJoinBG = 0
AiPlayerbot.CommandServerPort = 0
```

Also raise map update threads in the disposable `worldserver.conf`:

```conf
MapUpdate.Threads = 4
```

## First In-Game Dungeon Path

Use addclass bots for the first proof instead of waiting for autonomous random
bots:

1. Start disposable `authserver` and `worldserver` only after DB/config paths are
   verified as `_pb` paths.
2. Create or log into a GM test account on the disposable realm.
3. Create a level-appropriate test character:
   - RFC: Horde, level 15-20.
   - Deadmines: Alliance, level 18-25.
4. Add a small party with chat commands:
   - `.playerbots bot addclass warrior`
   - `.playerbots bot addclass priest`
   - `.playerbots bot addclass mage`
   - `.playerbots bot addclass rogue`
5. Party commands for the pull test:
   - `/p follow`
   - `/p nc +loot`
   - `/p co +assist`
   - Target tank bot and use `/p give leader` only if needed.
6. Run `tools/warwid/bot-tests/manual-runner.sh ragefire-chasm-5` or
   `deadmines-5` from the live checkout or copy that scaffold into this proof
   tree before collecting evidence.

## Warwid Module Integration Notes

- `mod-ah-bot`: keep separate from Playerbots. It populates auctions and does
  not satisfy dungeon party roles. For proof, verify it compiles later; do not
  point AHBot at Playerbot random accounts.
- `mod-aoe-loot`: compatible conceptually. Keep enabled after basic combat is
  proven and confirm bot looting does not duplicate or bypass group loot rules.
- `mod-autobalance`: important for RFC/Deadmines scaling. The live module patch
  `patches/warwid/mod-autobalance-console-null-session.patch` must be carried
  into any Docker/live build path because the Warwid Dockerfile applies it.
- `mod-individual-progression`: already treats accounts matching `^RNDBOT.*` as
  bot accounts. Keep `IndividualProgression.BotAccountsRegex = "^RNDBOT.*"` and
  verify addclass/random account names still match before progression evidence.
- `mod-solo-lfg`: useful after bots are in-game. For the first proof, use direct
  addclass party formation; then test LFG queue behavior separately.

## Current Blockers

- Docker cannot be run from this shell without a fresh docker-group session or
  an explicitly approved sudo path.
- No local MySQL/MariaDB server or client binary is available in this shell, so
  isolated `_pb` database creation and server boot still need an approved
  disposable DB path.
- The existing Warwid modules are not yet present in this proof worktree. Add
  them after `mod-playerbots` config/build proves clean, then resolve any compile
  conflicts against the Playerbot fork.
- No live deploy, restart, or DB import is approved.
