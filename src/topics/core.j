# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - client, request plumbing, shared validation and JSON readers.
# Spliced into steam.j via include - not a standalone module.

/**
 * Host of the Steam Web API (the `api.steampowered.com` interfaces).
 */
export def const API_BASE as string init "https://api.steampowered.com";

/**
 * Host of the Steam storefront API (`store.steampowered.com/api/...`).
 */
export def const STORE_BASE as string init "https://store.steampowered.com";

/**
 * Host of the Steam Community site (profiles, the market, the workshop).
 */
export def const COMMUNITY_BASE as string init "https://steamcommunity.com";

/**
 * Host serving app artwork (capsules, headers, icons).
 */
export def const MEDIA_BASE as string init "https://cdn.akamai.steamstatic.com";

/**
 * Per-request idle timeout a fresh client starts with, in milliseconds.
 */
export def const DEFAULT_TIMEOUT_MS as int init 15000;

/**
 * Number of times a fresh client retries a 429 or 5xx before giving up.
 */
export def const DEFAULT_RETRIES as int init 2;

/**
 * Largest response body read, in bytes (32 MiB). Steam's replies are
 * kilobytes and the app catalogue megabytes; the cap stops a misbehaving
 * endpoint from filling memory.
 */
export def const MAX_RESPONSE_BYTES as int init 33554432;

/**
 * Base delay a fresh client waits before retrying, in milliseconds.
 */
export def const DEFAULT_BACKOFF_MS as int init 500;

/**
 * Wallet currency id for US dollars, the currency a new client starts with.
 */
export def const CURRENCY_USD as int init 1;

/**
 * Wallet currency id for pounds sterling.
 */
export def const CURRENCY_GBP as int init 2;

/**
 * Wallet currency id for euros.
 */
export def const CURRENCY_EUR as int init 3;

/**
 * Wallet currency id for Swiss francs.
 */
export def const CURRENCY_CHF as int init 4;

/**
 * Wallet currency id for Russian roubles.
 */
export def const CURRENCY_RUB as int init 5;

/**
 * Wallet currency id for Polish zloty.
 */
export def const CURRENCY_PLN as int init 6;

/**
 * Wallet currency id for Brazilian reais.
 */
export def const CURRENCY_BRL as int init 7;

/**
 * Wallet currency id for Japanese yen.
 */
export def const CURRENCY_JPY as int init 8;

/**
 * Wallet currency id for Australian dollars.
 */
export def const CURRENCY_AUD as int init 21;

/**
 * Wallet currency id for Canadian dollars.
 */
export def const CURRENCY_CAD as int init 20;

/**
 * A configured Steam caller.
 *
 * A plain value with no socket and no state. Every builder returns a copy,
 * so keep it: `$c = steam.setVerbose($c, true);`. An empty `key` is legal;
 * only the calls that need a key refuse it.
 *
 * @field key {string} the Steam Web API key, or "" for the keyless endpoints
 * @field language {string} the `l` / `language` parameter, e.g. "english"
 * @field countryCode {string} two-letter storefront country, e.g. "US"; decides
 *        prices and regional availability
 * @field currency {int} wallet currency id for market prices
 * @field timeoutMs {int} per-request idle timeout in milliseconds
 * @field retries {int} retry budget for a 429 or 5xx
 * @field backoffMs {int} base delay before the first retry, in milliseconds
 * @field verbose {bool} print every request to stdout, credentials redacted
 */
export def struct Client {
    key as string,
    language as string,
    countryCode as string,
    currency as int,
    timeoutMs as int,
    retries as int,
    backoffMs as int,
    verbose as bool
};

/**
 * Build a client around a Steam Web API key (from
 * <https://steamcommunity.com/dev/apikey>). The key is trimmed; "" gives a
 * client for the keyless endpoints only. `STEAM_VERBOSE` set to 1, true,
 * yes or on seeds the verbose flag.
 *
 * @param apiKey {string} the Web API key, or "" for keyless use
 * @return {Client} a client with English / US / USD defaults, 15000 ms
 *         timeout, 2 retries and 500 ms backoff
 * @example
 *   def c as steam.Client init steam.client("YOUR-KEY");
 */
export func client(apiKey as string) {
    return Client{
        key: strings.trim($apiKey),
        language: "english",
        countryCode: "US",
        currency: CURRENCY_USD,
        timeoutMs: DEFAULT_TIMEOUT_MS,
        retries: DEFAULT_RETRIES,
        backoffMs: DEFAULT_BACKOFF_MS,
        verbose: verboseFromEnv()
    };
}

/**
 * Build a client from `STEAM_API_KEY`, applying `STEAM_LANGUAGE` and
 * `STEAM_COUNTRY` when they are not blank. `STEAM_VERBOSE` works as in
 * `client`.
 *
 * @return {Client} a client configured from the environment
 * @throws {Error} kind "steam" when `STEAM_COUNTRY` is not two letters
 * @example
 *   def c as steam.Client init steam.clientFromEnv();
 */
export func clientFromEnv() {
    def c as Client init client(os.getEnv("STEAM_API_KEY"));
    def lang as string init strings.trim(os.getEnv("STEAM_LANGUAGE"));
    if ($lang != "") {
        $c = withLanguage($c, $lang);
    }
    def cc as string init strings.trim(os.getEnv("STEAM_COUNTRY"));
    if ($cc != "") {
        $c = withCountry($c, $cc);
    }
    return $c;
}

/**
 * A copy of the client asking for another language. Affects localized text:
 * achievement names, store descriptions, genre and category labels. The
 * name is lowercased.
 *
 * @param c {Client} the client to copy
 * @param language {string} a Steam language name, e.g. "english", "german"
 * @return {Client} the copy
 * @throws {Error} kind "steam" when `language` is blank
 */
export func withLanguage(c as Client, language as string) {
    def value as string init strings.lower(ensureText($language, "language"));
    def next as Client init $c;
    $next.language = $value;
    return $next;
}

/**
 * A copy of the client pinned to a storefront country, which decides
 * currency, availability and age gating. The code is uppercased.
 *
 * @param c {Client} the client to copy
 * @param countryCode {string} a two-letter ISO country code, e.g. "DE"
 * @return {Client} the copy
 * @throws {Error} kind "steam" when the code is not two letters
 */
export func withCountry(c as Client, countryCode as string) {
    def value as string init strings.upper(strings.trim($countryCode));
    if (len($value) != 2) {
        raiseError("the country code must be two letters, got \"" + $value + "\"");
    }
    def next as Client init $c;
    $next.countryCode = $value;
    return $next;
}

/**
 * A copy of the client quoting market prices in another wallet currency.
 *
 * @param c {Client} the client to copy
 * @param currency {int} a wallet currency id, e.g. `CURRENCY_EUR`
 * @return {Client} the copy
 * @throws {Error} kind "steam" when the id is not positive
 */
export func withCurrency(c as Client, currency as int) {
    if ($currency <= 0) {
        raiseError("the currency id must be positive, got " + convert.toString($currency));
    }
    def next as Client init $c;
    $next.currency = $currency;
    return $next;
}

/**
 * A copy of the client with another per-request idle timeout.
 *
 * 0 does not restore `DEFAULT_TIMEOUT_MS`: the bundled `http` module reads
 * it as unset and applies its own 30000 ms default.
 *
 * @param c {Client} the client to copy
 * @param timeoutMs {int} idle timeout in milliseconds; 0 for http's 30000
 * @return {Client} the copy
 * @throws {Error} kind "steam" when the timeout is negative
 */
export func withTimeout(c as Client, timeoutMs as int) {
    if ($timeoutMs < 0) {
        raiseError("the timeout must not be negative");
    }
    def next as Client init $c;
    $next.timeoutMs = $timeoutMs;
    return $next;
}

/**
 * A copy of the client with another retry budget for a 429 or 5xx. A
 * numeric `Retry-After` longer than the backoff is honoured, capped at 30 s.
 *
 * @param c {Client} the client to copy
 * @param retries {int} retry budget per request, 0 to disable
 * @return {Client} the copy
 * @throws {Error} kind "steam" when the budget is negative
 */
export func withRetries(c as Client, retries as int) {
    if ($retries < 0) {
        raiseError("the retry budget must not be negative");
    }
    def next as Client init $c;
    $next.retries = $retries;
    return $next;
}

/**
 * A copy of the client with another base retry delay, doubled per attempt
 * and capped at 30 s. The Community Market throttles at roughly twenty
 * requests a minute per address, so a loop over it wants seconds here.
 *
 * 0 does not restore `DEFAULT_BACKOFF_MS`: the bundled `http` module reads
 * it as unset and uses 250 ms.
 *
 * @param c {Client} the client to copy
 * @param backoffMs {int} base delay in milliseconds; 0 for http's 250
 * @return {Client} the copy
 * @throws {Error} kind "steam" when the delay is negative
 * @example
 *   $c = steam.withBackoff(steam.withRetries($c, 4), 3000);
 */
export func withBackoff(c as Client, backoffMs as int) {
    if ($backoffMs < 0) {
        raiseError("the retry backoff must not be negative");
    }
    def next as Client init $c;
    $next.backoffMs = $backoffMs;
    return $next;
}

/**
 * A copy of the client that prints each request as one `steam>` line
 * (method, URL, parameters) before sending it. `key`, `access_token`,
 * `token` and `login_token` print as `<redacted>`.
 *
 * @param c {Client} the client to copy
 * @param enabled {bool} true to print requests
 * @return {Client} the copy
 * @example
 *   $c = steam.setVerbose($c, true);
 */
export func setVerbose(c as Client, enabled as bool) {
    def next as Client init $c;
    $next.verbose = $enabled;
    return $next;
}

/**
 * Whether the client echoes its requests.
 *
 * @param c {Client} the client to inspect
 * @return {bool} the verbose flag
 */
export func isVerbose(c as Client) {
    return $c.verbose;
}

/**
 * Whether the client carries a Web API key.
 *
 * @param c {Client} the client to inspect
 * @return {bool} true when a non-empty key is configured
 */
export func hasKey(c as Client) {
    return $c.key != "";
}

/**
 * Call any Web API method with GET and decode the reply. The client's key
 * is added when it has one.
 *
 * @param c {Client} an API client
 * @param service {string} the interface name, e.g. "ISteamUser"
 * @param method {string} the method name, e.g. "GetPlayerSummaries"
 * @param version {int} the method version, e.g. 2
 * @param params {map of string to string} query parameters, {} for none
 * @return {json.Value} the decoded response body
 * @throws {Error} kind "steam" when a name is not letters and digits, the
 *                 version is not positive, on a non-2xx status, a transport
 *                 failure, or a non-JSON reply
 * @example
 *   def v as json.Value init steam.call($c, "ISteamApps", "GetAppList", 2, {});
 */
export func call(
    c as Client,
    service as string,
    method as string,
    version as int,
    params as map of string to string) {
    return apiGet($c, $service, $method, $version, $params);
}

/**
 * Throw the deck's error.
 *
 * @param message {string} human-readable failure description
 * @throws {Error} always, kind "steam"
 * @internal
 */
func raiseError(message as string) {
    throw Error{kind: "steam", message: $message, file: "", line: 0, col: 0};
}

/**
 * Read `STEAM_VERBOSE` as a boolean.
 *
 * @return {bool} true when the variable is set to something truthy
 * @internal
 */
func verboseFromEnv() {
    def raw as string init strings.lower(strings.trim(os.getEnv("STEAM_VERBOSE")));
    return $raw == "1" or $raw == "true" or $raw == "yes" or $raw == "on";
}

/**
 * Build the path of a Web API method.
 *
 * @param service {string} the interface name
 * @param method {string} the method name
 * @param version {int} the method version
 * @return {string} the path, e.g. "/ISteamUser/GetPlayerSummaries/v2/"
 * @throws {Error} kind "steam" on a blank name or a non-positive version
 * @internal
 */
func apiPath(service as string, method as string, version as int) {
    def s as string init ensureApiName($service, "interface name");
    def m as string init ensureApiName($method, "method name");
    if ($version <= 0) {
        raiseError("the method version must be positive, got " + convert.toString($version));
    }
    return "/" + $s + "/" + $m + "/v" + convert.toString($version) + "/";
}

/**
 * Build the REST client used for one request.
 *
 * @param base {string} the host to talk to
 * @param c {Client} the API client carrying the request policy
 * @return {rest.Client} a configured REST client
 * @internal
 */
func httpClient(base as string, c as Client) {
    def r as rest.Client init rest.client($base);
    $r = rest.withTimeout($r, $c.timeoutMs);
    $r = rest.withRetries($r, $c.retries);
    $r = rest.withBackoff($r, $c.backoffMs);
    $r = rest.withRedirects($r, 3);
    def policy as http.Options init $r.options;
    $policy.maxBytes = MAX_RESPONSE_BYTES;
    $r.options = $policy;
    return $r;
}

/**
 * Copy a parameter map with the client's key appended.
 *
 * @param c {Client} the API client
 * @param params {map of string to string} the caller's parameters
 * @return {map of string to string} the parameters actually sent
 * @internal
 */
func withKey(c as Client, params as map of string to string) {
    def merged as map of string to string init $params;
    if ($c.key != "") {
        $merged["key"] = $c.key;
    }
    return $merged;
}

/**
 * Whether a parameter carries a credential and must not be printed.
 *
 * @param name {string} the parameter name
 * @return {bool} true for the API key, the OAuth-style tokens, and a
 *         game server login token
 * @internal
 */
func isSecret(name as string) {
    return $name == "key" or $name == "access_token" or $name == "token" or
        $name == "login_token";
}

/**
 * Render a request for the verbose transcript.
 *
 * @param verb {string} the HTTP method
 * @param url {string} the full URL without a query string
 * @param params {map of string to string} the parameters, secrets included
 * @return {string} one printable line, secrets redacted
 * @internal
 */
func requestLine(verb as string, url as string, params as map of string to string) {
    def parts as list of string init [];
    for (def name in $params) {
        if (isSecret($name)) {
            $parts[] = $name + "=<redacted>";
        } else {
            $parts[] = $name + "=" + uri.encodeForm($params[$name]);
        }
    }
    if (len($parts) == 0) {
        return $verb + " " + $url;
    }
    return $verb + " " + $url + "?" + strings.join($parts, "&");
}

/**
 * Print a request when the client is verbose.
 *
 * @param c {Client} the API client
 * @param verb {string} the HTTP method
 * @param url {string} the full URL without a query string
 * @param params {map of string to string} the parameters
 * @internal
 */
func logRequest(c as Client, verb as string, url as string, params as map of string to string) {
    if (not $c.verbose) {
        return;
    }
    def line as string init requestLine($verb, $url, $params);
    io.printf("steam> %s\n", $line);
}

/**
 * GET a Web API method and decode the reply.
 *
 * @param c {Client} the API client
 * @param service {string} the interface name
 * @param method {string} the method name
 * @param version {int} the method version
 * @param params {map of string to string} query parameters
 * @return {json.Value} the decoded body
 * @throws {Error} kind "steam" on a transport failure or a non-JSON reply
 * @internal
 */
func apiGet(
    c as Client,
    service as string,
    method as string,
    version as int,
    params as map of string to string) {
    def path as string init apiPath($service, $method, $version);
    def query as map of string to string init withKey($c, $params);
    logRequest($c, "GET", API_BASE + $path, $query);
    return getJson(httpClient(API_BASE, $c), $path, $query, API_BASE + $path);
}

/**
 * POST a Web API method as a form and decode the reply. The
 * `ISteamRemoteStorage` lookups only answer a form POST.
 *
 * @param c {Client} the API client
 * @param service {string} the interface name
 * @param method {string} the method name
 * @param version {int} the method version
 * @param params {map of string to string} form fields
 * @return {json.Value} the decoded body
 * @throws {Error} kind "steam" on a non-2xx status or a non-JSON reply
 * @internal
 */
func apiPost(
    c as Client,
    service as string,
    method as string,
    version as int,
    params as map of string to string) {
    def path as string init apiPath($service, $method, $version);
    def form as map of string to string init withKey($c, $params);
    def url as string init API_BASE + $path;
    logRequest($c, "POST", $url, $form);
    def body as string init uri.buildQuery($form);
    def reply as rest.Response init postForm(httpClient(API_BASE, $c), $path, $body, $url);
    ensureOk($reply.status, $url);
    return decodeBody($reply.body, $url);
}

/**
 * GET a path on the storefront host and decode the reply. The key is never
 * sent there.
 *
 * @param c {Client} the API client
 * @param path {string} a path under `store.steampowered.com`
 * @param params {map of string to string} query parameters
 * @return {json.Value} the decoded body
 * @throws {Error} kind "steam" on a transport failure or a non-JSON reply
 * @internal
 */
func storeGet(c as Client, path as string, params as map of string to string) {
    def url as string init STORE_BASE + $path;
    logRequest($c, "GET", $url, $params);
    return getJson(httpClient(STORE_BASE, $c), $path, $params, $url);
}

/**
 * GET a path on the community host and decode the reply. The key is never
 * sent there.
 *
 * @param c {Client} the API client
 * @param path {string} a path under `steamcommunity.com`
 * @param params {map of string to string} query parameters
 * @return {json.Value} the decoded body
 * @throws {Error} kind "steam" on a transport failure or a non-JSON reply
 * @internal
 */
func communityGet(c as Client, path as string, params as map of string to string) {
    def url as string init COMMUNITY_BASE + $path;
    logRequest($c, "GET", $url, $params);
    return getJson(httpClient(COMMUNITY_BASE, $c), $path, $params, $url);
}

/**
 * Run a GET, translating any transport error into the deck's own.
 *
 * @param r {rest.Client} the configured REST client
 * @param path {string} the request path
 * @param params {map of string to string} query parameters
 * @param url {string} the full URL, for the error message
 * @return {json.Value} the decoded body
 * @throws {Error} kind "steam" wrapping whatever went wrong
 * @internal
 */
func getJson(r as rest.Client, path as string, params as map of string to string, url as string) {
    try {
        return rest.getJson($r, $path, $params);
    } catch (e) {
        raiseError("GET " + $url + " failed: " + $e.message);
    }
}

/**
 * Run a form POST, translating any transport error into the deck's own.
 *
 * @param r {rest.Client} the configured REST client
 * @param path {string} the request path
 * @param body {string} the form-encoded body
 * @param url {string} the full URL, for the error message
 * @return {rest.Response} the raw response
 * @throws {Error} kind "steam" wrapping whatever went wrong
 * @internal
 */
func postForm(r as rest.Client, path as string, body as string, url as string) {
    try {
        return rest.post($r, $path, "application/x-www-form-urlencoded", $body);
    } catch (e) {
        raiseError("POST " + $url + " failed: " + $e.message);
    }
}

/**
 * Refuse a non-2xx status.
 *
 * @param status {int} the HTTP status code
 * @param url {string} the URL that produced it
 * @throws {Error} kind "steam" when the status is outside 2xx
 * @internal
 */
func ensureOk(status as int, url as string) {
    if ($status >= 200 and $status < 300) {
        return;
    }
    raiseError($url + " answered HTTP " + convert.toString($status) + ": " +
        statusHint($status));
}

/**
 * Explain the Steam-specific meaning of an unhappy status code.
 *
 * @param status {int} the HTTP status code
 * @return {string} a sentence naming the usual cause
 * @internal
 */
func statusHint(status as int) {
    match ($status) {
        when 400 { return "Steam rejected the parameters"; }
        when 401 { return "the API key is missing or not valid"; }
        when 403 { return "the key is valid but not allowed to read this profile"; }
        when 404 { return "no such method or object"; }
        when 429 { return "the key is being rate limited"; }
        when 500, 502, 503 { return "Steam is having trouble; retry later"; }
        else { return "unexpected status"; }
    }
}

/**
 * Decode a response body, naming the URL when it is not JSON.
 *
 * @param body {string} the raw response body
 * @param url {string} the URL that produced it
 * @return {json.Value} the decoded document
 * @throws {Error} kind "steam" when the body is not JSON
 * @internal
 */
func decodeBody(body as string, url as string) {
    try {
        return json.decode($body);
    } catch (e) {
        raiseError($url + " did not answer JSON: " + $e.message);
    }
}

/**
 * Refuse a blank string, trimming it otherwise.
 *
 * @param value {string} the value to check
 * @param what {string} what it is, for the message
 * @return {string} the trimmed value
 * @throws {Error} kind "steam" when the value is blank
 * @internal
 */
func ensureText(value as string, what as string) {
    def trimmed as string init strings.trim($value);
    if ($trimmed == "") {
        raiseError("the " + $what + " must not be empty");
    }
    return $trimmed;
}

/**
 * Refuse anything that is not a Steam interface or method name. The names
 * land in the URL path verbatim, so a `/` or `..` from a `call` caller would
 * reshape the request path.
 *
 * @param value {string} the candidate name
 * @param what {string} what it is, for the message
 * @return {string} the trimmed name
 * @throws {Error} kind "steam" when the name is blank or not letters and digits
 * @internal
 */
func ensureApiName(value as string, what as string) {
    def name as string init ensureText($value, $what);
    if (not isApiName($name)) {
        raiseError("the " + $what + " must be letters and digits, got \"" + $name + "\"");
    }
    return $name;
}

/**
 * Whether a name is letter-initial and otherwise letters and digits.
 *
 * @param text {string} the candidate
 * @return {bool} true when it is safe to splice into a URL path
 * @internal
 */
func isApiName(text as string) {
    if (len($text) == 0) {
        return false;
    }
    def first as bool init true;
    for (def ch in strings.chars($text)) {
        def letter as bool init ($ch >= "a" and $ch <= "z") or ($ch >= "A" and $ch <= "Z");
        if (not $letter and ($first or not ($ch >= "0" and $ch <= "9"))) {
            return false;
        }
        $first = false;
    }
    return true;
}

/**
 * Refuse anything that is not a plausible Steam application id.
 *
 * @param appId {int} the app id to check
 * @return {int} the same id
 * @throws {Error} kind "steam" when the id is not positive
 * @internal
 */
func ensureAppId(appId as int) {
    if ($appId <= 0) {
        raiseError("the app id must be positive, got " + convert.toString($appId));
    }
    return $appId;
}

/**
 * Refuse a non-positive count.
 *
 * @param count {int} the requested number of items
 * @param what {string} what is being counted, for the message
 * @return {int} the same count
 * @throws {Error} kind "steam" when the count is not positive
 * @internal
 */
func ensureCount(count as int, what as string) {
    if ($count <= 0) {
        raiseError("the number of " + $what + " must be positive, got " +
            convert.toString($count));
    }
    return $count;
}

/**
 * Refuse a client with no Web API key.
 *
 * @param c {Client} the client to check
 * @param what {string} the operation that needs the key
 * @throws {Error} kind "steam" when the client has no key
 * @internal
 */
func requireKey(c as Client, what as string) {
    if ($c.key == "") {
        raiseError($what + " needs a Steam Web API key - get one at " +
            COMMUNITY_BASE + "/dev/apikey and pass it to steam.client()");
    }
}

/**
 * Join Steam ids into the comma-separated list the API expects.
 *
 * @param steamIds {list of string} the ids
 * @param limit {int} the largest batch the endpoint accepts
 * @return {string} the joined list
 * @throws {Error} kind "steam" on an empty list, an oversized batch, or an
 *                 id that is not a 64-bit Steam id
 * @internal
 */
func joinSteamIds(steamIds as list of string, limit as int) {
    if (len($steamIds) == 0) {
        raiseError("at least one Steam id is required");
    }
    if (len($steamIds) > $limit) {
        raiseError("at most " + convert.toString($limit) +
            " Steam ids fit in one request, got " + convert.toString(len($steamIds)));
    }
    def cleaned as list of string init [];
    for (def id in $steamIds) {
        $cleaned[] = ensureSteamId($id);
    }
    return strings.join($cleaned, ",");
}

/**
 * Read a string out of a JSON document, defaulting to "". Steam sends ids
 * as numbers or strings, so a number or bool is stringified.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer into it
 * @return {string} the value, or "" when absent or null
 * @internal
 */
func nodeString(v as json.Value, ptr as string) {
    if (not json.has($v, $ptr)) {
        return "";
    }
    def kind as string init json.typeOf($v, $ptr);
    match ($kind) {
        when "string" { return json.asString($v, $ptr); }
        when "int" { return convert.toString(json.asInt($v, $ptr)); }
        when "float" { return convert.toString(json.asFloat($v, $ptr)); }
        when "bool" { return convert.toString(json.asBool($v, $ptr)); }
        else { return ""; }
    }
}

/**
 * Read an int out of a JSON document, defaulting to 0.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer into it
 * @return {int} the value, or 0 when absent or not numeric
 * @internal
 */
func nodeInt(v as json.Value, ptr as string) {
    if (not json.has($v, $ptr)) {
        return 0;
    }
    def kind as string init json.typeOf($v, $ptr);
    match ($kind) {
        when "int" { return json.asInt($v, $ptr); }
        when "float" { return floatToIntOrZero(json.asFloat($v, $ptr)); }
        when "bool" { return boolToInt(json.asBool($v, $ptr)); }
        when "string" { return parseIntOrZero(json.asString($v, $ptr)); }
        else { return 0; }
    }
}

/**
 * Read a float out of a JSON document, defaulting to 0.0.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer into it
 * @return {float} the value, or 0.0 when absent or not numeric
 * @internal
 */
func nodeFloat(v as json.Value, ptr as string) {
    if (not json.has($v, $ptr)) {
        return 0.0;
    }
    def kind as string init json.typeOf($v, $ptr);
    match ($kind) {
        when "float" { return json.asFloat($v, $ptr); }
        when "int" { return convert.toFloat(json.asInt($v, $ptr)); }
        when "string" { return parseFloatOrZero(json.asString($v, $ptr)); }
        else { return 0.0; }
    }
}

/**
 * Read a bool out of a JSON document, defaulting to false. Steam writes
 * flags as `true`, `1` or `"1"` depending on the endpoint; all read as true.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer into it
 * @return {bool} the flag, or false when absent
 * @internal
 */
func nodeBool(v as json.Value, ptr as string) {
    if (not json.has($v, $ptr)) {
        return false;
    }
    def kind as string init json.typeOf($v, $ptr);
    match ($kind) {
        when "bool" { return json.asBool($v, $ptr); }
        when "int" { return json.asInt($v, $ptr) != 0; }
        when "string" { return truthyWord(json.asString($v, $ptr)); }
        else { return false; }
    }
}

/**
 * Length of a JSON list, 0 when the pointer names anything else.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer into it
 * @return {int} the element count, or 0
 * @internal
 */
func nodeLength(v as json.Value, ptr as string) {
    if (not json.has($v, $ptr)) {
        return 0;
    }
    if (json.typeOf($v, $ptr) != "list") {
        return 0;
    }
    return json.length($v, $ptr);
}

/**
 * Address one element of a JSON list.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer to the list
 * @param index {int} the element index
 * @return {json.Value} the element
 * @internal
 */
func nodeItem(v as json.Value, ptr as string, index as int) {
    return json.get($v, $ptr + "/" + convert.toString($index));
}

/**
 * Read a JSON list of strings, defaulting to an empty list.
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer to the list
 * @return {list of string} the elements, stringified
 * @internal
 */
func nodeStringList(v as json.Value, ptr as string) {
    def out as list of string init [];
    for (def i in 0..nodeLength($v, $ptr)) {
        $out[] = nodeString($v, $ptr + "/" + convert.toString($i));
    }
    return $out;
}

/**
 * Read one field of every element of a JSON list of maps (the storefront's
 * shape for genres, categories and tags).
 *
 * @param v {json.Value} the document
 * @param ptr {string} a JSON Pointer to the list
 * @param field {string} the field to collect from each element
 * @return {list of string} the collected values
 * @internal
 */
func nodeFieldList(v as json.Value, ptr as string, field as string) {
    def out as list of string init [];
    for (def i in 0..nodeLength($v, $ptr)) {
        $out[] = nodeString($v, $ptr + "/" + convert.toString($i) + "/" + $field);
    }
    return $out;
}

/**
 * Narrow a float to an int, answering 0 rather than throwing.
 * `convert.toInt` raises past the int64 range, which would otherwise abort
 * a whole struct fold over one bad field.
 *
 * @param value {float} the number to narrow
 * @return {int} the truncated value, or 0 when it does not fit
 * @internal
 */
func floatToIntOrZero(value as float) {
    try {
        return convert.toInt($value);
    } catch (e) {
        return 0;
    }
}

/**
 * Parse an int, answering 0 rather than throwing.
 *
 * @param text {string} the text to parse
 * @return {int} the number, or 0 when it does not parse
 * @internal
 */
func parseIntOrZero(text as string) {
    try {
        return convert.toInt(strings.trim($text));
    } catch (e) {
        return 0;
    }
}

/**
 * Parse a float, answering 0.0 rather than throwing.
 *
 * @param text {string} the text to parse
 * @return {float} the number, or 0.0 when it does not parse
 * @internal
 */
func parseFloatOrZero(text as string) {
    try {
        return convert.toFloat(strings.trim($text));
    } catch (e) {
        return 0.0;
    }
}

/**
 * Whether a word spells an affirmative.
 *
 * @param text {string} the word
 * @return {bool} true for "1", "true", "yes", and "on", in any case
 * @internal
 */
func truthyWord(text as string) {
    def word as string init strings.lower(strings.trim($text));
    return $word == "1" or $word == "true" or $word == "yes" or $word == "on";
}

/**
 * Map a bool onto 1 / 0.
 *
 * @param value {bool} the flag
 * @return {int} 1 when true, 0 when false
 * @internal
 */
func boolToInt(value as bool) {
    if ($value) {
        return 1;
    }
    return 0;
}

/**
 * Render a bool as the "1" / "0" the API expects in a query.
 *
 * @param value {bool} the flag
 * @return {string} "1" or "0"
 * @internal
 */
func boolParam(value as bool) {
    return convert.toString(boolToInt($value));
}
