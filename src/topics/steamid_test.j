# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the steamid topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

# 76561197960287930 is the documented example account (account id 22202).

func testParseSteamId() {
    def p as SteamId init parseSteamId("76561197960287930");
    testing.assertEqual($p.id64, "76561197960287930");
    testing.assertEqual($p.universe, UNIVERSE_PUBLIC);
    testing.assertEqual($p.accountType, ACCOUNT_INDIVIDUAL);
    testing.assertEqual($p.instance, 1);
    testing.assertEqual($p.accountId, 22202);
}

func testParseSteamIdRejectsJunk() {
    testing.assertThrows("parseShortId", "steam");
    testing.assertThrows("parseLetters", "steam");
}

func parseShortId() {
    parseSteamId("7656119796028793");
}

func parseLetters() {
    parseSteamId("7656119796028793x");
}

func testToSteamId64RoundTrips() {
    def p as SteamId init parseSteamId("76561197960287930");
    testing.assertEqual(toSteamId64($p), "76561197960287930");
}

func testToSteamId64Validates() {
    testing.assertThrows("badUniverse", "steam");
    testing.assertThrows("badAccountId", "steam");
}

func badUniverse() {
    toSteamId64(SteamId{id64: "", universe: 256, accountType: 1, instance: 1, accountId: 1});
}

func badAccountId() {
    toSteamId64(SteamId{id64: "", universe: 1, accountType: 1, instance: 1, accountId: -1});
}

func testIsSteamId() {
    testing.assertTrue(isSteamId("76561197960287930"));
    testing.assertTrue(isSteamId("  76561197960287930  "));
    testing.assertTrue(isSteamId("103582791429521412"));
    testing.assertFalse(isSteamId("123"));
    testing.assertFalse(isSteamId("7656119796028793a"));
    testing.assertFalse(isSteamId(""));
}

func testIsSteamIdRejectsOutOfRangeNumbers() {
    # 20 digits: parses past int64, so the number never materializes
    testing.assertFalse(isSteamId("99999999999999999999"));
    # 17 zeros: the right shape, but not an id
    testing.assertFalse(isSteamId("00000000000000000"));
    # universe 0 - below the lowest universe Steam issues
    testing.assertFalse(isSteamId("10000000000000000"));
    # universe 6 - above the highest
    testing.assertFalse(isSteamId("500000000000000000"));
}

func testIsSteamId64IsIndividualOnly() {
    testing.assertTrue(isSteamId64("76561197960287930"));
    testing.assertFalse(isSteamId64("103582791429521412"));
    testing.assertFalse(isSteamId64("nope"));
}

func testAccountIdAndBack() {
    testing.assertEqual(accountId("76561197960287930"), 22202);
    testing.assertEqual(steamId64FromAccountId(22202), "76561197960287930");
    testing.assertEqual(INDIVIDUAL_BASE + 22202, 76561197960287930);
}

func testSteamId64FromAccountIdValidates() {
    testing.assertThrows("zeroAccountId", "steam");
}

func zeroAccountId() {
    steamId64FromAccountId(0);
}

func testToSteamId2() {
    testing.assertEqual(toSteamId2("76561197960287930"), "STEAM_1:0:11101");
    testing.assertEqual(toSteamId2("76561197960287931"), "STEAM_1:1:11101");
}

func testToSteamId2RefusesGroups() {
    testing.assertThrows("groupToSteamId2", "steam");
}

func groupToSteamId2() {
    toSteamId2("103582791429521412");
}

func testToSteamId3() {
    testing.assertEqual(toSteamId3("76561197960287930"), "[U:1:22202]");
    testing.assertEqual(toSteamId3("103582791429521412"), "[g:1:4]");
}

func testFromSteamId2() {
    testing.assertEqual(fromSteamId2("STEAM_1:0:11101"), "76561197960287930");
    testing.assertEqual(fromSteamId2("STEAM_0:0:11101"), "76561197960287930");
    testing.assertEqual(fromSteamId2("  steam_1:1:11101  "), "76561197960287931");
}

func testFromSteamId2RejectsJunk() {
    testing.assertThrows("notSteamTwo", "steam");
    testing.assertThrows("badParity", "steam");
    testing.assertThrows("shortSteamTwo", "steam");
}

func notSteamTwo() {
    fromSteamId2("[U:1:22202]");
}

func badParity() {
    fromSteamId2("STEAM_1:2:11101");
}

func testFromSteamId2RejectsNonNumericFields() {
    testing.assertThrows("letterUniverse", "steam");
    testing.assertThrows("letterAccountHalf", "steam");
}

func letterUniverse() {
    fromSteamId2("STEAM_x:0:11101");
}

func letterAccountHalf() {
    fromSteamId2("STEAM_1:0:abc");
}

func shortSteamTwo() {
    fromSteamId2("STEAM_1:0");
}

func testFromSteamId3() {
    testing.assertEqual(fromSteamId3("[U:1:22202]"), "76561197960287930");
    testing.assertEqual(fromSteamId3("U:1:22202"), "76561197960287930");
    testing.assertEqual(fromSteamId3("[U:1:22202:1]"), "76561197960287930");
    testing.assertEqual(fromSteamId3("[g:1:4]"), "103582791429521412");
}

func testFromSteamId3RejectsJunk() {
    testing.assertThrows("unknownLetter", "steam");
    testing.assertThrows("shortSteamThree", "steam");
}

func unknownLetter() {
    fromSteamId3("[Z:1:22202]");
}

func shortSteamThree() {
    fromSteamId3("[U:1]");
}

func testNormalizeSteamIdAcceptsEveryNotation() {
    testing.assertEqual(normalizeSteamId("76561197960287930"), "76561197960287930");
    testing.assertEqual(normalizeSteamId("STEAM_1:0:11101"), "76561197960287930");
    testing.assertEqual(normalizeSteamId("[U:1:22202]"), "76561197960287930");
}

func testNormalizeSteamIdRejectsJunk() {
    testing.assertThrows("normalizeEmpty", "steam");
    testing.assertThrows("normalizeVanity", "steam");
}

func normalizeEmpty() {
    normalizeSteamId("   ");
}

func normalizeVanity() {
    normalizeSteamId("gabelogannewell");
}

func testLooksLikeSteamId() {
    testing.assertTrue(looksLikeSteamId("STEAM_1:0:11101"));
    testing.assertTrue(looksLikeSteamId("[U:1:22202]"));
    testing.assertTrue(looksLikeSteamId("76561197960287930"));
    testing.assertFalse(looksLikeSteamId("gabelogannewell"));
}

func testProfileUrls() {
    testing.assertEqual(
        profileUrl("STEAM_1:0:11101"),
        "https://steamcommunity.com/profiles/76561197960287930");
    testing.assertEqual(
        vanityProfileUrl(" gabelogannewell "),
        "https://steamcommunity.com/id/gabelogannewell");
    testing.assertEqual(
        groupUrl("103582791429521412"),
        "https://steamcommunity.com/gid/103582791429521412");
}

func testAccountTypeName() {
    testing.assertEqual(accountTypeName(ACCOUNT_INDIVIDUAL), "individual");
    testing.assertEqual(accountTypeName(ACCOUNT_CLAN), "group");
    testing.assertEqual(accountTypeName(99), "unknown");
}

func testIsDigits() {
    testing.assertTrue(isDigits("0123456789"));
    testing.assertFalse(isDigits(""));
    testing.assertFalse(isDigits("12 3"));
    testing.assertFalse(isDigits("-1"));
}

func testTypeLetterRoundTrip() {
    for (def kind in [0, 1, 2, 3, 4, 5, 6, 7, 8, 10]) {
        testing.assertEqual(letterType(typeLetter($kind), "x"), $kind);
    }
}

func testChatLettersAllMapToChat() {
    # typeLetter only ever emits "T", so the round-trip test above never
    # feeds "L" (lobby) or "c" (clan chat) back in - these do
    for (def letter in ["T", "L", "c"]) {
        testing.assertEqual(letterType($letter, "x"), ACCOUNT_CHAT);
    }
    testing.assertEqual(typeLetter(ACCOUNT_CHAT), "T");
    testing.assertEqual(fromSteamId3("[L:1:4]"), fromSteamId3("[T:1:4]"));
}

func testDefaultInstance() {
    testing.assertEqual(defaultInstance(ACCOUNT_INDIVIDUAL), 1);
    testing.assertEqual(defaultInstance(ACCOUNT_CLAN), 0);
}

# --- adversarial input: none of these may reach an uncaught [runtime] error,
# --- and none may return a plausible-looking but wrong id

func testHostileFieldsAllRaiseSteamErrors() {
    for (def name in [
        "universeOverflowsShift",
        "universeTooLarge",
        "halfDoublesPastRange",
        "halfTooLarge",
        "accountTooLarge",
        "typeTooLarge"
    ]) {
        testing.assertThrows($name, "steam");
    }
}

func universeOverflowsShift() {
    # 200 fits the 8-bit field but 200 << 56 wraps to a negative id
    normalizeSteamId("[U:200:1]");
}

func universeTooLarge() {
    normalizeSteamId("[U:99999999999999999999:1]");
}

func halfDoublesPastRange() {
    normalizeSteamId("STEAM_1:0:5000000000000000000");
}

func halfTooLarge() {
    normalizeSteamId("STEAM_1:0:99999999999999999999");
}

func accountTooLarge() {
    normalizeSteamId("[U:1:99999999999999999999]");
}

func typeTooLarge() {
    toSteamId64(SteamId{id64: "", universe: 1, accountType: 11, instance: 1, accountId: 1});
}

func testToSteamId64BoundsTheRealDomainNotTheBitWidth() {
    # universe 6 and account type 11 both fit their bit-fields but are not
    # values Steam issues - accepting them produced corrupt ids
    testing.assertThrows("universeSix", "steam");
    testing.assertEqual(UNIVERSE_MAX, 5);
    for (def universe in [1, 2, 3, 4, 5]) {
        def built as string init toSteamId64(SteamId{
            id64: "",
            universe: $universe,
            accountType: ACCOUNT_INDIVIDUAL,
            instance: 1,
            accountId: 22202
        });
        # anything this builds must survive the round trip
        testing.assertTrue(isSteamId($built));
        testing.assertEqual(parseSteamId($built).universe, $universe);
    }
}

func universeSix() {
    toSteamId64(SteamId{id64: "", universe: 6, accountType: 1, instance: 1, accountId: 1});
}

func testLooksLikeSteamIdStaysFalseForHostileInput() {
    for (def bad in [
        "[U:200:1]",
        "STEAM_1:0:99999999999999999999",
        "[U:1:99999999999999999999]",
        "[U:99999999999999999999:1]"
    ]) {
        testing.assertFalse(looksLikeSteamId($bad));
    }
}

func testVanityProfileUrlEncodesThePath() {
    testing.assertEqual(
        vanityProfileUrl("../../evil"),
        "https://steamcommunity.com/id/..%2F..%2Fevil");
    testing.assertEqual(vanityProfileUrl("a b"), "https://steamcommunity.com/id/a%20b");
}
