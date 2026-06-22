#!/usr/bin/env bash
set -euo pipefail

CONF_DIR="${CONF_DIR:-/azerothcore/env/dist/etc}"
MODULE_CONF_DIR="$CONF_DIR/modules"

set_config_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local escaped_key

    escaped_key="$(printf '%s' "$key" | sed 's/[][\/.^$*+?{}()|]/\\&/g')"

    if grep -Eq "^[[:space:]]*${escaped_key}[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*${escaped_key}[[:space:]]*=.*$|${key} = ${value}|" "$file"
    else
        printf '\n%s = %s\n' "$key" "$value" >>"$file"
    fi
}

ensure_module_config() {
    local name="$1"
    local dist="$MODULE_CONF_DIR/$name.dist"
    local conf="$MODULE_CONF_DIR/$name"

    if [[ ! -f "$dist" ]]; then
        echo "Required module configuration is missing: $dist" >&2
        exit 1
    fi

    if [[ ! -f "$conf" ]]; then
        cp "$dist" "$conf"
    fi

    printf '%s' "$conf"
}

mkdir -p "$MODULE_CONF_DIR"

WORLD_CONF="$CONF_DIR/worldserver.conf"
if [[ ! -f "$WORLD_CONF" ]]; then
    echo "Required worldserver configuration is missing: $WORLD_CONF" >&2
    exit 1
fi

# Keep friends together even when they choose different factions.
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Calendar" "1"
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Chat" "1"
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Channel" "1"
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Group" "1"
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Guild" "1"
set_config_value "$WORLD_CONF" "AllowTwoSide.Interaction.Auction" "1"

# Reduce repetition without bypassing zone, profession, or equipment progression.
set_config_value "$WORLD_CONF" "Rate.XP.Kill" "1.5"
set_config_value "$WORLD_CONF" "Rate.XP.Quest" "1.5"
set_config_value "$WORLD_CONF" "Rate.XP.Quest.DF" "1.0"
set_config_value "$WORLD_CONF" "Rate.Reputation.Gain" "1.5"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Poor" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Normal" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Uncommon" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Rare" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Epic" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Legendary" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Artifact" "1"
set_config_value "$WORLD_CONF" "Rate.Drop.Item.Referenced" "1"

IPP_CONF="$(ensure_module_config individualProgression.conf)"
set_config_value "$IPP_CONF" "IndividualProgression.Enable" "1"
set_config_value "$IPP_CONF" "IndividualProgression.EnforceGroupRules" "1"
set_config_value "$IPP_CONF" "IndividualProgression.VanillaPowerAdjustment" "0.6"
set_config_value "$IPP_CONF" "IndividualProgression.VanillaHealingAdjustment" "0.5"
set_config_value "$IPP_CONF" "IndividualProgression.TBCPowerAdjustment" "0.6"
set_config_value "$IPP_CONF" "IndividualProgression.TBCHealingAdjustment" "0.6"
set_config_value "$IPP_CONF" "IndividualProgression.BotOnlyAdjustments" "0"
set_config_value "$IPP_CONF" "IndividualProgression.QuestXPFix" "1"
set_config_value "$IPP_CONF" "IndividualProgression.SimpleConfigOverride" "1"
set_config_value "$IPP_CONF" "IndividualProgression.DisableRDF" "0"
set_config_value "$IPP_CONF" "IndividualProgression.ProgressionLimit" "0"
set_config_value "$IPP_CONF" "IndividualProgression.StartingProgression" "0"
set_config_value "$IPP_CONF" "IndividualProgression.DeathKnightUnlockProgression" "13"
set_config_value "$IPP_CONF" "IndividualProgression.DeathKnightStartingProgression" "13"
set_config_value "$IPP_CONF" "IndividualProgression.doableNaxx40Bosses_4H" "1"
set_config_value "$IPP_CONF" "IndividualProgression.doableNaxx40Bosses_Gluth" "1"
set_config_value "$IPP_CONF" "IndividualProgression.doableNaxx40Bosses_Patchwerk" "1"
set_config_value "$IPP_CONF" "IndividualProgression.doableNaxx40Bosses_Razuvious" "1"
set_config_value "$IPP_CONF" "IndividualProgression.MoltenCore.AqualEssenceCooldownReduction" "60"

AUTOBALANCE_CONF="$(ensure_module_config AutoBalance.conf)"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.Enable.Global" "1"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.MinPlayers" "1"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.MinPlayers.Heroic" "1"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.MinPlayers.Raid" "1"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.MinPlayers.RaidHeroic" "1"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPoint" "0.5"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointHeroic" "0.5"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid" "0.4"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaidHeroic" "0.4"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid10M" "0.4"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid10MHeroic" "0.4"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid25M" "0.35"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid25MHeroic" "0.35"
set_config_value "$AUTOBALANCE_CONF" "AutoBalance.InflectionPointRaid40M" "0.35"

AOE_LOOT_CONF="$(ensure_module_config mod_aoe_loot.conf)"
set_config_value "$AOE_LOOT_CONF" "AOELoot.Enable" "1"
set_config_value "$AOE_LOOT_CONF" "AOELoot.Message" "0"
set_config_value "$AOE_LOOT_CONF" "AOELoot.Range" "30.0"
set_config_value "$AOE_LOOT_CONF" "AOELoot.Group" "1"

SOLO_LFG_CONF="$(ensure_module_config SoloLfg.conf)"
set_config_value "$SOLO_LFG_CONF" "SoloLFG.Enable" "1"
set_config_value "$SOLO_LFG_CONF" "SoloLFG.Announce" "0"
set_config_value "$SOLO_LFG_CONF" "SoloLFG.FixedXP" "1"
set_config_value "$SOLO_LFG_CONF" "SoloLFG.FixedXPRate" "0.5"

AHBOT_CONF="$(ensure_module_config mod_ahbot.conf)"
AHBOT_ACCOUNT_ID="${AC_AHBOT_ACCOUNT_ID:-0}"
AHBOT_CHARACTER_GUID="${AC_AHBOT_CHARACTER_GUID:-0}"
AHBOT_ENABLED=0
if [[ "$AHBOT_ACCOUNT_ID" != "0" || "$AHBOT_CHARACTER_GUID" != "0" ]]; then
    AHBOT_ENABLED=1
fi

set_config_value "$AHBOT_CONF" "AuctionHouseBot.EnableSeller" "$AHBOT_ENABLED"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.EnableBuyer" "$AHBOT_ENABLED"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.Account" "$AHBOT_ACCOUNT_ID"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.GUID" "$AHBOT_CHARACTER_GUID"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.UseMarketPriceForSeller" "1"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.ItemsPerCycle" "100"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.ConsiderOnlyBotAuctions" "1"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.DuplicatesCount" "3"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.DivisibleStacks" "1"
set_config_value "$AHBOT_CONF" "AuctionHouseBot.ProfessionItems" "1"

echo "Applied Warwid solo/small-group configuration."
