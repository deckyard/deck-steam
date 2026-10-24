# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the IEconService and ISteamEconomy interfaces: trades and items.
# Spliced into steam.j via include - not a standalone module.

/**
 * Trade offer state: made, and waiting for the other side.
 */
export def const TRADE_ACTIVE as int init 2;

/**
 * Trade offer state: accepted, items exchanged.
 */
export def const TRADE_ACCEPTED as int init 3;

/**
 * Trade offer state: withdrawn by whoever made it.
 */
export def const TRADE_CANCELED as int init 6;

/**
 * Trade offer state: turned down by whoever received it.
 */
export def const TRADE_DECLINED as int init 7;

/**
 * Trade offer state: accepted, but the items are in escrow.
 */
export def const TRADE_IN_ESCROW as int init 11;

/**
 * One item on one side of a trade offer, named by catalogue coordinates.
 * A title takes a separate `ISteamEconomy` class lookup, which this deck
 * does not make.
 *
 * @field appId {int} the game the item belongs to
 * @field contextId {string} the inventory context within that game
 * @field assetId {string} the item's unique inventory id
 * @field classId {string} the item's class (what kind of thing it is)
 * @field instanceId {string} the item's instance (its particular attributes)
 * @field amount {int} how many, for a stackable item
 * @field missing {bool} the item has left the inventory since the offer was
 *        made, so accepting fails
 */
export def struct TradeAsset {
    appId as int,
    contextId as string,
    assetId as string,
    classId as string,
    instanceId as string,
    amount as int,
    missing as bool
};

/**
 * One trade offer.
 *
 * @field tradeOfferId {string} the offer's id
 * @field otherSteamId {string} the other party's 64-bit Steam id, widened
 *        from the 32-bit account id Steam sends
 * @field message {string} the note attached to the offer
 * @field state {int} one of the `TRADE_*` constants
 * @field isOurOffer {bool} whether the key's account made the offer
 * @field timeCreated {int} Unix time the offer was made
 * @field timeUpdated {int} Unix time the offer last changed
 * @field expirationTime {int} Unix time the offer lapses
 * @field escrowEndDate {int} Unix time escrow lifts, 0 when there is none
 * @field toGive {list of TradeAsset} what the key's account would hand over
 * @field toReceive {list of TradeAsset} what it would get back
 */
export def struct TradeOffer {
    tradeOfferId as string,
    otherSteamId as string,
    message as string,
    state as int,
    isOurOffer as bool,
    timeCreated as int,
    timeUpdated as int,
    expirationTime as int,
    escrowEndDate as int,
    toGive as list of TradeAsset,
    toReceive as list of TradeAsset
};

/**
 * The trade offers on both sides of one account.
 *
 * @field sent {list of TradeOffer} offers the account has made
 * @field received {list of TradeOffer} offers made to the account
 */
export def struct TradeOffers {
    sent as list of TradeOffer,
    received as list of TradeOffer
};

/**
 * Trade offer counts without the offers: the cheap call to poll, with
 * `tradeOffers` only when a count moves.
 *
 * @field pendingReceived {int} incoming offers still awaiting an answer
 * @field newReceived {int} incoming offers arrived since the cutoff
 * @field updatedReceived {int} incoming offers changed since the cutoff
 * @field pendingSent {int} outgoing offers still awaiting an answer
 * @field newlyAcceptedSent {int} outgoing offers accepted since the cutoff
 * @field updatedSent {int} outgoing offers changed since the cutoff
 * @field escrowReceived {int} incoming offers held in escrow
 * @field escrowSent {int} outgoing offers held in escrow
 */
export def struct TradeOffersSummary {
    pendingReceived as int,
    newReceived as int,
    updatedReceived as int,
    pendingSent as int,
    newlyAcceptedSent as int,
    updatedSent as int,
    escrowReceived as int,
    escrowSent as int
};

/**
 * A price Valve publishes for an item class in a game's item store.
 *
 * @field classId {string} the item class
 * @field name {string} the store's internal name for it
 * @field date {string} the date the item was added, "" when Valve gives none
 * @field prices {map of string to int} price per currency code, in minor units
 */
export def struct AssetPrice {
    classId as string,
    name as string,
    date as string,
    prices as map of string to int
};

/**
 * Count the trade offers of the key's own account.
 *
 * @param c {Client} an API client with a key
 * @param timeCutoff {int} Unix time the "new" and "updated" counts are
 *        measured from; 0 counts everything
 * @return {TradeOffersSummary} the counts
 * @throws {Error} kind "steam" without a key, on a negative cutoff, or on
 *                 a transport failure
 */
export func tradeOffersSummary(c as Client, timeCutoff as int) {
    requireKey($c, "reading trade offers");
    if ($timeCutoff < 0) {
        raiseError("the time cutoff must not be negative");
    }
    def params as map of string to string init {"time_last_visit": convert.toString($timeCutoff)};
    def body as json.Value init apiGet($c, "IEconService", "GetTradeOffersSummary", 1, $params);
    return TradeOffersSummary{
        pendingReceived: nodeInt($body, "/response/pending_received_count"),
        newReceived: nodeInt($body, "/response/new_received_count"),
        updatedReceived: nodeInt($body, "/response/updated_received_count"),
        pendingSent: nodeInt($body, "/response/pending_sent_count"),
        newlyAcceptedSent: nodeInt($body, "/response/newly_accepted_sent_count"),
        updatedSent: nodeInt($body, "/response/updated_sent_count"),
        escrowReceived: nodeInt($body, "/response/escrow_received_count"),
        escrowSent: nodeInt($body, "/response/escrow_sent_count")
    };
}

/**
 * List the trade offers of the key's own account. There is no `steamid`
 * parameter: an offer is private to its parties. Item descriptions are not
 * requested.
 *
 * @param c {Client} an API client with a key
 * @param getSent {bool} include offers the account has made
 * @param getReceived {bool} include offers made to the account
 * @param activeOnly {bool} skip offers that are already settled
 * @return {TradeOffers} the offers, in the two directions
 * @throws {Error} kind "steam" without a key, when both directions are
 *                 off, or on a transport failure
 * @example
 *   def t as steam.TradeOffers init steam.tradeOffers($c, false, true, true);
 *   for (def o in $t.received) {
 *       io.printf("%s from %s\n", $o.tradeOfferId, $o.otherSteamId);
 *   }
 */
export func tradeOffers(c as Client, getSent as bool, getReceived as bool, activeOnly as bool) {
    requireKey($c, "reading trade offers");
    if (not $getSent and not $getReceived) {
        raiseError("ask for sent offers, received offers, or both");
    }
    def params as map of string to string init {
        "get_sent_offers": boolParam($getSent),
        "get_received_offers": boolParam($getReceived),
        "active_only": boolParam($activeOnly),
        "get_descriptions": "0"
    };
    def body as json.Value init apiGet($c, "IEconService", "GetTradeOffers", 1, $params);
    return TradeOffers{
        sent: tradeOfferListFrom($body, "/response/trade_offers_sent"),
        received: tradeOfferListFrom($body, "/response/trade_offers_received")
    };
}

/**
 * Read one trade offer by id.
 *
 * @param c {Client} an API client with a key
 * @param tradeOfferId {string} the offer id
 * @return {TradeOffer} the offer
 * @throws {Error} kind "steam" without a key, on a non-numeric id, when
 *                 the offer is not the key's to read, or on a transport
 *                 failure
 */
export func tradeOffer(c as Client, tradeOfferId as string) {
    requireKey($c, "reading a trade offer");
    def id as string init strings.trim($tradeOfferId);
    if (not isDigits($id)) {
        raiseError("\"" + $id + "\" is not a trade offer id");
    }
    def params as map of string to string init {"tradeofferid": $id, "language": $c.language};
    def body as json.Value init apiGet($c, "IEconService", "GetTradeOffer", 1, $params);
    if (not json.has($body, "/response/offer")) {
        raiseError("no trade offer " + $id + " is visible to this key");
    }
    return tradeOfferFrom(json.get($body, "/response/offer"));
}

/**
 * Read the prices a game's item store charges, asking for the client's
 * currency. `prices` holds only the currencies Valve priced an item in.
 *
 * @param c {Client} an API client with a key
 * @param appId {int} the game
 * @return {list of AssetPrice} one entry per item class on sale
 * @throws {Error} kind "steam" without a key, on a bad app id, when the
 *                 game has no item store, or on a transport failure
 */
export func assetPrices(c as Client, appId as int) {
    requireKey($c, "reading asset prices");
    def params as map of string to string init {
        "appid": convert.toString(ensureAppId($appId)),
        "currency": currencyCode($c.currency),
        "language": $c.language
    };
    def body as json.Value init apiGet($c, "ISteamEconomy", "GetAssetPrices", 1, $params);
    if (not nodeBool($body, "/result/success")) {
        raiseError("app " + convert.toString($appId) + " publishes no asset prices");
    }
    def out as list of AssetPrice init [];
    for (def i in 0..nodeLength($body, "/result/assets")) {
        $out[] = assetPriceFrom(nodeItem($body, "/result/assets", $i));
    }
    return $out;
}

/**
 * The name of a trade offer state (1-11).
 *
 * @param state {int} one of the `TRADE_*` constants
 * @return {string} e.g. "active", or "unknown" for anything else
 */
export func tradeOfferStateName(state as int) {
    match ($state) {
        when 1 { return "invalid"; }
        when 2 { return "active"; }
        when 3 { return "accepted"; }
        when 4 { return "countered"; }
        when 5 { return "expired"; }
        when 6 { return "canceled"; }
        when 7 { return "declined"; }
        when 8 { return "invalid items"; }
        when 9 { return "awaiting confirmation"; }
        when 10 { return "canceled by second factor"; }
        when 11 { return "in escrow"; }
        else { return "unknown"; }
    }
}

/**
 * Whether an offer is still waiting on somebody.
 *
 * @param offer {TradeOffer} the offer
 * @return {bool} true while it is active (2) or awaiting confirmation (9)
 */
export func isPendingOffer(offer as TradeOffer) {
    return $offer.state == TRADE_ACTIVE or $offer.state == 9;
}

/**
 * Whether one side of an offer is empty: a gift or a scam, never a trade.
 *
 * @param offer {TradeOffer} the offer
 * @return {bool} true when one side of the offer is empty
 */
export func isOneSided(offer as TradeOffer) {
    return len($offer.toGive) == 0 or len($offer.toReceive) == 0;
}

/**
 * Fold a list of trade offers into structs.
 *
 * @param body {json.Value} the decoded response
 * @param ptr {string} JSON Pointer to the offer list
 * @return {list of TradeOffer} the folded offers
 * @internal
 */
func tradeOfferListFrom(body as json.Value, ptr as string) {
    def out as list of TradeOffer init [];
    for (def i in 0..nodeLength($body, $ptr)) {
        $out[] = tradeOfferFrom(nodeItem($body, $ptr, $i));
    }
    return $out;
}

/**
 * Fold one trade offer into a struct.
 *
 * The other party's 32-bit account id is widened to a 64-bit id.
 *
 * @param node {json.Value} one offer object
 * @return {TradeOffer} the folded offer
 * @internal
 */
func tradeOfferFrom(node as json.Value) {
    def other as int init nodeInt($node, "/accountid_other");
    def otherId as string init "";
    if ($other > 0) {
        $otherId = steamId64FromAccountId($other);
    }
    return TradeOffer{
        tradeOfferId: nodeString($node, "/tradeofferid"),
        otherSteamId: $otherId,
        message: nodeString($node, "/message"),
        state: nodeInt($node, "/trade_offer_state"),
        isOurOffer: nodeBool($node, "/is_our_offer"),
        timeCreated: nodeInt($node, "/time_created"),
        timeUpdated: nodeInt($node, "/time_updated"),
        expirationTime: nodeInt($node, "/expiration_time"),
        escrowEndDate: nodeInt($node, "/escrow_end_date"),
        toGive: tradeAssetsFrom($node, "/items_to_give"),
        toReceive: tradeAssetsFrom($node, "/items_to_receive")
    };
}

/**
 * Fold one side of a trade offer into structs.
 *
 * @param node {json.Value} the offer object
 * @param ptr {string} JSON Pointer to the item list
 * @return {list of TradeAsset} the folded items
 * @internal
 */
func tradeAssetsFrom(node as json.Value, ptr as string) {
    def out as list of TradeAsset init [];
    for (def i in 0..nodeLength($node, $ptr)) {
        def item as json.Value init nodeItem($node, $ptr, $i);
        $out[] = TradeAsset{
            appId: nodeInt($item, "/appid"),
            contextId: nodeString($item, "/contextid"),
            assetId: nodeString($item, "/assetid"),
            classId: nodeString($item, "/classid"),
            instanceId: nodeString($item, "/instanceid"),
            amount: nodeInt($item, "/amount"),
            missing: nodeBool($item, "/missing")
        };
    }
    return $out;
}

/**
 * Fold one `GetAssetPrices` row into a struct.
 *
 * @param node {json.Value} one element of the `assets` list
 * @return {AssetPrice} the folded entry
 * @internal
 */
func assetPriceFrom(node as json.Value) {
    def prices as map of string to int init {};
    if (json.has($node, "/prices") and json.typeOf($node, "/prices") == "map") {
        for (def code in json.keys($node, "/prices")) {
            $prices[$code] = nodeInt($node, "/prices/" + $code);
        }
    }
    return AssetPrice{
        classId: nodeString($node, "/classid"),
        name: nodeString($node, "/name"),
        date: nodeString($node, "/date"),
        prices: $prices
    };
}
