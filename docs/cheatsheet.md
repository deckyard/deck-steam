# Cheatsheet

Every export, by topic. The guides linked from [the introduction](index.md)
explain the background; this page lists signatures, values and fields.

```jennifer
import "@deckyard/steam/" as steam;
def c as steam.Client init steam.client("YOUR-KEY");   # "" for the keyless endpoints
```

Every failure is `Error{kind: "steam"}`. Each call that takes a `Client`
also throws on a transport failure or a non-JSON reply; the Notes column
lists the other conditions. Arguments are checked before any request.

## Which calls need a key

Get a key at <https://steamcommunity.com/dev/apikey>. Valve rate-limits per
key. A key-gated call on a keyless client throws before any request.

| Keyless | Needs a key |
| ------- | ----------- |
| `newsForApp`, `newsForAppFeeds` | `playerSummaries`, `playerSummary`, `friendList`, `playerBans`, `playerBan`, `resolveVanityUrl`, `userGroups` |
| `currentPlayers`, `globalAchievementRarity` | `ownedGames`, `ownedGameCount`, `recentlyPlayedGames`, `steamLevel`, `badges`, `badgeProgress`, `sharedGameLender` |
| `appDetails`, `appDetailsMany`, `appPrices`, `packageDetails`, `featured` | `playerAchievements`, `userStats`, `gameSchema` |
| `priceOverview` | `appList`, `appListPage` |
| `publishedFileDetails`, `publishedFile`, `collectionDetails`, `collectionItems` | `tradeOffersSummary`, `tradeOffers`, `tradeOffer`, `assetPrices` |
| `upToDateCheck`, `serversAtAddress`, `serverInfo`, `supportedApiList` | `gameServerAccounts`, `gameServerInfo`, `queryLoginToken` |
| `resolveAccount` with an id | `resolveAccount` with a vanity name |

`call` sends the key when the client has one. The id, URL, money and markup
helpers make no request.

## Client

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `client(apiKey)` | `Client` | key trimmed; English, US, USD, 15000 ms timeout, 2 retries, 500 ms backoff; `STEAM_VERBOSE` = 1, true, yes or on sets `verbose` |
| `clientFromEnv()` | `Client` | `client(STEAM_API_KEY)`, then `STEAM_LANGUAGE` and `STEAM_COUNTRY` when not blank; throws when `STEAM_COUNTRY` is not two letters |
| `withLanguage(c, language)` | `Client` | lowercased; throws when blank |
| `withCountry(c, countryCode)` | `Client` | uppercased; throws unless two letters |
| `withCurrency(c, currency)` | `Client` | a `CURRENCY_*` id; throws unless positive |
| `withTimeout(c, timeoutMs)` | `Client` | idle timeout per read; 0 means http's 30000 ms, not `DEFAULT_TIMEOUT_MS`; throws when negative |
| `withRetries(c, retries)` | `Client` | retries of a 429 or 5xx; 0 disables; throws when negative |
| `withBackoff(c, backoffMs)` | `Client` | first retry delay, doubled per attempt, raised to a numeric `Retry-After`, capped at 30 s; 0 means http's 250 ms, not `DEFAULT_BACKOFF_MS`; throws when negative |
| `setVerbose(c, enabled)` | `Client` | print each request before sending it |
| `isVerbose(c)` | `bool` | |
| `hasKey(c)` | `bool` | true for a non-empty key |
| `call(c, service, method, version, params)` | `json.Value` | GET any Web API method; throws when a name is not letter-initial letters and digits, the version is not positive, or the status is not 2xx |

Builders return a copy: `$c = steam.withCountry($c, "DE");`.

Verbose output, one line per request. `key`, `access_token`, `token` and
`login_token` print as `<redacted>`:

```
steam> GET https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?steamids=76561197960287930&key=<redacted>
steam> POST https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/?itemcount=1&publishedfileids%5B0%5D=450814997
```

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `API_BASE` | `"https://api.steampowered.com"` | Web API host |
| `STORE_BASE` | `"https://store.steampowered.com"` | storefront host |
| `COMMUNITY_BASE` | `"https://steamcommunity.com"` | community host (profiles, market, Workshop) |
| `MEDIA_BASE` | `"https://cdn.akamai.steamstatic.com"` | artwork host |
| `DEFAULT_TIMEOUT_MS` | `15000` | a new client's idle timeout |
| `DEFAULT_RETRIES` | `2` | a new client's retry budget |
| `DEFAULT_BACKOFF_MS` | `500` | a new client's first retry delay |
| `MAX_RESPONSE_BYTES` | `33554432` | body cap (32 MiB) |
| `CURRENCY_USD` | `1` | US dollar, a new client's currency |
| `CURRENCY_GBP` | `2` | pound sterling |
| `CURRENCY_EUR` | `3` | euro |
| `CURRENCY_CHF` | `4` | Swiss franc |
| `CURRENCY_RUB` | `5` | Russian rouble |
| `CURRENCY_PLN` | `6` | Polish zloty |
| `CURRENCY_BRL` | `7` | Brazilian real |
| `CURRENCY_JPY` | `8` | Japanese yen |
| `CURRENCY_CAD` | `20` | Canadian dollar |
| `CURRENCY_AUD` | `21` | Australian dollar |

### `Client`

| Field | Meaning |
| ----- | ------- |
| `key as string` | Web API key, "" for keyless use |
| `language as string` | `l` / `language` parameter, e.g. "english" |
| `countryCode as string` | storefront country, e.g. "US" |
| `currency as int` | wallet currency id for market prices |
| `timeoutMs as int` | idle timeout in milliseconds |
| `retries as int` | retry budget for a 429 or 5xx |
| `backoffMs as int` | first retry delay in milliseconds |
| `verbose as bool` | print requests |

## Steam ids

Every `steamId` argument in the deck accepts all three notations.

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `parseSteamId(id64)` | `SteamId` | throws when not a 64-bit id |
| `toSteamId64(parts)` | `string` | ignores `parts.id64`; throws when a field is outside the range Steam issues |
| `isSteamId(text)` | `bool` | 17 to 20 digits, universe 1-5, account type at most 10 |
| `isSteamId64(text)` | `bool` | a personal account only |
| `looksLikeSteamId(text)` | `bool` | `normalizeSteamId` would accept it |
| `normalizeSteamId(text)` | `string` | any notation to the id64; throws when none fits |
| `toSteamId2(id64)` | `string` | `"STEAM_1:0:11101"`; throws for a non-personal account |
| `toSteamId3(id64)` | `string` | `"[U:1:22202]"`; a group is `[g:1:W]` |
| `fromSteamId2(text)` | `string` | `STEAM_0` reads as universe 1 |
| `fromSteamId3(text)` | `string` | brackets optional; honours `[U:1:W:instance]` |
| `accountId(id64)` | `int` | the 32-bit account number ("friend id") |
| `steamId64FromAccountId(account)` | `string` | personal account; throws outside 1 to 4294967295 |
| `profileUrl(id64)` | `string` | `https://steamcommunity.com/profiles/<id64>`; any notation |
| `vanityProfileUrl(vanity)` | `string` | `https://steamcommunity.com/id/<name>`, name percent-encoded |
| `groupUrl(id64)` | `string` | `https://steamcommunity.com/gid/<id64>` |
| `accountTypeName(accountType)` | `string` | "individual", "group", ...; "unknown" outside 0-10 |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `INDIVIDUAL_BASE` | `76561197960265728` | id64 of personal account number 0 |
| `CLAN_BASE` | `103582791429521408` | id64 of group number 0 |
| `UNIVERSE_PUBLIC` | `1` | the public universe |
| `UNIVERSE_MAX` | `5` | highest universe Steam issues |
| `ACCOUNT_INDIVIDUAL` | `1` | a person |
| `ACCOUNT_MULTISEAT` | `2` | multiseat (cyber-cafe) account |
| `ACCOUNT_GAME_SERVER` | `3` | persistent game server |
| `ACCOUNT_ANON_GAME_SERVER` | `4` | anonymous game server |
| `ACCOUNT_CONTENT_SERVER` | `6` | content server |
| `ACCOUNT_CLAN` | `7` | group |
| `ACCOUNT_CHAT` | `8` | chat room |
| `ACCOUNT_ANON_USER` | `10` | anonymous user |

### `SteamId`

| Field | Meaning |
| ----- | ------- |
| `id64 as string` | 17-digit decimal id |
| `universe as int` | bits 56-63; 1 = public |
| `accountType as int` | bits 52-55; 1 = individual, 7 = group |
| `instance as int` | bits 32-51; 1 for a desktop account |
| `accountId as int` | bits 0-31, the "friend id" |

```jennifer
steam.toSteamId2("76561197960287930");     # STEAM_1:0:11101
steam.fromSteamId3("[g:1:4]");             # 103582791429521412 (a group)
steam.accountTypeName(steam.parseSteamId("103582791429521412").accountType);   # group
```

## Users (`ISteamUser`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `playerSummaries(c, steamIds)` | `list of PlayerSummary` | 1 to 100 ids; unknown accounts are left out |
| `playerSummary(c, steamId)` | `PlayerSummary` | throws when the account is unknown |
| `friendList(c, steamId)` | `list of Friend` | oldest first; empty when private |
| `playerBans(c, steamIds)` | `list of PlayerBan` | 1 to 100 ids |
| `playerBan(c, steamId)` | `PlayerBan` | throws when there is no record |
| `resolveVanityUrl(c, vanity)` | `string` | id64, "" when no profile has the name |
| `resolveAccount(c, text)` | `string` | id in any notation, vanity name or `/id/<name>` URL; only a vanity name costs a request; throws when nothing matches |
| `userGroups(c, steamId)` | `list of string` | group id64s; empty when private |
| `personaStateName(state)` | `string` | "offline", "online", "busy", ...; "unknown" otherwise |
| `visibilityName(visibility)` | `string` | "private", "friends only", "public"; "unknown" otherwise |
| `isPublic(player)` | `bool` | `communityVisibilityState` is `VISIBILITY_PUBLIC` |
| `isOnline(player)` | `bool` | any state but offline |
| `isInGame(player)` | `bool` | `gameId` is neither "" nor "0" |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `PERSONA_OFFLINE` | `0` | signed out |
| `PERSONA_ONLINE` | `1` | signed in |
| `PERSONA_BUSY` | `2` | busy |
| `PERSONA_AWAY` | `3` | away |
| `PERSONA_SNOOZE` | `4` | idle long enough to snooze |
| `PERSONA_LOOKING_TO_TRADE` | `5` | looking to trade |
| `PERSONA_LOOKING_TO_PLAY` | `6` | looking to play |
| `VISIBILITY_PRIVATE` | `1` | only the account itself |
| `VISIBILITY_FRIENDS` | `2` | friends |
| `VISIBILITY_PUBLIC` | `3` | everyone |
| `RELATIONSHIP_FRIEND` | `"friend"` | the friend-list relationship |
| `SUMMARY_BATCH` | `100` | largest `playerSummaries` / `playerBans` batch |

### `PlayerSummary`

Only `steamId`, `personaName`, `profileUrl`, the avatars and `personaState`
are guaranteed. The rest is filled in only for a public profile that
publishes the field, so "" or 0 means "not shared".

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | id64 |
| `personaName as string` | display name |
| `profileUrl as string` | community profile URL |
| `avatar as string` | 32x32 avatar URL |
| `avatarMedium as string` | 64x64 avatar URL |
| `avatarFull as string` | 184x184 avatar URL |
| `avatarHash as string` | hash shared by the avatar URLs |
| `personaState as int` | a `PERSONA_*` value |
| `communityVisibilityState as int` | a `VISIBILITY_*` value |
| `profileState as int` | 1 once a community profile is configured |
| `lastLogoff as int` | Unix time of the last sign-out |
| `commentPermission as int` | non-zero when strangers may comment |
| `realName as string` | real name |
| `primaryClanId as string` | id64 of the primary group |
| `timeCreated as int` | Unix time the account was created |
| `personaStateFlags as int` | client flags |
| `countryCode as string` | two-letter country |
| `stateCode as string` | region within the country |
| `cityId as int` | Steam's city id |
| `gameId as string` | app being played, "" or "0" when none |
| `gameExtraInfo as string` | title being played |
| `gameServerIp as string` | server being played on |

### `Friend`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | the friend's id64 |
| `relationship as string` | "friend" |
| `friendSince as int` | Unix time of the friendship |

### `PlayerBan`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | id64 |
| `communityBanned as bool` | banned from community features |
| `vacBanned as bool` | at least one VAC ban |
| `vacBans as int` | VAC bans across all games |
| `gameBans as int` | developer-issued game bans |
| `daysSinceLastBan as int` | 0 when never banned |
| `economyBan as string` | "none", "probation" or "banned" |

## Player (`IPlayerService`)

These need the account's game details to be public; a private library comes
back empty, not as an error.

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `ownedGames(c, steamId, includeAppInfo, includeFreeGames)` | `list of OwnedGame` | `includeAppInfo` adds name and icon; without `includeFreeGames` played free-to-play titles are left out |
| `ownedGameCount(c, steamId)` | `int` | counts played free-to-play titles; 0 when private |
| `recentlyPlayedGames(c, steamId, count)` | `list of OwnedGame` | last two weeks, most recent first; throws unless `count` is positive |
| `steamLevel(c, steamId)` | `int` | 0 when hidden |
| `badges(c, steamId)` | `BadgeCollection` | |
| `badgeProgress(c, steamId, badgeId)` | `list of BadgeQuest` | throws unless `badgeId` is positive |
| `sharedGameLender(c, steamId, appId)` | `string` | the Family Sharing lender's id64, "" when owned |
| `playtimeHours(minutes)` | `float` | hours, rounded to one decimal |
| `totalPlaytime(games)` | `int` | sum of `playtimeForever`, minutes |
| `mostPlayed(games, count)` | `list of OwnedGame` | longest `playtimeForever` first; throws unless `count` is positive |
| `unplayed(games)` | `list of OwnedGame` | zero `playtimeForever` |
| `gameIconUrl(appId, iconHash)` | `string` | "" for an empty hash |

### `OwnedGame`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | app id |
| `name as string` | title, "" without app info |
| `playtimeForever as int` | lifetime minutes |
| `playtimeTwoWeeks as int` | minutes in the last two weeks |
| `playtimeWindows as int` | lifetime minutes on Windows |
| `playtimeMac as int` | lifetime minutes on macOS |
| `playtimeLinux as int` | lifetime minutes on Linux |
| `playtimeDeck as int` | lifetime minutes on a Steam Deck |
| `iconHash as string` | icon hash for `gameIconUrl`, "" without app info |
| `hasCommunityVisibleStats as bool` | the game publishes stats |
| `lastPlayed as int` | Unix time of the last launch, 0 when never |

### `Badge`

| Field | Meaning |
| ----- | ------- |
| `badgeId as int` | badge id |
| `appId as int` | app, 0 for a Steam-wide badge |
| `level as int` | badge level |
| `completionTime as int` | Unix time the level was reached |
| `xp as int` | experience it is worth |
| `scarcity as int` | accounts holding it |
| `communityItemId as string` | community item id |
| `borderColor as int` | 1 for a foil badge |

### `BadgeCollection`

| Field | Meaning |
| ----- | ------- |
| `playerLevel as int` | Steam level |
| `playerXp as int` | total experience |
| `xpNeededToLevelUp as int` | experience missing for the next level |
| `xpNeededCurrentLevel as int` | experience the current level started at |
| `badges as list of Badge` | every badge held |

### `BadgeQuest`

| Field | Meaning |
| ----- | ------- |
| `questId as int` | task id |
| `completed as bool` | done |

## Stats (`ISteamUserStats`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `playerAchievements(c, steamId, appId)` | `PlayerAchievements` | localized; throws when Steam refuses (private profile, unowned game, no stats) |
| `userStats(c, steamId, appId)` | `list of StatValue` | empty when the game keeps none |
| `globalAchievementRarity(c, appId)` | `list of AchievementRarity` | keyless; internal names |
| `currentPlayers(c, appId)` | `int` | keyless; throws when Steam has no count |
| `gameSchema(c, appId)` | `GameSchema` | localized |
| `unlockedCount(achievements)` | `int` | |
| `completionPercent(achievements)` | `float` | 0.0 to 100.0; 0.0 for none |
| `lockedAchievements(achievements)` | `list of Achievement` | not yet earned |
| `rarest(rarities, count)` | `list of AchievementRarity` | lowest percentage first; throws unless `count` is positive |

### `Achievement`

| Field | Meaning |
| ----- | ------- |
| `apiName as string` | internal name |
| `achieved as bool` | unlocked |
| `unlockTime as int` | Unix time, 0 while locked |
| `name as string` | display name |
| `description as string` | "" while a hidden achievement is locked |

### `PlayerAchievements`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | account |
| `appId as int` | game |
| `gameName as string` | title |
| `achievements as list of Achievement` | every achievement, locked or not |

### `StatValue`

| Field | Meaning |
| ----- | ------- |
| `name as string` | internal name |
| `value as int` | current value |

### `AchievementRarity`

| Field | Meaning |
| ----- | ------- |
| `name as string` | internal name, to join with `SchemaAchievement.name` |
| `percent as float` | share of players, 0-100 |

### `SchemaAchievement`

| Field | Meaning |
| ----- | ------- |
| `name as string` | internal name |
| `displayName as string` | localized title |
| `description as string` | localized description, "" when hidden |
| `hidden as bool` | description withheld until unlocked |
| `icon as string` | unlocked icon URL |
| `iconGray as string` | locked icon URL |

### `SchemaStat`

| Field | Meaning |
| ----- | ------- |
| `name as string` | internal name |
| `displayName as string` | localized label, "" when none |
| `defaultValue as int` | starting value |

### `GameSchema`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | game |
| `gameName as string` | title |
| `gameVersion as string` | schema version |
| `achievements as list of SchemaAchievement` | defined achievements |
| `stats as list of SchemaStat` | defined statistics |

## Apps (`IStoreService`, `ISteamApps`, `ISteamWebAPIUtil`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `appListPage(c, lastAppId, maxResults)` | `AppListPage` | games only; `lastAppId` 0 to start; `maxResults` 1 to 50000 |
| `appList(c, maxPages)` | `list of App` | pages of 50000 until none are left or `maxPages` is reached |
| `findApps(apps, term)` | `list of App` | case-insensitive substring; throws on a blank term |
| `appById(apps, appId)` | `App` | `appId` 0 and name "" when absent |
| `upToDateCheck(c, appId, version)` | `VersionCheck` | keyless; throws on a negative version |
| `serversAtAddress(c, address)` | `list of GameServer` | keyless; `ip` or `ip:port`; empty when none |
| `serverInfo(c)` | `ServerInfo` | keyless |
| `supportedApiList(c)` | `list of ApiMethod` | the public methods, plus those the key unlocks |
| `storePageUrl(appId)` | `string` | `https://store.steampowered.com/app/<id>` |
| `headerImageUrl(appId)` | `string` | `<MEDIA_BASE>/steam/apps/<id>/header.jpg` |
| `capsuleImageUrl(appId)` | `string` | `<MEDIA_BASE>/steam/apps/<id>/capsule_231x87.jpg` |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `APPLIST_PAGE_MAX` | `50000` | largest catalogue page |

### `App`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | app id |
| `name as string` | name |

### `AppListPage`

| Field | Meaning |
| ----- | ------- |
| `apps as list of App` | the entries |
| `lastAppId as int` | pass as `lastAppId` for the next page |
| `haveMore as bool` | another page follows |

### `VersionCheck`

| Field | Meaning |
| ----- | ------- |
| `upToDate as bool` | the version is current |
| `versionIsListable as bool` | Steam still lists it |
| `requiredVersion as int` | lowest version allowed to connect |
| `message as string` | Steam's explanation, "" when none |

### `GameServer`

| Field | Meaning |
| ----- | ------- |
| `address as string` | `ip:port` |
| `appId as int` | game |
| `gameDir as string` | game directory, e.g. "tf" |
| `region as int` | Steam region code |
| `gamePort as int` | client port |
| `specPort as int` | SourceTV port, 0 when none |
| `secure as bool` | VAC enabled |
| `lan as bool` | LAN-only |

### `ServerInfo`

| Field | Meaning |
| ----- | ------- |
| `serverTime as int` | Unix time at Steam |
| `serverTimeString as string` | the same, formatted by Steam |

### `ApiMethod`

| Field | Meaning |
| ----- | ------- |
| `interfaceName as string` | e.g. "ISteamUser" |
| `name as string` | e.g. "GetPlayerSummaries" |
| `version as int` | method version |
| `httpMethod as string` | "GET" or "POST" |
| `parameters as list of string` | parameter names |

## News (`ISteamNews`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `newsForApp(c, appId, count, maxLength)` | `list of NewsItem` | newest first; `maxLength` 0 for whole bodies; throws unless `count` is positive or when `maxLength` is negative |
| `newsForAppFeeds(c, appId, count, maxLength, feeds)` | `list of NewsItem` | as `newsForApp`, from comma-separated `feeds` ("" for all) |
| `plainText(markup)` | `string` | strips HTML and BBCode, see [news](news.md) |
| `summarize(text, maxChars)` | `string` | at most `maxChars` characters, cut at a word, ending in one `…`; throws unless `maxChars` is positive |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `FEED_ANNOUNCEMENTS` | `"steam_community_announcements"` | the game's own announcements |
| `FEED_STEAM` | `"steam_updates"` | Steam's editorial posts |
| `MARKUP_SPAN` | `512` | longest run, in code points, `plainText` reads as one tag |
| `BLOCK_TAGS` | br, p, div, li, ul, ol, tr, td, th, table, blockquote, h1-h6, hr, pre, list, olist, quote, code, `*` | tags `plainText` replaces with a space |
| `BBCODE_TAGS` | b, i, u, s, strike, url, img, list, olist, `*`, quote, code, noparse, h1-h3, hr, spoiler, table, tr, th, td, previewyoutube, dynamiclink, carousel, expand, video, steamwidget, randomboxes | BBCode tags `plainText` removes |
| `CLAN_IMAGE_TOKENS` | `{STEAM_CLAN_LOC_IMAGE}`, `{STEAM_CLAN_IMAGE}` | image embeds `plainText` drops with their path |

### `NewsItem`

| Field | Meaning |
| ----- | ------- |
| `gid as string` | unique id |
| `title as string` | headline |
| `url as string` | where to read it |
| `isExternalUrl as bool` | `url` leaves Steam |
| `author as string` | poster, "" when none |
| `contents as string` | body, HTML and/or BBCode |
| `feedLabel as string` | feed label, e.g. "Community Announcements" |
| `feedName as string` | feed name for `feeds`, e.g. "steam_community_announcements" |
| `feedType as int` | Steam's feed type |
| `date as int` | Unix time posted |
| `appId as int` | game |

## Store (`store.steampowered.com`)

Keyless and regional: the client's `countryCode` and `language` go with every
request. One request per app id.

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `appDetails(c, appId)` | `AppDetails` | throws when there is no record (delisted, region-locked, not an app) |
| `appDetailsMany(c, appIds)` | `list of AppDetails` | ids without a record are left out |
| `appPrices(c, appIds)` | `list of AppPrice` | one entry per id, `found` false without a record; throws on an empty list |
| `packageDetails(c, packageId)` | `PackageDetails` | throws unless positive, or when there is no record |
| `featured(c)` | `FeaturedLists` | |
| `isDiscounted(price)` | `bool` | `discountPercent` > 0 and `final` < `initial` |
| `savings(price)` | `int` | `initial` - `final` in minor units, 0 when not discounted |
| `majorUnits(minorUnits)` | `float` | divided by 100, yen included |
| `discountLabel(price)` | `string` | e.g. "-66%", "" when not discounted |

The id lists are checked in full before the first request; a transport
failure throws rather than shortening the list.

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `APPDETAILS_PATH` | `"/api/appdetails"` | app record path |
| `PACKAGEDETAILS_PATH` | `"/api/packagedetails"` | package record path |
| `FEATURED_PATH` | `"/api/featured"` | featured lists path |

### `Price`

Amounts are ints in minor units. A free or unreleased title has a zeroed
`Price`.

| Field | Meaning |
| ----- | ------- |
| `currency as string` | ISO code, e.g. "EUR" |
| `initial as int` | undiscounted price |
| `final as int` | current price |
| `discountPercent as int` | 0 when none |
| `initialFormatted as string` | Steam's rendering of `initial`, "" at full price |
| `finalFormatted as string` | Steam's rendering of `final`, the one to show |

### `Platforms`

| Field | Meaning |
| ----- | ------- |
| `windows as bool` | Windows build |
| `mac as bool` | macOS build |
| `linux as bool` | native Linux build (Proton not counted) |

### `AppDetails`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | app id |
| `name as string` | title |
| `kind as string` | "game", "dlc", "demo", "music", ... |
| `requiredAge as int` | age gate, 0 when none |
| `isFree as bool` | costs nothing |
| `shortDescription as string` | blurb, HTML |
| `aboutTheGame as string` | long description, HTML |
| `supportedLanguages as string` | language list, HTML |
| `headerImage as string` | banner URL |
| `capsuleImage as string` | capsule URL |
| `website as string` | developer site, "" when none |
| `developers as list of string` | developers |
| `publishers as list of string` | publishers |
| `price as Price` | zeroed when free or unreleased |
| `platforms as Platforms` | builds |
| `categories as list of string` | e.g. "Multi-player" |
| `genres as list of string` | e.g. "Action" |
| `dlc as list of int` | DLC app ids |
| `metacriticScore as int` | 0 when unscored |
| `metacriticUrl as string` | "" when unscored |
| `recommendations as int` | user recommendations |
| `achievementCount as int` | achievements defined |
| `releaseDate as string` | as Steam renders it |
| `comingSoon as bool` | not yet released |

### `AppPrice`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | app id |
| `found as bool` | the storefront had a record |
| `free as bool` | free to play |
| `price as Price` | zeroed when free or not found |

### `PackageDetails`

| Field | Meaning |
| ----- | ------- |
| `packageId as int` | package id |
| `name as string` | name |
| `pageImage as string` | store image URL |
| `apps as list of App` | apps in it |
| `price as Price` | price |
| `platforms as Platforms` | builds |
| `releaseDate as string` | as Steam renders it |
| `comingSoon as bool` | not yet released |

### `FeaturedApp`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | app id |
| `name as string` | title |
| `discounted as bool` | on sale |
| `discountPercent as int` | 0 when none |
| `originalPrice as int` | undiscounted, minor units |
| `finalPrice as int` | current, minor units |
| `currency as string` | ISO code |
| `capsuleImage as string` | wide capsule URL |
| `headerImage as string` | header URL |
| `windowsAvailable as bool` | Windows build |
| `macAvailable as bool` | macOS build |
| `linuxAvailable as bool` | native Linux build |

### `FeaturedLists`

| Field | Meaning |
| ----- | ------- |
| `largeCapsules as list of FeaturedApp` | front-page banners, often empty outside a sale |
| `windows as list of FeaturedApp` | featured for Windows |
| `mac as list of FeaturedApp` | featured for macOS |
| `linux as list of FeaturedApp` | featured for Linux |

## Market (`steamcommunity.com/market`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `priceOverview(c, appId, marketHashName)` | `MarketPrice` | keyless; in the client's currency; `found` false when unpriced; roughly 20 requests a minute per address |
| `marketListingUrl(appId, marketHashName)` | `string` | name percent-encoded |
| `marketSearchUrl(appId, term)` | `string` | `term` "" browses everything |
| `currencyCode(currency)` | `string` | ISO code of a `CURRENCY_*` id, "" for any other |
| `parseMoney(text)` | `float` | last `.` or `,` is decimal when 1 or 2 digits follow; 0.0 when unreadable |
| `parseMoneyCents(text)` | `int` | `parseMoney` x 100, rounded; 0 past `MAX_MONEY_UNITS` |
| `parseCount(text)` | `int` | digits only; 0 when none or too large |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `PRICEOVERVIEW_PATH` | `"/market/priceoverview/"` | price path |
| `MAX_MONEY_UNITS` | `1.0e15` | largest amount `parseMoneyCents` scales |

### `MarketPrice`

| Field | Meaning |
| ----- | ------- |
| `found as bool` | the market had a price |
| `lowestPrice as string` | cheapest listing, as Steam formatted it |
| `medianPrice as string` | median recent sale, as Steam formatted it |
| `lowestCents as int` | `lowestPrice` in minor units |
| `medianCents as int` | `medianPrice` in minor units |
| `volume as int` | sold in the last 24 hours, 0 when Steam omits it |

## Workshop (`ISteamRemoteStorage`)

Keyless. Both lookups are form POSTs with indexed `publishedfileids[N]`
fields; Steam answers nothing else here.

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `publishedFileDetails(c, publishedFileIds)` | `list of PublishedFile` | 1 to 100 numeric ids; unknown items left out |
| `publishedFile(c, publishedFileId)` | `PublishedFile` | throws when there is no such item |
| `collectionDetails(c, collectionIds)` | `list of Collection` | 1 to 100 numeric ids; one entry per id, in order |
| `collectionItems(c, collectionId)` | `list of string` | member ids in collection order; throws when there is no such collection |
| `workshopUrl(publishedFileId)` | `string` | `https://steamcommunity.com/sharedfiles/filedetails/?id=<id>` |
| `workshopBrowseUrl(appId)` | `string` | `https://store.steampowered.com/app/<id>/workshop/` |
| `workshopVisibilityName(visibility)` | `string` | "public", "friends only", "private", "unlisted"; "unknown" otherwise |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `WORKSHOP_PUBLIC` | `0` | anyone |
| `WORKSHOP_FRIENDS` | `1` | the author's friends |
| `WORKSHOP_PRIVATE` | `2` | the author |
| `WORKSHOP_UNLISTED` | `3` | by direct link, not listed |
| `WORKSHOP_BATCH` | `100` | largest batch per request |

### `PublishedFile`

| Field | Meaning |
| ----- | ------- |
| `publishedFileId as string` | id, the number in the Workshop URL |
| `creator as string` | author's id64 |
| `creatorAppId as int` | app it was authored in |
| `consumerAppId as int` | app it is played in |
| `title as string` | title |
| `description as string` | BBCode |
| `filename as string` | stored file name |
| `fileSize as int` | bytes |
| `fileUrl as string` | direct download, "" for most items |
| `previewUrl as string` | preview image URL |
| `timeCreated as int` | Unix time published |
| `timeUpdated as int` | Unix time updated |
| `visibility as int` | a `WORKSHOP_*` value |
| `banned as bool` | banned by Valve |
| `banReason as string` | "" when not banned |
| `subscriptions as int` | current subscribers |
| `favorited as int` | current favourites |
| `lifetimeSubscriptions as int` | subscribers ever |
| `lifetimeFavorited as int` | favourites ever |
| `views as int` | page views |
| `tags as list of string` | Workshop tags |

### `CollectionItem`

| Field | Meaning |
| ----- | ------- |
| `publishedFileId as string` | member id |
| `sortOrder as int` | position |
| `fileType as int` | Steam's file-type code |

### `Collection`

| Field | Meaning |
| ----- | ------- |
| `publishedFileId as string` | the collection's id |
| `found as bool` | Steam had it |
| `items as list of CollectionItem` | members in order |

## Econ (`IEconService`, `ISteamEconomy`)

The trade calls read the key owner's own offers; there is no `steamid`
parameter. Accepting and declining are not offered: they need the mobile
confirmation flow.

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `tradeOffersSummary(c, timeCutoff)` | `TradeOffersSummary` | counts only; `timeCutoff` 0 counts everything; throws when negative |
| `tradeOffers(c, getSent, getReceived, activeOnly)` | `TradeOffers` | throws when both directions are false |
| `tradeOffer(c, tradeOfferId)` | `TradeOffer` | throws on a non-numeric id or an offer the key cannot see |
| `assetPrices(c, appId)` | `list of AssetPrice` | throws when the game has no item store |
| `tradeOfferStateName(state)` | `string` | states 1-11, "unknown" otherwise |
| `isPendingOffer(offer)` | `bool` | active (2) or awaiting confirmation (9) |
| `isOneSided(offer)` | `bool` | one side is empty |

| Constant | Value | Meaning |
| -------- | ----- | ------- |
| `TRADE_ACTIVE` | `2` | waiting for the other side |
| `TRADE_ACCEPTED` | `3` | items exchanged |
| `TRADE_CANCELED` | `6` | withdrawn by the sender |
| `TRADE_DECLINED` | `7` | turned down by the recipient |
| `TRADE_IN_ESCROW` | `11` | accepted, items in escrow |

### `TradeAsset`

| Field | Meaning |
| ----- | ------- |
| `appId as int` | game |
| `contextId as string` | inventory context |
| `assetId as string` | inventory id |
| `classId as string` | item class |
| `instanceId as string` | item instance |
| `amount as int` | count, for a stackable item |
| `missing as bool` | left the inventory since the offer; accepting fails |

### `TradeOffer`

| Field | Meaning |
| ----- | ------- |
| `tradeOfferId as string` | id |
| `otherSteamId as string` | other party's id64, widened from the 32-bit id Steam sends |
| `message as string` | note |
| `state as int` | a `TRADE_*` value or another state 1-11 |
| `isOurOffer as bool` | the key's account made it |
| `timeCreated as int` | Unix time made |
| `timeUpdated as int` | Unix time last changed |
| `expirationTime as int` | Unix time it lapses |
| `escrowEndDate as int` | Unix time escrow lifts, 0 when none |
| `toGive as list of TradeAsset` | what the key's account hands over |
| `toReceive as list of TradeAsset` | what it gets |

### `TradeOffers`

| Field | Meaning |
| ----- | ------- |
| `sent as list of TradeOffer` | made by the account |
| `received as list of TradeOffer` | made to the account |

### `TradeOffersSummary`

| Field | Meaning |
| ----- | ------- |
| `pendingReceived as int` | incoming, awaiting an answer |
| `newReceived as int` | incoming since the cutoff |
| `updatedReceived as int` | incoming changed since the cutoff |
| `pendingSent as int` | outgoing, awaiting an answer |
| `newlyAcceptedSent as int` | outgoing accepted since the cutoff |
| `updatedSent as int` | outgoing changed since the cutoff |
| `escrowReceived as int` | incoming in escrow |
| `escrowSent as int` | outgoing in escrow |

### `AssetPrice`

| Field | Meaning |
| ----- | ------- |
| `classId as string` | item class |
| `name as string` | the store's internal name |
| `date as string` | date added, "" when none |
| `prices as map of string to int` | minor units per ISO code; only the codes Valve priced |

## Servers (`IGameServersService`)

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `gameServerAccounts(c)` | `list of GameServerAccount` | the key owner's accounts, login tokens included |
| `gameServerInfo(c, steamId)` | `GameServerInfo` | public record of any server account |
| `queryLoginToken(c, loginToken)` | `LoginTokenStatus` | throws on a blank token |
| `isUsableServerAccount(account)` | `bool` | neither deleted nor expired |

### `GameServerAccount`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | server's id64 |
| `appId as int` | game |
| `loginToken as string` | secret, treat as a password |
| `memo as string` | note |
| `deleted as bool` | deleted |
| `expired as bool` | token expired through disuse |
| `lastLogon as int` | Unix time of the last login |

### `GameServerInfo`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | server's id64 |
| `appId as int` | game, 0 when unknown |

### `LoginTokenStatus`

| Field | Meaning |
| ----- | ------- |
| `steamId as string` | owning server account |
| `banned as bool` | banned from listing |
| `expires as int` | Unix time it stops working, 0 when it does not |

## Errors

Messages name the fix or the cause:

- validation: `the app id must be positive, got 0`
- transport: `GET https://store.steampowered.com/api/appdetails failed: ...`
  (the URL never carries the query string, so never the key)
- refusal: `the storefront has no record of app 1 in country US - it may be
  delisted, region-locked, or not an app at all`

A non-2xx GET reads `... failed: rest.getJson: HTTP <status>: <body>`. A
non-2xx POST names the usual cause: 400 rejected parameters, 401 missing or
invalid key, 403 key not allowed to read the profile, 404 no such method or
object, 429 rate limited, 500/502/503 Steam trouble.

```jennifer
try {
    def d as steam.AppDetails init steam.appDetails($c, $appId);
} catch (e) {
    io.eprintf("%s\n", $e.message);
}
```

## Costs

- **One connection per request.** `rest` keeps no keep-alive session, so
  `appPrices`, `appDetailsMany` and `appList` pay a TLS handshake per id or
  page.
- **Bodies are capped at `MAX_RESPONSE_BYTES`** (32 MiB).
- **`plainText` is linear in the body length**, also on adversarial input
  (loose brackets, repeated image markers), so it is safe on user-written
  Workshop descriptions.

## Requirements

- Jennifer 0.25.0 or newer, the default `jennifer` binary: requests go
  through [`rest`](https://jennifer-lang.dev/modules/rest.html) and
  [`http`](https://jennifer-lang.dev/modules/http.html) to `net`, which
  `jennifer-tiny` stubs out. The pure helpers work on both.
- Standard library `strings`, `lists`, `convert`, `math`, `json`, `io`, `os`;
  bundled modules `rest`, `http`, `uri`. No other deck.

Tests run offline: `jennifer test src/steam_test.j`. Anchor a filter to
`^test` (`--filter='^testParseMoney'`); the refusal helpers are top-level
functions that throw by design.
