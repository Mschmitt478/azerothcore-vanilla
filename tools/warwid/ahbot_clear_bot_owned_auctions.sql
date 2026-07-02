SET @ahbot_guid := 2;
USE acore_characters;

SELECT 'ahbot_clear_bot_owned_auctions_before' AS marker, COUNT(*) AS auctions
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
WHERE ii.owner_guid = @ahbot_guid;

CREATE TEMPORARY TABLE ahbot_items_to_delete AS
SELECT ah.itemguid
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
WHERE ii.owner_guid = @ahbot_guid;

DELETE ah
FROM acore_characters.auctionhouse ah
JOIN ahbot_items_to_delete doomed ON doomed.itemguid = ah.itemguid;

DELETE ii
FROM acore_characters.item_instance ii
JOIN ahbot_items_to_delete doomed ON doomed.itemguid = ii.guid;

SELECT 'ahbot_clear_bot_owned_auctions_after' AS marker, COUNT(*) AS auctions
FROM acore_characters.auctionhouse ah
JOIN acore_characters.item_instance ii ON ii.guid = ah.itemguid
WHERE ii.owner_guid = @ahbot_guid;
