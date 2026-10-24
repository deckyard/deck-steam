# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the stats topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func achievementFixture() {
    def out as list of Achievement init [
        Achievement{apiName: "A", achieved: true, unlockTime: 1, name: "", description: ""},
        Achievement{apiName: "B", achieved: false, unlockTime: 0, name: "", description: ""},
        Achievement{apiName: "C", achieved: true, unlockTime: 2, name: "", description: ""},
        Achievement{apiName: "D", achieved: false, unlockTime: 0, name: "", description: ""}
    ];
    return $out;
}

func testUnlockedCount() {
    testing.assertEqual(unlockedCount(achievementFixture()), 2);
    def none as list of Achievement init [];
    testing.assertEqual(unlockedCount($none), 0);
}

func testCompletionPercent() {
    testing.assertEqual(completionPercent(achievementFixture()), 50.0);
    def none as list of Achievement init [];
    testing.assertEqual(completionPercent($none), 0.0);
}

func testLockedAchievements() {
    def locked as list of Achievement init lockedAchievements(achievementFixture());
    testing.assertEqual(len($locked), 2);
    testing.assertEqual($locked[0].apiName, "B");
    testing.assertEqual($locked[1].apiName, "D");
}

func testRarest() {
    def all as list of AchievementRarity init [
        AchievementRarity{name: "common", percent: 88.5},
        AchievementRarity{name: "rare", percent: 0.4},
        AchievementRarity{name: "middling", percent: 12.0}
    ];
    def top as list of AchievementRarity init rarest($all, 2);
    testing.assertEqual(len($top), 2);
    testing.assertEqual($top[0].name, "rare");
    testing.assertEqual($top[1].name, "middling");
    testing.assertEqual(len(rarest($all, 10)), 3);
    testing.assertThrows("rarestZero", "steam");
}

func rarestZero() {
    def none as list of AchievementRarity init [];
    rarest($none, 0);
}

func testGameSchemaFrom() {
    def body as json.Value init json.decode('{
        "game": {
            "gameName": "Portal 2",
            "gameVersion": "9",
            "availableGameStats": {
                "achievements": [
                    {
                        "name": "ACH_WAKE_UP",
                        "defaultvalue": 0,
                        "displayName": "Wake Up Call",
                        "hidden": 0,
                        "description": "Survive the manual override.",
                        "icon": "https://img.example/a.jpg",
                        "icongray": "https://img.example/a_gray.jpg"
                    },
                    {"name": "ACH_SECRET", "displayName": "Secret", "hidden": 1}
                ],
                "stats": [
                    {"name": "PORTALS_PLACED", "defaultvalue": 0, "displayName": "Portals"},
                    {"name": "STEPS", "defaultvalue": 7}
                ]
            }
        }
    }');
    def schema as GameSchema init gameSchemaFrom($body, 620);
    testing.assertEqual($schema.appId, 620);
    testing.assertEqual($schema.gameName, "Portal 2");
    testing.assertEqual($schema.gameVersion, "9");
    testing.assertEqual(len($schema.achievements), 2);
    testing.assertEqual($schema.achievements[0].displayName, "Wake Up Call");
    testing.assertFalse($schema.achievements[0].hidden);
    testing.assertEqual($schema.achievements[0].iconGray, "https://img.example/a_gray.jpg");
    testing.assertTrue($schema.achievements[1].hidden);
    testing.assertEqual($schema.achievements[1].description, "");
    testing.assertEqual(len($schema.stats), 2);
    testing.assertEqual($schema.stats[0].displayName, "Portals");
    testing.assertEqual($schema.stats[1].defaultValue, 7);
}

func testGameSchemaFromEmptyGame() {
    def body as json.Value init json.decode('{"game": {}}');
    def schema as GameSchema init gameSchemaFrom($body, 999);
    testing.assertEqual($schema.gameName, "");
    testing.assertEqual(len($schema.achievements), 0);
    testing.assertEqual(len($schema.stats), 0);
}

func testStatsRefusal() {
    testing.assertContains(statsRefusal("Profile is not public"), "private");
    testing.assertContains(statsRefusal("Requested app has no stats"), "no achievement stats");
    testing.assertContains(statsRefusal(""), "may not own");
    testing.assertEqual(statsRefusal("Something else entirely"), "Something else entirely");
}

func testKeylessStatsCallsRefuseEarly() {
    testing.assertThrows("keylessAchievements", "steam");
    testing.assertThrows("keylessUserStats", "steam");
    testing.assertThrows("keylessSchema", "steam");
}

func keylessAchievements() {
    playerAchievements(client(""), "76561197960287930", 440);
}

func keylessUserStats() {
    userStats(client(""), "76561197960287930", 440);
}

func keylessSchema() {
    gameSchema(client(""), 440);
}

func testStatsCallsValidateAppId() {
    testing.assertThrows("rarityForBadApp", "steam");
    testing.assertThrows("playersForBadApp", "steam");
}

func rarityForBadApp() {
    globalAchievementRarity(client("k"), 0);
}

func playersForBadApp() {
    currentPlayers(client("k"), -1);
}
