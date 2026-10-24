# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the apps topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func catalogueFixture() {
    def out as list of App init [
        App{appId: 400, name: "Portal"},
        App{appId: 620, name: "Portal 2"},
        App{appId: 440, name: "Team Fortress 2"}
    ];
    return $out;
}

func testFindApps() {
    def hits as list of App init findApps(catalogueFixture(), "portal");
    testing.assertEqual(len($hits), 2);
    testing.assertEqual($hits[0].appId, 400);
    testing.assertEqual($hits[1].appId, 620);
    testing.assertEqual(len(findApps(catalogueFixture(), "PORTAL 2")), 1);
    testing.assertEqual(len(findApps(catalogueFixture(), "nothing here")), 0);
    testing.assertThrows("findWithBlankTerm", "steam");
}

func findWithBlankTerm() {
    findApps(catalogueFixture(), "  ");
}

func testAppById() {
    testing.assertEqual(appById(catalogueFixture(), 440).name, "Team Fortress 2");
    testing.assertEqual(appById(catalogueFixture(), 999).appId, 0);
    testing.assertThrows("appByZeroId", "steam");
}

func appByZeroId() {
    appById(catalogueFixture(), 0);
}

func testGameServerFrom() {
    def node as json.Value init json.decode('{
        "addr": "192.0.2.10:27015",
        "gmsindex": 1,
        "appid": 440,
        "gamedir": "tf",
        "region": 3,
        "secure": true,
        "lan": false,
        "gameport": 27015,
        "specport": 27020
    }');
    def s as GameServer init gameServerFrom($node);
    testing.assertEqual($s.address, "192.0.2.10:27015");
    testing.assertEqual($s.appId, 440);
    testing.assertEqual($s.gameDir, "tf");
    testing.assertEqual($s.region, 3);
    testing.assertEqual($s.gamePort, 27015);
    testing.assertEqual($s.specPort, 27020);
    testing.assertTrue($s.secure);
    testing.assertFalse($s.lan);
}

func testImageUrls() {
    testing.assertEqual(storePageUrl(440), "https://store.steampowered.com/app/440");
    testing.assertEqual(
        headerImageUrl(440),
        "https://cdn.akamai.steamstatic.com/steam/apps/440/header.jpg");
    testing.assertEqual(
        capsuleImageUrl(620),
        "https://cdn.akamai.steamstatic.com/steam/apps/620/capsule_231x87.jpg");
    testing.assertThrows("storeUrlForBadApp", "steam");
}

func storeUrlForBadApp() {
    storePageUrl(0);
}

func testUpToDateCheckValidates() {
    testing.assertThrows("checkNegativeVersion", "steam");
    testing.assertThrows("checkBadApp", "steam");
}

func checkNegativeVersion() {
    upToDateCheck(client(""), 440, -1);
}

func checkBadApp() {
    upToDateCheck(client(""), 0, 1);
}

func testServersAtAddressValidates() {
    testing.assertThrows("serversAtBlankAddress", "steam");
}

func serversAtBlankAddress() {
    serversAtAddress(client(""), "   ");
}

func testAppListPageFrom() {
    def body as json.Value init json.decode('{
        "response": {
            "apps": [
                {"appid": 400, "name": "Portal", "last_modified": 1700000000},
                {"appid": 620, "name": "Portal 2", "last_modified": 1700000001}
            ],
            "have_more_results": true,
            "last_appid": 620
        }
    }');
    def page as AppListPage init appListPageFrom($body);
    testing.assertEqual(len($page.apps), 2);
    testing.assertEqual($page.apps[1].name, "Portal 2");
    testing.assertEqual($page.lastAppId, 620);
    testing.assertTrue($page.haveMore);
}

func testAppListPageFromLastPage() {
    def body as json.Value init json.decode('{"response": {"apps": []}}');
    def page as AppListPage init appListPageFrom($body);
    testing.assertEqual(len($page.apps), 0);
    testing.assertEqual($page.lastAppId, 0);
    testing.assertFalse($page.haveMore);
}

func testAppListNeedsAKeyAndABudget() {
    testing.assertThrows("keylessAppList", "steam");
    testing.assertThrows("appListWithZeroPages", "steam");
    testing.assertThrows("appListPageTooBig", "steam");
    testing.assertThrows("appListPageNegativeCursor", "steam");
}

func keylessAppList() {
    appList(client(""), 1);
}

func appListWithZeroPages() {
    appList(client("k"), 0);
}

func appListPageTooBig() {
    appListPage(client("k"), 0, APPLIST_PAGE_MAX + 1);
}

func appListPageNegativeCursor() {
    appListPage(client("k"), -1, 10);
}
