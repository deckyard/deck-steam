# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the market topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testParseMoneyAmericanFormat() {
    testing.assertEqual(parseMoney("$1.23"), 1.23);
    testing.assertEqual(parseMoney("$1,234.56"), 1234.56);
    testing.assertEqual(parseMoney("CDN$ 4.56"), 4.56);
    testing.assertEqual(parseMoney("£0.99"), 0.99);
}

func testParseMoneyEuropeanFormat() {
    testing.assertEqual(parseMoney("0,03€"), 0.03);
    testing.assertEqual(parseMoney("1.234,56€"), 1234.56);
    testing.assertEqual(parseMoney("9,99 zl"), 9.99);
}

func testParseMoneyWithoutFraction() {
    testing.assertEqual(parseMoney("1234"), 1234.0);
    testing.assertEqual(parseMoney("12.345"), 12345.0);
    testing.assertEqual(parseMoney("1 234 руб."), 1234.0);
}

func testParseMoneyOneDecimalDigit() {
    testing.assertEqual(parseMoney("1,5€"), 1.5);
}

func testParseMoneyWithoutDigits() {
    testing.assertEqual(parseMoney(""), 0.0);
    testing.assertEqual(parseMoney("--"), 0.0);
}

func testParseMoneyCents() {
    testing.assertEqual(parseMoneyCents("$1.23"), 123);
    testing.assertEqual(parseMoneyCents("0,03€"), 3);
    testing.assertEqual(parseMoneyCents("$1,234.56"), 123456);
    testing.assertEqual(parseMoneyCents(""), 0);
}

func testParseCount() {
    testing.assertEqual(parseCount("12,345"), 12345);
    testing.assertEqual(parseCount("12.345"), 12345);
    testing.assertEqual(parseCount("7"), 7);
    testing.assertEqual(parseCount(""), 0);
}

func testMarketPriceFrom() {
    def body as json.Value init json.decode('{
        "success": true,
        "lowest_price": "0,03€",
        "volume": "12,345",
        "median_price": "0,04€"
    }');
    def q as MarketPrice init marketPriceFrom($body);
    testing.assertTrue($q.found);
    testing.assertEqual($q.lowestPrice, "0,03€");
    testing.assertEqual($q.medianPrice, "0,04€");
    testing.assertEqual($q.lowestCents, 3);
    testing.assertEqual($q.medianCents, 4);
    testing.assertEqual($q.volume, 12345);
}

func testMarketPriceFromThinlyTradedItem() {
    def body as json.Value init json.decode('{"success": true, "lowest_price": "$1.99"}');
    def q as MarketPrice init marketPriceFrom($body);
    testing.assertTrue($q.found);
    testing.assertEqual($q.lowestCents, 199);
    testing.assertEqual($q.medianPrice, "");
    testing.assertEqual($q.medianCents, 0);
    testing.assertEqual($q.volume, 0);
}

func testMarketPriceFromFailure() {
    def q as MarketPrice init marketPriceFrom(json.decode('{"success": false}'));
    testing.assertFalse($q.found);
    testing.assertEqual($q.lowestCents, 0);
    testing.assertEqual($q.volume, 0);
}

func testMarketListingUrl() {
    testing.assertEqual(
        marketListingUrl(730, "AK-47 | Redline (Field-Tested)"),
        "https://steamcommunity.com/market/listings/730/" +
            "AK-47%20%7C%20Redline%20%28Field-Tested%29");
    testing.assertThrows("listingForBadApp", "steam");
    testing.assertThrows("listingWithoutName", "steam");
}

func listingForBadApp() {
    marketListingUrl(0, "Mann Co. Supply Crate Key");
}

func listingWithoutName() {
    marketListingUrl(730, "  ");
}

func testMarketSearchUrl() {
    testing.assertEqual(
        marketSearchUrl(440, ""),
        "https://steamcommunity.com/market/search?appid=440");
    testing.assertEqual(
        marketSearchUrl(440, "crate key"),
        "https://steamcommunity.com/market/search?appid=440&q=crate+key");
}

func testCurrencyCode() {
    testing.assertEqual(currencyCode(CURRENCY_USD), "USD");
    testing.assertEqual(currencyCode(CURRENCY_EUR), "EUR");
    testing.assertEqual(currencyCode(CURRENCY_JPY), "JPY");
    testing.assertEqual(currencyCode(CURRENCY_CAD), "CAD");
    testing.assertEqual(currencyCode(999), "");
}

func testPriceOverviewValidates() {
    testing.assertThrows("overviewForBadApp", "steam");
    testing.assertThrows("overviewWithoutName", "steam");
}

func overviewForBadApp() {
    priceOverview(client(""), 0, "Mann Co. Supply Crate Key");
}

func overviewWithoutName() {
    priceOverview(client(""), 440, "");
}

# --- adversarial input: these strings come from the server, so a malformed
# --- one must read as 0 rather than raise an uncaught conversion error

func testParseMoneySurvivesAbsurdDigitRuns() {
    testing.assertEqual(parseMoney(strings.repeat("9", 400)), 0.0);
    testing.assertEqual(parseMoney(strings.repeat("9", 400) + ",00"), 0.0);
}

func testParseCountSurvivesAbsurdDigitRuns() {
    testing.assertEqual(parseCount(strings.repeat("9", 30)), 0);
    testing.assertEqual(parseCount(strings.repeat("9", 400)), 0);
}

func testParseMoneyCentsClampsInsteadOfOverflowing() {
    # 1e30 is a valid float but scaling it to cents does not fit an int64
    testing.assertEqual(parseMoneyCents(strings.repeat("9", 30)), 0);
    testing.assertEqual(parseMoneyCents(strings.repeat("9", 400)), 0);
    testing.assertEqual(parseMoneyCents("$1.23"), 123);
}

func testMarketPriceFromSurvivesAHostileBody() {
    def body as json.Value init json.decode('{
        "success": true,
        "lowest_price": "99999999999999999999999999999999999999999",
        "volume": "99999999999999999999999999999999999999999",
        "median_price": "$1.23"
    }');
    def q as MarketPrice init marketPriceFrom($body);
    testing.assertTrue($q.found);
    testing.assertEqual($q.lowestCents, 0);
    testing.assertEqual($q.volume, 0);
    testing.assertEqual($q.medianCents, 123);
}
