# Store - the storefront

`store.steampowered.com/api/...` is the storefront's own JSON, not part of
the Web API: undocumented by Valve, keyless and regional. It is the only
source of prices, descriptions and release dates.

```jennifer
def d as steam.AppDetails init steam.appDetails($c, 620);
io.printf("%s (%s) - %s\n", $d.name, $d.releaseDate, $d.price.finalFormatted);
io.printf("%s\n", steam.plainText($d.shortDescription));
```

## One id per request

The storefront takes exactly one `appids` value. A comma-separated list is
answered with 400, and the documented `filter=price_overview` is ignored.
`appPrices` and `appDetailsMany` therefore make one request per id:

- `appPrices` returns one `AppPrice` per id, with `found` false for an id
  the storefront has no record of (delisted or region-locked);
- `appDetailsMany` leaves such ids out.

Both validate every id before the first request, and a transport failure
throws, so a `found` false entry or a short list never means the network
failed halfway.

```jennifer
for (def p in steam.appPrices($c, [620, 440, 730, 400])) {
    if (not $p.found) {
        io.printf("%d|pad=7  (delisted or region-locked)\n", $p.appId);
    } elseif ($p.free) {
        io.printf("%d|pad=7  free to play\n", $p.appId);
    } else {
        io.printf("%d|pad=7  %s %s\n", $p.appId,
            $p.price.finalFormatted, steam.discountLabel($p.price));
    }
}
```

That is four requests, each a full record of about 30 KB over its own TLS
connection. Spread a large wishlist over time.

## Regions

`withCountry` decides currency, availability and age rating. The same app
from a client pinned to `"DE"` is priced in euros; from `"JP"` it may have
another rating or no record, which `appDetails` reports:

```
the storefront has no record of app 12345 in country DE - it may be
delisted, region-locked, or not an app at all
```

## Money

Prices are ints in minor units (cents, pence), safe to compare and sum:

```jennifer
steam.isDiscounted($d.price);      # true when final is below initial
steam.savings($d.price);           # 660 (minor units)
steam.discountLabel($d.price);     # "-66%"
steam.majorUnits($d.price.final);  # 3.39
```

`finalFormatted` is Steam's rendering for the country, symbol included; show
that. `initialFormatted` is empty at full price. `majorUnits` divides by 100
for every currency, yen included, because Steam reports yen in hundredths
too.

A free or unreleased title has a zeroed `Price`: check `isFree` and
`comingSoon` first.

## HTML

`shortDescription`, `aboutTheGame` and `supportedLanguages` are HTML, as
Steam sent them. [`plainText`](news.md#markup) turns them into text.

## Packages and the front page

`packageDetails(c, packageId)` reads a package: name, price and the `App`s
in it.

`featured(c)` returns the front page's four lists: `largeCapsules`,
`windows`, `mac`, `linux`. `largeCapsules` is often empty outside a sale,
so fall back to a platform list.

See [`examples/store.j`](https://github.com/deckyard/deck-steam/blob/main/examples/store.j).
