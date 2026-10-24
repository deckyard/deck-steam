# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the IPlayerService interface: library, playtime, level, badges.
# Spliced into steam.j via include - not a standalone module.

/**
 * A game in an account's library and its playtime. `name` and `iconHash`
 * are filled in only when `ownedGames` was asked for app info.
 *
 * @field appId {int} the application id
 * @field name {string} the title, "" when app info was not requested
 * @field playtimeForever {int} lifetime playtime in minutes
 * @field playtimeTwoWeeks {int} playtime in the last two weeks, in minutes
 * @field playtimeWindows {int} lifetime minutes on Windows
 * @field playtimeMac {int} lifetime minutes on macOS
 * @field playtimeLinux {int} lifetime minutes on Linux
 * @field playtimeDeck {int} lifetime minutes on a Steam Deck
 * @field iconHash {string} content hash of the library icon, for `gameIconUrl`
 * @field hasCommunityVisibleStats {bool} whether the game publishes stats
 * @field lastPlayed {int} Unix time the game was last launched, 0 when never
 */
export def struct OwnedGame {
    appId as int,
    name as string,
    playtimeForever as int,
    playtimeTwoWeeks as int,
    playtimeWindows as int,
    playtimeMac as int,
    playtimeLinux as int,
    playtimeDeck as int,
    iconHash as string,
    hasCommunityVisibleStats as bool,
    lastPlayed as int
};

/**
 * One community badge an account has earned.
 *
 * @field badgeId {int} the badge id
 * @field appId {int} the app the badge belongs to, 0 for a Steam-wide badge
 * @field level {int} the badge level
 * @field completionTime {int} Unix time the level was reached
 * @field xp {int} experience the badge is worth
 * @field scarcity {int} how many accounts hold this badge
 * @field communityItemId {string} id of the badge's community item
 * @field borderColor {int} border colour index (1 for a foil badge)
 */
export def struct Badge {
    badgeId as int,
    appId as int,
    level as int,
    completionTime as int,
    xp as int,
    scarcity as int,
    communityItemId as string,
    borderColor as int
};

/**
 * An account's badge collection and the level it adds up to.
 *
 * @field playerLevel {int} the Steam level shown on the profile
 * @field playerXp {int} total experience
 * @field xpNeededToLevelUp {int} experience still missing for the next level
 * @field xpNeededCurrentLevel {int} experience the current level started at
 * @field badges {list of Badge} every badge the account holds
 */
export def struct BadgeCollection {
    playerLevel as int,
    playerXp as int,
    xpNeededToLevelUp as int,
    xpNeededCurrentLevel as int,
    badges as list of Badge
};

/**
 * One task of a task-based badge.
 *
 * @field questId {int} the task id
 * @field completed {bool} whether the account has done it
 */
export def struct BadgeQuest {
    questId as int,
    completed as bool
};

/**
 * List the games in an account's library.
 *
 * Needs the account's game details to be public; a private library comes
 * back empty, not as an error. Without `includeAppInfo` the reply is much
 * smaller. Without `includeFreeGames`, free-to-play titles are left out
 * even when the account has played them.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @param includeAppInfo {bool} also fetch each game's name and icon
 * @param includeFreeGames {bool} also count played free-to-play titles
 * @return {list of OwnedGame} the library, in Steam's own order
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 * @example
 *   def lib as list of steam.OwnedGame init
 *       steam.ownedGames($c, "76561197960287930", true, true);
 */
export func ownedGames(
    c as Client,
    steamId as string,
    includeAppInfo as bool,
    includeFreeGames as bool) {
    requireKey($c, "reading a game library");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "include_appinfo": boolParam($includeAppInfo),
        "include_played_free_games": boolParam($includeFreeGames)
    };
    def body as json.Value init apiGet($c, "IPlayerService", "GetOwnedGames", 1, $params);
    return ownedGamesFrom($body, "/response/games");
}

/**
 * Count the games in an account's library without listing them. Played
 * free-to-play titles are counted.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {int} the number of games, 0 when the library is private
 * @throws {Error} kind "steam" as `ownedGames` does
 */
export func ownedGameCount(c as Client, steamId as string) {
    requireKey($c, "counting a game library");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "include_appinfo": "0",
        "include_played_free_games": "1"
    };
    def body as json.Value init apiGet($c, "IPlayerService", "GetOwnedGames", 1, $params);
    return nodeInt($body, "/response/game_count");
}

/**
 * List what an account has played in the last two weeks.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @param count {int} how many titles to return at most
 * @return {list of OwnedGame} the recent titles, most recently played first
 * @throws {Error} kind "steam" without a key, on an unparseable id, on a
 *                 non-positive count, or on a transport failure
 */
export func recentlyPlayedGames(c as Client, steamId as string, count as int) {
    requireKey($c, "reading recent playtime");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "count": convert.toString(ensureCount($count, "recent games"))
    };
    def body as json.Value init apiGet($c, "IPlayerService", "GetRecentlyPlayedGames", 1, $params);
    return ownedGamesFrom($body, "/response/games");
}

/**
 * Read an account's Steam level.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {int} the level, 0 when the profile hides it
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 */
export func steamLevel(c as Client, steamId as string) {
    requireKey($c, "reading a Steam level");
    def params as map of string to string init {"steamid": normalizeSteamId($steamId)};
    def body as json.Value init apiGet($c, "IPlayerService", "GetSteamLevel", 1, $params);
    return nodeInt($body, "/response/player_level");
}

/**
 * Read an account's badges and the experience behind its level.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {BadgeCollection} the badges and the level they add up to
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 */
export func badges(c as Client, steamId as string) {
    requireKey($c, "reading badges");
    def params as map of string to string init {"steamid": normalizeSteamId($steamId)};
    def body as json.Value init apiGet($c, "IPlayerService", "GetBadges", 1, $params);
    return badgeCollectionFrom($body);
}

/**
 * Read how far an account has got with a task-based badge.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @param badgeId {int} the badge to inspect
 * @return {list of BadgeQuest} one entry per task
 * @throws {Error} kind "steam" without a key, on a non-positive badge id,
 *                 or on a transport failure
 */
export func badgeProgress(c as Client, steamId as string, badgeId as int) {
    requireKey($c, "reading badge progress");
    if ($badgeId <= 0) {
        raiseError("the badge id must be positive, got " + convert.toString($badgeId));
    }
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "badgeid": convert.toString($badgeId)
    };
    def body as json.Value init apiGet(
        $c,
        "IPlayerService",
        "GetCommunityBadgeProgress",
        1,
        $params);
    def out as list of BadgeQuest init [];
    for (def i in 0..nodeLength($body, "/response/quests")) {
        def node as json.Value init nodeItem($body, "/response/quests", $i);
        $out[] = BadgeQuest{
            questId: nodeInt($node, "/questid"),
            completed: nodeBool($node, "/completed")
        };
    }
    return $out;
}

/**
 * Which account lent the copy of a game an account is playing through
 * Family Sharing, so a ban can go to the owner rather than the borrower.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} the borrowing account, any notation
 * @param appId {int} the game being played
 * @return {string} the lender's 64-bit id, or "" when the copy is owned
 * @throws {Error} kind "steam" without a key, on a bad app id, or on a
 *                 transport failure
 */
export func sharedGameLender(c as Client, steamId as string, appId as int) {
    requireKey($c, "checking Family Sharing");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "appid_playing": convert.toString(ensureAppId($appId))
    };
    def body as json.Value init apiGet($c, "IPlayerService", "IsPlayingSharedGame", 1, $params);
    def lender as string init nodeString($body, "/response/lender_steamid");
    if ($lender == "0") {
        return "";
    }
    return $lender;
}

/**
 * Playtime in hours, rounded to one decimal.
 *
 * @param minutes {int} a playtime in minutes
 * @return {float} the same span in hours, rounded to one decimal
 */
export func playtimeHours(minutes as int) {
    return math.round(convert.toFloat($minutes) / 6.0) / 10.0;
}

/**
 * Total lifetime playtime across a list of games, in minutes.
 *
 * @param games {list of OwnedGame} the games to add up
 * @return {int} the summed minutes
 */
export func totalPlaytime(games as list of OwnedGame) {
    def total as int init 0;
    for (def g in $games) {
        $total = $total + $g.playtimeForever;
    }
    return $total;
}

/**
 * The most-played games of a library, longest first.
 *
 * @param games {list of OwnedGame} the library
 * @param count {int} how many to return at most
 * @return {list of OwnedGame} the top games, longest playtime first
 * @throws {Error} kind "steam" when `count` is not positive
 * @example
 *   for (def g in steam.mostPlayed($lib, 5)) {
 *       io.printf("%s|pad=40 %f|prec=1 h\n", $g.name, steam.playtimeHours($g.playtimeForever));
 *   }
 */
export func mostPlayed(games as list of OwnedGame, count as int) {
    ensureCount($count, "games");
    def ranked as list of OwnedGame init lists.reverse(lists.sortBy($games, playtimeKey));
    if (len($ranked) <= $count) {
        return $ranked;
    }
    return lists.head($ranked, $count);
}

/**
 * Games in a library that have never been launched.
 *
 * @param games {list of OwnedGame} the library
 * @return {list of OwnedGame} the games with zero lifetime playtime
 */
export func unplayed(games as list of OwnedGame) {
    return lists.filter($games, isUnplayed);
}

/**
 * The URL of a game's library icon, built from the app id and the hash.
 *
 * @param appId {int} the application id
 * @param iconHash {string} the hash from `OwnedGame.iconHash`
 * @return {string} the icon URL, or "" when the game has no icon
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func gameIconUrl(appId as int, iconHash as string) {
    ensureAppId($appId);
    def hash as string init strings.trim($iconHash);
    if ($hash == "") {
        return "";
    }
    return MEDIA_BASE + "/steamcommunity/public/images/apps/" +
        convert.toString($appId) + "/" + $hash + ".jpg";
}

/**
 * Fold a list of library rows into structs (`GetOwnedGames` and
 * `GetRecentlyPlayedGames` share the shape).
 *
 * @param body {json.Value} the decoded response
 * @param ptr {string} JSON Pointer to the `games` list
 * @return {list of OwnedGame} the folded games
 * @internal
 */
func ownedGamesFrom(body as json.Value, ptr as string) {
    def out as list of OwnedGame init [];
    for (def i in 0..nodeLength($body, $ptr)) {
        $out[] = ownedGameFrom(nodeItem($body, $ptr, $i));
    }
    return $out;
}

/**
 * Fold one library row into a struct.
 *
 * @param node {json.Value} one element of a `games` list
 * @return {OwnedGame} the folded game
 * @internal
 */
func ownedGameFrom(node as json.Value) {
    return OwnedGame{
        appId: nodeInt($node, "/appid"),
        name: nodeString($node, "/name"),
        playtimeForever: nodeInt($node, "/playtime_forever"),
        playtimeTwoWeeks: nodeInt($node, "/playtime_2weeks"),
        playtimeWindows: nodeInt($node, "/playtime_windows_forever"),
        playtimeMac: nodeInt($node, "/playtime_mac_forever"),
        playtimeLinux: nodeInt($node, "/playtime_linux_forever"),
        playtimeDeck: nodeInt($node, "/playtime_deck_forever"),
        iconHash: nodeString($node, "/img_icon_url"),
        hasCommunityVisibleStats: nodeBool($node, "/has_community_visible_stats"),
        lastPlayed: nodeInt($node, "/rtime_last_played")
    };
}

/**
 * Fold a `GetBadges` reply into a struct.
 *
 * @param body {json.Value} the decoded response
 * @return {BadgeCollection} the folded collection
 * @internal
 */
func badgeCollectionFrom(body as json.Value) {
    def owned as list of Badge init [];
    for (def i in 0..nodeLength($body, "/response/badges")) {
        def node as json.Value init nodeItem($body, "/response/badges", $i);
        $owned[] = Badge{
            badgeId: nodeInt($node, "/badgeid"),
            appId: nodeInt($node, "/appid"),
            level: nodeInt($node, "/level"),
            completionTime: nodeInt($node, "/completion_time"),
            xp: nodeInt($node, "/xp"),
            scarcity: nodeInt($node, "/scarcity"),
            communityItemId: nodeString($node, "/communityitemid"),
            borderColor: nodeInt($node, "/border_color")
        };
    }
    return BadgeCollection{
        playerLevel: nodeInt($body, "/response/player_level"),
        playerXp: nodeInt($body, "/response/player_xp"),
        xpNeededToLevelUp: nodeInt($body, "/response/player_xp_needed_to_level_up"),
        xpNeededCurrentLevel: nodeInt($body, "/response/player_xp_needed_current_level"),
        badges: $owned
    };
}

/**
 * Sort key: a game's lifetime playtime.
 *
 * @param game {OwnedGame} the game
 * @return {int} its lifetime minutes
 * @internal
 */
func playtimeKey(game as OwnedGame) {
    return $game.playtimeForever;
}

/**
 * Whether a game has never been launched.
 *
 * @param game {OwnedGame} the game
 * @return {bool} true when its lifetime playtime is zero
 * @internal
 */
func isUnplayed(game as OwnedGame) {
    return $game.playtimeForever == 0;
}
