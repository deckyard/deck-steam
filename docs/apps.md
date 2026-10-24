# Apps - the catalogue, versions, servers

`IStoreService` (the catalogue), `ISteamApps` (version checks, servers) and
`ISteamWebAPIUtil` (the API's own metadata).

## The catalogue

Valve retired the keyless `ISteamApps/GetAppList/v2`; it answers 404,
though much code online still calls it. The replacement,
`IStoreService/GetAppList/v1`, needs a key and is paginated. This deck asks
it for games only: no DLC, software, videos or hardware.

```jennifer
def catalogue as list of steam.App init steam.appList($c, 20);   # at most 20 pages
io.printf("%d apps\n", len($catalogue));
```

`appList` reads pages of `APPLIST_PAGE_MAX` (50000), the largest Steam
serves, until none are left or the page budget is spent. The catalogue runs
to several pages, so keep the result and search it in memory:

```jennifer
for (def a in steam.findApps($catalogue, "portal")) {
    io.printf("%d|pad=8  %s\n", $a.appId, $a.name);
}
io.printf("%s\n", steam.appById($catalogue, 620).name);
```

`findApps` matches a case-insensitive substring. `appById` returns an `App`
with id 0 and name `""` when nothing matches.

To resume across runs, page with `appListPage` directly (`lastAppId` 0 for
the first page):

```jennifer
def page as steam.AppListPage init steam.appListPage($c, $cursor, 10000);
$cursor = $page.lastAppId;
```

## Version checks (keyless)

The check a launcher makes before letting a player connect:

```jennifer
def v as steam.VersionCheck init steam.upToDateCheck($c, 440, 1);
io.printf("current: %t, required %d - %s\n",
    $v.upToDate, $v.requiredVersion, $v.message);
```

## Game servers at an address (keyless)

```jennifer
for (def s in steam.serversAtAddress($c, "208.78.164.10")) {
    io.printf("%s runs app %d (%s), VAC %t\n",
        $s.address, $s.appId, $s.gameDir, $s.secure);
}
```

An address alone lists every server on the host; `:port` narrows it to one.
An address with no servers gives an empty list.

## Image URLs (no request)

```jennifer
steam.storePageUrl(620);      # https://store.steampowered.com/app/620
steam.headerImageUrl(620);    # .../steam/apps/620/header.jpg
steam.capsuleImageUrl(620);   # .../steam/apps/620/capsule_231x87.jpg
```

They are built from the app id, so they work for an app the storefront has
no record for.

## What a key can call

```jennifer
for (def m in steam.supportedApiList($c)) {
    io.printf("%s.%s v%d %s\n", $m.interfaceName, $m.name, $m.version, $m.httpMethod);
}
```

Without a key this lists the public methods; with one it adds the publisher
methods that key unlocks. It also shows when an endpoint you rely on has
gone.

`serverInfo($c)` reads Steam's clock, to check a local clock before
comparing it with Steam's Unix times.

See [`examples/apps.j`](https://github.com/deckyard/deck-steam/blob/main/examples/apps.j).
