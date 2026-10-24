# Users - profiles, friends, bans

`ISteamUser`. Every call here needs a key, except `resolveAccount` given an
id.

## Profiles

```jennifer
def p as steam.PlayerSummary init steam.playerSummary($c, "76561197960287930");
io.printf("%s - %s\n", $p.personaName, steam.personaStateName($p.personaState));
```

`playerSummaries` takes up to `SUMMARY_BATCH` (100) ids per request, enough
for a friend list or a server roster:

```jennifer
use lists;

def ids as list of string init [];
for (def f in steam.friendList($c, $id)) {
    $ids[] = $f.steamId;
}
if (len($ids) > steam.SUMMARY_BATCH) {
    $ids = lists.head($ids, steam.SUMMARY_BATCH);
}
for (def friend in steam.playerSummaries($c, $ids)) {
    io.printf("%s\n", $friend.personaName);
}
```

Accounts Steam does not know are left out, so the result may be shorter
than the input. `playerSummary` throws instead.

### Private fields

Only `steamId`, `personaName`, `profileUrl`, the three avatars and
`personaState` are guaranteed. `realName`, `timeCreated`, `countryCode`,
`lastLogoff` and the rest are filled in only when the profile is public and
the account publishes that field. An empty `realName` means "not shared":

```jennifer
if (steam.isPublic($p) and $p.realName != "") {
    io.printf("real name %s\n", $p.realName);
}
```

`isOnline` is true for every state but offline. `isInGame` exists because
Steam sets `gameId` to `"0"` rather than omitting it when nothing is played.

## Vanity names

`steamcommunity.com/id/gabelogannewell` is a custom URL, not an id.
`resolveVanityUrl` turns the name into an id64, or `""` when no profile has
it.

`resolveAccount` is the call for user input. It accepts an id in any
notation (no request, no key), a vanity name, or a pasted profile URL, from
which it cuts `/id/`, a `?query`, a `#fragment` and trailing slashes. It
throws when nothing matches:

```jennifer
def id as string init steam.resolveAccount($c, $whateverTheUserTyped);
```

## Friends and groups

A private friend list comes back empty, not as an error. Each `Friend` has
`friendSince` as a Unix time. `userGroups` returns the group id64s, empty
for a private profile; `groupUrl` links one.

## Bans

```jennifer
def b as steam.PlayerBan init steam.playerBan($c, $id);
io.printf("%d VAC bans, %d game bans, economy: %s\n",
    $b.vacBans, $b.gameBans, $b.economyBan);
```

`playerBans` batches like `playerSummaries`. `economyBan` is `"none"`,
`"probation"` or `"banned"`. `daysSinceLastBan` is 0 for an account never
banned, so read it with `vacBanned` / `communityBanned`.

This endpoint capitalizes its JSON keys (`SteamId`, `VACBanned`,
`NumberOfVACBans`), unlike every other Steam endpoint. That matters only
when you read it through `call`.

See [`examples/users.j`](https://github.com/deckyard/deck-steam/blob/main/examples/users.j).
