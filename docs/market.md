# Market - Community Market prices

`steamcommunity.com/market/priceoverview/` quotes an item's current price.
No key, and the hardest rate limit Steam has.

```jennifer
def c as steam.Client init steam.withCurrency(steam.client(""), steam.CURRENCY_EUR);
def q as steam.MarketPrice init
    steam.priceOverview($c, 730, "AK-47 | Redline (Field-Tested)");
io.printf("%s (median %s, %d sold today)\n", $q.lowestPrice, $q.medianPrice, $q.volume);
```

## Naming the item

The item is named by its market hash name, the exact string in its market
URL with wear and quality. `"AK-47 | Redline"`,
`"AK-47 | Redline (Field-Tested)"` and
`"StatTrak™ AK-47 | Redline (Field-Tested)"` are three different items.

`marketListingUrl(appId, name)` builds the page URL with the name
percent-encoded; opening it is a quick check that the name is right:

```jennifer
io.printf("%s\n", steam.marketListingUrl(730, "AK-47 | Redline (Field-Tested)"));
# https://steamcommunity.com/market/listings/730/AK-47%20%7C%20Redline%20%28Field-Tested%29
```

## Money as strings

The endpoint returns locale-formatted strings and no numeric amount:

```json
{"success": true, "lowest_price": "0,03€", "volume": "12,345", "median_price": "0,04€"}
```

`MarketPrice` keeps both: `lowestPrice` / `medianPrice` as Steam wrote them,
`lowestCents` / `medianCents` parsed. Show the strings; compute with the
cents.

The parsers are pure and work on any Steam-formatted amount:

```jennifer
steam.parseMoney("$1,234.56");    # 1234.56
steam.parseMoney("1.234,56€");    # 1234.56
steam.parseMoney("0,03€");        # 0.03
steam.parseMoneyCents("0,03€");   # 3
steam.parseCount("12,345");       # 12345
```

The rule, which needs no locale: the last `.` or `,` is the decimal mark
when one or two digits follow it, and a thousands separator otherwise. So
`"12.345"` reads as 12345 and `"12.34"` as 12.34, right in both conventions.
`parseCount` ignores every separator, since a volume has no fraction.
Unreadable text gives 0, and so does an amount above `MAX_MONEY_UNITS`
(1.0e15) in `parseMoneyCents`.

## Rate limits

Roughly twenty requests a minute per address. Past that Steam answers 429
and stays strict for a while. Set the client up before walking more than a
handful of items:

```jennifer
$c = steam.withRetries($c, 4);
$c = steam.withBackoff($c, 3000);
```

Retries honour `Retry-After` up to 30 s each. A few hundred items still
need a slow loop and a cache.

`found` is false when the market has no price for the item. A thinly traded
item can come back with `found` true, a `lowestPrice`, and no volume, which
reads as 0.

See [`examples/market.j`](https://github.com/deckyard/deck-steam/blob/main/examples/market.j).
