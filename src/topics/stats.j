# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the ISteamUserStats interface: achievements, stats, player counts.
# Spliced into steam.j via include - not a standalone module.

/**
 * One achievement and whether an account has earned it. A hidden
 * achievement keeps its description empty until unlocked.
 *
 * @field apiName {string} the stable internal name, e.g. "TF_PLAY_GAME_FRIENDSONLY"
 * @field achieved {bool} whether the account has unlocked it
 * @field unlockTime {int} Unix time of the unlock, 0 when still locked
 * @field name {string} the display name, "" when not localized
 * @field description {string} the display description, "" when hidden or not localized
 */
export def struct Achievement {
    apiName as string,
    achieved as bool,
    unlockTime as int,
    name as string,
    description as string
};

/**
 * An account's achievement record for one game.
 *
 * @field steamId {string} the account
 * @field appId {int} the game
 * @field gameName {string} the game's title as Steam reports it
 * @field achievements {list of Achievement} every achievement, unlocked or not
 */
export def struct PlayerAchievements {
    steamId as string,
    appId as int,
    gameName as string,
    achievements as list of Achievement
};

/**
 * One numeric statistic a game tracks per account.
 *
 * @field name {string} the stat's internal name
 * @field value {int} its current value for the account
 */
export def struct StatValue {
    name as string,
    value as int
};

/**
 * How common an achievement is across everyone who plays a game.
 *
 * @field name {string} the achievement's internal name
 * @field percent {float} the share of players who have it, 0-100
 */
export def struct AchievementRarity {
    name as string,
    percent as float
};

/**
 * An achievement as the game itself defines it.
 *
 * @field name {string} the stable internal name
 * @field displayName {string} the localized title
 * @field description {string} the localized description, "" when hidden
 * @field hidden {bool} whether the description is withheld until unlocked
 * @field icon {string} URL of the unlocked icon
 * @field iconGray {string} URL of the locked icon
 */
export def struct SchemaAchievement {
    name as string,
    displayName as string,
    description as string,
    hidden as bool,
    icon as string,
    iconGray as string
};

/**
 * A statistic as the game itself defines it.
 *
 * @field name {string} the stable internal name
 * @field displayName {string} the localized label, "" when the game gives none
 * @field defaultValue {int} the value a fresh account starts at
 */
export def struct SchemaStat {
    name as string,
    displayName as string,
    defaultValue as int
};

/**
 * The achievements and statistics a game defines.
 *
 * @field appId {int} the game
 * @field gameName {string} the game's title
 * @field gameVersion {string} the stats schema version
 * @field achievements {list of SchemaAchievement} the defined achievements
 * @field stats {list of SchemaStat} the defined statistics
 */
export def struct GameSchema {
    appId as int,
    gameName as string,
    gameVersion as string,
    achievements as list of SchemaAchievement,
    stats as list of SchemaStat
};

/**
 * Read an account's achievements for one game.
 *
 * The account's game details must be public and it must own the game.
 * Steam refuses otherwise, so this throws where `ownedGames` returns an
 * empty list.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @param appId {int} the game
 * @return {PlayerAchievements} the record, localized to the client's language
 * @throws {Error} kind "steam" without a key, on an unparseable id or a bad
 *                 app id, when Steam refuses (private profile, unowned game,
 *                 no stats), or on a transport failure
 * @example
 *   def a as steam.PlayerAchievements init
 *       steam.playerAchievements($c, "76561197960287930", 440);
 *   io.printf("%f|prec=0%% done\n", steam.completionPercent($a.achievements));
 */
export func playerAchievements(c as Client, steamId as string, appId as int) {
    requireKey($c, "reading achievements");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "appid": convert.toString(ensureAppId($appId)),
        "l": $c.language
    };
    def body as json.Value init apiGet($c, "ISteamUserStats", "GetPlayerAchievements", 1, $params);
    if (not nodeBool($body, "/playerstats/success")) {
        raiseError("Steam will not report achievements for app " +
            convert.toString($appId) + ": " +
            statsRefusal(nodeString($body, "/playerstats/error")));
    }
    def out as list of Achievement init [];
    for (def i in 0..nodeLength($body, "/playerstats/achievements")) {
        def node as json.Value init nodeItem($body, "/playerstats/achievements", $i);
        $out[] = Achievement{
            apiName: nodeString($node, "/apiname"),
            achieved: nodeBool($node, "/achieved"),
            unlockTime: nodeInt($node, "/unlocktime"),
            name: nodeString($node, "/name"),
            description: nodeString($node, "/description")
        };
    }
    return PlayerAchievements{
        steamId: nodeString($body, "/playerstats/steamID"),
        appId: $appId,
        gameName: nodeString($body, "/playerstats/gameName"),
        achievements: $out
    };
}

/**
 * Read the counters a game keeps for an account (shots fired, distance
 * travelled), as opposed to its achievements.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @param appId {int} the game
 * @return {list of StatValue} the statistics, empty when the game keeps none
 * @throws {Error} kind "steam" without a key, on a bad app id, or on a
 *                 transport failure
 */
export func userStats(c as Client, steamId as string, appId as int) {
    requireKey($c, "reading game statistics");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "appid": convert.toString(ensureAppId($appId))
    };
    def body as json.Value init apiGet($c, "ISteamUserStats", "GetUserStatsForGame", 2, $params);
    def out as list of StatValue init [];
    for (def i in 0..nodeLength($body, "/playerstats/stats")) {
        def node as json.Value init nodeItem($body, "/playerstats/stats", $i);
        $out[] = StatValue{name: nodeString($node, "/name"), value: nodeInt($node, "/value")};
    }
    return $out;
}

/**
 * Read the share of players holding each of a game's achievements. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game
 * @return {list of AchievementRarity} the achievements, rarest last
 * @throws {Error} kind "steam" on a bad app id or a transport failure
 */
export func globalAchievementRarity(c as Client, appId as int) {
    def params as map of string to string init {"gameid": convert.toString(ensureAppId($appId))};
    def body as json.Value init apiGet(
        $c,
        "ISteamUserStats",
        "GetGlobalAchievementPercentagesForApp",
        2,
        $params);
    def out as list of AchievementRarity init [];
    for (def i in 0..nodeLength($body, "/achievementpercentages/achievements")) {
        def node as json.Value init nodeItem($body, "/achievementpercentages/achievements", $i);
        $out[] = AchievementRarity{
            name: nodeString($node, "/name"),
            percent: nodeFloat($node, "/percent")
        };
    }
    return $out;
}

/**
 * Count who is playing a game right now. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game
 * @return {int} the current player count
 * @throws {Error} kind "steam" on a bad app id, when Steam has no count
 *                 for the app, or on a transport failure
 * @example
 *   io.printf("%d in game\n", steam.currentPlayers($c, 730));
 */
export func currentPlayers(c as Client, appId as int) {
    def params as map of string to string init {"appid": convert.toString(ensureAppId($appId))};
    def body as json.Value init apiGet(
        $c,
        "ISteamUserStats",
        "GetNumberOfCurrentPlayers",
        1,
        $params);
    if (nodeInt($body, "/response/result") != 1) {
        raiseError("Steam reports no player count for app " + convert.toString($appId));
    }
    return nodeInt($body, "/response/player_count");
}

/**
 * Read a game's achievement and statistic definitions.
 *
 * @param c {Client} an API client with a key
 * @param appId {int} the game
 * @return {GameSchema} the definitions, localized to the client's language
 * @throws {Error} kind "steam" without a key, on a bad app id, or on a
 *                 transport failure
 */
export func gameSchema(c as Client, appId as int) {
    requireKey($c, "reading a game schema");
    def params as map of string to string init {
        "appid": convert.toString(ensureAppId($appId)),
        "l": $c.language
    };
    def body as json.Value init apiGet($c, "ISteamUserStats", "GetSchemaForGame", 2, $params);
    return gameSchemaFrom($body, $appId);
}

/**
 * How many of a list of achievements are unlocked.
 *
 * @param achievements {list of Achievement} the record to count
 * @return {int} the number unlocked
 */
export func unlockedCount(achievements as list of Achievement) {
    def done as int init 0;
    for (def a in $achievements) {
        if ($a.achieved) {
            $done = $done + 1;
        }
    }
    return $done;
}

/**
 * What share of a list of achievements is unlocked, as a percentage.
 *
 * @param achievements {list of Achievement} the record to measure
 * @return {float} 0.0 to 100.0; 0.0 for a game with no achievements
 */
export func completionPercent(achievements as list of Achievement) {
    if (len($achievements) == 0) {
        return 0.0;
    }
    return convert.toFloat(unlockedCount($achievements)) *
        100.0 / convert.toFloat(len($achievements));
}

/**
 * The achievements of a record that are still locked.
 *
 * @param achievements {list of Achievement} the record to filter
 * @return {list of Achievement} the ones not yet earned
 */
export func lockedAchievements(achievements as list of Achievement) {
    return lists.filter($achievements, isLocked);
}

/**
 * The rarest achievements of a game, rarest first.
 *
 * @param rarities {list of AchievementRarity} from `globalAchievementRarity`
 * @param count {int} how many to return at most
 * @return {list of AchievementRarity} the rarest, ascending by percentage
 * @throws {Error} kind "steam" when `count` is not positive
 */
export func rarest(rarities as list of AchievementRarity, count as int) {
    ensureCount($count, "achievements");
    def ranked as list of AchievementRarity init lists.sortBy($rarities, rarityKey);
    if (len($ranked) <= $count) {
        return $ranked;
    }
    return lists.head($ranked, $count);
}

/**
 * Fold a `GetSchemaForGame` reply into a struct.
 *
 * @param body {json.Value} the decoded response
 * @param appId {int} the game the request was for
 * @return {GameSchema} the folded schema
 * @internal
 */
func gameSchemaFrom(body as json.Value, appId as int) {
    def achieved as list of SchemaAchievement init [];
    def base as string init "/game/availableGameStats";
    for (def i in 0..nodeLength($body, $base + "/achievements")) {
        def node as json.Value init nodeItem($body, $base + "/achievements", $i);
        $achieved[] = SchemaAchievement{
            name: nodeString($node, "/name"),
            displayName: nodeString($node, "/displayName"),
            description: nodeString($node, "/description"),
            hidden: nodeBool($node, "/hidden"),
            icon: nodeString($node, "/icon"),
            iconGray: nodeString($node, "/icongray")
        };
    }
    def counters as list of SchemaStat init [];
    for (def i in 0..nodeLength($body, $base + "/stats")) {
        def node as json.Value init nodeItem($body, $base + "/stats", $i);
        $counters[] = SchemaStat{
            name: nodeString($node, "/name"),
            displayName: nodeString($node, "/displayName"),
            defaultValue: nodeInt($node, "/defaultvalue")
        };
    }
    return GameSchema{
        appId: $appId,
        gameName: nodeString($body, "/game/gameName"),
        gameVersion: nodeString($body, "/game/gameVersion"),
        achievements: $achieved,
        stats: $counters
    };
}

/**
 * Translate Steam's terse stats refusal into a sentence.
 *
 * @param reason {string} the `error` field of the reply, "" when absent
 * @return {string} something a user can act on
 * @internal
 */
func statsRefusal(reason as string) {
    def text as string init strings.lower(strings.trim($reason));
    if (strings.contains($text, "private") or strings.contains($text, "not public")) {
        return "the profile's game details are private";
    }
    if (strings.contains($text, "no stats")) {
        return "the game publishes no achievement stats";
    }
    if ($text == "") {
        return "the account may not own the game, or its profile is private";
    }
    return $reason;
}

/**
 * Whether an achievement is still locked.
 *
 * @param achievement {Achievement} the entry
 * @return {bool} true when it has not been earned
 * @internal
 */
func isLocked(achievement as Achievement) {
    return not $achievement.achieved;
}

/**
 * Sort key: how common an achievement is.
 *
 * @param rarity {AchievementRarity} the entry
 * @return {float} its percentage
 * @internal
 */
func rarityKey(rarity as AchievementRarity) {
    return $rarity.percent;
}
