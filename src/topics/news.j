# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the ISteamNews interface, plus markup-to-text for its bodies.
# Spliced into steam.j via include - not a standalone module.

/**
 * The feed name of a game's own Steam announcements.
 */
export def const FEED_ANNOUNCEMENTS as string init "steam_community_announcements";

/**
 * The feed name of Steam's own editorial posts about a game.
 */
export def const FEED_STEAM as string init "steam_updates";

/**
 * Longest run, in code points, `plainText` treats as one tag. It stops an
 * unclosed `<` from scanning to the end of the body; the tag-name check,
 * not this bound, tells markup from prose.
 */
export def const MARKUP_SPAN as int init 512;

/**
 * Tag names that separate words: `plainText` replaces them with a space.
 * Any other tag (bold, italics, a link) is removed without one.
 */
export def const BLOCK_TAGS as list of string init [
    "br",
    "p",
    "div",
    "li",
    "ul",
    "ol",
    "tr",
    "td",
    "th",
    "table",
    "blockquote",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "hr",
    "pre",
    "list",
    "olist",
    "quote",
    "code",
    "*"
];

/**
 * The BBCode tags `plainText` removes. A bracketed word outside this list,
 * such as `[citation needed]`, is kept.
 */
export def const BBCODE_TAGS as list of string init [
    "b",
    "i",
    "u",
    "s",
    "strike",
    "url",
    "img",
    "list",
    "olist",
    "*",
    "quote",
    "code",
    "noparse",
    "h1",
    "h2",
    "h3",
    "hr",
    "spoiler",
    "table",
    "tr",
    "th",
    "td",
    "previewyoutube",
    "dynamiclink",
    "carousel",
    "expand",
    "video",
    "steamwidget",
    "randomboxes"
];

/**
 * The image-host placeholders of community announcements
 * (`{STEAM_CLAN_IMAGE}/path.png`). `plainText` drops each with its path.
 */
export def const CLAN_IMAGE_TOKENS as list of string init [
    '{STEAM_CLAN_LOC_IMAGE}',
    '{STEAM_CLAN_IMAGE}'
];

/**
 * One item of a game's news feed. `contents` is HTML, BBCode or both;
 * `plainText` turns it into text.
 *
 * @field gid {string} the item's globally unique id
 * @field title {string} the headline
 * @field url {string} where the item can be read
 * @field isExternalUrl {bool} whether `url` leaves Steam
 * @field author {string} the poster, "" when Steam gives none
 * @field contents {string} the body, as markup
 * @field feedLabel {string} the human-readable feed name, e.g. "Community Announcements"
 * @field feedName {string} the feed's internal name, e.g. "steam_community_announcements"
 * @field feedType {int} Steam's internal feed type
 * @field date {int} Unix time the item was posted
 * @field appId {int} the game the item belongs to
 */
export def struct NewsItem {
    gid as string,
    title as string,
    url as string,
    isExternalUrl as bool,
    author as string,
    contents as string,
    feedLabel as string,
    feedName as string,
    feedType as int,
    date as int,
    appId as int
};

/**
 * Read a game's most recent news from every feed. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game
 * @param count {int} how many items to fetch
 * @param maxLength {int} truncate each body to this many characters; 0 for
 *        the whole body
 * @return {list of NewsItem} the items, newest first
 * @throws {Error} kind "steam" on a bad app id, a non-positive count, a
 *                 negative length, or a transport failure
 * @example
 *   for (def n in steam.newsForApp($c, 440, 5, 300)) {
 *       io.printf("%s\n  %s\n", $n.title, steam.plainText($n.contents));
 *   }
 */
export func newsForApp(c as Client, appId as int, count as int, maxLength as int) {
    return newsForAppFeeds($c, $appId, $count, $maxLength, "");
}

/**
 * Read a game's most recent news from named feeds only, leaving out Steam
 * editorial and third-party outlets. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game
 * @param count {int} how many items to fetch
 * @param maxLength {int} truncate each body to this many characters; 0 for
 *        the whole body
 * @param feeds {string} comma-separated feed names, "" for every feed
 * @return {list of NewsItem} the items, newest first
 * @throws {Error} kind "steam" on a bad app id, a non-positive count, a
 *                 negative length, or a transport failure
 * @example
 *   steam.newsForAppFeeds($c, 440, 5, 0, steam.FEED_ANNOUNCEMENTS);
 */
export func newsForAppFeeds(
    c as Client,
    appId as int,
    count as int,
    maxLength as int,
    feeds as string) {
    if ($maxLength < 0) {
        raiseError("the maximum body length must not be negative");
    }
    def params as map of string to string init {
        "appid": convert.toString(ensureAppId($appId)),
        "count": convert.toString(ensureCount($count, "news items")),
        "maxlength": convert.toString($maxLength)
    };
    def named as string init strings.trim($feeds);
    if ($named != "") {
        $params["feeds"] = $named;
    }
    def body as json.Value init apiGet($c, "ISteamNews", "GetNewsForApp", 2, $params);
    def out as list of NewsItem init [];
    for (def i in 0..nodeLength($body, "/appnews/newsitems")) {
        $out[] = newsItemFrom(nodeItem($body, "/appnews/newsitems", $i));
    }
    return $out;
}

/**
 * Strip HTML and BBCode markup out of a news body.
 *
 * Removes recognized tags (`BLOCK_TAGS` become a space, others nothing),
 * drops `CLAN_IMAGE_TOKENS` embeds with their path, decodes `&nbsp;`,
 * `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&apos;`, `&hellip;`, `&mdash;`,
 * `&ndash;` and `&amp;`, and collapses whitespace. A bracketed run that
 * never closes, closes more than `MARKUP_SPAN` code points away, or does
 * not open with a tag name is kept, so `2 < 3 and 4 > 1` and
 * `[citation needed]` survive. Linear in the length of the input.
 *
 * @param markup {string} a news body
 * @return {string} the same text with the markup removed
 * @example
 *   steam.plainText("[b]Update[/b]<br>Fixed <i>everything</i>.");
 *   # "Update Fixed everything."
 */
export func plainText(markup as string) {
    def runes as list of string init strings.chars($markup);
    def parts as list of string init [];
    def i as int init 0;
    while ($i < len($runes)) {
        def embed as int init clanImageEnd($runes, $i);
        if ($embed >= 0) {
            $parts[] = " ";
            $i = $embed;
            continue;
        }
        def close as int init markupEnd($runes, $i);
        if ($close < 0) {
            $parts[] = $runes[$i];
            $i = $i + 1;
        } else {
            $parts[] = tagSpacing(sliceRunes($runes, $i + 1, $close));
            $i = $close + 1;
        }
    }
    return collapseSpaces(decodeEntities(strings.join($parts, "")));
}

/**
 * Shorten text to fit a line, breaking on a word boundary. Whitespace runs
 * are collapsed first.
 *
 * @param text {string} the text to shorten
 * @param maxChars {int} the longest result to produce, ellipsis included
 * @return {string} the text, or a prefix of it ending in a single "…"
 * @throws {Error} kind "steam" when `maxChars` is not positive
 * @example
 *   steam.summarize(steam.plainText($item.contents), 72);
 */
export func summarize(text as string, maxChars as int) {
    ensureCount($maxChars, "characters");
    def clean as string init collapseSpaces($text);
    if (len($clean) <= $maxChars) {
        return $clean;
    }
    def cut as string init strings.substring($clean, 0, $maxChars - 1);
    def space as int init lastSpace($cut);
    if ($space > 0) {
        $cut = strings.substring($cut, 0, $space);
    }
    return strings.trimRight($cut) + "…";
}

/**
 * Fold one `GetNewsForApp` row into a struct.
 *
 * @param node {json.Value} one element of the `newsitems` list
 * @return {NewsItem} the folded item
 * @internal
 */
func newsItemFrom(node as json.Value) {
    return NewsItem{
        gid: nodeString($node, "/gid"),
        title: nodeString($node, "/title"),
        url: nodeString($node, "/url"),
        isExternalUrl: nodeBool($node, "/is_external_url"),
        author: nodeString($node, "/author"),
        contents: nodeString($node, "/contents"),
        feedLabel: nodeString($node, "/feedlabel"),
        feedName: nodeString($node, "/feedname"),
        feedType: nodeInt($node, "/feed_type"),
        date: nodeInt($node, "/date"),
        appId: nodeInt($node, "/appid")
    };
}

/**
 * Where the markup starting at one position ends.
 *
 * A `<` or `[` that opens a recognized tag reports the index of its
 * closing bracket; prose, arithmetic or an unclosed bracket reports -1 and
 * is copied through. The name check runs before the scan for the closing
 * bracket, so a loose bracket costs one comparison, not a `MARKUP_SPAN`
 * search.
 *
 * @param runes {list of string} the text, one entry per code point
 * @param at {int} the position to look at
 * @return {int} index of the closing bracket, or -1 when this is not markup
 * @internal
 */
func markupEnd(runes as list of string, at as int) {
    def ch as string init $runes[$at];
    if ($ch != "<" and $ch != "[") {
        return -1;
    }
    if (not opensTagName($runes, $at)) {
        return -1;
    }
    if ($ch == "<") {
        def close as int init closingBracket($runes, $at, ">");
        if ($close >= 0 and isHtmlTag(sliceRunes($runes, $at + 1, $close))) {
            return $close;
        }
        return -1;
    }
    if ($ch == "[") {
        def close as int init closingBracket($runes, $at, "]");
        if ($close >= 0 and isBbcodeTag(sliceRunes($runes, $at + 1, $close))) {
            return $close;
        }
        return -1;
    }
    return -1;
}

/**
 * Find the bracket that closes a tag, within the markup span.
 *
 * @param runes {list of string} the text, one entry per code point
 * @param open {int} index of the opening bracket
 * @param closer {string} the closing bracket to look for
 * @return {int} its index, or -1 when there is none close enough
 * @internal
 */
func closingBracket(runes as list of string, open as int, closer as string) {
    def limit as int init $open + MARKUP_SPAN;
    if ($limit > len($runes)) {
        $limit = len($runes);
    }
    for (def i in ($open + 1)..$limit) {
        if ($runes[$i] == $closer) {
            return $i;
        }
    }
    return -1;
}

/**
 * Join a half-open run of code points back into a string.
 *
 * @param runes {list of string} the text, one entry per code point
 * @param start {int} first index to take
 * @param stop {int} first index to leave out
 * @return {string} the joined run
 * @internal
 */
func sliceRunes(runes as list of string, start as int, stop as int) {
    return strings.join(lists.slice($runes, $start, $stop), "");
}

/**
 * The bare name of a tag, without its slash or attributes.
 *
 * @param inner {string} what stood between the brackets
 * @return {string} the lowercased tag name
 * @internal
 */
func tagName(inner as string) {
    def text as string init strings.lower(strings.trim($inner));
    if (strings.startsWith($text, "/")) {
        $text = strings.substring($text, 1);
    }
    for (def cut in [" ", "=", "/"]) {
        def at as int init strings.indexOf($text, $cut);
        if ($at >= 0) {
            $text = strings.substring($text, 0, $at);
        }
    }
    return strings.trim($text);
}

/**
 * What a removed tag leaves behind.
 *
 * A block tag becomes a space; an inline one disappears, so `a<b>b</b>c`
 * stays one word.
 *
 * @param inner {string} what stood between the brackets
 * @return {string} " " for a block tag, "" for an inline one
 * @internal
 */
func tagSpacing(inner as string) {
    if (lists.contains(BLOCK_TAGS, tagName($inner))) {
        return " ";
    }
    return "";
}

/**
 * Whether an angle-bracketed run is an HTML tag rather than prose.
 *
 * A tag opens with a name, optionally behind a slash; a `<` followed by a
 * digit, a space or punctuation is prose.
 *
 * @param inner {string} what stood between the angle brackets
 * @return {bool} true when the run opens with a tag name
 * @internal
 */
func isHtmlTag(inner as string) {
    def text as string init strings.trim($inner);
    if (strings.startsWith($text, "/")) {
        $text = strings.substring($text, 1);
    }
    if ($text == "") {
        return false;
    }
    def head as string init strings.lower(strings.substring($text, 0, 1));
    if ($head < "a" or $head > "z") {
        return false;
    }
    return tagName($inner) != "";
}

/**
 * Whether a bracketed run is BBCode rather than prose.
 *
 * @param inner {string} what stood between the square brackets
 * @return {bool} true when the name is one Steam's BBCode defines
 * @internal
 */
func isBbcodeTag(inner as string) {
    return lists.contains(BBCODE_TAGS, tagName($inner));
}

/**
 * Decode the HTML entities Steam emits. `&amp;` is undone last, so
 * `&amp;lt;` becomes the text `&lt;`, not `<`.
 *
 * @param text {string} text that may hold entities
 * @return {string} the decoded text
 * @internal
 */
func decodeEntities(text as string) {
    def out as string init $text;
    $out = strings.replace($out, "&nbsp;", " ");
    $out = strings.replace($out, "&lt;", "<");
    $out = strings.replace($out, "&gt;", ">");
    $out = strings.replace($out, "&quot;", "\"");
    $out = strings.replace($out, "&#39;", "'");
    $out = strings.replace($out, "&apos;", "'");
    $out = strings.replace($out, "&hellip;", "…");
    $out = strings.replace($out, "&mdash;", "—");
    $out = strings.replace($out, "&ndash;", "–");
    return strings.replace($out, "&amp;", "&");
}

/**
 * Whether a bracket at this position could open a tag name.
 *
 * A tag opens with a letter, optionally behind a slash, or with `*`
 * (BBCode's list item). Settling this in O(1) saves scanning ahead for a
 * closing bracket.
 *
 * @param runes {list of string} the text, one entry per code point
 * @param at {int} index of the opening bracket
 * @return {bool} true when a tag name could start here
 * @internal
 */
func opensTagName(runes as list of string, at as int) {
    def next as int init $at + 1;
    if ($next >= len($runes)) {
        return false;
    }
    def ch as string init $runes[$next];
    if ($ch == "/") {
        $next = $next + 1;
        if ($next >= len($runes)) {
            return false;
        }
        $ch = $runes[$next];
    }
    if ($ch == "*") {
        return true;
    }
    return ($ch >= "a" and $ch <= "z") or ($ch >= "A" and $ch <= "Z");
}

/**
 * Where a Steam clan-image embed and the path behind it end.
 *
 * Handled inside `plainText`'s single pass: a separate sweep would search
 * the body once per marker, quadratic in the number of images.
 *
 * @param runes {list of string} the text, one entry per code point
 * @param at {int} the position to look at
 * @return {int} the index just past the embed, or -1 when there is none here
 * @internal
 */
func clanImageEnd(runes as list of string, at as int) {
    if ($runes[$at] != "\{") {
        return -1;
    }
    for (def token in CLAN_IMAGE_TOKENS) {
        def stop as int init $at + len($token);
        if ($stop <= len($runes) and sliceRunes($runes, $at, $stop) == $token) {
            def past as int init $stop;
            while ($past < len($runes) and not isSpace($runes[$past])) {
                $past = $past + 1;
            }
            return $past;
        }
    }
    return -1;
}

/**
 * Collapse every run of whitespace into one space and trim the ends.
 *
 * @param text {string} the text to tidy
 * @return {string} the tidied text
 * @internal
 */
func collapseSpaces(text as string) {
    def parts as list of string init [];
    def blank as bool init true;
    for (def ch in strings.chars($text)) {
        if (isSpace($ch)) {
            if (not $blank) {
                $parts[] = " ";
                $blank = true;
            }
        } else {
            $parts[] = $ch;
            $blank = false;
        }
    }
    return strings.trim(strings.join($parts, ""));
}

/**
 * Whether one code point is whitespace.
 *
 * @param ch {string} a single code point
 * @return {bool} true for space, tab, newline, and carriage return
 * @internal
 */
func isSpace(ch as string) {
    return $ch == " " or $ch == "\t" or $ch == "\n" or $ch == "\r";
}

/**
 * Index of the last space in a string.
 *
 * @param text {string} the text to scan
 * @return {int} the index, or -1 when there is no space
 * @internal
 */
func lastSpace(text as string) {
    def runes as list of string init strings.chars($text);
    def found as int init -1;
    for (def i in 0..len($runes)) {
        if ($runes[$i] == " ") {
            $found = $i;
        }
    }
    return $found;
}
