# steam

`@deckyard/steam` is a typed client for Valve's Steam Web API, the
storefront and the Community Market. One guide per topic; every export,
value and field is in the [cheatsheet](cheatsheet.md). Each topic has a
runnable program in
[`examples/`](https://github.com/deckyard/deck-steam/tree/main/examples).

This deck is part of [Deckyard](https://github.com/deckyard), community decks for [Jennifer](https://jennifer-lang.dev/).

| Guide | Covers |
| ----- | ------ |
| [core.md](core.md) | the `Client`, keys, verbose mode, errors, calling any method |
| [steamid.md](steamid.md) | the three Steam id notations and converting between them |
| [users.md](users.md) | profiles, friends, bans, groups, vanity names |
| [player.md](player.md) | game libraries, playtime, level, badges, Family Sharing |
| [stats.md](stats.md) | achievements, statistics, rarity, live player counts |
| [apps.md](apps.md) | the app catalogue, version checks, servers, image URLs |
| [news.md](news.md) | news feeds, and HTML/BBCode bodies as plain text |
| [store.md](store.md) | storefront records, regional prices, packages, the front page |
| [market.md](market.md) | Community Market prices and locale-formatted money |
| [workshop.md](workshop.md) | Workshop items and collections |
| [econ.md](econ.md) | trade offers and item store prices |
| [servers.md](servers.md) | game server accounts and login tokens |

Start with [core.md](core.md), then [steamid.md](steamid.md): almost every
call takes an id. [news.md](news.md), [store.md](store.md) and
[market.md](market.md) need no key.
