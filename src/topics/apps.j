# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the ISteamApps and ISteamWebAPIUtil interfaces: the app catalogue.
# Spliced into steam.j via include - not a standalone module.

/**
 * Largest page `IStoreService/GetAppList` will serve at once.
 */
export def const APPLIST_PAGE_MAX as int init 50000;

/**
 * One entry of Steam's public application catalogue.
 *
 * @field appId {int} the application id
 * @field name {string} the application's name
 */
export def struct App {
    appId as int,
    name as string
};

/**
 * One page of the application catalogue and the id to resume from.
 *
 * @field apps {list of App} the page's entries
 * @field lastAppId {int} the id to pass as `lastAppId` for the next page
 * @field haveMore {bool} whether another page follows
 */
export def struct AppListPage {
    apps as list of App,
    lastAppId as int,
    haveMore as bool
};

/**
 * What Steam says about a game client's version.
 *
 * @field upToDate {bool} whether the version asked about is current
 * @field versionIsListable {bool} whether it is a version Steam still lists
 * @field requiredVersion {int} the lowest version still allowed to connect
 * @field message {string} Steam's own explanation, "" when it gave none
 */
export def struct VersionCheck {
    upToDate as bool,
    versionIsListable as bool,
    requiredVersion as int,
    message as string
};

/**
 * A game server Steam knows about at some IP address.
 *
 * @field address {string} the server's `ip:port` as Steam reports it
 * @field appId {int} the game it runs
 * @field gameDir {string} the game's directory name, e.g. "tf"
 * @field region {int} Steam's region code
 * @field gamePort {int} the port clients connect to
 * @field specPort {int} the SourceTV port, 0 when there is none
 * @field secure {bool} whether VAC is enabled
 * @field lan {bool} whether the server is marked LAN-only
 */
export def struct GameServer {
    address as string,
    appId as int,
    gameDir as string,
    region as int,
    gamePort as int,
    specPort as int,
    secure as bool,
    lan as bool
};

/**
 * The Steam Web API's clock, for checking a local clock against Steam's
 * timestamps.
 *
 * @field serverTime {int} Unix time at Steam
 * @field serverTimeString {string} the same instant, formatted by Steam
 */
export def struct ServerInfo {
    serverTime as int,
    serverTimeString as string
};

/**
 * One method of one Web API interface, as Steam documents it.
 *
 * @field interfaceName {string} the interface, e.g. "ISteamUser"
 * @field name {string} the method, e.g. "GetPlayerSummaries"
 * @field version {int} the method version
 * @field httpMethod {string} "GET" or "POST"
 * @field parameters {list of string} the parameter names it accepts
 */
export def struct ApiMethod {
    interfaceName as string,
    name as string,
    version as int,
    httpMethod as string,
    parameters as list of string
};

/**
 * Read one page of Steam's game catalogue from `IStoreService/GetAppList`
 * (games only: no DLC, software, videos or hardware). Valve retired the
 * keyless `ISteamApps/GetAppList`, which now answers 404. Pass `lastAppId`
 * 0 for the first page, then the previous page's `lastAppId`.
 *
 * @param c {Client} an API client with a key
 * @param lastAppId {int} resume after this app id; 0 to start
 * @param maxResults {int} how many entries to ask for, 1 to 50000
 * @return {AppListPage} the page and where to resume
 * @throws {Error} kind "steam" without a key, on a negative `lastAppId`, on
 *                 a page size outside 1-50000, or on a transport failure
 */
export func appListPage(c as Client, lastAppId as int, maxResults as int) {
    requireKey($c, "reading the app catalogue");
    if ($lastAppId < 0) {
        raiseError("the resume app id must not be negative");
    }
    ensureCount($maxResults, "results");
    if ($maxResults > APPLIST_PAGE_MAX) {
        raiseError("at most " + convert.toString(APPLIST_PAGE_MAX) +
            " apps fit in one page, got " + convert.toString($maxResults));
    }
    def params as map of string to string init {
        "include_games": "true",
        "include_dlc": "false",
        "include_software": "false",
        "include_videos": "false",
        "include_hardware": "false",
        "last_appid": convert.toString($lastAppId),
        "max_results": convert.toString($maxResults)
    };
    def body as json.Value init apiGet($c, "IStoreService", "GetAppList", 1, $params);
    return appListPageFrom($body);
}

/**
 * Download Steam's game catalogue, walking `appListPage` in pages of
 * `APPLIST_PAGE_MAX` until Steam has no more or `maxPages` is reached. The
 * catalogue runs to several pages, so keep the result; `findApps` and
 * `appById` search it in memory.
 *
 * @param c {Client} an API client with a key
 * @param maxPages {int} stop after this many pages, however much is left
 * @return {list of App} the catalogue, ascending by app id
 * @throws {Error} kind "steam" without a key, on a non-positive page
 *                 budget, or on a transport failure
 * @example
 *   def catalogue as list of steam.App init steam.appList($c, 20);
 *   for (def a in steam.findApps($catalogue, "portal")) {
 *       io.printf("%d|pad=7  %s\n", $a.appId, $a.name);
 *   }
 */
export func appList(c as Client, maxPages as int) {
    ensureCount($maxPages, "pages");
    def out as list of App init [];
    def cursor as int init 0;
    for (def page in 0..$maxPages) {
        def batch as AppListPage init appListPage($c, $cursor, APPLIST_PAGE_MAX);
        for (def a in $batch.apps) {
            $out[] = $a;
        }
        if (not $batch.haveMore or $batch.lastAppId <= $cursor) {
            break;
        }
        $cursor = $batch.lastAppId;
    }
    return $out;
}

/**
 * Search a downloaded catalogue by name, case-insensitively.
 *
 * @param apps {list of App} a catalogue from `appList`
 * @param term {string} the substring to look for
 * @return {list of App} every app whose name contains the term
 * @throws {Error} kind "steam" when the term is blank
 */
export func findApps(apps as list of App, term as string) {
    def needle as string init strings.lower(ensureText($term, "search term"));
    def hits as list of App init [];
    for (def a in $apps) {
        if (strings.contains(strings.lower($a.name), $needle)) {
            $hits[] = $a;
        }
    }
    return $hits;
}

/**
 * Look one app id up in a downloaded catalogue.
 *
 * @param apps {list of App} a catalogue from `appList`
 * @param appId {int} the id to find
 * @return {App} the entry, or an app with id 0 and no name when absent
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func appById(apps as list of App, appId as int) {
    ensureAppId($appId);
    for (def a in $apps) {
        if ($a.appId == $appId) {
            return $a;
        }
    }
    return App{appId: 0, name: ""};
}

/**
 * Ask Steam whether a game client version is still current. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game
 * @param version {int} the client version to check
 * @return {VersionCheck} Steam's verdict
 * @throws {Error} kind "steam" on a bad app id, a negative version, or a
 *                 transport failure
 */
export func upToDateCheck(c as Client, appId as int, version as int) {
    if ($version < 0) {
        raiseError("the client version must not be negative");
    }
    def params as map of string to string init {
        "appid": convert.toString(ensureAppId($appId)),
        "version": convert.toString($version)
    };
    def body as json.Value init apiGet($c, "ISteamApps", "UpToDateCheck", 1, $params);
    return VersionCheck{
        upToDate: nodeBool($body, "/response/up_to_date"),
        versionIsListable: nodeBool($body, "/response/version_is_listable"),
        requiredVersion: nodeInt($body, "/response/required_version"),
        message: nodeString($body, "/response/message")
    };
}

/**
 * List the game servers Steam sees at one address. Keyless. An address
 * alone lists every server on the host; `:port` narrows it to one.
 *
 * @param c {Client} an API client, with or without a key
 * @param address {string} an IP address, optionally with `:port`
 * @return {list of GameServer} the servers Steam knows there
 * @throws {Error} kind "steam" on a blank address or a transport failure
 */
export func serversAtAddress(c as Client, address as string) {
    def params as map of string to string init {"addr": ensureText($address, "server address")};
    def body as json.Value init apiGet($c, "ISteamApps", "GetServersAtAddress", 1, $params);
    def out as list of GameServer init [];
    for (def i in 0..nodeLength($body, "/response/servers")) {
        $out[] = gameServerFrom(nodeItem($body, "/response/servers", $i));
    }
    return $out;
}

/**
 * Read the Steam Web API's clock.
 *
 * @param c {Client} an API client, with or without a key
 * @return {ServerInfo} Steam's current time
 * @throws {Error} kind "steam" on a transport failure
 */
export func serverInfo(c as Client) {
    def body as json.Value init apiGet($c, "ISteamWebAPIUtil", "GetServerInfo", 1, {});
    return ServerInfo{
        serverTime: nodeInt($body, "/servertime"),
        serverTimeString: nodeString($body, "/servertimestring")
    };
}

/**
 * List every Web API method the client may call: the public surface
 * without a key, plus the publisher methods a key unlocks.
 *
 * @param c {Client} an API client, with or without a key
 * @return {list of ApiMethod} every method, flattened across interfaces
 * @throws {Error} kind "steam" on a transport failure
 */
export func supportedApiList(c as Client) {
    def body as json.Value init apiGet($c, "ISteamWebAPIUtil", "GetSupportedAPIList", 1, {});
    def out as list of ApiMethod init [];
    for (def i in 0..nodeLength($body, "/apilist/interfaces")) {
        def base as string init "/apilist/interfaces/" + convert.toString($i);
        def name as string init nodeString($body, $base + "/name");
        for (def j in 0..nodeLength($body, $base + "/methods")) {
            def mptr as string init $base + "/methods/" + convert.toString($j);
            $out[] = ApiMethod{
                interfaceName: $name,
                name: nodeString($body, $mptr + "/name"),
                version: nodeInt($body, $mptr + "/version"),
                httpMethod: nodeString($body, $mptr + "/httpmethod"),
                parameters: nodeFieldList($body, $mptr + "/parameters", "name")
            };
        }
    }
    return $out;
}

/**
 * The store page URL of an app.
 *
 * @param appId {int} the application id
 * @return {string} e.g. "https://store.steampowered.com/app/440"
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func storePageUrl(appId as int) {
    return STORE_BASE + "/app/" + convert.toString(ensureAppId($appId));
}

/**
 * The header image of an app (`header.jpg`, the store page banner).
 *
 * @param appId {int} the application id
 * @return {string} the image URL
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func headerImageUrl(appId as int) {
    return appImageUrl($appId, "header.jpg");
}

/**
 * The small capsule image of an app (`capsule_231x87.jpg`).
 *
 * @param appId {int} the application id
 * @return {string} the image URL
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func capsuleImageUrl(appId as int) {
    return appImageUrl($appId, "capsule_231x87.jpg");
}

/**
 * Build the URL of one of an app's published images.
 *
 * @param appId {int} the application id
 * @param file {string} the file name under the app's media directory
 * @return {string} the image URL
 * @throws {Error} kind "steam" when the app id is not positive or the file
 *                 name is blank
 * @internal
 */
func appImageUrl(appId as int, file as string) {
    return MEDIA_BASE + "/steam/apps/" + convert.toString(ensureAppId($appId)) + "/" +
        ensureText($file, "image file name");
}

/**
 * Fold a `GetAppList` reply into a page.
 *
 * @param body {json.Value} the decoded response
 * @return {AppListPage} the folded page
 * @internal
 */
func appListPageFrom(body as json.Value) {
    def apps as list of App init [];
    for (def i in 0..nodeLength($body, "/response/apps")) {
        def node as json.Value init nodeItem($body, "/response/apps", $i);
        $apps[] = App{appId: nodeInt($node, "/appid"), name: nodeString($node, "/name")};
    }
    return AppListPage{
        apps: $apps,
        lastAppId: nodeInt($body, "/response/last_appid"),
        haveMore: nodeBool($body, "/response/have_more_results")
    };
}

/**
 * Fold one `GetServersAtAddress` row into a struct.
 *
 * @param node {json.Value} one element of the `servers` list
 * @return {GameServer} the folded server
 * @internal
 */
func gameServerFrom(node as json.Value) {
    return GameServer{
        address: nodeString($node, "/addr"),
        appId: nodeInt($node, "/appid"),
        gameDir: nodeString($node, "/gamedir"),
        region: nodeInt($node, "/region"),
        gamePort: nodeInt($node, "/gameport"),
        specPort: nodeInt($node, "/specport"),
        secure: nodeBool($node, "/secure"),
        lan: nodeBool($node, "/lan")
    };
}
