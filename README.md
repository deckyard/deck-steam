# @deckyard/steam

[![test](https://github.com/deckyard/deck-steam/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-steam/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-steam/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-steam)](https://github.com/deckyard/deck-steam/releases/latest)

A typed client for Valve's Steam Web API (`ISteamUser`, `IPlayerService`,
`ISteamUserStats`, `ISteamApps`, `ISteamNews`, `ISteamRemoteStorage`,
`IEconService`, `IGameServersService`), the storefront on
`store.steampowered.com` and the Community Market on `steamcommunity.com`,
for [Jennifer](https://jennifer-lang.dev/). Replies come back as structs,
Steam ids are accepted in all three notations, arguments are checked before
any request, and every failure is `Error{kind: "steam"}`.

## Install

```sh
jvc add @deckyard/steam
```

`jvc` vendors `src/` to `vendor/deckyard/steam/`. To vendor by hand, unpack
`src/` from the release archive `deckyard-steam-<version>.tar.gz` there.
Needs Jennifer 0.25.0 or newer and the default `jennifer` binary
(`jennifer-tiny` has no `net`).

## Example

```jennifer
import "@deckyard/steam/" as steam;

def c as steam.Client init steam.clientFromEnv();      # reads STEAM_API_KEY

# needs a key: profiles, libraries, achievements
def id as string init steam.resolveAccount($c, "gabelogannewell");
def p as steam.PlayerSummary init steam.playerSummary($c, $id);
io.printf("%s is %s\n", $p.personaName, steam.personaStateName($p.personaState));
def lib as list of steam.OwnedGame init steam.ownedGames($c, $id, true, true);
for (def g in steam.mostPlayed($lib, 5)) {
    io.printf("%s|pad=40 %f|prec=1 h\n", $g.name, steam.playtimeHours($g.playtimeForever));
}

# keyless: player counts, the storefront, the market, news
io.printf("%d in game\n", steam.currentPlayers($c, 730));
def d as steam.AppDetails init steam.appDetails($c, 620);
def q as steam.MarketPrice init steam.priceOverview($c, 440, "Mann Co. Supply Crate Key");
for (def n in steam.newsForApp($c, 440, 3, 0)) {
    io.printf("%s\n  %s\n", $n.title, steam.summarize(steam.plainText($n.contents), 120));
}

# no request at all
steam.toSteamId2("76561197960287930");    # STEAM_1:0:11101
```

Get a key at <https://steamcommunity.com/dev/apikey>. `STEAM_VERBOSE=1`
prints each request with the key redacted. [`examples/`](examples/) has one
runnable program per topic.

## Documentation

<https://deckyard.github.io/deck-steam/>: a guide per topic and the
[cheatsheet](docs/cheatsheet.md) of every export. Valve's own reference:
[Steam Web API documentation](https://partner.steamgames.com/doc/webapi_overview).

## Disclaimer

Steam, Valve and the Steam logo are trademarks of Valve Corporation. This is
an independent library, not affiliated with, endorsed or supported by Valve.
Valve changes the Web API without notice and has retired endpoints before
(see [apps](docs/apps.md#the-catalogue)). Respect the
[Steam Web API Terms of Use](https://steamcommunity.com/dev/apiterms) and the
rate limits; hammering the Community Market gets an address blocked. Use at
your own risk; no warranty of any kind.

## License

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
