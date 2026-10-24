# News - feeds, and making them readable

`ISteamNews`. No key.

```jennifer
for (def n in steam.newsForApp($c, 440, 5, 0)) {
    io.printf("%s\n  %s\n", $n.title, $n.url);
}
```

`count` is how many items to fetch, newest first; `maxLength` truncates
each body to that many characters, 0 for whole bodies.

A game's feed mixes the developer's announcements with Steam editorial and
third-party outlets. Name the feeds to keep only some:

```jennifer
steam.newsForAppFeeds($c, 440, 5, 0, steam.FEED_ANNOUNCEMENTS);
```

`feeds` is comma-separated. `FEED_ANNOUNCEMENTS`
(`steam_community_announcements`) and `FEED_STEAM` (`steam_updates`) are
the common two; `NewsItem.feedName` gives the name of any other.

## Markup

`NewsItem.contents` is HTML, BBCode, or both in one body:

```
{STEAM_CLAN_LOC_IMAGE}/554111/1adda6.png [b]Australian Hightower[/b] is
back!<br>Fixed <i>everything</i>&nbsp;&amp; more.
```

`plainText` turns it into text:

```jennifer
io.printf("%s\n", steam.plainText($item.contents));
# Australian Hightower is back! Fixed everything & more.
```

In one pass it

- replaces block tags (`<br>`, `<p>`, `[list]`, `[*]`, the `BLOCK_TAGS`
  list) with a space and removes inline ones (`<b>`, `[url]`) entirely;
- drops `{STEAM_CLAN_IMAGE}` and `{STEAM_CLAN_LOC_IMAGE}` embeds with the
  path behind them;
- decodes `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&apos;`, `&nbsp;`,
  `&hellip;`, `&mdash;` and `&ndash;`;
- collapses whitespace.

A bracketed run counts as a tag only when it opens with a tag name (any
letter for HTML, a `BBCODE_TAGS` name for BBCode) and closes within
`MARKUP_SPAN` (512) code points, so prose survives:

```jennifer
steam.plainText("2 < 3 and 4 > 1");     # 2 < 3 and 4 > 1
steam.plainText("[citation needed]");   # [citation needed]
steam.plainText("array[0] is first");   # array[0] is first
```

The cost is linear in the body length, adversarial input included.

`summarize(text, maxChars)` then cuts at a word boundary and appends one
`…`, never exceeding `maxChars`:

```jennifer
io.printf("%s\n", steam.summarize(steam.plainText($item.contents), 160));
```

Both are pure, so they work as well on a Workshop description, which is
BBCode too.

See [`examples/news.j`](https://github.com/deckyard/deck-steam/blob/main/examples/news.j).
