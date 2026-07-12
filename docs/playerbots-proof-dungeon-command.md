# Playerbots QA Dungeon Commands

The QA commands are implemented by the separate
`mod-playerbots-automated-testing` sibling module. The pinned
`modules/mod-playerbots` checkout remains unchanged.

Enable the extension only in the disposable QA configuration:

```ini
PlayerbotsAutomatedTesting.Enable = 1
```

Commands:

```text
playerbotsqa reset [all|run=<id>]
playerbotsqa stage <dungeon> <groupSize 1-5> [run=<id>] [class ...]
playerbotsqa crawl <dungeon> [run=<id>] <status|pull|step 1-5>
```

Example 1-5 cohorts:

```text
playerbotsqa stage deadmines 1 run=101 warrior
playerbotsqa stage deadmines 2 run=201 warrior priest
playerbotsqa stage deadmines 3 run=301 warrior priest mage
playerbotsqa stage deadmines 4 run=401 warrior priest mage rogue
playerbotsqa stage deadmines 5 run=501 warrior priest mage rogue hunter
```

Advance and inspect a cohort:

```text
playerbotsqa crawl deadmines run=301 2
playerbotsqa crawl deadmines run=301 pull
playerbotsqa crawl deadmines run=301 status
playerbotsqa reset run=301
```

The extension selects characters from the random-bot accounts initialized by
Playerbots, prepares them to the target dungeon level, forms a same-faction
party, places it in one instance, and emits `PLAYERBOTS_PROOF_DUNGEON` and
`PLAYERBOTS_PROOF_CRAWL` evidence markers.

Current deterministic crawl paths are Ragefire Chasm and the Deadmines. The
automation remains disabled by default and must only run against the isolated
`acore_*_pb` databases.
