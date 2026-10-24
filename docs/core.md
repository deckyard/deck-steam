# Core - the client

Every call takes a `Client`. It is a plain value with no socket and no
state, and every builder returns a copy, so keep the result:

```jennifer
import "@deckyard/steam/" as steam;

def c as steam.Client init steam.client("YOUR-KEY");
$c = steam.withCountry($c, "DE");        # kept
steam.withCountry($c, "DE");             # discarded, changes nothing
```

## Keys

Take a key from <https://steamcommunity.com/dev/apikey>. It is tied to your
account, Valve rate-limits per key, and the
[API Terms of Use](https://steamcommunity.com/dev/apiterms) apply to what you
do with it, including a rule against redistributing the data you pull.

`clientFromEnv()` reads the key from `STEAM_API_KEY`, and `STEAM_LANGUAGE`
and `STEAM_COUNTRY` when they are set:

```jennifer
def c as steam.Client init steam.clientFromEnv();
if (not steam.hasKey($c)) {
    io.eprintf("set STEAM_API_KEY\n");
    exit 1;
}
```

`steam.client("")` is a valid client. The storefront, the Community Market,
news, the Workshop, live player counts and global achievement rarity answer
without a key; the calls that need one throw before sending anything. The
[cheatsheet](cheatsheet.md#which-calls-need-a-key) has the full split.

## What the client carries

| Field | Set with | Affects |
| ----- | -------- | ------- |
| `key` | `client` / `clientFromEnv` | which endpoints answer |
| `language` | `withLanguage` | localized text: achievement names, store descriptions, genre labels |
| `countryCode` | `withCountry` | storefront currency, availability, age rating |
| `currency` | `withCurrency` | the wallet currency the market quotes |
| `timeoutMs` | `withTimeout` | per-read idle timeout, 15000 ms by default |
| `retries` / `backoffMs` | `withRetries` / `withBackoff` | retries of a 429 or 5xx: 2, from 500 ms |

The backoff doubles per attempt, is raised to a numeric `Retry-After` when
Steam sends a longer one, and is capped at 30 s. The Community Market needs
more than the defaults:

```jennifer
$c = steam.withRetries(steam.withBackoff($c, 3000), 4);
```

`withTimeout($c, 0)` and `withBackoff($c, 0)` do not restore this deck's
defaults. The bundled `http` module reads 0 as unset and applies its own:
a 30000 ms timeout and a 250 ms backoff.

## Verbose mode

`setVerbose($c, true)`, or `STEAM_VERBOSE=1` (also `true`, `yes`, `on`) when
the client is built, prints each request before it goes out:

```
steam> GET https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?steamids=76561197960287930&key=<redacted>
steam> GET https://store.steampowered.com/api/appdetails?appids=620&cc=DE&l=german
```

`key`, `access_token`, `token` and `login_token` always print as
`<redacted>`. The key is only ever sent to `api.steampowered.com`.

## Errors

Every failure is `Error{kind: "steam"}`. Arguments are checked before
anything is sent:

```jennifer
try {
    steam.appDetails($c, 0);
} catch (e) {
    io.printf("%s\n", $e.message);      # the app id must be positive, got 0
}
```

A transport failure names the method and the URL without its query string,
so the message never carries the key. A non-2xx reply to a GET carries the
status and body from `rest`; the two POST lookups translate the status
instead: 401 "the API key is missing or not valid", 403 "the key is valid
but not allowed to read this profile", 429 "the key is being rate limited".

## Calling any method

`call` sends a GET to any Web API method and returns the decoded document,
with the client's key added when it has one. Interface and method names must
be letters and digits, so a `/` or `..` cannot reshape the path:

```jennifer
use json;

def v as json.Value init steam.call($c, "ISteamApps", "GetSDRConfig", 1,
    {"appid": "730"});
io.printf("%s\n", json.encodePretty($v));
```

`supportedApiList($c)` lists the methods the key can call (see
[apps](apps.md#what-a-key-can-call)).
