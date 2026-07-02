#!/usr/bin/env python3
"""Create a manual-assisted result folder for one validated bot dungeon scenario."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from types import ModuleType
from typing import Any


ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results"


def load_validator() -> ModuleType:
    spec = importlib.util.spec_from_file_location("validate_scenarios", ROOT / "validate-scenarios.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load validate-scenarios.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validate_scenarios = load_validator()


def git_value(args: list[str]) -> str | None:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def find_scenario(scenario_id: str) -> tuple[Path, dict[str, Any]]:
    for path, scenario in validate_scenarios.load_scenarios():
        if scenario.get("scenario_id") == scenario_id:
            errors = validate_scenarios.validate_scenario(path, scenario)
            if errors:
                raise SystemExit(f"Scenario {scenario_id} is invalid: {'; '.join(errors)}")
            return path, scenario
    raise SystemExit(f"Scenario not found: {scenario_id}")


def write_csv(path: Path, headers: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(headers)


def create_result_folder(scenario_path: Path, scenario: dict[str, Any], results_dir: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    result_dir = results_dir / f"{timestamp}-{scenario['scenario_id']}"
    result_dir.mkdir(parents=True, exist_ok=False)

    shutil.copy2(scenario_path, result_dir / "scenario.json")
    (result_dir / "logs").mkdir()
    (result_dir / "screenshots").mkdir()
    (result_dir / "logs" / ".gitkeep").write_text("", encoding="utf-8")
    (result_dir / "screenshots" / ".gitkeep").write_text("", encoding="utf-8")

    metadata = {
        "scenario_id": scenario["scenario_id"],
        "runner_mode": "manual-assisted",
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "git_commit": git_value(["rev-parse", "--short", "HEAD"]),
        "git_branch": git_value(["branch", "--show-current"]),
        "status": "evidence-template-created",
        "non_invasive_guards": {
            "installs_bot_modules": False,
            "enables_soap_or_ra": False,
            "writes_live_database": False,
            "changes_tuning_or_configs": False,
            "restarts_live_server": False
        }
    }
    (result_dir / "run-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    (result_dir / "gm-command-output.md").write_text(
        "# GM Command Output\n\n"
        "Paste manually captured in-game GM/client output here.\n\n"
        "Do not add account passwords, connection strings, private keys, or live DB credentials.\n\n"
        "## Setup\n\n"
        "- Scenario marker:\n"
        f"  - `{scenario['scenario_id']}`\n"
        "- Manual party setup notes:\n\n"
        "## Run Log\n\n"
        "- Start timestamp:\n"
        "- End timestamp:\n"
        "- Bosses killed:\n"
        "- Deaths:\n"
        "- Wipes:\n",
        encoding="utf-8",
    )

    metrics = {
        "scenario_id": scenario["scenario_id"],
        "dungeon_name": scenario["dungeon_name"],
        "party_size": scenario["party_size"],
        "start_time": None,
        "end_time": None,
        "duration_minutes": None,
        "completion_success": None,
        "boss_kills": None,
        "trash_kills": None,
        "deaths": None,
        "wipes": None,
        "failure_reason": None
    }
    (result_dir / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    write_csv(
        result_dir / "metrics.csv",
        [
            "scenario_id",
            "dungeon_name",
            "party_size",
            "start_time",
            "end_time",
            "duration_minutes",
            "completion_success",
            "boss_kills",
            "trash_kills",
            "deaths",
            "wipes",
            "failure_reason",
        ],
    )
    write_csv(
        result_dir / "economy.csv",
        [
            "scenario_id",
            "raw_gold_copper",
            "xp_gained",
            "item_count",
            "item_quality_distribution",
            "vendor_value_copper",
            "total_value_copper",
            "value_per_player_copper",
            "value_per_hour_copper",
            "exceeds_5p_baseline",
        ],
    )
    (result_dir / "autobalance.md").write_text(
        "# AutoBalance Evidence\n\n"
        "- Config/profile observed: CURRENT_SERVER_CONFIG\n"
        "- Relevant log excerpts:\n"
        "- Difficulty notes:\n",
        encoding="utf-8",
    )
    write_csv(
        result_dir / "progression.csv",
        [
            "scenario_id",
            "character",
            "progression_before",
            "entry_attempt",
            "entry_allowed",
            "progression_after",
            "notes",
        ],
    )
    write_csv(
        result_dir / "lfg.csv",
        [
            "scenario_id",
            "lfg_mode",
            "queued",
            "roles_selected",
            "teleport_used",
            "entry_success",
            "completion_credit",
            "xp_behavior",
            "notes",
        ],
    )
    return result_dir


def print_manual_checklist(scenario: dict[str, Any], result_dir: Path) -> None:
    print(f"Created result folder: {result_dir}")
    print()
    print("Manual-assisted checklist:")
    print("1. Use the current server configuration as-is; do not change tuning or enable SOAP/RA.")
    print("2. Prepare the party manually according to scenario.json composition.")
    print("3. Enter the dungeon manually and record start/end timestamps in metrics.json or metrics.csv.")
    print("4. Capture GM/client output in gm-command-output.md and screenshots/log excerpts in the evidence folders.")
    print("5. Record combat, economy, AutoBalance, progression, and LFG observations in the provided templates.")
    print()
    print("No live commands were issued by this runner.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scenario_id")
    parser.add_argument("--results-dir", type=Path, default=RESULTS_DIR)
    args = parser.parse_args()

    scenario_path, scenario = find_scenario(args.scenario_id)
    result_dir = create_result_folder(scenario_path, scenario, args.results_dir)
    print_manual_checklist(scenario, result_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
