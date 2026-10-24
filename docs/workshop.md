# Workshop - items and collections

`ISteamRemoteStorage`. No key. Both lookups answer only a form `POST` with
indexed `publishedfileids[N]` fields; the deck builds it.

```jennifer
def item as steam.PublishedFile init steam.publishedFile($c, "450814997");
io.printf("%s by %s\n", $item.title, steam.profileUrl($item.creator));
io.printf("%d subscribers now, %d ever\n",
    $item.subscriptions, $item.lifetimeSubscriptions);
io.printf("%s\n", steam.summarize(steam.plainText($item.description), 200));
```

The id is the number in the item's URL,
`steamcommunity.com/sharedfiles/filedetails/?id=450814997`; `workshopUrl`
builds that URL.

`publishedFileDetails` takes up to `WORKSHOP_BATCH` (100) numeric ids per
request. Items Steam does not know are left out, so the result may be
shorter than the input; `publishedFile` throws instead.

## Collections

A collection is a published file whose contents are other published files.
`collectionItems` returns the member ids, and `publishedFileDetails`
expands them:

```jennifer
def ids as list of string init steam.collectionItems($c, "123456789");
for (def m in steam.publishedFileDetails($c, $ids)) {
    io.printf("%s|pad=14 %s\n", $m.publishedFileId, $m.title);
}
```

`collectionDetails` is the batched form: one `Collection` per id, in order,
each with a `found` flag and its `CollectionItem`s in collection order.

## Fields

- `creatorAppId` is the app the item was made in, `consumerAppId` the app
  it is played in. A game with a separate SDK app (Source games, Dota) sets
  them apart.
- `visibility` is a `WORKSHOP_*` value; `workshopVisibilityName` names it.
  Unlisted means reachable by link but not in the browse list.
- `fileUrl` is empty for most items: Valve delivers Workshop content
  through the client, not over HTTP.
- `description` is BBCode; see [`plainText`](news.md#markup).
- `banned` / `banReason`: check them before recommending an item.

See [`examples/workshop.j`](https://github.com/deckyard/deck-steam/blob/main/examples/workshop.j).
