# Econ - trading and item stores

`IEconService` reads the trade offers of the account that owns the API key.
There is no `steamid` parameter: an offer is private to its two parties, so
the key is the identity.

## Polling

`tradeOffersSummary` returns counts only; poll it, and list offers only
when a count moves:

```jennifer
def s as steam.TradeOffersSummary init steam.tradeOffersSummary($c, 0);
if ($s.pendingReceived > 0) {
    def t as steam.TradeOffers init steam.tradeOffers($c, false, true, true);
    ...
}
```

`timeCutoff` is the Unix time the `new*` and `updated*` counts start from:
the time of your last poll, or 0 for everything.

## Reading offers

```jennifer
def t as steam.TradeOffers init steam.tradeOffers($c, true, true, true);
for (def o in $t.received) {
    io.printf("%s from %s: %s\n", $o.tradeOfferId, $o.otherSteamId,
        steam.tradeOfferStateName($o.state));
    io.printf("  give %d, get %d\n", len($o.toGive), len($o.toReceive));
}
```

`activeOnly` skips settled offers; the full history gets long. At least one
of `getSent` and `getReceived` must be true.

Steam names the other party by 32-bit account id; the deck widens it to an
id64, so `otherSteamId` goes straight into `playerSummary`.

`isPendingOffer` covers active (2) and awaiting confirmation (9).
`isOneSided` is true when one side is empty: a gift or a scam, never a
trade, and worth wiring into an auto-decline rule.

## Items

A `TradeAsset` carries `appId`, `contextId`, `assetId`, `classId` and
`instanceId`: catalogue coordinates, not a name. A name takes a separate
`ISteamEconomy` class lookup, which this deck does not make; trade bots keep
their own class cache. `missing` means the item has left the inventory
since the offer was made, so accepting it fails.

## Item store prices

`assetPrices(c, appId)` reads what a game's own item store charges:

```jennifer
use maps;

def code as string init steam.currencyCode($c.currency);
for (def a in steam.assetPrices($c, 440)) {
    if (maps.has($a.prices, $code)) {
        io.printf("%s|pad=28 %d\n", $a.name, $a.prices[$code]);
    }
}
```

Amounts are ints in minor units keyed by ISO code, and only the codes Valve
priced the item in are present. A missing map key is a runtime error in
Jennifer, so guard the read with `maps.has`. A game without an item store
throws rather than returning an empty list.

## Not offered

Accepting, declining and cancelling offers need Steam's mobile confirmation
flow, not the Web API, so this deck does not offer them.

See [`examples/econ.j`](https://github.com/deckyard/deck-steam/blob/main/examples/econ.j).
