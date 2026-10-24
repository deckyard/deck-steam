# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the Community Market: item prices and the money parsing they need.
# Spliced into steam.j via include - not a standalone module.

/**
 * Community path serving one item's current market price.
 */
export def const PRICEOVERVIEW_PATH as string init "/market/priceoverview/";

/**
 * Largest amount `parseMoneyCents` scales into minor units. Multiplying by
 * 100 must stay inside an int64, so anything larger is malformed input and
 * reads as 0.
 */
export def const MAX_MONEY_UNITS as float init 1.0e15;

/**
 * What the Community Market charges for one item. Steam sends only
 * locale-formatted strings (`"0,03€"`, `"$1,234.56"`); the `*Cents` fields
 * are `parseMoneyCents` readings of them. Show the strings, compute with
 * the cents. Steam omits `volume` for a thinly traded item; it then reads 0.
 *
 * @field found {bool} whether the market had a price at all
 * @field lowestPrice {string} the cheapest listing, as Steam formatted it
 * @field medianPrice {string} the median recent sale, as Steam formatted it
 * @field lowestCents {int} `lowestPrice` in the currency's minor units
 * @field medianCents {int} `medianPrice` in the currency's minor units
 * @field volume {int} copies sold in the last 24 hours
 */
export def struct MarketPrice {
    found as bool,
    lowestPrice as string,
    medianPrice as string,
    lowestCents as int,
    medianCents as int,
    volume as int
};

/**
 * Look up an item's Community Market price, in the client's `currency`.
 * Keyless. The item is named by its market hash name, the exact string in
 * its market URL with wear and quality, e.g.
 * `"AK-47 | Redline (Field-Tested)"`. Steam allows roughly twenty requests a
 * minute per address; for a loop, raise `withRetries` and `withBackoff`.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the game the item belongs to, e.g. 730
 * @param marketHashName {string} the item's exact market name
 * @return {MarketPrice} the quote, with `found` false when the market has
 *         no price for the item
 * @throws {Error} kind "steam" on a bad app id, a blank name, or a
 *                 transport failure
 * @example
 *   def c as steam.Client init steam.withCurrency(steam.client(""), steam.CURRENCY_EUR);
 *   def q as steam.MarketPrice init
 *       steam.priceOverview($c, 730, "AK-47 | Redline (Field-Tested)");
 *   io.printf("%s (%d sold today)\n", $q.lowestPrice, $q.volume);
 */
export func priceOverview(c as Client, appId as int, marketHashName as string) {
    def params as map of string to string init {
        "appid": convert.toString(ensureAppId($appId)),
        "currency": convert.toString($c.currency),
        "market_hash_name": ensureText($marketHashName, "market hash name")
    };
    def body as json.Value init communityGet($c, PRICEOVERVIEW_PATH, $params);
    return marketPriceFrom($body);
}

/**
 * The Community Market page of one item.
 *
 * @param appId {int} the game the item belongs to
 * @param marketHashName {string} the item's exact market name
 * @return {string} the listing URL, with the name percent-encoded
 * @throws {Error} kind "steam" on a bad app id or a blank name
 * @example
 *   steam.marketListingUrl(730, "AK-47 | Redline (Field-Tested)");
 */
export func marketListingUrl(appId as int, marketHashName as string) {
    return COMMUNITY_BASE + "/market/listings/" + convert.toString(ensureAppId($appId)) +
        "/" + uri.encode(ensureText($marketHashName, "market hash name"));
}

/**
 * The Community Market search page for one game.
 *
 * @param appId {int} the game to search within
 * @param term {string} the search text, "" to browse everything
 * @return {string} the search URL, query form-encoded
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func marketSearchUrl(appId as int, term as string) {
    def query as map of string to string init {"appid": convert.toString(ensureAppId($appId))};
    def text as string init strings.trim($term);
    if ($text != "") {
        $query["q"] = $text;
    }
    return COMMUNITY_BASE + "/market/search?" + uri.buildQuery($query);
}

/**
 * The ISO code of a wallet currency id.
 *
 * @param currency {int} one of the `CURRENCY_*` constants
 * @return {string} the ISO code, or "" for an id this deck does not name
 */
export func currencyCode(currency as int) {
    match ($currency) {
        when 1 { return "USD"; }
        when 2 { return "GBP"; }
        when 3 { return "EUR"; }
        when 4 { return "CHF"; }
        when 5 { return "RUB"; }
        when 6 { return "PLN"; }
        when 7 { return "BRL"; }
        when 8 { return "JPY"; }
        when 20 { return "CAD"; }
        when 21 { return "AUD"; }
        else { return ""; }
    }
}

/**
 * Read a locale-formatted money string (`"$1,234.56"`, `"1.234,56€"`,
 * `"CDN$ 4.56"`) as a number. The last `.` or `,` is the decimal mark when
 * one or two digits follow it, and a thousands separator otherwise, so
 * `"12.345"` is 12345.0 and `"12.34"` is 12.34. Other characters, including
 * a minus sign, are ignored. Text without digits, or a digit run too long
 * to parse, reads as 0.0 rather than throwing.
 *
 * @param text {string} a formatted amount
 * @return {float} the amount, or 0.0 when the text holds no usable number
 * @example
 *   steam.parseMoney("1.234,56€");   # 1234.56
 */
export func parseMoney(text as string) {
    def digits as list of string init [];
    def lastSeparator as int init -1;
    for (def ch in strings.chars($text)) {
        if ($ch >= "0" and $ch <= "9") {
            $digits[] = $ch;
        } elseif ($ch == "." or $ch == ",") {
            $lastSeparator = len($digits);
        }
    }
    if (len($digits) == 0) {
        return 0.0;
    }
    def fraction as int init 0;
    if ($lastSeparator >= 0) {
        def trailing as int init len($digits) - $lastSeparator;
        if ($trailing >= 1 and $trailing <= 2) {
            $fraction = $trailing;
        }
    }
    def whole as float init parseFloatOrZero(strings.join($digits, ""));
    if ($fraction == 1) {
        return $whole / 10.0;
    }
    if ($fraction == 2) {
        return $whole / 100.0;
    }
    return $whole;
}

/**
 * Read a formatted money string as an amount in minor units.
 *
 * @param text {string} a formatted amount
 * @return {int} the amount in cents, pence, or the like; 0 when the text
 *         holds no usable number or names an amount past `MAX_MONEY_UNITS`
 */
export func parseMoneyCents(text as string) {
    def amount as float init parseMoney($text);
    if ($amount > MAX_MONEY_UNITS or $amount < -MAX_MONEY_UNITS) {
        return 0;
    }
    return convert.toInt(math.round($amount * 100.0));
}

/**
 * Read a locale-grouped count (`"12,345"`, `"12.345"`), such as a sales
 * volume, as an int. Every non-digit is ignored.
 *
 * @param text {string} a formatted count
 * @return {int} the count, or 0 when the text holds no digits or names a
 *         number too large to be one
 */
export func parseCount(text as string) {
    def digits as list of string init [];
    for (def ch in strings.chars($text)) {
        if ($ch >= "0" and $ch <= "9") {
            $digits[] = $ch;
        }
    }
    if (len($digits) == 0) {
        return 0;
    }
    return parseIntOrZero(strings.join($digits, ""));
}

/**
 * Fold a `priceoverview` reply into a struct.
 *
 * @param body {json.Value} the decoded reply
 * @return {MarketPrice} the folded quote
 * @internal
 */
func marketPriceFrom(body as json.Value) {
    if (not nodeBool($body, "/success")) {
        return MarketPrice{
            found: false,
            lowestPrice: "",
            medianPrice: "",
            lowestCents: 0,
            medianCents: 0,
            volume: 0
        };
    }
    def lowest as string init nodeString($body, "/lowest_price");
    def median as string init nodeString($body, "/median_price");
    return MarketPrice{
        found: true,
        lowestPrice: $lowest,
        medianPrice: $median,
        lowestCents: parseMoneyCents($lowest),
        medianCents: parseMoneyCents($median),
        volume: parseCount(nodeString($body, "/volume"))
    };
}
