# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the player topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func libraryFixture() {
    return json.decode('{
        "response": {
            "game_count": 3,
            "games": [
                {
                    "appid": 440,
                    "name": "Team Fortress 2",
                    "playtime_forever": 6000,
                    "playtime_2weeks": 120,
                    "playtime_windows_forever": 4000,
                    "playtime_mac_forever": 0,
                    "playtime_linux_forever": 2000,
                    "playtime_deck_forever": 30,
                    "img_icon_url": "e3f595a92552da3d664ad00277fad2107345f743",
                    "has_community_visible_stats": true,
                    "rtime_last_played": 1700000000
                },
                {"appid": 620, "name": "Portal 2", "playtime_forever": 900},
                {"appid": 730, "name": "Counter-Strike 2", "playtime_forever": 0}
            ]
        }
    }');
}

func testOwnedGamesFrom() {
    def games as list of OwnedGame init ownedGamesFrom(libraryFixture(), "/response/games");
    testing.assertEqual(len($games), 3);
    def tf as OwnedGame init $games[0];
    testing.assertEqual($tf.appId, 440);
    testing.assertEqual($tf.name, "Team Fortress 2");
    testing.assertEqual($tf.playtimeForever, 6000);
    testing.assertEqual($tf.playtimeTwoWeeks, 120);
    testing.assertEqual($tf.playtimeWindows, 4000);
    testing.assertEqual($tf.playtimeLinux, 2000);
    testing.assertEqual($tf.playtimeDeck, 30);
    testing.assertEqual($tf.iconHash, "e3f595a92552da3d664ad00277fad2107345f743");
    testing.assertTrue($tf.hasCommunityVisibleStats);
    testing.assertEqual($tf.lastPlayed, 1700000000);
}

func testOwnedGamesFromFillsAbsentFields() {
    def games as list of OwnedGame init ownedGamesFrom(libraryFixture(), "/response/games");
    def portal as OwnedGame init $games[1];
    testing.assertEqual($portal.playtimeTwoWeeks, 0);
    testing.assertEqual($portal.iconHash, "");
    testing.assertFalse($portal.hasCommunityVisibleStats);
}

func testOwnedGamesFromPrivateLibrary() {
    def empty as json.Value init json.decode('{"response": {}}');
    def none as list of OwnedGame init [];
    testing.assertEqual(ownedGamesFrom($empty, "/response/games"), $none);
}

func testTotalPlaytime() {
    testing.assertEqual(totalPlaytime(ownedGamesFrom(libraryFixture(), "/response/games")), 6900);
}

func testMostPlayed() {
    def games as list of OwnedGame init ownedGamesFrom(libraryFixture(), "/response/games");
    def top as list of OwnedGame init mostPlayed($games, 2);
    testing.assertEqual(len($top), 2);
    testing.assertEqual($top[0].appId, 440);
    testing.assertEqual($top[1].appId, 620);
    testing.assertEqual(len(mostPlayed($games, 99)), 3);
    testing.assertThrows("mostPlayedZero", "steam");
}

func mostPlayedZero() {
    def none as list of OwnedGame init [];
    mostPlayed($none, 0);
}

func testUnplayed() {
    def backlog as list of OwnedGame init unplayed(ownedGamesFrom(
        libraryFixture(),
        "/response/games"));
    testing.assertEqual(len($backlog), 1);
    testing.assertEqual($backlog[0].appId, 730);
}

func testPlaytimeHours() {
    testing.assertEqual(playtimeHours(0), 0.0);
    testing.assertEqual(playtimeHours(60), 1.0);
    testing.assertEqual(playtimeHours(90), 1.5);
    testing.assertEqual(playtimeHours(6000), 100.0);
    testing.assertEqual(playtimeHours(5), 0.1);
}

func testGameIconUrl() {
    testing.assertEqual(
        gameIconUrl(440, "abc"),
        "https://cdn.akamai.steamstatic.com/steamcommunity/public/images/apps/440/abc.jpg");
    testing.assertEqual(gameIconUrl(440, "  "), "");
    testing.assertThrows("iconForBadApp", "steam");
}

func iconForBadApp() {
    gameIconUrl(0, "abc");
}

func testBadgeCollectionFrom() {
    def body as json.Value init json.decode('{
        "response": {
            "badges": [
                {
                    "badgeid": 1,
                    "level": 5,
                    "completion_time": 1500000000,
                    "xp": 500,
                    "scarcity": 1234,
                    "appid": 440,
                    "communityitemid": "99",
                    "border_color": 1
                },
                {"badgeid": 13, "level": 1, "xp": 100, "scarcity": 9}
            ],
            "player_xp": 4200,
            "player_level": 42,
            "player_xp_needed_to_level_up": 300,
            "player_xp_needed_current_level": 4000
        }
    }');
    def col as BadgeCollection init badgeCollectionFrom($body);
    testing.assertEqual($col.playerLevel, 42);
    testing.assertEqual($col.playerXp, 4200);
    testing.assertEqual($col.xpNeededToLevelUp, 300);
    testing.assertEqual($col.xpNeededCurrentLevel, 4000);
    testing.assertEqual(len($col.badges), 2);
    testing.assertEqual($col.badges[0].appId, 440);
    testing.assertEqual($col.badges[0].communityItemId, "99");
    testing.assertEqual($col.badges[0].borderColor, 1);
    testing.assertEqual($col.badges[1].appId, 0);
}

func testKeylessPlayerCallsRefuseEarly() {
    testing.assertThrows("keylessOwnedGames", "steam");
    testing.assertThrows("keylessLevel", "steam");
    testing.assertThrows("keylessBadges", "steam");
}

func keylessOwnedGames() {
    ownedGames(client(""), "76561197960287930", true, true);
}

func keylessLevel() {
    steamLevel(client(""), "76561197960287930");
}

func keylessBadges() {
    badges(client(""), "76561197960287930");
}

func testLibraryCallsRefuseEarly() {
    testing.assertThrows("keylessGameCount", "steam");
    testing.assertThrows("keylessRecentGames", "steam");
    testing.assertThrows("zeroRecentGames", "steam");
    testing.assertThrows("keylessBadgeProgress", "steam");
    testing.assertThrows("zeroBadgeId", "steam");
    testing.assertThrows("keylessLender", "steam");
    testing.assertThrows("zeroLenderAppId", "steam");
}

func keylessGameCount() {
    ownedGameCount(client(""), "76561197960287930");
}

func keylessRecentGames() {
    recentlyPlayedGames(client(""), "76561197960287930", 5);
}

func zeroRecentGames() {
    recentlyPlayedGames(client("abc"), "76561197960287930", 0);
}

func keylessBadgeProgress() {
    badgeProgress(client(""), "76561197960287930", 2);
}

func zeroBadgeId() {
    badgeProgress(client("abc"), "76561197960287930", 0);
}

func keylessLender() {
    sharedGameLender(client(""), "76561197960287930", 440);
}

func zeroLenderAppId() {
    sharedGameLender(client("abc"), "76561197960287930", 0);
}
