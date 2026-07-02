#!/usr/bin/env python3
"""Validate Warwid bot dungeon scenario configs without touching live services."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
SCENARIOS_DIR = ROOT / "scenarios"

REQUIRED_FIELDS = {
    "scenario_id",
    "dungeon_name",
    "map_id",
    "entrance_location",
    "party_size",
    "faction",
    "level",
    "composition",
    "progression_state",
    "autobalance_profile",
    "lfg_mode",
    "timeout_minutes",
    "success_thresholds",
    "reward_thresholds",
}

KNOWN_DUNGEONS = {
    "Ragefire Chasm": {"map_id": 389, "aliases": {"rfc", "ragefire", "ragefire-chasm"}},
    "Deadmines": {"map_id": 36, "aliases": {"vc", "deadmines", "the-deadmines"}},
}

VALID_FACTIONS = {"ALLIANCE", "HORDE", "ANY"}
VALID_ROLES = {"TANK", "HEALER", "DPS"}


def load_scenarios() -> list[tuple[Path, dict[str, Any]]]:
    scenarios: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted(SCENARIOS_DIR.glob("*.json")):
        with path.open(encoding="utf-8") as handle:
            scenarios.append((path, json.load(handle)))
    return scenarios


def validate_scenario(path: Path, scenario: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    missing = sorted(REQUIRED_FIELDS - scenario.keys())
    if missing:
        errors.append(f"missing required fields: {', '.join(missing)}")

    scenario_id = scenario.get("scenario_id")
    if not isinstance(scenario_id, str) or not scenario_id:
        errors.append("scenario_id must be a non-empty string")
    elif path.stem != scenario_id:
        errors.append(f"filename must match scenario_id ({path.stem!r} != {scenario_id!r})")

    dungeon_name = scenario.get("dungeon_name")
    dungeon = KNOWN_DUNGEONS.get(dungeon_name)
    if dungeon is None:
        errors.append(f"unknown dungeon_name: {dungeon_name!r}")
    elif scenario.get("map_id") != dungeon["map_id"]:
        errors.append(f"map_id for {dungeon_name} must be {dungeon['map_id']}")

    party_size = scenario.get("party_size")
    if not isinstance(party_size, int) or not 1 <= party_size <= 5:
        errors.append("party_size must be an integer from 1 through 5")

    faction = scenario.get("faction")
    if faction not in VALID_FACTIONS:
        errors.append(f"faction must be one of {sorted(VALID_FACTIONS)}")

    level = scenario.get("level")
    if not isinstance(level, int) or not 1 <= level <= 80:
        errors.append("level must be an integer from 1 through 80")

    timeout = scenario.get("timeout_minutes")
    if not isinstance(timeout, int) or timeout <= 0:
        errors.append("timeout_minutes must be a positive integer")

    entrance = scenario.get("entrance_location")
    if not isinstance(entrance, dict) or not {"map", "zone", "description"} <= entrance.keys():
        errors.append("entrance_location must contain map, zone, and description")

    composition = scenario.get("composition")
    if not isinstance(composition, list) or not composition:
        errors.append("composition must be a non-empty list")
    elif isinstance(party_size, int) and len(composition) != party_size:
        errors.append("composition length must match party_size")
    else:
        slots = set()
        for member in composition:
            if not isinstance(member, dict):
                errors.append("composition entries must be objects")
                continue
            for field in ("slot", "class", "spec", "role"):
                if field not in member:
                    errors.append(f"composition entry missing {field}")
            if member.get("role") not in VALID_ROLES:
                errors.append(f"invalid role in composition: {member.get('role')!r}")
            slot = member.get("slot")
            if not isinstance(slot, int) or slot < 1:
                errors.append(f"invalid composition slot: {slot!r}")
            elif slot in slots:
                errors.append(f"duplicate composition slot: {slot}")
            slots.add(slot)

    thresholds = scenario.get("success_thresholds")
    if not isinstance(thresholds, dict):
        errors.append("success_thresholds must be an object")
    else:
        for key in ("completion_required", "boss_kills_min", "deaths_max", "wipes_max"):
            if key not in thresholds:
                errors.append(f"success_thresholds missing {key}")

    rewards = scenario.get("reward_thresholds")
    if not isinstance(rewards, dict):
        errors.append("reward_thresholds must be an object")
    else:
        for key in (
            "compare_to_5_player_baseline",
            "total_reward_must_not_exceed_5p_baseline",
            "raw_gold_copper_max",
            "xp_max",
            "item_value_copper_max",
        ):
            if key not in rewards:
                errors.append(f"reward_thresholds missing {key}")

    return errors


def select_scenarios(
    scenarios: list[tuple[Path, dict[str, Any]]], scenario_id: str | None, dungeon_filter: str | None
) -> list[tuple[Path, dict[str, Any]]]:
    selected = scenarios
    if scenario_id:
        selected = [(path, scenario) for path, scenario in selected if scenario.get("scenario_id") == scenario_id]
    if dungeon_filter:
        normalized = dungeon_filter.strip().lower().replace(" ", "-")
        selected = [
            (path, scenario)
            for path, scenario in selected
            if scenario.get("dungeon_name") == dungeon_filter
            or normalized in KNOWN_DUNGEONS.get(scenario.get("dungeon_name"), {}).get("aliases", set())
        ]
    return selected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Validate all scenarios (default)")
    parser.add_argument("--scenario", help="Validate one scenario_id")
    parser.add_argument("--dungeon", help="Validate one dungeon by name or alias")
    args = parser.parse_args()

    scenarios = load_scenarios()
    selected = select_scenarios(scenarios, args.scenario, args.dungeon)
    if not selected:
        print("No matching scenarios found.", file=sys.stderr)
        return 1

    seen_ids: dict[str, Path] = {}
    failed = 0
    for path, scenario in selected:
        errors = validate_scenario(path, scenario)
        scenario_id = scenario.get("scenario_id", path.stem)
        if scenario_id in seen_ids:
            errors.append(f"duplicate scenario_id also used by {seen_ids[scenario_id]}")
        else:
            seen_ids[scenario_id] = path

        if errors:
            failed += 1
            print(f"FAIL {path}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"PASS {scenario_id} ({scenario['dungeon_name']}, party_size={scenario['party_size']})")

    print(f"Validated {len(selected)} scenario(s); failures={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
