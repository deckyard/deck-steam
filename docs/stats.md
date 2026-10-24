# Stats - achievements and statistics

`ISteamUserStats`. The per-account calls need a key and a public profile;
the per-game rarity and player count need neither.

## Live player counts (keyless)

```jennifer
io.printf("%d in game\n", steam.currentPlayers($c, 730));
```

Throws when Steam has no count for the app, rather than returning 0.

## Achievement rarity (keyless)

`globalAchievementRarity` gives the share of players, 0-100, holding each
achievement:

```jennifer
def r as list of steam.AchievementRarity init steam.globalAchievementRarity($c, 620);
for (def a in steam.rarest($r, 5)) {
    io.printf("%s|pad=40 %f|prec=2%%\n", $a.name, $a.percent);
}
```

The names are internal API names. Join them with `gameSchema` on `name` for
display titles.

## Per-account achievements

```jennifer
def rec as steam.PlayerAchievements init steam.playerAchievements($c, $id, 620);
io.printf("%s: %d/%d (%f|prec=0%%)\n", $rec.gameName,
    steam.unlockedCount($rec.achievements), len($rec.achievements),
    steam.completionPercent($rec.achievements));
```

The record lists every achievement the game defines; `lockedAchievements`
keeps the ones still locked. `unlockTime` is a Unix time, 0 while locked.
`name` and `description` are in the client's language, and a hidden
achievement has an empty `description` until it is unlocked.

Steam refuses a private profile, an account that does not own the game and
a game without stats. The call throws with the reason translated:

```
Steam will not report achievements for app 620:
  the profile's game details are private
```

## Statistics

`userStats` returns the counters a game keeps for a player (shots fired,
distance travelled), empty when the game keeps none.

## The schema

`gameSchema` returns the game's definitions: display names, descriptions,
unlocked and grey icons, which achievements are hidden, and each statistic
with its default value.

```jennifer
def s as steam.GameSchema init steam.gameSchema($c, 620);
for (def a in $s.achievements) {
    io.printf("%s|pad=28 %s\n", $a.name, $a.displayName);
}
```

See [`examples/stats.j`](https://github.com/deckyard/deck-steam/blob/main/examples/stats.j).
