# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the users topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testPlayerSummaryFrom() {
    def node as json.Value init json.decode('{
        "steamid": "76561197960287930",
        "communityvisibilitystate": 3,
        "profilestate": 1,
        "personaname": "Rabscuttle",
        "profileurl": "https://steamcommunity.com/id/rabscuttle/",
        "avatar": "https://avatars.example/a.jpg",
        "avatarmedium": "https://avatars.example/a_medium.jpg",
        "avatarfull": "https://avatars.example/a_full.jpg",
        "avatarhash": "deadbeef",
        "lastlogoff": 1701000000,
        "personastate": 1,
        "realname": "Ada",
        "primaryclanid": "103582791429521412",
        "timecreated": 1063407589,
        "personastateflags": 0,
        "loccountrycode": "AT",
        "locstatecode": "09",
        "loccityid": 1234,
        "gameid": "440",
        "gameextrainfo": "Team Fortress 2",
        "gameserverip": "192.0.2.10:27015",
        "commentpermission": 1
    }');
    def p as PlayerSummary init playerSummaryFrom($node);
    testing.assertEqual($p.steamId, "76561197960287930");
    testing.assertEqual($p.personaName, "Rabscuttle");
    testing.assertEqual($p.avatarFull, "https://avatars.example/a_full.jpg");
    testing.assertEqual($p.avatarHash, "deadbeef");
    testing.assertEqual($p.personaState, PERSONA_ONLINE);
    testing.assertEqual($p.communityVisibilityState, VISIBILITY_PUBLIC);
    testing.assertEqual($p.realName, "Ada");
    testing.assertEqual($p.primaryClanId, "103582791429521412");
    testing.assertEqual($p.timeCreated, 1063407589);
    testing.assertEqual($p.countryCode, "AT");
    testing.assertEqual($p.cityId, 1234);
    testing.assertEqual($p.gameId, "440");
    testing.assertEqual($p.gameExtraInfo, "Team Fortress 2");
    testing.assertEqual($p.gameServerIp, "192.0.2.10:27015");
    testing.assertTrue(isPublic($p));
    testing.assertTrue(isOnline($p));
    testing.assertTrue(isInGame($p));
}

func testPlayerSummaryFromPrivateProfile() {
    def node as json.Value init json.decode('{
        "steamid": "76561197960287930",
        "communityvisibilitystate": 1,
        "personaname": "Private",
        "personastate": 0
    }');
    def p as PlayerSummary init playerSummaryFrom($node);
    testing.assertEqual($p.realName, "");
    testing.assertEqual($p.timeCreated, 0);
    testing.assertEqual($p.gameId, "");
    testing.assertFalse(isPublic($p));
    testing.assertFalse(isOnline($p));
    testing.assertFalse(isInGame($p));
}

func testIsInGameIgnoresZero() {
    def node as json.Value init json.decode('{"steamid": "1", "gameid": "0"}');
    testing.assertFalse(isInGame(playerSummaryFrom($node)));
}

func testFriendFrom() {
    def node as json.Value init json.decode('{
        "steamid": "76561197960265731",
        "relationship": "friend",
        "friend_since": 1234567890
    }');
    def f as Friend init friendFrom($node);
    testing.assertEqual($f.steamId, "76561197960265731");
    testing.assertEqual($f.relationship, RELATIONSHIP_FRIEND);
    testing.assertEqual($f.friendSince, 1234567890);
}

func testPlayerBanFrom() {
    def node as json.Value init json.decode('{
        "SteamId": "76561197960287930",
        "CommunityBanned": false,
        "VACBanned": true,
        "NumberOfVACBans": 2,
        "DaysSinceLastBan": 1337,
        "NumberOfGameBans": 1,
        "EconomyBan": "none"
    }');
    def b as PlayerBan init playerBanFrom($node);
    testing.assertEqual($b.steamId, "76561197960287930");
    testing.assertFalse($b.communityBanned);
    testing.assertTrue($b.vacBanned);
    testing.assertEqual($b.vacBans, 2);
    testing.assertEqual($b.gameBans, 1);
    testing.assertEqual($b.daysSinceLastBan, 1337);
    testing.assertEqual($b.economyBan, "none");
}

func testPersonaStateName() {
    testing.assertEqual(personaStateName(PERSONA_OFFLINE), "offline");
    testing.assertEqual(personaStateName(PERSONA_LOOKING_TO_PLAY), "looking to play");
    testing.assertEqual(personaStateName(42), "unknown");
}

func testVisibilityName() {
    testing.assertEqual(visibilityName(VISIBILITY_PRIVATE), "private");
    testing.assertEqual(visibilityName(VISIBILITY_FRIENDS), "friends only");
    testing.assertEqual(visibilityName(VISIBILITY_PUBLIC), "public");
    testing.assertEqual(visibilityName(0), "unknown");
}

func testVanitySegment() {
    testing.assertEqual(vanitySegment("gabelogannewell"), "gabelogannewell");
    testing.assertEqual(
        vanitySegment("https://steamcommunity.com/id/gabelogannewell/"),
        "gabelogannewell");
    testing.assertEqual(vanitySegment("  steamcommunity.com/id/robin/  "), "robin");
}

func testVanitySegmentDropsQueryAndFragment() {
    testing.assertEqual(vanitySegment("https://steamcommunity.com/id/name?utm=x"), "name");
    testing.assertEqual(vanitySegment("https://steamcommunity.com/id/name#comments"), "name");
    testing.assertEqual(vanitySegment("https://steamcommunity.com/id/name/?utm=x"), "name");
    testing.assertEqual(vanitySegment("name?x=1#y"), "name");
    testing.assertThrows("emptyVanity", "steam");
}

func emptyVanity() {
    vanitySegment("https://steamcommunity.com/id/");
}

func testSummaryBatchIsHundred() {
    testing.assertEqual(SUMMARY_BATCH, 100);
    testing.assertThrows("oversizedSummaryBatch", "steam");
}

func oversizedSummaryBatch() {
    def many as list of string init [];
    for (def i in 0..SUMMARY_BATCH + 1) {
        $many[] = steamId64FromAccountId($i + 1);
    }
    joinSteamIds($many, SUMMARY_BATCH);
}

func testKeylessCallsRefuseEarly() {
    testing.assertThrows("keylessSummaries", "steam");
    testing.assertThrows("keylessFriendList", "steam");
    testing.assertThrows("keylessVanity", "steam");
    testing.assertThrows("keylessGroups", "steam");
}

func keylessSummaries() {
    playerSummaries(client(""), ["76561197960287930"]);
}

func keylessFriendList() {
    friendList(client(""), "76561197960287930");
}

func keylessVanity() {
    resolveVanityUrl(client(""), "gabelogannewell");
}

func keylessGroups() {
    userGroups(client(""), "76561197960287930");
}

func testResolveAccountShortCircuitsOnAnId() {
    testing.assertEqual(resolveAccount(client(""), "STEAM_1:0:11101"), "76561197960287930");
    testing.assertEqual(resolveAccount(client(""), "[U:1:22202]"), "76561197960287930");
}

func testSingleAccountCallsRefuseEarly() {
    testing.assertThrows("keylessPlayerSummary", "steam");
    testing.assertThrows("keylessBan", "steam");
    testing.assertThrows("keylessBans", "steam");
    testing.assertThrows("emptyBanBatch", "steam");
    testing.assertThrows("unparseableBanId", "steam");
}

func keylessPlayerSummary() {
    playerSummary(client(""), "76561197960287930");
}

func keylessBan() {
    playerBan(client(""), "STEAM_1:0:11101");
}

func keylessBans() {
    playerBans(client(""), ["76561197960287930"]);
}

func emptyBanBatch() {
    def none as list of string init [];
    playerBans(client("abc"), $none);
}

func unparseableBanId() {
    playerBan(client("abc"), "not-a-steam-id");
}
