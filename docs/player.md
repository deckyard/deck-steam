# Player - libraries, playtime, badges

`IPlayerService`. Every call needs a key, and the target account's game
details must be public.

## The library

```jennifer
def lib as list of steam.OwnedGame init steam.ownedGames($c, $id, true, true);
```

- `includeAppInfo` adds each game's name and icon hash. Without it the reply
  is much smaller, which matters for a large library.
- `includeFreeGames` set to false leaves out free-to-play titles the account
  has played, so a library of mostly free games can come back nearly empty.

A private library comes back empty, not as an error. To tell private from
empty, check the profile's `communityVisibilityState` first.

`ownedGameCount` counts without listing, played free-to-play titles
included.

## Playtime

Steam counts minutes:

```jennifer
for (def g in steam.mostPlayed($lib, 10)) {
    io.printf("%s|pad=40 %f|prec=1 h\n", $g.name, steam.playtimeHours($g.playtimeForever));
}
io.printf("%f|prec=1 h in total\n", steam.playtimeHours(steam.totalPlaytime($lib)));
io.printf("%d never launched\n", len(steam.unplayed($lib)));
```

`playtimeTwoWeeks` is the rolling recent figure, 0 for anything not played
lately. `playtimeWindows`, `playtimeMac`, `playtimeLinux` and `playtimeDeck`
are lifetime figures per platform and need not add up to `playtimeForever`:
Steam only started counting them in 2018.

`recentlyPlayedGames` returns the same struct for the last two weeks, most
recent first.

## Icons

`OwnedGame` carries only the icon hash; `gameIconUrl` builds the URL, or
returns `""` for a game with no icon:

```jennifer
io.printf("%s\n", steam.gameIconUrl($g.appId, $g.iconHash));
# https://cdn.akamai.steamstatic.com/steamcommunity/public/images/apps/440/e3f5...743.jpg
```

## Level and badges

`steamLevel` is the number on the profile, 0 when hidden. `badges` returns
every badge and the experience behind the level:

```jennifer
def col as steam.BadgeCollection init steam.badges($c, $id);
io.printf("level %d, %d XP, %d to go\n",
    $col.playerLevel, $col.playerXp, $col.xpNeededToLevelUp);
```

`badgeProgress($c, $id, $badgeId)` lists the tasks of a task-based badge
and whether each is done.

## Family Sharing

`sharedGameLender($c, $id, $appId)` returns the id64 of the account that
lent the copy being played, or `""` when the player owns it. A server plugin
uses it to ban the owner rather than the borrower.

See [`examples/player.j`](https://github.com/deckyard/deck-steam/blob/main/examples/player.j).
