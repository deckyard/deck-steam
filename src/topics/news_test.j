# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the news topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testNewsItemFrom() {
    def node as json.Value init json.decode('{
        "gid": "5124094402190815898",
        "title": "Scream Fortress has returned!",
        "url": "https://steamstore-a.akamaihd.net/news/externalpost/tf2_blog/1",
        "is_external_url": true,
        "author": "Valve",
        "contents": "The <b>update</b> is live.",
        "feedlabel": "Community Announcements",
        "date": 1698000000,
        "feedname": "steam_community_announcements",
        "feed_type": 1,
        "appid": 440
    }');
    def n as NewsItem init newsItemFrom($node);
    testing.assertEqual($n.gid, "5124094402190815898");
    testing.assertEqual($n.title, "Scream Fortress has returned!");
    testing.assertTrue($n.isExternalUrl);
    testing.assertEqual($n.author, "Valve");
    testing.assertEqual($n.feedLabel, "Community Announcements");
    testing.assertEqual($n.feedName, FEED_ANNOUNCEMENTS);
    testing.assertEqual($n.feedType, 1);
    testing.assertEqual($n.date, 1698000000);
    testing.assertEqual($n.appId, 440);
}

func testPlainTextStripsHtml() {
    testing.assertEqual(plainText("<p>Hello <b>world</b>.</p>"), "Hello world.");
    testing.assertEqual(plainText("one<br>two"), "one two");
    testing.assertEqual(plainText("a<b>b</b>c"), "abc");
}

func testPlainTextStripsBbcode() {
    testing.assertEqual(plainText("[b]Update[/b][hr][/hr]Fixed it."), "Update Fixed it.");
    testing.assertEqual(plainText("[url=https://example.org]link[/url]"), "link");
    testing.assertEqual(plainText("[list][*]one[*]two[/list]"), "one two");
}

func testPlainTextKeepsProse() {
    testing.assertEqual(plainText("[citation needed]"), "[citation needed]");
    testing.assertEqual(plainText("if a < b then"), "if a < b then");
    testing.assertEqual(plainText("array[0] is first"), "array[0] is first");
}

func testPlainTextKeepsArithmetic() {
    testing.assertEqual(plainText("2 < 3 and 4 > 1"), "2 < 3 and 4 > 1");
    testing.assertEqual(plainText("x<3>y"), "x<3>y");
    testing.assertEqual(plainText("unclosed <tag"), "unclosed <tag");
}

func testIsHtmlTag() {
    testing.assertTrue(isHtmlTag("br"));
    testing.assertTrue(isHtmlTag("/p"));
    testing.assertTrue(isHtmlTag('a href="x"'));
    testing.assertFalse(isHtmlTag(" 3 and 4 "));
    testing.assertFalse(isHtmlTag(""));
    testing.assertFalse(isHtmlTag("/"));
    testing.assertFalse(isHtmlTag("-- comment --"));
}

func testPlainTextDecodesEntities() {
    testing.assertEqual(plainText("Tom &amp; Jerry"), "Tom & Jerry");
    testing.assertEqual(plainText("&quot;quoted&quot;"), "\"quoted\"");
    testing.assertEqual(plainText("a&nbsp;b"), "a b");
    testing.assertEqual(plainText("&amp;lt; stays"), "&lt; stays");
}

func testPlainTextStripsClanImages() {
    testing.assertEqual(
        plainText('{STEAM_CLAN_LOC_IMAGE}/554111/1adda6.png Australian Hightower is back!'),
        "Australian Hightower is back!");
    testing.assertEqual(plainText('before {STEAM_CLAN_IMAGE}/1/a.png after'), "before after");
    testing.assertEqual(plainText('trailing {STEAM_CLAN_IMAGE}/1/a.png'), "trailing");
}

func testPlainTextLeavesOtherBracesAlone() {
    testing.assertEqual(plainText('{OTHER}/1/a.png'), '{OTHER}/1/a.png');
    testing.assertEqual(plainText('a {x} b'), 'a {x} b');
}

func testPlainTextStripsRepeatedClanImages() {
    testing.assertEqual(
        plainText('{STEAM_CLAN_IMAGE}/a.png one {STEAM_CLAN_LOC_IMAGE}/b.png two'),
        "one two");
}

func testClanImageEnd() {
    # the marker is 18 runes, the path that follows is 8 more
    testing.assertEqual(clanImageEnd(strings.chars('{STEAM_CLAN_IMAGE}/1/a.png x'), 0), 26);
    testing.assertEqual(clanImageEnd(strings.chars('{STEAM_CLAN_IMAGE}/1/a.png'), 0), 26);
    testing.assertEqual(clanImageEnd(strings.chars('{OTHER}/1/a.png'), 0), -1);
    testing.assertEqual(clanImageEnd(strings.chars("no brace here"), 0), -1);
}

func testOpensTagName() {
    testing.assertTrue(opensTagName(strings.chars("<b>"), 0));
    testing.assertTrue(opensTagName(strings.chars("</p>"), 0));
    testing.assertTrue(opensTagName(strings.chars("[*]"), 0));
    testing.assertTrue(opensTagName(strings.chars("[/url]"), 0));
    # these are what make the scan O(1) instead of MARKUP_SPAN wide
    testing.assertFalse(opensTagName(strings.chars("[["), 0));
    testing.assertFalse(opensTagName(strings.chars("<3"), 0));
    testing.assertFalse(opensTagName(strings.chars("< b>"), 0));
    testing.assertFalse(opensTagName(strings.chars("<"), 0));
    testing.assertFalse(opensTagName(strings.chars("</"), 0));
}

func testPlainTextKeepsBracketFollowedBySpace() {
    # tightened with the O(1) precheck: "< b>" is prose, not a tag
    testing.assertEqual(plainText("a < b> c"), "a < b> c");
}

func testPlainTextHandlesLongImageTags() {
    def markup as string init "<img src=\"https://cdn.example/steam/news/280478/" +
        "highjinx26_small.png?t=1506190994\">Australian Hightower is back!";
    testing.assertEqual(plainText($markup), "Australian Hightower is back!");
}

func testPlainTextCollapsesWhitespace() {
    testing.assertEqual(plainText("  lots\n\n of\t\tspace  "), "lots of space");
    testing.assertEqual(plainText(""), "");
}

func testTagName() {
    testing.assertEqual(tagName("br"), "br");
    testing.assertEqual(tagName("/P"), "p");
    testing.assertEqual(tagName("br /"), "br");
    testing.assertEqual(tagName('a href="x"'), "a");
    testing.assertEqual(tagName("url=https://example.org"), "url");
}

func testTagSpacing() {
    testing.assertEqual(tagSpacing("br"), " ");
    testing.assertEqual(tagSpacing("/p"), " ");
    testing.assertEqual(tagSpacing("b"), "");
    testing.assertEqual(tagSpacing("span"), "");
}

func testIsBbcodeTag() {
    testing.assertTrue(isBbcodeTag("b"));
    testing.assertTrue(isBbcodeTag("/url"));
    testing.assertTrue(isBbcodeTag("url=https://example.org"));
    testing.assertFalse(isBbcodeTag("citation needed"));
    testing.assertFalse(isBbcodeTag("0"));
}

func testCollapseSpaces() {
    testing.assertEqual(collapseSpaces("  a \n b  "), "a b");
    testing.assertEqual(collapseSpaces("   "), "");
}

func testLastSpace() {
    testing.assertEqual(lastSpace("a b c"), 3);
    testing.assertEqual(lastSpace("abc"), -1);
}

func testSummarize() {
    testing.assertEqual(summarize("short enough", 40), "short enough");
    testing.assertEqual(summarize("one two three four", 12), "one two…");
    testing.assertEqual(summarize("  spaced   out  ", 40), "spaced out");
    testing.assertThrows("summarizeZero", "steam");
}

func summarizeZero() {
    summarize("text", 0);
}

func testSummarizeNeverExceedsBudget() {
    def long as string init "a long line of words that will certainly need trimming";
    for (def limit in [5, 10, 20, 30]) {
        testing.assertTrue(len(summarize($long, $limit)) <= $limit);
    }
}

func testNewsValidatesArguments() {
    testing.assertThrows("newsForBadApp", "steam");
    testing.assertThrows("newsWithZeroCount", "steam");
    testing.assertThrows("newsWithNegativeLength", "steam");
}

func newsForBadApp() {
    newsForApp(client(""), 0, 5, 300);
}

func newsWithZeroCount() {
    newsForApp(client(""), 440, 0, 300);
}

func newsWithNegativeLength() {
    newsForApp(client(""), 440, 5, -1);
}

func testNewsForAppFeedsValidates() {
    testing.assertThrows("negativeNewsLength", "steam");
    testing.assertThrows("zeroNewsAppId", "steam");
    testing.assertThrows("zeroNewsCount", "steam");
}

func negativeNewsLength() {
    newsForAppFeeds(client(""), 440, 5, -1, FEED_ANNOUNCEMENTS);
}

func zeroNewsAppId() {
    newsForAppFeeds(client(""), 0, 5, 0, "");
}

func zeroNewsCount() {
    newsForAppFeeds(client(""), 440, 0, 0, FEED_ANNOUNCEMENTS);
}
