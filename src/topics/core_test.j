# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the core topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testClientDefaults() {
    def c as Client init client("  abc  ");
    testing.assertEqual($c.key, "abc");
    testing.assertEqual($c.language, "english");
    testing.assertEqual($c.countryCode, "US");
    testing.assertEqual($c.currency, CURRENCY_USD);
    testing.assertEqual($c.timeoutMs, DEFAULT_TIMEOUT_MS);
    testing.assertEqual($c.retries, DEFAULT_RETRIES);
    testing.assertEqual($c.backoffMs, DEFAULT_BACKOFF_MS);
    testing.assertTrue(hasKey($c));
}

func testKeylessClient() {
    testing.assertFalse(hasKey(client("")));
}

func testBuildersReturnCopies() {
    def c as Client init client("abc");
    def other as Client init withLanguage($c, "German");
    testing.assertEqual($other.language, "german");
    testing.assertEqual($c.language, "english");
    testing.assertEqual(withCountry($c, "de").countryCode, "DE");
    testing.assertEqual(withCurrency($c, CURRENCY_EUR).currency, CURRENCY_EUR);
    testing.assertEqual(withTimeout($c, 500).timeoutMs, 500);
    testing.assertEqual(withRetries($c, 0).retries, 0);
    testing.assertEqual(withBackoff($c, 3000).backoffMs, 3000);
    testing.assertTrue(isVerbose(setVerbose($c, true)));
    testing.assertFalse(isVerbose($c));
}

func testBuildersValidate() {
    testing.assertThrows("blankLanguage", "steam");
    testing.assertThrows("shortCountry", "steam");
    testing.assertThrows("zeroCurrency", "steam");
    testing.assertThrows("negativeTimeout", "steam");
    testing.assertThrows("negativeRetries", "steam");
    testing.assertThrows("negativeBackoff", "steam");
}

func blankLanguage() {
    withLanguage(client(""), "   ");
}

func shortCountry() {
    withCountry(client(""), "DEU");
}

func testWithCountryErrorNamesTheCheckedCode() {
    def threw as bool init false;
    def message as string init "";
    try {
        withCountry(client(""), "  deu  ");
    } catch (e) {
        $threw = true;
        $message = $e.message;
    }
    testing.assertTrue($threw);
    # the trimmed, uppercased form - quoting the raw input would hide the
    # padding in a terminal and read as though "deu" were three letters wide
    testing.assertContains($message, "\"DEU\"");
}

func zeroCurrency() {
    withCurrency(client(""), 0);
}

func negativeTimeout() {
    withTimeout(client(""), -1);
}

func negativeRetries() {
    withRetries(client(""), -1);
}

func negativeBackoff() {
    withBackoff(client(""), -1);
}

func testApiPath() {
    testing.assertEqual(
        apiPath("ISteamUser", "GetPlayerSummaries", 2),
        "/ISteamUser/GetPlayerSummaries/v2/");
    testing.assertEqual(
        apiPath("  ISteamNews  ", "GetNewsForApp", 2),
        "/ISteamNews/GetNewsForApp/v2/");
}

func testApiPathRejectsJunk() {
    testing.assertThrows("emptyService", "steam");
    testing.assertThrows("zeroVersion", "steam");
}

func emptyService() {
    apiPath("", "GetNewsForApp", 2);
}

func zeroVersion() {
    apiPath("ISteamNews", "GetNewsForApp", 0);
}

func testWithKeyAppendsOnlyWhenPresent() {
    def params as map of string to string init {"steamids": "1"};
    testing.assertFalse(maps.has(withKey(client(""), $params), "key"));
    testing.assertEqual(withKey(client("secret"), $params)["key"], "secret");
    testing.assertFalse(maps.has($params, "key"));
}

func testIsSecret() {
    testing.assertTrue(isSecret("key"));
    testing.assertTrue(isSecret("access_token"));
    testing.assertTrue(isSecret("token"));
    testing.assertTrue(isSecret("login_token"));
    testing.assertFalse(isSecret("steamids"));
}

func testRequestLine() {
    testing.assertEqual(
        requestLine("GET", "https://api.steampowered.com/x/", {"key": "secret", "a": "1"}),
        "GET https://api.steampowered.com/x/?key=<redacted>&a=1");
    testing.assertEqual(
        requestLine("GET", "https://store.example/api", {"q": "half life"}),
        "GET https://store.example/api?q=half+life");
    testing.assertEqual(
        requestLine("GET", "https://store.example/api", {}),
        "GET https://store.example/api");
}

func testStatusHint() {
    testing.assertContains(statusHint(401), "not valid");
    testing.assertContains(statusHint(429), "rate limited");
    testing.assertContains(statusHint(418), "unexpected");
}

func testEnsureOkAcceptsTwoHundreds() {
    ensureOk(200, "https://example.invalid");
    ensureOk(204, "https://example.invalid");
    testing.assertThrows("notFoundStatus", "steam");
}

func notFoundStatus() {
    ensureOk(404, "https://example.invalid");
}

func testDecodeBodyRejectsHtml() {
    testing.assertEqual(nodeInt(decodeBody('{"n": 3}', "u"), "/n"), 3);
    testing.assertThrows("decodeHtml", "steam");
}

func decodeHtml() {
    decodeBody("<html>nope</html>", "https://example.invalid");
}

func testEnsureText() {
    testing.assertEqual(ensureText("  hi  ", "thing"), "hi");
    testing.assertThrows("blankText", "steam");
}

func blankText() {
    ensureText("   ", "thing");
}

func testEnsureAppId() {
    testing.assertEqual(ensureAppId(440), 440);
    testing.assertThrows("zeroAppId", "steam");
}

func zeroAppId() {
    ensureAppId(0);
}

func testEnsureCount() {
    testing.assertEqual(ensureCount(3, "news items"), 3);
    testing.assertThrows("zeroCount", "steam");
}

func zeroCount() {
    ensureCount(0, "news items");
}

func testRequireKey() {
    requireKey(client("abc"), "this call");
    testing.assertThrows("keylessCall", "steam");
}

func keylessCall() {
    requireKey(client(""), "this call");
}

func testJoinSteamIds() {
    testing.assertEqual(
        joinSteamIds(["76561197960287930", "[U:1:22202]"], 100),
        "76561197960287930,76561197960287930");
    testing.assertThrows("noSteamIds", "steam");
    testing.assertThrows("tooManySteamIds", "steam");
}

func noSteamIds() {
    def none as list of string init [];
    joinSteamIds($none, 100);
}

func tooManySteamIds() {
    joinSteamIds(["76561197960287930", "76561197960287931"], 1);
}

func testNodeString() {
    def v as json.Value init json.decode('{"s": "x", "i": 7, "f": 1.5, "b": true, "n": null, "l": []}');
    testing.assertEqual(nodeString($v, "/s"), "x");
    testing.assertEqual(nodeString($v, "/i"), "7");
    testing.assertEqual(nodeString($v, "/b"), "true");
    testing.assertEqual(nodeString($v, "/n"), "");
    testing.assertEqual(nodeString($v, "/l"), "");
    testing.assertEqual(nodeString($v, "/missing"), "");
}

func testNodeInt() {
    def v as json.Value init json.decode('{"i": 7, "f": 2.9, "s": "42", "junk": "x", "b": true, "n": null}');
    testing.assertEqual(nodeInt($v, "/i"), 7);
    testing.assertEqual(nodeInt($v, "/f"), 2);
    testing.assertEqual(nodeInt($v, "/s"), 42);
    testing.assertEqual(nodeInt($v, "/junk"), 0);
    testing.assertEqual(nodeInt($v, "/b"), 1);
    testing.assertEqual(nodeInt($v, "/n"), 0);
    testing.assertEqual(nodeInt($v, "/missing"), 0);
}

func testNodeFloat() {
    def v as json.Value init json.decode('{"f": 1.5, "i": 3, "s": "2.25", "junk": "x"}');
    testing.assertEqual(nodeFloat($v, "/f"), 1.5);
    testing.assertEqual(nodeFloat($v, "/i"), 3.0);
    testing.assertEqual(nodeFloat($v, "/s"), 2.25);
    testing.assertEqual(nodeFloat($v, "/junk"), 0.0);
    testing.assertEqual(nodeFloat($v, "/missing"), 0.0);
}

func testNodeBool() {
    def v as json.Value init json.decode('{"t": true, "one": 1, "zero": 0, "yes": "yes", "no": "no"}');
    testing.assertTrue(nodeBool($v, "/t"));
    testing.assertTrue(nodeBool($v, "/one"));
    testing.assertFalse(nodeBool($v, "/zero"));
    testing.assertTrue(nodeBool($v, "/yes"));
    testing.assertFalse(nodeBool($v, "/no"));
    testing.assertFalse(nodeBool($v, "/missing"));
}

func testNodeLengthAndItem() {
    def v as json.Value init json.decode('{"xs": [10, 20, 30], "m": {"a": 1}}');
    testing.assertEqual(nodeLength($v, "/xs"), 3);
    testing.assertEqual(nodeLength($v, "/m"), 0);
    testing.assertEqual(nodeLength($v, "/missing"), 0);
    testing.assertEqual(nodeInt(nodeItem($v, "/xs", 1), ""), 20);
}

func testNodeStringList() {
    def v as json.Value init json.decode('{"tags": ["a", "b"], "ids": [1, 2]}');
    testing.assertEqual(nodeStringList($v, "/tags"), ["a", "b"]);
    testing.assertEqual(nodeStringList($v, "/ids"), ["1", "2"]);
    def none as list of string init [];
    testing.assertEqual(nodeStringList($v, "/missing"), $none);
}

func testNodeFieldList() {
    def v as json.Value init json.decode('{"genres": [{"id": "1", "description": "Action"}, {"description": "Indie"}]}');
    testing.assertEqual(nodeFieldList($v, "/genres", "description"), ["Action", "Indie"]);
}

func testParseHelpers() {
    testing.assertEqual(parseIntOrZero(" 12 "), 12);
    testing.assertEqual(parseIntOrZero("nope"), 0);
    testing.assertEqual(parseFloatOrZero(" 1.5 "), 1.5);
    testing.assertEqual(parseFloatOrZero("nope"), 0.0);
    testing.assertTrue(truthyWord("YES"));
    testing.assertFalse(truthyWord("off"));
    testing.assertEqual(boolToInt(true), 1);
    testing.assertEqual(boolParam(false), "0");
}

# --- adversarial input: a single out-of-range number in a Steam reply must
# --- not abort a whole struct fold

func testNodeIntSurvivesOutOfRangeNumbers() {
    def v as json.Value init json.decode('{"huge": 1e300, "tiny": -1e300, "ok": 5}');
    testing.assertEqual(nodeInt($v, "/huge"), 0);
    testing.assertEqual(nodeInt($v, "/tiny"), 0);
    testing.assertEqual(nodeInt($v, "/ok"), 5);
}

func testNodeIntSurvivesOverlongNumericStrings() {
    def v as json.Value init json.decode('{"s": "99999999999999999999999999999999"}');
    testing.assertEqual(nodeInt($v, "/s"), 0);
}

func testIsApiName() {
    testing.assertTrue(isApiName("ISteamUser"));
    testing.assertTrue(isApiName("GetSDRConfig"));
    testing.assertTrue(isApiName("HTTP2"));
    testing.assertFalse(isApiName(""));
    testing.assertFalse(isApiName("2Fast"));
    testing.assertFalse(isApiName("../../evil"));
    testing.assertFalse(isApiName("Get/News"));
    testing.assertFalse(isApiName("Get News"));
    testing.assertFalse(isApiName("Get_News"));
}

func testApiPathRefusesPathTraversal() {
    # call() takes these from the caller and splices them into the URL path
    testing.assertThrows("traversalInService", "steam");
    testing.assertThrows("traversalInMethod", "steam");
}

func traversalInService() {
    apiPath("../../ISteamNews", "GetNewsForApp", 2);
}

func traversalInMethod() {
    apiPath("ISteamNews", "GetNewsForApp/../..", 2);
}

func testHttpClientCapsTheResponseBody() {
    testing.assertTrue(MAX_RESPONSE_BYTES > 0);
    testing.assertEqual(httpClient(API_BASE, client("")).options.maxBytes, MAX_RESPONSE_BYTES);
}

func testClientFromEnv() {
    def saved as list of string init [
        os.getEnv("STEAM_API_KEY"),
        os.getEnv("STEAM_LANGUAGE"),
        os.getEnv("STEAM_COUNTRY")
    ];
    os.setEnv("STEAM_API_KEY", " envkey ");
    os.setEnv("STEAM_LANGUAGE", "German");
    os.setEnv("STEAM_COUNTRY", "de");
    def set as Client init clientFromEnv();
    os.setEnv("STEAM_LANGUAGE", "  ");
    os.setEnv("STEAM_COUNTRY", "");
    def bare as Client init clientFromEnv();
    os.setEnv("STEAM_API_KEY", $saved[0]);
    os.setEnv("STEAM_LANGUAGE", $saved[1]);
    os.setEnv("STEAM_COUNTRY", $saved[2]);
    testing.assertEqual($set.key, "envkey");
    testing.assertEqual($set.language, "german");
    testing.assertEqual($set.countryCode, "DE");
    # blank variables keep the client() defaults
    testing.assertEqual($bare.language, "english");
    testing.assertEqual($bare.countryCode, "US");
}
