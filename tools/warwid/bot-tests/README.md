# Warwid Bot Dungeon Test Scaffold

This is the first non-invasive scaffold for EMBER-65/EMBER-66 dungeon testing.
It implements only the config skeleton and manual-assisted runner described in
`BOT_DUNGEON_TESTING_FRAMEWORK.md`.

## Scope

- Ragefire Chasm scenarios for party sizes 1-5.
- Deadmines scenarios for party sizes 1-5.
- Offline dry-run validation of scenario configs.
- Manual-assisted result folder generation with evidence templates.

## Safety

These scripts do not install Playerbots or NPCBots, enable SOAP or RA, mutate the
live database, change server tuning/configs, or restart the live server. The
manual runner only validates local config files and writes result templates.

## Usage

Validate every scenario:

```bash
tools/warwid/bot-tests/dry-run-validator.sh
```

Validate one scenario:

```bash
tools/warwid/bot-tests/dry-run-validator.sh --scenario ragefire-chasm-1
```

Create a manual-assisted evidence folder:

```bash
tools/warwid/bot-tests/manual-runner.sh deadmines-5
```

Use `--results-dir /tmp/bot-test-results` to write throwaway validation output
outside the repository.

## Evidence Files

Each manual-assisted run creates:

- `scenario.json`
- `run-metadata.json`
- `gm-command-output.md`
- `metrics.json`
- `metrics.csv`
- `economy.csv`
- `autobalance.md`
- `progression.csv`
- `lfg.csv`
- `logs/.gitkeep`
- `screenshots/.gitkeep`
