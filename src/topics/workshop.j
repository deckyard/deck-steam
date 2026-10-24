# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - the ISteamRemoteStorage interface: Workshop items and collections.
# Spliced into steam.j via include - not a standalone module.

/**
 * Workshop visibility: anyone can find the item.
 */
export def const WORKSHOP_PUBLIC as int init 0;

/**
 * Workshop visibility: only the author's friends can find the item.
 */
export def const WORKSHOP_FRIENDS as int init 1;

/**
 * Workshop visibility: only the author can see the item.
 */
export def const WORKSHOP_PRIVATE as int init 2;

/**
 * Workshop visibility: reachable by direct link, but not listed.
 */
export def const WORKSHOP_UNLISTED as int init 3;

/**
 * The largest batch the published-file endpoints accept in one request.
 */
export def const WORKSHOP_BATCH as int init 100;

/**
 * One published Workshop item.
 *
 * @field publishedFileId {string} the item's id, the number in its Workshop URL
 * @field creator {string} the author's 64-bit Steam id
 * @field creatorAppId {int} the app the item was authored in
 * @field consumerAppId {int} the app the item is played in
 * @field title {string} the item's title
 * @field description {string} the item's description, as BBCode
 * @field filename {string} the stored file's name
 * @field fileSize {int} the stored file's size in bytes
 * @field fileUrl {string} a direct download URL, "" for most items
 * @field previewUrl {string} URL of the item's preview image
 * @field timeCreated {int} Unix time the item was first published
 * @field timeUpdated {int} Unix time of the last update
 * @field visibility {int} one of the `WORKSHOP_*` constants
 * @field banned {bool} whether Valve has banned the item
 * @field banReason {string} why, "" when it is not banned
 * @field subscriptions {int} current subscriber count
 * @field favorited {int} current favourite count
 * @field lifetimeSubscriptions {int} subscribers ever
 * @field lifetimeFavorited {int} favourites ever
 * @field views {int} how often the item's page has been viewed
 * @field tags {list of string} the item's Workshop tags
 */
export def struct PublishedFile {
    publishedFileId as string,
    creator as string,
    creatorAppId as int,
    consumerAppId as int,
    title as string,
    description as string,
    filename as string,
    fileSize as int,
    fileUrl as string,
    previewUrl as string,
    timeCreated as int,
    timeUpdated as int,
    visibility as int,
    banned as bool,
    banReason as string,
    subscriptions as int,
    favorited as int,
    lifetimeSubscriptions as int,
    lifetimeFavorited as int,
    views as int,
    tags as list of string
};

/**
 * One member of a Workshop collection.
 *
 * @field publishedFileId {string} the member item's id
 * @field sortOrder {int} its position in the collection
 * @field fileType {int} Steam's internal file-type code
 */
export def struct CollectionItem {
    publishedFileId as string,
    sortOrder as int,
    fileType as int
};

/**
 * A Workshop collection and what it contains.
 *
 * @field publishedFileId {string} the collection's own id
 * @field found {bool} whether Steam had a collection with that id
 * @field items {list of CollectionItem} its members, in collection order
 */
export def struct Collection {
    publishedFileId as string,
    found as bool,
    items as list of CollectionItem
};

/**
 * Look up Workshop items by id. Keyless; sent as a form POST, the only
 * form Steam answers here.
 *
 * @param c {Client} an API client, with or without a key
 * @param publishedFileIds {list of string} up to 100 item ids
 * @return {list of PublishedFile} one entry per item Steam knew; unknown
 *         ids are left out
 * @throws {Error} kind "steam" on an empty or oversized batch, on an id
 *                 that is not a number, or on a transport failure
 * @example
 *   def items as list of steam.PublishedFile init
 *       steam.publishedFileDetails($c, ["450814997"]);
 */
export func publishedFileDetails(c as Client, publishedFileIds as list of string) {
    def form as map of string to string init fileIdForm($publishedFileIds, "itemcount");
    def body as json.Value init apiPost(
        $c,
        "ISteamRemoteStorage",
        "GetPublishedFileDetails",
        1,
        $form);
    def out as list of PublishedFile init [];
    for (def i in 0..nodeLength($body, "/response/publishedfiledetails")) {
        def node as json.Value init nodeItem($body, "/response/publishedfiledetails", $i);
        if (nodeInt($node, "/result") == 1) {
            $out[] = publishedFileFrom($node);
        }
    }
    return $out;
}

/**
 * Look up one Workshop item by id.
 *
 * @param c {Client} an API client, with or without a key
 * @param publishedFileId {string} the item id
 * @return {PublishedFile} the item
 * @throws {Error} kind "steam" when Steam has no such item, or as
 *                 `publishedFileDetails` does
 */
export func publishedFile(c as Client, publishedFileId as string) {
    def found as list of PublishedFile init publishedFileDetails($c, [$publishedFileId]);
    if (len($found) == 0) {
        raiseError("the Workshop has no item " + strings.trim($publishedFileId));
    }
    return $found[0];
}

/**
 * Look up Workshop collections by id. Keyless; sent as a form POST.
 *
 * @param c {Client} an API client, with or without a key
 * @param collectionIds {list of string} up to 100 collection ids
 * @return {list of Collection} one entry per id asked, in the same order
 * @throws {Error} kind "steam" on an empty or oversized batch, on an id
 *                 that is not a number, or on a transport failure
 */
export func collectionDetails(c as Client, collectionIds as list of string) {
    def form as map of string to string init fileIdForm($collectionIds, "collectioncount");
    def body as json.Value init apiPost(
        $c,
        "ISteamRemoteStorage",
        "GetCollectionDetails",
        1,
        $form);
    def out as list of Collection init [];
    for (def i in 0..nodeLength($body, "/response/collectiondetails")) {
        $out[] = collectionFrom(nodeItem($body, "/response/collectiondetails", $i));
    }
    return $out;
}

/**
 * List the item ids inside one Workshop collection.
 *
 * @param c {Client} an API client, with or without a key
 * @param collectionId {string} the collection id
 * @return {list of string} the member item ids, in collection order
 * @throws {Error} kind "steam" when Steam has no such collection, or as
 *                 `collectionDetails` does
 * @example
 *   def ids as list of string init steam.collectionItems($c, "123456789");
 *   def items as list of steam.PublishedFile init steam.publishedFileDetails($c, $ids);
 */
export func collectionItems(c as Client, collectionId as string) {
    def found as list of Collection init collectionDetails($c, [$collectionId]);
    if (len($found) == 0 or not $found[0].found) {
        raiseError("the Workshop has no collection " + strings.trim($collectionId));
    }
    def ids as list of string init [];
    for (def item in $found[0].items) {
        $ids[] = $item.publishedFileId;
    }
    return $ids;
}

/**
 * The Workshop page of one item.
 *
 * @param publishedFileId {string} the item id
 * @return {string} the item's URL
 * @throws {Error} kind "steam" when the id is not a number
 */
export func workshopUrl(publishedFileId as string) {
    return COMMUNITY_BASE + "/sharedfiles/filedetails/?id=" +
        ensureFileId($publishedFileId);
}

/**
 * The Workshop browse page of one game.
 *
 * @param appId {int} the game
 * @return {string} the browse URL
 * @throws {Error} kind "steam" when the app id is not positive
 */
export func workshopBrowseUrl(appId as int) {
    return STORE_BASE + "/app/" + convert.toString(ensureAppId($appId)) + "/workshop/";
}

/**
 * The name of a Workshop visibility.
 *
 * @param visibility {int} one of the `WORKSHOP_*` constants
 * @return {string} e.g. "public", or "unknown" for anything else
 */
export func workshopVisibilityName(visibility as int) {
    match ($visibility) {
        when 0 { return "public"; }
        when 1 { return "friends only"; }
        when 2 { return "private"; }
        when 3 { return "unlisted"; }
        else { return "unknown"; }
    }
}

/**
 * Build the form body the published-file endpoints expect: a count field
 * and one indexed `publishedfileids[N]` field per id.
 *
 * @param ids {list of string} the item or collection ids
 * @param countField {string} "itemcount" or "collectioncount"
 * @return {map of string to string} the form fields
 * @throws {Error} kind "steam" on an empty or oversized batch, or on an id
 *                 that is not a number
 * @internal
 */
func fileIdForm(ids as list of string, countField as string) {
    if (len($ids) == 0) {
        raiseError("at least one published file id is required");
    }
    if (len($ids) > WORKSHOP_BATCH) {
        raiseError("at most " + convert.toString(WORKSHOP_BATCH) +
            " published file ids fit in one request, got " +
            convert.toString(len($ids)));
    }
    def form as map of string to string init {};
    $form[$countField] = convert.toString(len($ids));
    for (def i in 0..len($ids)) {
        $form["publishedfileids[" + convert.toString($i) + "]"] = ensureFileId($ids[$i]);
    }
    return $form;
}

/**
 * Refuse anything that is not a published file id.
 *
 * @param id {string} the candidate
 * @return {string} the trimmed id
 * @throws {Error} kind "steam" when the id is blank or not all digits
 * @internal
 */
func ensureFileId(id as string) {
    def digits as string init strings.trim($id);
    if (not isDigits($digits)) {
        raiseError("\"" + $digits + "\" is not a published file id");
    }
    return $digits;
}

/**
 * Fold one `publishedfiledetails` row into a struct.
 *
 * @param node {json.Value} one element of the list
 * @return {PublishedFile} the folded item
 * @internal
 */
func publishedFileFrom(node as json.Value) {
    return PublishedFile{
        publishedFileId: nodeString($node, "/publishedfileid"),
        creator: nodeString($node, "/creator"),
        creatorAppId: nodeInt($node, "/creator_app_id"),
        consumerAppId: nodeInt($node, "/consumer_app_id"),
        title: nodeString($node, "/title"),
        description: nodeString($node, "/description"),
        filename: nodeString($node, "/filename"),
        fileSize: nodeInt($node, "/file_size"),
        fileUrl: nodeString($node, "/file_url"),
        previewUrl: nodeString($node, "/preview_url"),
        timeCreated: nodeInt($node, "/time_created"),
        timeUpdated: nodeInt($node, "/time_updated"),
        visibility: nodeInt($node, "/visibility"),
        banned: nodeBool($node, "/banned"),
        banReason: nodeString($node, "/ban_reason"),
        subscriptions: nodeInt($node, "/subscriptions"),
        favorited: nodeInt($node, "/favorited"),
        lifetimeSubscriptions: nodeInt($node, "/lifetime_subscriptions"),
        lifetimeFavorited: nodeInt($node, "/lifetime_favorited"),
        views: nodeInt($node, "/views"),
        tags: nodeFieldList($node, "/tags", "tag")
    };
}

/**
 * Fold one `collectiondetails` row into a struct.
 *
 * @param node {json.Value} one element of the list
 * @return {Collection} the folded collection
 * @internal
 */
func collectionFrom(node as json.Value) {
    def items as list of CollectionItem init [];
    for (def i in 0..nodeLength($node, "/children")) {
        def child as json.Value init nodeItem($node, "/children", $i);
        $items[] = CollectionItem{
            publishedFileId: nodeString($child, "/publishedfileid"),
            sortOrder: nodeInt($child, "/sortorder"),
            fileType: nodeInt($child, "/filetype")
        };
    }
    return Collection{
        publishedFileId: nodeString($node, "/publishedfileid"),
        found: nodeInt($node, "/result") == 1,
        items: $items
    };
}
