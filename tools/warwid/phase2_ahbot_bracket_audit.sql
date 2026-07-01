SET @ahbot_guid := 2;

SELECT 'phase2_ahbot_bracket_audit' AS audit_name, NOW() AS observed_at, @ahbot_guid AS ahbot_guid;

SELECT
    COUNT(*) AS bot_owned_auctions,
    ROUND(SUM(ah.buyoutprice) / 10000, 2) AS total_buyout_gold,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold,
    ROUND(MIN(ah.buyoutprice) / 10000, 4) AS min_buyout_gold,
    ROUND(MAX(ah.buyoutprice) / 10000, 4) AS max_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
WHERE ii.owner_guid = @ahbot_guid;

SELECT
    CASE
        WHEN it.RequiredLevel = 0 AND it.ItemLevel <= 20 THEN '00 cosmetic/trade/low'
        WHEN it.RequiredLevel BETWEEN 1 AND 19 THEN '01 level 1-19'
        WHEN it.RequiredLevel BETWEEN 20 AND 39 THEN '02 level 20-39'
        WHEN it.RequiredLevel BETWEEN 40 AND 59 THEN '03 level 40-59'
        WHEN it.RequiredLevel BETWEEN 60 AND 69 THEN '04 level 60-69'
        WHEN it.RequiredLevel BETWEEN 70 AND 79 THEN '05 level 70-79'
        WHEN it.RequiredLevel >= 80 THEN '06 level 80'
        ELSE '99 no required level'
    END AS level_bracket,
    COUNT(*) AS auctions,
    SUM(ii.count) AS item_stack_count,
    ROUND(SUM(ah.buyoutprice) / 10000, 2) AS total_buyout_gold,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold,
    ROUND(MAX(ah.buyoutprice) / 10000, 4) AS max_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ii.owner_guid = @ahbot_guid
GROUP BY level_bracket
ORDER BY level_bracket;

SELECT
    it.Quality,
    CASE it.Quality
        WHEN 0 THEN 'poor'
        WHEN 1 THEN 'common'
        WHEN 2 THEN 'uncommon'
        WHEN 3 THEN 'rare'
        WHEN 4 THEN 'epic'
        WHEN 5 THEN 'legendary'
        ELSE 'other'
    END AS quality_name,
    COUNT(*) AS auctions,
    ROUND(SUM(ah.buyoutprice) / 10000, 2) AS total_buyout_gold,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold,
    ROUND(MAX(ah.buyoutprice) / 10000, 4) AS max_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ii.owner_guid = @ahbot_guid
GROUP BY it.Quality
ORDER BY it.Quality;

SELECT
    it.class,
    CASE it.class
        WHEN 0 THEN 'consumable'
        WHEN 1 THEN 'container'
        WHEN 2 THEN 'weapon'
        WHEN 4 THEN 'armor'
        WHEN 7 THEN 'trade goods'
        WHEN 9 THEN 'recipe'
        WHEN 11 THEN 'quiver'
        WHEN 12 THEN 'quest'
        WHEN 15 THEN 'misc'
        WHEN 16 THEN 'glyph'
        ELSE 'other'
    END AS class_name,
    COUNT(*) AS auctions,
    ROUND(SUM(ah.buyoutprice) / 10000, 2) AS total_buyout_gold,
    ROUND(AVG(ah.buyoutprice) / 10000, 4) AS avg_buyout_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ii.owner_guid = @ahbot_guid
GROUP BY it.class
ORDER BY auctions DESC, it.class;

SELECT
    COUNT(*) AS vendor_resale_candidates,
    ROUND(COALESCE(SUM(GREATEST((it.SellPrice * ii.count) - ah.buyoutprice, 0)), 0) / 10000, 4) AS total_possible_vendor_profit_gold
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ii.owner_guid = @ahbot_guid
  AND ah.buyoutprice > 0
  AND it.SellPrice * ii.count > ah.buyoutprice;

SELECT
    COUNT(*) AS risky_quality_or_level_auctions
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
JOIN acore_world.item_template it ON it.entry = ii.itemEntry
WHERE ii.owner_guid = @ahbot_guid
  AND (
      it.Quality >= 3
      OR (it.Quality >= 2 AND it.RequiredLevel >= 60)
      OR it.ItemLevel >= 187
  );

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
WHERE ii.owner_guid = @ahbot_guid
ORDER BY it.Quality DESC, it.RequiredLevel DESC, it.ItemLevel DESC, ah.buyoutprice DESC
LIMIT 40;

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
WHERE ii.owner_guid = @ahbot_guid
ORDER BY ah.buyoutprice ASC, it.ItemLevel DESC
LIMIT 40;
