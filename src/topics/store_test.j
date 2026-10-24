# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the store topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func appDetailsFixture() {
    return json.decode('{
        "type": "game",
        "name": "Portal 2",
        "steam_appid": 620,
        "required_age": 0,
        "is_free": false,
        "dlc": [323180, 401260],
        "short_description": "The sequel.",
        "about_the_game": "<p>Long text.</p>",
        "supported_languages": "English<strong>*</strong>, German",
        "header_image": "https://img.example/620/header.jpg",
        "capsule_image": "https://img.example/620/capsule.jpg",
        "website": "https://thinkwithportals.com",
        "developers": ["Valve"],
        "publishers": ["Valve"],
        "price_overview": {
            "currency": "EUR",
            "initial": 999,
            "final": 339,
            "discount_percent": 66,
            "initial_formatted": "9,99€",
            "final_formatted": "3,39€"
        },
        "platforms": {"windows": true, "mac": true, "linux": true},
        "metacritic": {"score": 95, "url": "https://metacritic.example/portal-2"},
        "categories": [
            {"id": 2, "description": "Single-player"},
            {"id": 1, "description": "Multi-player"}
        ],
        "genres": [{"id": "1", "description": "Action"}],
        "recommendations": {"total": 259000},
        "achievements": {"total": 51},
        "release_date": {"coming_soon": false, "date": "19 Apr, 2011"}
    }');
}

func testAppDetailsFrom() {
    def d as AppDetails init appDetailsFrom(appDetailsFixture(), 620);
    testing.assertEqual($d.appId, 620);
    testing.assertEqual($d.name, "Portal 2");
    testing.assertEqual($d.kind, "game");
    testing.assertEqual($d.requiredAge, 0);
    testing.assertFalse($d.isFree);
    testing.assertEqual($d.shortDescription, "The sequel.");
    testing.assertEqual($d.website, "https://thinkwithportals.com");
    testing.assertEqual($d.developers, ["Valve"]);
    testing.assertEqual($d.publishers, ["Valve"]);
    testing.assertEqual($d.categories, ["Single-player", "Multi-player"]);
    testing.assertEqual($d.genres, ["Action"]);
    testing.assertEqual($d.dlc, [323180, 401260]);
    testing.assertEqual($d.metacriticScore, 95);
    testing.assertEqual($d.recommendations, 259000);
    testing.assertEqual($d.achievementCount, 51);
    testing.assertEqual($d.releaseDate, "19 Apr, 2011");
    testing.assertFalse($d.comingSoon);
    testing.assertTrue($d.platforms.linux);
}

func testPriceFrom() {
    def p as Price init priceFrom(appDetailsFixture(), "/price_overview");
    testing.assertEqual($p.currency, "EUR");
    testing.assertEqual($p.initial, 999);
    testing.assertEqual($p.final, 339);
    testing.assertEqual($p.discountPercent, 66);
    testing.assertEqual($p.finalFormatted, "3,39€");
    testing.assertTrue(isDiscounted($p));
    testing.assertEqual(savings($p), 660);
    testing.assertEqual(discountLabel($p), "-66%");
    testing.assertEqual(majorUnits($p.final), 3.39);
}

func testPriceFromAbsentObject() {
    def p as Price init priceFrom(json.decode('{"is_free": true}'), "/price_overview");
    testing.assertEqual($p, emptyPrice());
    testing.assertFalse(isDiscounted($p));
    testing.assertEqual(savings($p), 0);
    testing.assertEqual(discountLabel($p), "");
}

func testIsDiscountedNeedsBothSignals() {
    def odd as Price init Price{
        currency: "EUR",
        initial: 500,
        final: 500,
        discountPercent: 10,
        initialFormatted: "",
        finalFormatted: ""
    };
    testing.assertFalse(isDiscounted($odd));
}

func testPlatformsFrom() {
    def none as Platforms init platformsFrom(json.decode('{}'), "/platforms");
    testing.assertFalse($none.windows);
    testing.assertFalse($none.mac);
    testing.assertFalse($none.linux);
}

func testAppPriceFor() {
    def d as AppDetails init appDetailsFrom(appDetailsFixture(), 620);
    def p as AppPrice init appPriceFor($d);
    testing.assertEqual($p.appId, 620);
    testing.assertTrue($p.found);
    testing.assertFalse($p.free);
    testing.assertEqual($p.price.finalFormatted, "3,39€");
}

func testAppPriceForFreeTitle() {
    def free as json.Value init json.decode('{"name": "Dota 2", "is_free": true}');
    def p as AppPrice init appPriceFor(appDetailsFrom($free, 570));
    testing.assertTrue($p.found);
    testing.assertTrue($p.free);
    testing.assertEqual($p.price, emptyPrice());
}

func testPackageDetailsFrom() {
    def data as json.Value init json.decode('{
        "name": "Portal Bundle",
        "page_image": "https://img.example/pkg.jpg",
        "apps": [{"id": 400, "name": "Portal"}, {"id": 620, "name": "Portal 2"}],
        "price": {
            "currency": "USD",
            "initial": 1998,
            "final": 999,
            "discount_percent": 50
        },
        "platforms": {"windows": true, "mac": false, "linux": true},
        "release_date": {"coming_soon": false, "date": "19 Apr, 2011"}
    }');
    def p as PackageDetails init packageDetailsFrom($data, 1234);
    testing.assertEqual($p.packageId, 1234);
    testing.assertEqual($p.name, "Portal Bundle");
    testing.assertEqual(len($p.apps), 2);
    testing.assertEqual($p.apps[1].name, "Portal 2");
    testing.assertEqual($p.price.discountPercent, 50);
    testing.assertFalse($p.platforms.mac);
    testing.assertEqual($p.releaseDate, "19 Apr, 2011");
}

func testFeaturedListFrom() {
    def body as json.Value init json.decode('{
        "large_capsules": [
            {
                "id": 730,
                "name": "Counter-Strike 2",
                "discounted": false,
                "discount_percent": 0,
                "original_price": 0,
                "final_price": 0,
                "currency": "USD",
                "large_capsule_image": "https://img.example/730_capsule.jpg",
                "header_image": "https://img.example/730_header.jpg",
                "windows_available": true,
                "mac_available": false,
                "linux_available": true
            }
        ]
    }');
    def caps as list of FeaturedApp init featuredListFrom($body, "/large_capsules");
    testing.assertEqual(len($caps), 1);
    testing.assertEqual($caps[0].appId, 730);
    testing.assertEqual($caps[0].name, "Counter-Strike 2");
    testing.assertEqual($caps[0].capsuleImage, "https://img.example/730_capsule.jpg");
    testing.assertEqual($caps[0].headerImage, "https://img.example/730_header.jpg");
    testing.assertTrue($caps[0].linuxAvailable);
    testing.assertFalse($caps[0].macAvailable);
    def none as list of FeaturedApp init [];
    testing.assertEqual(featuredListFrom($body, "/featured_win"), $none);
}

func testMajorUnits() {
    testing.assertEqual(majorUnits(0), 0.0);
    testing.assertEqual(majorUnits(1999), 19.99);
    testing.assertEqual(majorUnits(5), 0.05);
}

func testStoreCallsValidateArguments() {
    testing.assertThrows("detailsForBadApp", "steam");
    testing.assertThrows("pricesForEmptyList", "steam");
    testing.assertThrows("packageWithZeroId", "steam");
}

func detailsForBadApp() {
    appDetails(client(""), 0);
}

func testAppDetailsManyValidatesBeforeAnyRequest() {
    # every id is checked up front, so a bad one in the middle of the list
    # fails locally instead of being swallowed into a silently short result
    testing.assertThrows("detailsManyWithBadId", "steam");
    def none as list of int init [];
    def empty as list of AppDetails init appDetailsMany(client(""), $none);
    testing.assertEqual(len($empty), 0);
}

func detailsManyWithBadId() {
    appDetailsMany(client(""), [620, 0]);
}

func testNoRecordMessageNamesTheCountry() {
    def message as string init noRecordMessage(withCountry(client(""), "DE"), 620);
    testing.assertContains($message, "620");
    testing.assertContains($message, "DE");
    testing.assertContains($message, "delisted");
}

func pricesForEmptyList() {
    def none as list of int init [];
    appPrices(client(""), $none);
}

func packageWithZeroId() {
    packageDetails(client(""), 0);
}
