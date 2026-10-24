# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the workshop topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testFileIdForm() {
    def form as map of string to string init fileIdForm([" 111 ", "222"], "itemcount");
    testing.assertEqual($form["itemcount"], "2");
    testing.assertEqual($form["publishedfileids[0]"], "111");
    testing.assertEqual($form["publishedfileids[1]"], "222");
    testing.assertEqual(len(maps.keys($form)), 3);
}

func testFileIdFormUsesTheGivenCountField() {
    def form as map of string to string init fileIdForm(["9"], "collectioncount");
    testing.assertTrue(maps.has($form, "collectioncount"));
    testing.assertFalse(maps.has($form, "itemcount"));
}

func testFileIdFormValidates() {
    testing.assertThrows("emptyFileIdBatch", "steam");
    testing.assertThrows("oversizedFileIdBatch", "steam");
    testing.assertThrows("nonNumericFileId", "steam");
}

func emptyFileIdBatch() {
    def none as list of string init [];
    fileIdForm($none, "itemcount");
}

func oversizedFileIdBatch() {
    def many as list of string init [];
    for (def i in 0..WORKSHOP_BATCH + 1) {
        $many[] = convert.toString($i + 1);
    }
    fileIdForm($many, "itemcount");
}

func nonNumericFileId() {
    fileIdForm(["abc"], "itemcount");
}

func testEnsureFileId() {
    testing.assertEqual(ensureFileId("  450814997 "), "450814997");
    testing.assertThrows("blankFileId", "steam");
}

func blankFileId() {
    ensureFileId("   ");
}

func testPublishedFileFrom() {
    def node as json.Value init json.decode('{
        "publishedfileid": "450814997",
        "result": 1,
        "creator": "76561197960287930",
        "creator_app_id": 4000,
        "consumer_app_id": 4000,
        "filename": "mods/thing.vpk",
        "file_size": 1048576,
        "file_url": "",
        "preview_url": "https://img.example/preview.jpg",
        "title": "A Thing",
        "description": "[b]Does things.[/b]",
        "time_created": 1400000000,
        "time_updated": 1500000000,
        "visibility": 0,
        "banned": false,
        "ban_reason": "",
        "subscriptions": 12345,
        "favorited": 678,
        "lifetime_subscriptions": 54321,
        "lifetime_favorited": 900,
        "views": 99999,
        "tags": [{"tag": "Scenario"}, {"tag": "Vehicle"}]
    }');
    def f as PublishedFile init publishedFileFrom($node);
    testing.assertEqual($f.publishedFileId, "450814997");
    testing.assertEqual($f.creator, "76561197960287930");
    testing.assertEqual($f.creatorAppId, 4000);
    testing.assertEqual($f.title, "A Thing");
    testing.assertEqual($f.fileSize, 1048576);
    testing.assertEqual($f.previewUrl, "https://img.example/preview.jpg");
    testing.assertEqual($f.visibility, WORKSHOP_PUBLIC);
    testing.assertFalse($f.banned);
    testing.assertEqual($f.subscriptions, 12345);
    testing.assertEqual($f.lifetimeFavorited, 900);
    testing.assertEqual($f.views, 99999);
    testing.assertEqual($f.tags, ["Scenario", "Vehicle"]);
    testing.assertEqual(plainText($f.description), "Does things.");
}

func testCollectionFrom() {
    def node as json.Value init json.decode('{
        "publishedfileid": "121212",
        "result": 1,
        "children": [
            {"publishedfileid": "1", "sortorder": 0, "filetype": 0},
            {"publishedfileid": "2", "sortorder": 1, "filetype": 0}
        ]
    }');
    def col as Collection init collectionFrom($node);
    testing.assertTrue($col.found);
    testing.assertEqual($col.publishedFileId, "121212");
    testing.assertEqual(len($col.items), 2);
    testing.assertEqual($col.items[1].publishedFileId, "2");
    testing.assertEqual($col.items[1].sortOrder, 1);
}

func testCollectionFromMissingCollection() {
    def col as Collection init collectionFrom(json.decode('{"publishedfileid": "9", "result": 9}'));
    testing.assertFalse($col.found);
    testing.assertEqual(len($col.items), 0);
}

func testWorkshopUrls() {
    testing.assertEqual(
        workshopUrl("450814997"),
        "https://steamcommunity.com/sharedfiles/filedetails/?id=450814997");
    testing.assertEqual(
        workshopBrowseUrl(4000),
        "https://store.steampowered.com/app/4000/workshop/");
    testing.assertThrows("workshopUrlForJunk", "steam");
}

func workshopUrlForJunk() {
    workshopUrl("not-an-id");
}

func testWorkshopVisibilityName() {
    testing.assertEqual(workshopVisibilityName(WORKSHOP_PUBLIC), "public");
    testing.assertEqual(workshopVisibilityName(WORKSHOP_FRIENDS), "friends only");
    testing.assertEqual(workshopVisibilityName(WORKSHOP_PRIVATE), "private");
    testing.assertEqual(workshopVisibilityName(WORKSHOP_UNLISTED), "unlisted");
    testing.assertEqual(workshopVisibilityName(7), "unknown");
}

func testWorkshopLookupsRefuseBadIds() {
    testing.assertThrows("emptyDetailsBatch", "steam");
    testing.assertThrows("nonNumericDetailsId", "steam");
    testing.assertThrows("nonNumericPublishedFile", "steam");
    testing.assertThrows("emptyCollectionBatch", "steam");
    testing.assertThrows("nonNumericCollectionItems", "steam");
}

func emptyDetailsBatch() {
    def none as list of string init [];
    publishedFileDetails(client(""), $none);
}

func nonNumericDetailsId() {
    publishedFileDetails(client(""), ["450814997", "mod"]);
}

func nonNumericPublishedFile() {
    publishedFile(client(""), "   ");
}

func emptyCollectionBatch() {
    def none as list of string init [];
    collectionDetails(client(""), $none);
}

func nonNumericCollectionItems() {
    collectionItems(client(""), "12x");
}
