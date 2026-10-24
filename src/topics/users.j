# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the ISteamUser interface: profiles, friends, bans, vanity names.
# Spliced into steam.j via include - not a standalone module.

/**
 * Persona state of an account that is signed out.
 */
export def const PERSONA_OFFLINE as int init 0;

/**
 * Persona state of an account that is signed in and available.
 */
export def const PERSONA_ONLINE as int init 1;

/**
 * Persona state of an account marked busy.
 */
export def const PERSONA_BUSY as int init 2;

/**
 * Persona state of an account marked away.
 */
export def const PERSONA_AWAY as int init 3;

/**
 * Persona state of an account idle long enough to snooze.
 */
export def const PERSONA_SNOOZE as int init 4;

/**
 * Persona state of an account looking to trade.
 */
export def const PERSONA_LOOKING_TO_TRADE as int init 5;

/**
 * Persona state of an account looking to play.
 */
export def const PERSONA_LOOKING_TO_PLAY as int init 6;

/**
 * Profile visible only to the account itself.
 */
export def const VISIBILITY_PRIVATE as int init 1;

/**
 * Profile visible to the account's friends.
 */
export def const VISIBILITY_FRIENDS as int init 2;

/**
 * Profile visible to everyone; only then are a `PlayerSummary`'s detail
 * fields filled in for a stranger.
 */
export def const VISIBILITY_PUBLIC as int init 3;

/**
 * The friend-list relationship every account has with its friends.
 */
export def const RELATIONSHIP_FRIEND as string init "friend";

/**
 * The largest batch `playerSummaries` and `playerBans` accept.
 */
export def const SUMMARY_BATCH as int init 100;

/**
 * A public profile as `GetPlayerSummaries` reports it.
 *
 * Only `steamId`, `personaName`, `profileUrl`, the avatars and
 * `personaState` are guaranteed. The rest is filled in only when
 * `communityVisibilityState` is `VISIBILITY_PUBLIC` and the account publishes
 * that field, so "" or 0 means "not shared", not "not set".
 *
 * @field steamId {string} the 64-bit account id
 * @field personaName {string} the display name
 * @field profileUrl {string} the community profile URL
 * @field avatar {string} 32x32 avatar URL
 * @field avatarMedium {string} 64x64 avatar URL
 * @field avatarFull {string} 184x184 avatar URL
 * @field avatarHash {string} content hash shared by the three avatar URLs
 * @field personaState {int} one of the `PERSONA_*` constants
 * @field communityVisibilityState {int} one of the `VISIBILITY_*` constants
 * @field profileState {int} 1 once the account has configured a community profile
 * @field lastLogoff {int} Unix time the account last signed out, 0 when private
 * @field commentPermission {int} non-zero when strangers may comment
 * @field realName {string} the real name, "" when not shared
 * @field primaryClanId {string} 64-bit id of the account's primary group
 * @field timeCreated {int} Unix time the account was created, 0 when private
 * @field personaStateFlags {int} client flags (in-app, big picture, ...)
 * @field countryCode {string} two-letter country, "" when not shared
 * @field stateCode {string} sub-country region code, "" when not shared
 * @field cityId {int} Steam's internal city id, 0 when not shared
 * @field gameId {string} app id currently being played, "" when not playing
 * @field gameExtraInfo {string} the title being played, "" when not playing
 * @field gameServerIp {string} server the account is playing on, "" when none
 */
export def struct PlayerSummary {
    steamId as string,
    personaName as string,
    profileUrl as string,
    avatar as string,
    avatarMedium as string,
    avatarFull as string,
    avatarHash as string,
    personaState as int,
    communityVisibilityState as int,
    profileState as int,
    lastLogoff as int,
    commentPermission as int,
    realName as string,
    primaryClanId as string,
    timeCreated as int,
    personaStateFlags as int,
    countryCode as string,
    stateCode as string,
    cityId as int,
    gameId as string,
    gameExtraInfo as string,
    gameServerIp as string
};

/**
 * One entry of an account's friend list.
 *
 * @field steamId {string} the friend's 64-bit account id
 * @field relationship {string} always "friend" today
 * @field friendSince {int} Unix time the friendship was made
 */
export def struct Friend {
    steamId as string,
    relationship as string,
    friendSince as int
};

/**
 * The ban record of one account.
 *
 * @field steamId {string} the 64-bit account id
 * @field communityBanned {bool} banned from the community features
 * @field vacBanned {bool} carries at least one VAC ban
 * @field vacBans {int} how many VAC bans across all games
 * @field gameBans {int} how many developer-issued game bans
 * @field daysSinceLastBan {int} days since the most recent ban, 0 when never banned
 * @field economyBan {string} trade-ban status: "none", "probation", or "banned"
 */
export def struct PlayerBan {
    steamId as string,
    communityBanned as bool,
    vacBanned as bool,
    vacBans as int,
    gameBans as int,
    daysSinceLastBan as int,
    economyBan as string
};

/**
 * Look up the profiles of up to 100 accounts in one request. Accounts
 * Steam does not know are absent from the result, so it may be shorter
 * than `steamIds`.
 *
 * @param c {Client} an API client with a key
 * @param steamIds {list of string} up to 100 Steam ids, any notation
 * @return {list of PlayerSummary} one entry per account Steam knew
 * @throws {Error} kind "steam" without a key, on an empty or oversized
 *                 batch, on an unparseable id, or on a transport failure
 * @example
 *   def ps as list of steam.PlayerSummary init
 *       steam.playerSummaries($c, ["76561197960287930", "STEAM_1:1:11101"]);
 */
export func playerSummaries(c as Client, steamIds as list of string) {
    requireKey($c, "reading player summaries");
    def params as map of string to string init {"steamids": joinSteamIds($steamIds, SUMMARY_BATCH)};
    def body as json.Value init apiGet($c, "ISteamUser", "GetPlayerSummaries", 2, $params);
    def out as list of PlayerSummary init [];
    for (def i in 0..nodeLength($body, "/response/players")) {
        $out[] = playerSummaryFrom(nodeItem($body, "/response/players", $i));
    }
    return $out;
}

/**
 * Look up one account's public profile.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {PlayerSummary} the profile
 * @throws {Error} kind "steam" when the account is unknown, or as
 *                 `playerSummaries` does
 * @example
 *   def p as steam.PlayerSummary init steam.playerSummary($c, "76561197960287930");
 */
export func playerSummary(c as Client, steamId as string) {
    def found as list of PlayerSummary init playerSummaries($c, [$steamId]);
    if (len($found) == 0) {
        raiseError("Steam knows no account " + normalizeSteamId($steamId));
    }
    return $found[0];
}

/**
 * Read an account's friend list.
 *
 * A private friend list comes back empty, not as an error.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {list of Friend} the friends, oldest friendship first
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 */
export func friendList(c as Client, steamId as string) {
    requireKey($c, "reading a friend list");
    def params as map of string to string init {
        "steamid": normalizeSteamId($steamId),
        "relationship": RELATIONSHIP_FRIEND
    };
    def body as json.Value init apiGet($c, "ISteamUser", "GetFriendList", 1, $params);
    def out as list of Friend init [];
    for (def i in 0..nodeLength($body, "/friendslist/friends")) {
        $out[] = friendFrom(nodeItem($body, "/friendslist/friends", $i));
    }
    return $out;
}

/**
 * Read the ban records of up to 100 accounts.
 *
 * @param c {Client} an API client with a key
 * @param steamIds {list of string} up to 100 Steam ids, any notation
 * @return {list of PlayerBan} one record per account
 * @throws {Error} kind "steam" without a key, on a bad batch, or on a
 *                 transport failure
 */
export func playerBans(c as Client, steamIds as list of string) {
    requireKey($c, "reading ban records");
    def params as map of string to string init {"steamids": joinSteamIds($steamIds, SUMMARY_BATCH)};
    def body as json.Value init apiGet($c, "ISteamUser", "GetPlayerBans", 1, $params);
    def out as list of PlayerBan init [];
    for (def i in 0..nodeLength($body, "/players")) {
        $out[] = playerBanFrom(nodeItem($body, "/players", $i));
    }
    return $out;
}

/**
 * Read one account's ban record.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {PlayerBan} the record
 * @throws {Error} kind "steam" when the account is unknown, or as
 *                 `playerBans` does
 */
export func playerBan(c as Client, steamId as string) {
    def found as list of PlayerBan init playerBans($c, [$steamId]);
    if (len($found) == 0) {
        raiseError("Steam has no ban record for " + normalizeSteamId($steamId));
    }
    return $found[0];
}

/**
 * Turn a custom profile name (`gabelogannewell` from
 * `steamcommunity.com/id/gabelogannewell`) into a 64-bit Steam id.
 *
 * @param c {Client} an API client with a key
 * @param vanity {string} the custom URL segment
 * @return {string} the 64-bit id, or "" when no profile has that name
 * @throws {Error} kind "steam" without a key, on a blank name, or on a
 *                 transport failure
 * @example
 *   def id as string init steam.resolveVanityUrl($c, "gabelogannewell");
 */
export func resolveVanityUrl(c as Client, vanity as string) {
    requireKey($c, "resolving a vanity URL");
    def params as map of string to string init {"vanityurl": ensureText($vanity, "vanity name")};
    def body as json.Value init apiGet($c, "ISteamUser", "ResolveVanityURL", 1, $params);
    if (nodeInt($body, "/response/success") != 1) {
        return "";
    }
    return nodeString($body, "/response/steamid");
}

/**
 * Resolve a Steam id in any notation, a vanity name or a pasted profile URL
 * to a 64-bit id. An id is converted locally; only a vanity name costs a
 * request, and only it needs a key. A URL's query and fragment are dropped.
 *
 * @param c {Client} an API client; a key is needed for a vanity name
 * @param text {string} a Steam id in any notation, a vanity name or a
 *        `/id/<name>` profile URL
 * @return {string} the 64-bit id
 * @throws {Error} kind "steam" on blank text, when no account matches, on a
 *                 vanity name without a key, or on a transport failure
 * @example
 *   def id as string init steam.resolveAccount($c, "gabelogannewell");
 */
export func resolveAccount(c as Client, text as string) {
    def raw as string init ensureText($text, "account");
    if (looksLikeSteamId($raw)) {
        return normalizeSteamId($raw);
    }
    def resolved as string init resolveVanityUrl($c, vanitySegment($raw));
    if ($resolved == "") {
        raiseError("no Steam account is called \"" + $raw + "\"");
    }
    return $resolved;
}

/**
 * List the groups an account belongs to.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} a Steam id in any notation
 * @return {list of string} the 64-bit group ids, empty when the profile is private
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 */
export func userGroups(c as Client, steamId as string) {
    requireKey($c, "reading group membership");
    def params as map of string to string init {"steamid": normalizeSteamId($steamId)};
    def body as json.Value init apiGet($c, "ISteamUser", "GetUserGroupList", 1, $params);
    if (not nodeBool($body, "/response/success")) {
        def none as list of string init [];
        return $none;
    }
    return nodeFieldList($body, "/response/groups", "gid");
}

/**
 * The name of a persona state.
 *
 * @param state {int} one of the `PERSONA_*` constants
 * @return {string} e.g. "online", or "unknown" for a value Steam has not
 *         documented
 */
export func personaStateName(state as int) {
    match ($state) {
        when 0 { return "offline"; }
        when 1 { return "online"; }
        when 2 { return "busy"; }
        when 3 { return "away"; }
        when 4 { return "snooze"; }
        when 5 { return "looking to trade"; }
        when 6 { return "looking to play"; }
        else { return "unknown"; }
    }
}

/**
 * The name of a profile visibility.
 *
 * @param visibility {int} one of the `VISIBILITY_*` constants
 * @return {string} e.g. "public", or "unknown" for anything else
 */
export func visibilityName(visibility as int) {
    match ($visibility) {
        when 1 { return "private"; }
        when 2 { return "friends only"; }
        when 3 { return "public"; }
        else { return "unknown"; }
    }
}

/**
 * Whether a profile is public, so its detail fields (`realName`,
 * `timeCreated`, ...) can be filled in.
 *
 * @param player {PlayerSummary} the profile
 * @return {bool} true when the profile is public
 */
export func isPublic(player as PlayerSummary) {
    return $player.communityVisibilityState == VISIBILITY_PUBLIC;
}

/**
 * Whether the account is signed in, in any of the online states.
 *
 * @param player {PlayerSummary} the profile
 * @return {bool} true for anything but offline
 */
export func isOnline(player as PlayerSummary) {
    return $player.personaState != PERSONA_OFFLINE;
}

/**
 * Whether the account is playing something right now.
 *
 * @param player {PlayerSummary} the profile
 * @return {bool} true when `gameId` is neither "" nor "0"
 */
export func isInGame(player as PlayerSummary) {
    return $player.gameId != "" and $player.gameId != "0";
}

/**
 * Fold one `GetPlayerSummaries` row into a struct.
 *
 * @param node {json.Value} one element of the `players` list
 * @return {PlayerSummary} the folded profile
 * @internal
 */
func playerSummaryFrom(node as json.Value) {
    return PlayerSummary{
        steamId: nodeString($node, "/steamid"),
        personaName: nodeString($node, "/personaname"),
        profileUrl: nodeString($node, "/profileurl"),
        avatar: nodeString($node, "/avatar"),
        avatarMedium: nodeString($node, "/avatarmedium"),
        avatarFull: nodeString($node, "/avatarfull"),
        avatarHash: nodeString($node, "/avatarhash"),
        personaState: nodeInt($node, "/personastate"),
        communityVisibilityState: nodeInt($node, "/communityvisibilitystate"),
        profileState: nodeInt($node, "/profilestate"),
        lastLogoff: nodeInt($node, "/lastlogoff"),
        commentPermission: nodeInt($node, "/commentpermission"),
        realName: nodeString($node, "/realname"),
        primaryClanId: nodeString($node, "/primaryclanid"),
        timeCreated: nodeInt($node, "/timecreated"),
        personaStateFlags: nodeInt($node, "/personastateflags"),
        countryCode: nodeString($node, "/loccountrycode"),
        stateCode: nodeString($node, "/locstatecode"),
        cityId: nodeInt($node, "/loccityid"),
        gameId: nodeString($node, "/gameid"),
        gameExtraInfo: nodeString($node, "/gameextrainfo"),
        gameServerIp: nodeString($node, "/gameserverip")
    };
}

/**
 * Fold one `GetFriendList` row into a struct.
 *
 * @param node {json.Value} one element of the `friends` list
 * @return {Friend} the folded entry
 * @internal
 */
func friendFrom(node as json.Value) {
    return Friend{
        steamId: nodeString($node, "/steamid"),
        relationship: nodeString($node, "/relationship"),
        friendSince: nodeInt($node, "/friend_since")
    };
}

/**
 * Fold one `GetPlayerBans` row into a struct.
 *
 * The one endpoint that capitalizes its keys (`SteamId`, `VACBanned`).
 *
 * @param node {json.Value} one element of the `players` list
 * @return {PlayerBan} the folded record
 * @internal
 */
func playerBanFrom(node as json.Value) {
    return PlayerBan{
        steamId: nodeString($node, "/SteamId"),
        communityBanned: nodeBool($node, "/CommunityBanned"),
        vacBanned: nodeBool($node, "/VACBanned"),
        vacBans: nodeInt($node, "/NumberOfVACBans"),
        gameBans: nodeInt($node, "/NumberOfGameBans"),
        daysSinceLastBan: nodeInt($node, "/DaysSinceLastBan"),
        economyBan: nodeString($node, "/EconomyBan")
    };
}

/**
 * Reduce a pasted profile URL to the vanity segment inside it.
 *
 * Accepts the bare name or a whole `https://steamcommunity.com/id/name/`,
 * and cuts off a `?query`, a `#fragment` and trailing slashes.
 *
 * @param text {string} a vanity name or a profile URL containing one
 * @return {string} the vanity segment
 * @throws {Error} kind "steam" when nothing is left after trimming
 * @internal
 */
func vanitySegment(text as string) {
    def raw as string init strings.trim($text);
    def marker as int init strings.indexOf($raw, "/id/");
    if ($marker >= 0) {
        $raw = strings.substring($raw, $marker + 4);
    }
    for (def cut in ["?", "#"]) {
        def at as int init strings.indexOf($raw, $cut);
        if ($at >= 0) {
            $raw = strings.substring($raw, 0, $at);
        }
    }
    while (strings.endsWith($raw, "/")) {
        $raw = strings.substring($raw, 0, len($raw) - 1);
    }
    return ensureText($raw, "vanity name");
}
