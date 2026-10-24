# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the IGameServersService interface: game server login tokens.
# Spliced into steam.j via include - not a standalone module.

/**
 * A persistent game server account registered by the key's owner, which
 * gives a dedicated server a stable identity in the server browser.
 * `loginToken` is a secret as sensitive as a password: verbose mode redacts
 * it, and so should your logs.
 *
 * @field steamId {string} the server's own 64-bit Steam id
 * @field appId {int} the game it serves
 * @field loginToken {string} the token the server authenticates with
 * @field memo {string} the note set when the account was created
 * @field deleted {bool} whether the account has been deleted
 * @field expired {bool} whether the token has expired through disuse
 * @field lastLogon {int} Unix time the server last logged in
 */
export def struct GameServerAccount {
    steamId as string,
    appId as int,
    loginToken as string,
    memo as string,
    deleted as bool,
    expired as bool,
    lastLogon as int
};

/**
 * The public record of a game server account.
 *
 * @field steamId {string} the server's 64-bit Steam id
 * @field appId {int} the game it serves, 0 when Steam does not know it
 */
export def struct GameServerInfo {
    steamId as string,
    appId as int
};

/**
 * What a login token is currently worth.
 *
 * @field steamId {string} the server account the token belongs to
 * @field banned {bool} whether the account is banned from listing
 * @field expires {int} Unix time the token stops working, 0 when it does not
 */
export def struct LoginTokenStatus {
    steamId as string,
    banned as bool,
    expires as int
};

/**
 * List the game server accounts the key's owner has registered. No
 * parameter names an account: these are the key owner's secrets.
 *
 * @param c {Client} an API client with a key
 * @return {list of GameServerAccount} the registered accounts
 * @throws {Error} kind "steam" without a key or on a transport failure
 * @example
 *   for (def s in steam.gameServerAccounts($c)) {
 *       io.printf("%s app %d  %s\n", $s.steamId, $s.appId, $s.memo);
 *   }
 */
export func gameServerAccounts(c as Client) {
    requireKey($c, "listing game server accounts");
    def body as json.Value init apiGet($c, "IGameServersService", "GetAccountList", 1, {});
    def out as list of GameServerAccount init [];
    for (def i in 0..nodeLength($body, "/response/servers")) {
        def node as json.Value init nodeItem($body, "/response/servers", $i);
        $out[] = GameServerAccount{
            steamId: nodeString($node, "/steamid"),
            appId: nodeInt($node, "/appid"),
            loginToken: nodeString($node, "/login_token"),
            memo: nodeString($node, "/memo"),
            deleted: nodeBool($node, "/is_deleted"),
            expired: nodeBool($node, "/is_expired"),
            lastLogon: nodeInt($node, "/rt_last_logon")
        };
    }
    return $out;
}

/**
 * Read the public record of one game server account.
 *
 * @param c {Client} an API client with a key
 * @param steamId {string} the server's Steam id, in any notation
 * @return {GameServerInfo} what Steam publishes about it
 * @throws {Error} kind "steam" without a key, on an unparseable id, or on
 *                 a transport failure
 */
export func gameServerInfo(c as Client, steamId as string) {
    requireKey($c, "reading a game server account");
    def params as map of string to string init {"steamid": normalizeSteamId($steamId)};
    def body as json.Value init apiGet(
        $c,
        "IGameServersService",
        "GetAccountPublicInfo",
        1,
        $params);
    return GameServerInfo{
        steamId: nodeString($body, "/response/steamid"),
        appId: nodeInt($body, "/response/appid")
    };
}

/**
 * Check whether a login token still works, e.g. when a server drops out of
 * the browser. An unused token expires.
 *
 * @param c {Client} an API client with a key
 * @param loginToken {string} the token to check
 * @return {LoginTokenStatus} what Steam thinks of it
 * @throws {Error} kind "steam" without a key, on a blank token, or on a
 *                 transport failure
 */
export func queryLoginToken(c as Client, loginToken as string) {
    requireKey($c, "checking a login token");
    def params as map of string to string init {
        "login_token": ensureText($loginToken, "login token")
    };
    def body as json.Value init apiGet($c, "IGameServersService", "QueryLoginToken", 1, $params);
    return LoginTokenStatus{
        steamId: nodeString($body, "/response/steamid"),
        banned: nodeBool($body, "/response/is_banned"),
        expires: nodeInt($body, "/response/expires")
    };
}

/**
 * Whether a server account can still list itself.
 *
 * @param account {GameServerAccount} the account
 * @return {bool} true when it is neither deleted nor expired
 */
export func isUsableServerAccount(account as GameServerAccount) {
    return not $account.deleted and not $account.expired;
}
