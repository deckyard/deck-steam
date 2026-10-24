# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the econ topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func tradeOfferFixture() {
    return json.decode('{
        "tradeofferid": "4501234567",
        "accountid_other": 22202,
        "message": "trade?",
        "expiration_time": 1710000000,
        "trade_offer_state": 2,
        "items_to_give": [
            {
                "appid": 440,
                "contextid": "2",
                "assetid": "111",
                "classid": "222",
                "instanceid": "0",
                "amount": "1",
                "missing": false
            }
        ],
        "items_to_receive": [
            {
                "appid": 440,
                "contextid": "2",
                "assetid": "333",
                "classid": "444",
                "instanceid": "0",
                "amount": "3",
                "missing": true
            }
        ],
        "is_our_offer": false,
        "time_created": 1700000000,
        "time_updated": 1700000100,
        "escrow_end_date": 0
    }');
}

func testTradeOfferFrom() {
    def o as TradeOffer init tradeOfferFrom(tradeOfferFixture());
    testing.assertEqual($o.tradeOfferId, "4501234567");
    testing.assertEqual($o.otherSteamId, "76561197960287930");
    testing.assertEqual($o.message, "trade?");
    testing.assertEqual($o.state, TRADE_ACTIVE);
    testing.assertFalse($o.isOurOffer);
    testing.assertEqual($o.timeCreated, 1700000000);
    testing.assertEqual($o.timeUpdated, 1700000100);
    testing.assertEqual($o.expirationTime, 1710000000);
    testing.assertEqual($o.escrowEndDate, 0);
    testing.assertTrue(isPendingOffer($o));
    testing.assertFalse(isOneSided($o));
}

func testTradeAssetsFrom() {
    def o as TradeOffer init tradeOfferFrom(tradeOfferFixture());
    testing.assertEqual(len($o.toGive), 1);
    testing.assertEqual($o.toGive[0].appId, 440);
    testing.assertEqual($o.toGive[0].assetId, "111");
    testing.assertEqual($o.toGive[0].amount, 1);
    testing.assertFalse($o.toGive[0].missing);
    testing.assertEqual($o.toReceive[0].amount, 3);
    testing.assertTrue($o.toReceive[0].missing);
}

func testTradeOfferFromWithoutOtherAccount() {
    def o as TradeOffer init tradeOfferFrom(json.decode('{"tradeofferid": "1", "trade_offer_state": 3}'));
    testing.assertEqual($o.otherSteamId, "");
    testing.assertEqual($o.state, TRADE_ACCEPTED);
    testing.assertFalse(isPendingOffer($o));
    testing.assertTrue(isOneSided($o));
}

func testTradeOfferListFrom() {
    def body as json.Value init json.decode('{
        "response": {
            "trade_offers_received": [
                {"tradeofferid": "1", "trade_offer_state": 2},
                {"tradeofferid": "2", "trade_offer_state": 7}
            ]
        }
    }');
    def got as list of TradeOffer init tradeOfferListFrom($body, "/response/trade_offers_received");
    testing.assertEqual(len($got), 2);
    testing.assertEqual($got[1].state, TRADE_DECLINED);
    def none as list of TradeOffer init [];
    testing.assertEqual(tradeOfferListFrom($body, "/response/trade_offers_sent"), $none);
}

func testTradeOfferStateName() {
    testing.assertEqual(tradeOfferStateName(TRADE_ACTIVE), "active");
    testing.assertEqual(tradeOfferStateName(TRADE_ACCEPTED), "accepted");
    testing.assertEqual(tradeOfferStateName(TRADE_CANCELED), "canceled");
    testing.assertEqual(tradeOfferStateName(TRADE_DECLINED), "declined");
    testing.assertEqual(tradeOfferStateName(TRADE_IN_ESCROW), "in escrow");
    testing.assertEqual(tradeOfferStateName(99), "unknown");
}

func testAssetPriceFrom() {
    def node as json.Value init json.decode('{
        "prices": {"USD": 249, "EUR": 229, "GBP": 199},
        "class": [{"name": "def_index", "value": "5021"}],
        "classid": "101785959",
        "name": "key",
        "date": "2011-09-30"
    }');
    def p as AssetPrice init assetPriceFrom($node);
    testing.assertEqual($p.classId, "101785959");
    testing.assertEqual($p.name, "key");
    testing.assertEqual($p.date, "2011-09-30");
    testing.assertEqual($p.prices["USD"], 249);
    testing.assertEqual($p.prices["EUR"], 229);
    testing.assertEqual(len(maps.keys($p.prices)), 3);
}

func testAssetPriceFromWithoutPrices() {
    def p as AssetPrice init assetPriceFrom(json.decode('{"classid": "1", "name": "x"}'));
    testing.assertEqual(len(maps.keys($p.prices)), 0);
}

func testEconCallsRefuseWithoutKey() {
    testing.assertThrows("keylessSummary", "steam");
    testing.assertThrows("keylessOffers", "steam");
    testing.assertThrows("keylessOffer", "steam");
    testing.assertThrows("keylessAssetPrices", "steam");
}

func keylessSummary() {
    tradeOffersSummary(client(""), 0);
}

func keylessOffers() {
    tradeOffers(client(""), true, true, true);
}

func keylessOffer() {
    tradeOffer(client(""), "1");
}

func keylessAssetPrices() {
    assetPrices(client(""), 440);
}

func testTradeOffersNeedsADirection() {
    testing.assertThrows("offersWithNoDirection", "steam");
}

func offersWithNoDirection() {
    tradeOffers(client("k"), false, false, true);
}

func testTradeOfferValidatesItsId() {
    testing.assertThrows("offerWithJunkId", "steam");
}

func offerWithJunkId() {
    tradeOffer(client("k"), "not-a-number");
}

func testSummaryRejectsNegativeCutoff() {
    testing.assertThrows("summaryWithNegativeCutoff", "steam");
}

func summaryWithNegativeCutoff() {
    tradeOffersSummary(client("k"), -1);
}
