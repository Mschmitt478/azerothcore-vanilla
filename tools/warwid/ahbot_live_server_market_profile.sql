SELECT 'ahbot_live_server_market_profile_before' AS marker;

SELECT
    auctionhouse,
    name,
    minitems,
    maxitems,
    percentwhitetradegoods,
    percentgreentradegoods,
    percentbluetradegoods,
    percentwhiteitems,
    percentgreenitems,
    percentblueitems,
    percentpurpleitems
FROM acore_world.mod_auctionhousebot
ORDER BY auctionhouse;

UPDATE acore_world.mod_auctionhousebot
SET
    minitems = 500,
    maxitems = 750,
    percentgreytradegoods = 0,
    percentwhitetradegoods = 20,
    percentgreentradegoods = 8,
    percentbluetradegoods = 2,
    percentpurpletradegoods = 0,
    percentorangetradegoods = 0,
    percentyellowtradegoods = 0,
    percentgreyitems = 0,
    percentwhiteitems = 23,
    percentgreenitems = 35,
    percentblueitems = 10,
    percentpurpleitems = 2,
    percentorangeitems = 0,
    percentyellowitems = 0,
    maxstackgrey = 0,
    maxstackwhite = 0,
    maxstackgreen = 3,
    maxstackblue = 2,
    maxstackpurple = 1,
    maxstackorange = 1,
    maxstackyellow = 1,
    buyerbiddinginterval = 1,
    buyerbidsperinterval = 2
WHERE auctionhouse IN (2, 6, 7);

SELECT 'ahbot_live_server_market_profile_after' AS marker;

SELECT
    auctionhouse,
    name,
    minitems,
    maxitems,
    percentgreytradegoods + percentwhitetradegoods + percentgreentradegoods +
        percentbluetradegoods + percentpurpletradegoods + percentorangetradegoods +
        percentyellowtradegoods + percentgreyitems + percentwhiteitems +
        percentgreenitems + percentblueitems + percentpurpleitems +
        percentorangeitems + percentyellowitems AS profile_percent_total,
    percentwhitetradegoods,
    percentgreentradegoods,
    percentbluetradegoods,
    percentwhiteitems,
    percentgreenitems,
    percentblueitems,
    percentpurpleitems
FROM acore_world.mod_auctionhousebot
ORDER BY auctionhouse;
