SELECT 'phase2_readonly_audit' AS audit_name, NOW() AS observed_at;

SELECT
    'auctionhouse_total' AS metric,
    COUNT(*) AS value
FROM acore_characters.auctionhouse;

SELECT
    ii.owner_guid AS ahbot_guid,
    COUNT(*) AS auctions,
    ROUND(SUM(ah.buyoutprice) / 10000, 2) AS total_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
GROUP BY ii.owner_guid
ORDER BY auctions DESC
LIMIT 10;

SELECT
    it.Quality,
    COUNT(*) AS auctions,
    ROUND(MIN(ah.buyoutprice) / 10000, 4) AS min_buyout_gold,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold,
    ROUND(MAX(ah.buyoutprice) / 10000, 4) AS max_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
GROUP BY it.Quality
ORDER BY it.Quality;

SELECT
    it.class,
    COUNT(*) AS auctions,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
GROUP BY it.class
ORDER BY auctions DESC;

SELECT
    COUNT(*) AS vendor_resale_candidates
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ah.buyoutprice > 0
  AND it.SellPrice * ii.count > ah.buyoutprice;

SELECT
    it.entry,
    it.name,
    it.Quality,
    it.class,
    it.subclass,
    it.ItemLevel,
    it.RequiredLevel,
    ii.count,
    ROUND(ah.buyoutprice / 10000, 4) AS buyout_gold,
    ROUND((it.SellPrice * ii.count) / 10000, 4) AS vendor_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
ORDER BY ah.buyoutprice ASC, it.ItemLevel DESC
LIMIT 40;

SELECT
    COUNT(*) AS progression_hidden_quests
FROM acore_world.quest_template
WHERE ID BETWEEN 66001 AND 66018;

SELECT
    COUNT(*) AS progression_condition_rows
FROM acore_world.conditions
WHERE ConditionValue1 BETWEEN 66001 AND 66018
   OR ConditionValue2 BETWEEN 66001 AND 66018
   OR ConditionValue3 BETWEEN 66001 AND 66018;

SELECT
    ID,
    QuestType,
    LogTitle
FROM acore_world.quest_template
WHERE ID BETWEEN 66001 AND 66018
ORDER BY ID;
