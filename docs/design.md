# Design

## Scope

The deck is a typed client for Valve™'s Steam™ services:

- the **Steam Web API** (`api.steampowered.com`): users, friends, bans,
  vanity names and groups; owned and recent games, levels and badges;
  achievements, stats and player counts; the app catalogue; news; Workshop
  items and collections; trade offers and items; game server login tokens;
- the **storefront API** (`store.steampowered.com`): app and package
  details, prices, the featured lists;
- the **Community Market** (`steamcommunity.com`): price overviews.

It also works offline: Steam id conversion between the 64-bit, SteamID2 and
SteamID3 notations and profile URLs, and `plainText`, which strips the HTML
and BBCode of news posts. `call` reaches any Web API method without a typed
verb. It needs the `net` capability for the network verbs.

The deck works with a Web API key or with no credential at all; it holds
no Steam login session.

## Decisions

- **A deck, not core.** Parts of the surface are reverse-engineered by the
  community and change without notice; that belongs in a deck that can
  release on its own schedule.
- **One plain `Client` value.** It carries the key, language, country,
  currency, timeout, retries, backoff and the verbose flag; builders return
  copies. `client("")` is valid: keyless endpoints work, keyed ones refuse
  locally before any request. `clientFromEnv` reads `STEAM_API_KEY`,
  `STEAM_LANGUAGE` and `STEAM_COUNTRY`; `STEAM_VERBOSE` seeds verbose mode.
- **One request path per host.** Web API requests add the key as a `key`
  parameter; storefront and market requests never carry it. The
  `ISteamRemoteStorage` lookups only answer a form POST, so they get one.
- **Steam ids are strings.** Every id argument accepts the 64-bit, SteamID2
  (`STEAM_X:Y:Z`) and SteamID3 (`[U:1:N]`) forms; `resolveAccount` also
  takes a vanity name or profile URL (which needs a key). Batched id lists
  are cut to each endpoint's limit. `UNIVERSE_MAX` is 5, not the 8-bit
  field's maximum, because a larger universe overflows the 64-bit id when
  shifted, and a shift wraps silently.
- **The keyed app catalogue.** Valve retired the keyless app list, which
  now answers 404, so `appList` uses the keyed store service (games only),
  paging by the last app id in pages of up to `APPLIST_PAGE_MAX` and
  stopping if the cursor does not advance.
- **One storefront request per app.** The storefront answers several app
  ids at once with 400 and ignores its price filter, so `appPrices` and
  `appDetailsMany` ask per id, after validating every id first.
- **Prices.** Storefront amounts are integers in minor units, and
  `majorUnits` always divides by 100, also for zero-decimal currencies,
  because Steam reports those in hundredths too. The market sends only
  locale-formatted strings (`"0,03€"`); `parseMoneyCents` reads them,
  bounded by `MAX_MONEY_UNITS` so the conversion stays inside the integer
  range.
- **Private profiles are not errors.** Where Steam signals a private
  profile rather than a failure (a `success` false on groups, for example),
  the verb returns an empty result.
- **Careful markup stripping.** `plainText` treats a bracketed run as
  markup only when it opens with a tag name and closes within
  `MARKUP_SPAN` code points, so prose such as `2 < 3` or
  `[citation needed]` survives.
- **A safe escape hatch.** `call` restricts service and method names to
  letter-initial alphanumerics, so a caller cannot reshape the path.

## Errors

Every failure of kind `"steam"` is a `SteamError` with `status`, the HTTP
status of a refused request (429 when the key is rate limited), 0
otherwise. Validation messages name the fix; a non-2xx POST names the usual
cause per status (a missing key, a private profile, rate limiting).

Generic kinds:

- a reply body past `MAX_RESPONSE_BYTES`, or a JSON reply past the
  decoder's nesting or node cap, is kind `"limit"`;
- a reply that does not arrive within the timeout is kind `"timeout"`, a
  connection closed mid-reply `"closed"`, a cancelled task `"cancelled"`,
  all passed on unchanged;
- a host that cannot be reached (refused, reset, unreachable, no DNS answer,
  a failed TLS handshake, closed before any reply) is the transport's
  `net.NetError` (kind `"net"`), passed on unchanged with `reason`, `op`,
  `sent` and `replied`;
- any other transport failure (a malformed reply) is a `SteamError` with
  status 0.

## Security and limits

- The key goes only to the Web API host, as a query parameter. Error
  messages name the URL without its query string, so they never carry the
  key; a `net.NetError` names only host and port.
- Verbose mode prints each request with `key`, `access_token`, `token` and
  `login_token` redacted.
- Replies are capped at `MAX_RESPONSE_BYTES` (32 MiB; the app catalogue is
  megabytes); requests time out after `DEFAULT_TIMEOUT_MS` (15 s) and
  follow at most 3 redirects.
- Retries are the `rest` module's: `DEFAULT_RETRIES` (2) with
  `DEFAULT_BACKOFF_MS` (500 ms) backoff, adjustable per client. The deck
  repeats nothing itself.

## Testing and validation

- No overlay touches the network. Network verbs are tested up to the
  argument check that fails before the request (a keyless client, a bad
  id), and every reply fold is tested against inline JSON fixtures shaped
  like Steam's answers. About 186 tests.
- Transport failures are tested against a closed loopback port through the
  request helpers.
- The examples need live endpoints and usually a key, so the gate only
  parses and lints them; they are read-only.

Not covered: no automated test talks to Steam, so a change on Valve's side
shows up only when someone runs the examples. `featured`, `serverInfo` and
`supportedApiList` are not yet called from an overlay.

## Known limitations and open questions

- `rest` keeps no keep-alive, so the per-app storefront requests each open
  their own TLS connection.
- Which endpoints need a key is per endpoint and decided by Valve; a
  keyless client finds out from a local refusal or a 401.

## Dependencies on the interpreter

- The bundled `rest`, `http` and `uri` modules, with `http`'s body cap
  (`maxBytes`).
- Thrown error structs and lint's L104 for `SteamError`, and `rest`'s
  `HttpError` status.
- `net.NetError` and the `"net"` kind (`jennifer`'s M28.65, transport
  errors have their own kind).
- Floor `>=0.27.0`: the tests use the UTF-8 codec of `encoding.encode` and
  `strings.replicate`, new in 0.27.0.
