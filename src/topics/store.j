# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the storefront API on store.steampowered.com: prices and metadata.
# Spliced into steam.j via include - not a standalone module.

/**
 * Storefront path serving one app's full record.
 */
export def const APPDETAILS_PATH as string init "/api/appdetails";

/**
 * Storefront path serving one package's record.
 */
export def const PACKAGEDETAILS_PATH as string init "/api/packagedetails";

/**
 * Storefront path serving the front page's featured lists.
 */
export def const FEATURED_PATH as string init "/api/featured";

/**
 * What a game costs on the storefront now. Amounts are ints in minor units
 * (cents, pence); `finalFormatted` is Steam's rendering for the country, the
 * one to show a user.
 *
 * @field currency {string} ISO currency code, e.g. "EUR"
 * @field initial {int} the undiscounted price, in minor units
 * @field final {int} what it costs today, in minor units
 * @field discountPercent {int} the discount, 0 when there is none
 * @field initialFormatted {string} Steam's rendering of `initial`, "" at full price
 * @field finalFormatted {string} Steam's rendering of `final`
 */
export def struct Price {
    currency as string,
    initial as int,
    final as int,
    discountPercent as int,
    initialFormatted as string,
    finalFormatted as string
};

/**
 * Which platforms a title ships a client for.
 *
 * @field windows {bool} a Windows build exists
 * @field mac {bool} a macOS build exists
 * @field linux {bool} a native Linux build exists (Proton is not counted)
 */
export def struct Platforms {
    windows as bool,
    mac as bool,
    linux as bool
};

/**
 * A title's storefront record. `price`, availability and age rating depend
 * on the client's `countryCode`. Free and unreleased titles carry a zeroed
 * `price`; check `isFree` and `comingSoon` first.
 *
 * @field appId {int} the application id
 * @field name {string} the title
 * @field kind {string} what it is: "game", "dlc", "demo", "music", ...
 * @field requiredAge {int} the age gate, 0 when there is none
 * @field isFree {bool} whether it costs nothing
 * @field shortDescription {string} the one-paragraph blurb
 * @field aboutTheGame {string} the long description, as HTML
 * @field supportedLanguages {string} Steam's language list, as HTML
 * @field headerImage {string} URL of the store banner
 * @field capsuleImage {string} URL of the small capsule
 * @field website {string} the developer's own site, "" when there is none
 * @field developers {list of string} who made it
 * @field publishers {list of string} who publishes it
 * @field price {Price} what it costs, zeroed when free or unreleased
 * @field platforms {Platforms} which clients exist
 * @field categories {list of string} store categories, e.g. "Multi-player"
 * @field genres {list of string} store genres, e.g. "Action"
 * @field dlc {list of int} app ids of its downloadable content
 * @field metacriticScore {int} the Metacritic score, 0 when unscored
 * @field metacriticUrl {string} the Metacritic page, "" when unscored
 * @field recommendations {int} how many user recommendations it has
 * @field achievementCount {int} how many achievements it defines
 * @field releaseDate {string} the release date as Steam renders it
 * @field comingSoon {bool} whether it has not been released yet
 */
export def struct AppDetails {
    appId as int,
    name as string,
    kind as string,
    requiredAge as int,
    isFree as bool,
    shortDescription as string,
    aboutTheGame as string,
    supportedLanguages as string,
    headerImage as string,
    capsuleImage as string,
    website as string,
    developers as list of string,
    publishers as list of string,
    price as Price,
    platforms as Platforms,
    categories as list of string,
    genres as list of string,
    dlc as list of int,
    metacriticScore as int,
    metacriticUrl as string,
    recommendations as int,
    achievementCount as int,
    releaseDate as string,
    comingSoon as bool
};

/**
 * One entry of `appPrices`. `found` is false when the storefront has no
 * record (delisted or region-locked); a free app has `found` true and
 * `free` true. Both carry a zeroed `price`.
 *
 * @field appId {int} the application id
 * @field found {bool} whether the storefront had a record for it
 * @field free {bool} whether it is free to play, in which case `price` is zeroed
 * @field price {Price} the price, zeroed when the app is free or unlisted
 */
export def struct AppPrice {
    appId as int,
    found as bool,
    free as bool,
    price as Price
};

/**
 * A package: apps sold as one storefront item.
 *
 * @field packageId {int} the package id
 * @field name {string} the package's name
 * @field pageImage {string} URL of its store image
 * @field apps {list of App} the apps it contains
 * @field price {Price} what the package costs
 * @field platforms {Platforms} which clients its apps have
 * @field releaseDate {string} the release date as Steam renders it
 * @field comingSoon {bool} whether it has not been released yet
 */
export def struct PackageDetails {
    packageId as int,
    name as string,
    pageImage as string,
    apps as list of App,
    price as Price,
    platforms as Platforms,
    releaseDate as string,
    comingSoon as bool
};

/**
 * One entry of a storefront featured list.
 *
 * @field appId {int} the application id
 * @field name {string} the title
 * @field discounted {bool} whether it is on sale
 * @field discountPercent {int} the discount, 0 when there is none
 * @field originalPrice {int} the undiscounted price, in minor units
 * @field finalPrice {int} what it costs today, in minor units
 * @field currency {string} ISO currency code of those amounts
 * @field capsuleImage {string} URL of the wide capsule Steam features it with
 * @field headerImage {string} URL of its store header image
 * @field windowsAvailable {bool} a Windows build exists
 * @field macAvailable {bool} a macOS build exists
 * @field linuxAvailable {bool} a native Linux build exists
 */
export def struct FeaturedApp {
    appId as int,
    name as string,
    discounted as bool,
    discountPercent as int,
    originalPrice as int,
    finalPrice as int,
    currency as string,
    capsuleImage as string,
    headerImage as string,
    windowsAvailable as bool,
    macAvailable as bool,
    linuxAvailable as bool
};

/**
 * The storefront front page, as four featured lists.
 *
 * @field largeCapsules {list of FeaturedApp} the big rotating banners, often
 *        empty outside a sale
 * @field windows {list of FeaturedApp} featured for Windows
 * @field mac {list of FeaturedApp} featured for macOS
 * @field linux {list of FeaturedApp} featured for Linux
 */
export def struct FeaturedLists {
    largeCapsules as list of FeaturedApp,
    windows as list of FeaturedApp,
    mac as list of FeaturedApp,
    linux as list of FeaturedApp
};

/**
 * One storefront reply, with "no such app" separated from "it failed". The
 * storefront answers a missing app with `success: false` and HTTP 200; that
 * is returned as a value, while a transport failure propagates.
 *
 * @field found {bool} whether the storefront had a record
 * @field data {json.Value} the record's `data` object, empty when absent
 * @internal
 */
def struct StoreRecord {
    found as bool,
    data as json.Value
};

/**
 * Read a title's storefront record for the client's country and language.
 * Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @param appId {int} the application id
 * @return {AppDetails} the record
 * @throws {Error} kind "steam" on a bad app id, when the storefront has no
 *                 record (a delisted or region-locked title), or on a
 *                 transport failure
 * @example
 *   def d as steam.AppDetails init steam.appDetails($c, 620);
 *   io.printf("%s - %s\n", $d.name, $d.price.finalFormatted);
 */
export func appDetails(c as Client, appId as int) {
    ensureAppId($appId);
    def record as StoreRecord init fetchAppRecord($c, $appId);
    if (not $record.found) {
        raiseError(noRecordMessage($c, $appId));
    }
    return appDetailsFrom($record.data, $appId);
}

/**
 * Read several titles' storefront records, one request per id (the
 * storefront takes one id per request). Ids without a record are left out;
 * a transport failure throws, so a short list never means the network
 * broke. An empty list makes no request.
 *
 * @param c {Client} an API client, with or without a key
 * @param appIds {list of int} the application ids
 * @return {list of AppDetails} one record per app the storefront knew, in
 *         the order asked; apps it has no record of are left out
 * @throws {Error} kind "steam" on a non-positive app id - checked for every
 *                 id before the first request - or on a transport failure
 */
export func appDetailsMany(c as Client, appIds as list of int) {
    for (def id in $appIds) {
        ensureAppId($id);
    }
    def out as list of AppDetails init [];
    for (def id in $appIds) {
        def record as StoreRecord init fetchAppRecord($c, $id);
        if ($record.found) {
            $out[] = appDetailsFrom($record.data, $id);
        }
    }
    return $out;
}

/**
 * Read what several titles cost, one request per id: the storefront answers
 * a comma-separated `appids` with 400 and ignores `filter=price_overview`.
 * An id without a record comes back with `found` false; a transport failure
 * throws. Every id is validated before the first request. Each request pulls
 * a full record over its own TLS connection (`rest` keeps no keep-alive), so
 * spread a large list over time.
 *
 * @param c {Client} an API client, with or without a key
 * @param appIds {list of int} the application ids
 * @return {list of AppPrice} one entry per id asked, in the same order
 * @throws {Error} kind "steam" on an empty list, a non-positive app id, or a
 *                 transport failure
 * @example
 *   for (def p in steam.appPrices($c, [620, 440])) {
 *       io.printf("%d %s\n", $p.appId, $p.price.finalFormatted);
 *   }
 */
export func appPrices(c as Client, appIds as list of int) {
    if (len($appIds) == 0) {
        raiseError("at least one app id is required");
    }
    for (def id in $appIds) {
        ensureAppId($id);
    }
    def out as list of AppPrice init [];
    for (def id in $appIds) {
        $out[] = onePrice($c, $id);
    }
    return $out;
}

/**
 * Read a package's storefront record.
 *
 * @param c {Client} an API client, with or without a key
 * @param packageId {int} the package id
 * @return {PackageDetails} the record
 * @throws {Error} kind "steam" on a non-positive id, when the storefront
 *                 has no record, or on a transport failure
 */
export func packageDetails(c as Client, packageId as int) {
    if ($packageId <= 0) {
        raiseError("the package id must be positive, got " + convert.toString($packageId));
    }
    def body as json.Value init storeGet(
        $c,
        PACKAGEDETAILS_PATH,
        {"packageids": convert.toString($packageId), "cc": $c.countryCode, "l": $c.language});
    def slot as string init "/" + convert.toString($packageId);
    if (not nodeBool($body, $slot + "/success")) {
        raiseError("the storefront has no record of package " +
            convert.toString($packageId) + " in country " + $c.countryCode);
    }
    return packageDetailsFrom(json.get($body, $slot + "/data"), $packageId);
}

/**
 * Read the storefront's featured lists for the client's country. Keyless.
 *
 * @param c {Client} an API client, with or without a key
 * @return {FeaturedLists} the front page's four lists
 * @throws {Error} kind "steam" on a transport failure
 */
export func featured(c as Client) {
    def body as json.Value init storeGet(
        $c,
        FEATURED_PATH,
        {"cc": $c.countryCode, "l": $c.language});
    return FeaturedLists{
        largeCapsules: featuredListFrom($body, "/large_capsules"),
        windows: featuredListFrom($body, "/featured_win"),
        mac: featuredListFrom($body, "/featured_mac"),
        linux: featuredListFrom($body, "/featured_linux")
    };
}

/**
 * Whether a price is currently reduced.
 *
 * @param price {Price} the price to inspect
 * @return {bool} true when `discountPercent` is positive and `final` is below
 *         `initial`
 */
export func isDiscounted(price as Price) {
    return $price.discountPercent > 0 and $price.initial > $price.final;
}

/**
 * How much a discount takes off, in the currency's minor units.
 *
 * @param price {Price} the price to inspect
 * @return {int} the saving, 0 at full price
 */
export func savings(price as Price) {
    if (not isDiscounted($price)) {
        return 0;
    }
    return $price.initial - $price.final;
}

/**
 * A price in whole currency units: the amount divided by 100. Yen and other
 * zero-decimal currencies are divided too, because Steam reports them in
 * hundredths as well.
 *
 * @param minorUnits {int} an amount in cents, pence, or the like
 * @return {float} the same amount in whole units
 */
export func majorUnits(minorUnits as int) {
    return convert.toFloat($minorUnits) / 100.0;
}

/**
 * A short discount label for a price.
 *
 * @param price {Price} the price to describe
 * @return {string} e.g. "-66%", or "" at full price
 */
export func discountLabel(price as Price) {
    if (not isDiscounted($price)) {
        return "";
    }
    return "-" + convert.toString($price.discountPercent) + "%";
}

/**
 * Ask the storefront for one app and report whether it had a record.
 *
 * @param c {Client} an API client
 * @param appId {int} the application id, already validated
 * @return {StoreRecord} the record, or `found` false when there is none
 * @throws {Error} kind "steam" on a transport failure or a non-JSON reply
 * @internal
 */
func fetchAppRecord(c as Client, appId as int) {
    def body as json.Value init storeGet(
        $c,
        APPDETAILS_PATH,
        {"appids": convert.toString($appId), "cc": $c.countryCode, "l": $c.language});
    def slot as string init "/" + convert.toString($appId);
    if (not nodeBool($body, $slot + "/success")) {
        return StoreRecord{found: false, data: json.map()};
    }
    return StoreRecord{found: true, data: json.get($body, $slot + "/data")};
}

/**
 * Explain a storefront record that is not there.
 *
 * @param c {Client} the client whose country was asked about
 * @param appId {int} the application id
 * @return {string} a sentence naming the usual causes
 * @internal
 */
func noRecordMessage(c as Client, appId as int) {
    return "the storefront has no record of app " + convert.toString($appId) +
        " in country " + $c.countryCode +
        " - it may be delisted, region-locked, or not an app at all";
}

/**
 * Fold a storefront app record into a struct.
 *
 * @param data {json.Value} the `data` object of an `appdetails` reply
 * @param appId {int} the app the request was for
 * @return {AppDetails} the folded record
 * @internal
 */
func appDetailsFrom(data as json.Value, appId as int) {
    def dlcIds as list of int init [];
    for (def i in 0..nodeLength($data, "/dlc")) {
        $dlcIds[] = nodeInt($data, "/dlc/" + convert.toString($i));
    }
    return AppDetails{
        appId: $appId,
        name: nodeString($data, "/name"),
        kind: nodeString($data, "/type"),
        requiredAge: nodeInt($data, "/required_age"),
        isFree: nodeBool($data, "/is_free"),
        shortDescription: nodeString($data, "/short_description"),
        aboutTheGame: nodeString($data, "/about_the_game"),
        supportedLanguages: nodeString($data, "/supported_languages"),
        headerImage: nodeString($data, "/header_image"),
        capsuleImage: nodeString($data, "/capsule_image"),
        website: nodeString($data, "/website"),
        developers: nodeStringList($data, "/developers"),
        publishers: nodeStringList($data, "/publishers"),
        price: priceFrom($data, "/price_overview"),
        platforms: platformsFrom($data, "/platforms"),
        categories: nodeFieldList($data, "/categories", "description"),
        genres: nodeFieldList($data, "/genres", "description"),
        dlc: $dlcIds,
        metacriticScore: nodeInt($data, "/metacritic/score"),
        metacriticUrl: nodeString($data, "/metacritic/url"),
        recommendations: nodeInt($data, "/recommendations/total"),
        achievementCount: nodeInt($data, "/achievements/total"),
        releaseDate: nodeString($data, "/release_date/date"),
        comingSoon: nodeBool($data, "/release_date/coming_soon")
    };
}

/**
 * Fold a storefront package record into a struct.
 *
 * @param data {json.Value} the `data` object of a `packagedetails` reply
 * @param packageId {int} the package the request was for
 * @return {PackageDetails} the folded record
 * @internal
 */
func packageDetailsFrom(data as json.Value, packageId as int) {
    def contents as list of App init [];
    for (def i in 0..nodeLength($data, "/apps")) {
        def node as json.Value init nodeItem($data, "/apps", $i);
        $contents[] = App{appId: nodeInt($node, "/id"), name: nodeString($node, "/name")};
    }
    return PackageDetails{
        packageId: $packageId,
        name: nodeString($data, "/name"),
        pageImage: nodeString($data, "/page_image"),
        apps: $contents,
        price: priceFrom($data, "/price"),
        platforms: platformsFrom($data, "/platforms"),
        releaseDate: nodeString($data, "/release_date/date"),
        comingSoon: nodeBool($data, "/release_date/coming_soon")
    };
}

/**
 * Fold a `price_overview` object into a struct.
 *
 * An absent object (a free or unreleased title) folds to a zeroed `Price`.
 *
 * @param node {json.Value} the enclosing document
 * @param ptr {string} JSON Pointer to the price object
 * @return {Price} the folded price
 * @internal
 */
func priceFrom(node as json.Value, ptr as string) {
    return Price{
        currency: nodeString($node, $ptr + "/currency"),
        initial: nodeInt($node, $ptr + "/initial"),
        final: nodeInt($node, $ptr + "/final"),
        discountPercent: nodeInt($node, $ptr + "/discount_percent"),
        initialFormatted: nodeString($node, $ptr + "/initial_formatted"),
        finalFormatted: nodeString($node, $ptr + "/final_formatted")
    };
}

/**
 * Fold a `platforms` object into a struct.
 *
 * @param node {json.Value} the enclosing document
 * @param ptr {string} JSON Pointer to the platforms object
 * @return {Platforms} the folded flags
 * @internal
 */
func platformsFrom(node as json.Value, ptr as string) {
    return Platforms{
        windows: nodeBool($node, $ptr + "/windows"),
        mac: nodeBool($node, $ptr + "/mac"),
        linux: nodeBool($node, $ptr + "/linux")
    };
}

/**
 * Read one app's price; a missing record becomes `found` false, a transport
 * failure propagates.
 *
 * @param c {Client} an API client
 * @param appId {int} the application id, already validated
 * @return {AppPrice} the entry, with `found` false when the storefront
 *         has no record of the app
 * @internal
 */
func onePrice(c as Client, appId as int) {
    def record as StoreRecord init fetchAppRecord($c, $appId);
    if (not $record.found) {
        return AppPrice{appId: $appId, found: false, free: false, price: emptyPrice()};
    }
    return appPriceFor(appDetailsFrom($record.data, $appId));
}

/**
 * Reduce a storefront record to its price.
 *
 * @param details {AppDetails} the record
 * @return {AppPrice} the price entry
 * @internal
 */
func appPriceFor(details as AppDetails) {
    return AppPrice{
        appId: $details.appId,
        found: true,
        free: $details.isFree,
        price: $details.price
    };
}

/**
 * Fold one of the front page's featured lists into structs.
 *
 * @param body {json.Value} the decoded `featured` reply
 * @param ptr {string} JSON Pointer to the list
 * @return {list of FeaturedApp} the folded entries
 * @internal
 */
func featuredListFrom(body as json.Value, ptr as string) {
    def out as list of FeaturedApp init [];
    for (def i in 0..nodeLength($body, $ptr)) {
        def node as json.Value init nodeItem($body, $ptr, $i);
        $out[] = FeaturedApp{
            appId: nodeInt($node, "/id"),
            name: nodeString($node, "/name"),
            discounted: nodeBool($node, "/discounted"),
            discountPercent: nodeInt($node, "/discount_percent"),
            originalPrice: nodeInt($node, "/original_price"),
            finalPrice: nodeInt($node, "/final_price"),
            currency: nodeString($node, "/currency"),
            capsuleImage: nodeString($node, "/large_capsule_image"),
            headerImage: nodeString($node, "/header_image"),
            windowsAvailable: nodeBool($node, "/windows_available"),
            macAvailable: nodeBool($node, "/mac_available"),
            linuxAvailable: nodeBool($node, "/linux_available")
        };
    }
    return $out;
}

/**
 * A zeroed price, for a title the storefront quotes no price for.
 *
 * @return {Price} the empty price
 * @internal
 */
func emptyPrice() {
    return Price{
        currency: "",
        initial: 0,
        final: 0,
        discountPercent: 0,
        initialFormatted: "",
        finalFormatted: ""
    };
}
