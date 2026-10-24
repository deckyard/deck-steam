# steam examples

One program per topic. All are read-only: none changes anything on Steam.

```
jennifer run examples/<topic>.j
```

| Example | Needs a key? | Environment |
| ------- | ------------ | ----------- |
| [steamid.j](steamid.j) | no, and no network | - |
| [core.j](core.j) | optional | `STEAM_API_KEY` |
| [news.j](news.j) | no | `STEAM_APPID` |
| [stats.j](stats.j) | partly | `STEAM_APPID`, `STEAM_API_KEY`, `STEAM_ACCOUNT` |
| [store.j](store.j) | no | `STEAM_COUNTRY` |
| [market.j](market.j) | no | `STEAM_CURRENCY` |
| [workshop.j](workshop.j) | no | `STEAM_WORKSHOP_ID`, `STEAM_COLLECTION_ID` |
| [apps.j](apps.j) | partly | `STEAM_API_KEY`, `STEAM_SEARCH` |
| [users.j](users.j) | yes | `STEAM_API_KEY`, `STEAM_ACCOUNT` |
| [player.j](player.j) | yes | `STEAM_API_KEY`, `STEAM_ACCOUNT` |
| [econ.j](econ.j) | yes | `STEAM_API_KEY` |
| [servers.j](servers.j) | yes | `STEAM_API_KEY` |

`STEAM_ACCOUNT` takes a vanity name, a profile URL, or a Steam id in any
notation. Get a key at <https://steamcommunity.com/dev/apikey>:

```
export STEAM_API_KEY=...
jennifer run examples/player.j
```

`STEAM_VERBOSE=1` prints each request, key redacted:

```
STEAM_VERBOSE=1 jennifer run examples/news.j
```
