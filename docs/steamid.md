# Steam ids - the three notations

One account, three spellings: a server log prints `STEAM_1:0:11101`, the
`status` command prints `[U:1:22202]`, the Web API uses
`76561197960287930`. Every call in this deck that takes a Steam id accepts
all three. The conversions below are for producing one particular spelling.

## The 64-bit id

| Bits | Field | Typical value |
| ---- | ----- | ------------- |
| 56-63 | universe | 1 (public) |
| 52-55 | account type | 1 (a person), 7 (a group), 3 (a game server) |
| 32-51 | instance | 1 for a desktop account |
| 0-31 | account id | the "friend id", 22202 above |

```jennifer
def p as steam.SteamId init steam.parseSteamId("76561197960287930");
io.printf("universe %d, type %s, account %d\n",
    $p.universe, steam.accountTypeName($p.accountType), $p.accountId);
# universe 1, type individual, account 22202
```

`toSteamId64` reverses it, and refuses fields outside the values Steam
issues (universe 1-5, type 0-10).

A personal id has 17 digits and a group id 18, but a game-server id has 17
as well, so length does not identify a person. `isSteamId` accepts any
account type; `isSteamId64` only a person:

```jennifer
steam.isSteamId("103582791429521412");     # true  - a group
steam.isSteamId64("103582791429521412");   # false - not a person
```

## Converting

```jennifer
steam.toSteamId2("76561197960287930");     # STEAM_1:0:11101
steam.toSteamId3("76561197960287930");     # [U:1:22202]
steam.fromSteamId2("STEAM_1:0:11101");     # 76561197960287930
steam.fromSteamId3("[U:1:22202]");         # 76561197960287930
steam.normalizeSteamId("[U:1:22202]");     # 76561197960287930
```

`STEAM_X:Y:Z` splits the account id into its low bit `Y` and the rest `Z`,
so `STEAM_1:0:11101` and `STEAM_1:1:11101` are consecutive accounts.
`STEAM_0`, which pre-2010 servers printed for the public universe, reads as
universe 1. `toSteamId2` throws for anything but a personal account: the
notation cannot spell one.

`[X:1:W]` names the type by letter, so a group is `[g:1:4]`. The brackets
are optional on input, and a fourth field sets the instance.

## User input

`normalizeSteamId` throws on anything that is not an id; `looksLikeSteamId`
is the test that does not. A vanity name is not an id and needs a request:
`resolveAccount` takes an id in any notation, a vanity name or a pasted
`https://steamcommunity.com/id/<name>/` and returns the id64, spending a
request only on the vanity case ([users](users.md#vanity-names)).

## URLs

```jennifer
steam.profileUrl("STEAM_1:0:11101");
# https://steamcommunity.com/profiles/76561197960287930
steam.vanityProfileUrl("gabelogannewell");
# https://steamcommunity.com/id/gabelogannewell
steam.groupUrl("103582791429521412");
# https://steamcommunity.com/gid/103582791429521412
```

None of this makes a request;
[`examples/steamid.j`](https://github.com/deckyard/deck-steam/blob/main/examples/steamid.j)
runs without a key or a connection.
