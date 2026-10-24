#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# workshop example - reading Workshop items and expanding a collection.
#
# Read-only and keyless.
#   STEAM_WORKSHOP_ID=450814997 jennifer run examples/workshop.j

use io;
use os;
use strings;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();

def wanted as string init os.getEnv("STEAM_WORKSHOP_ID");
if ($wanted == "") {
    io.printf("set STEAM_WORKSHOP_ID to a Workshop item id\n");
    io.printf("  (the number in https://steamcommunity.com/sharedfiles/filedetails/?id=...)\n");
    exit 1;
}

def item as steam.PublishedFile init steam.publishedFile($c, $wanted);
io.printf("%s\n", $item.title);
io.printf("  by         %s\n", steam.profileUrl($item.creator));
io.printf("  app        %d\n", $item.consumerAppId);
io.printf("  visibility %s\n", steam.workshopVisibilityName($item.visibility));
io.printf("  size       %d bytes\n", $item.fileSize);
io.printf("  subs       %d now, %d ever\n", $item.subscriptions, $item.lifetimeSubscriptions);
io.printf("  tags       %s\n", strings.join($item.tags, ", "));
io.printf("  page       %s\n", steam.workshopUrl($item.publishedFileId));
io.printf("\n%s\n", steam.summarize(steam.plainText($item.description), 300));

# a collection id works here too: expand it and read every member
def collectionId as string init os.getEnv("STEAM_COLLECTION_ID");
if ($collectionId == "") {
    exit 0;
}
def ids as list of string init steam.collectionItems($c, $collectionId);
io.printf("\ncollection %s holds %d items:\n", $collectionId, len($ids));
for (def member in steam.publishedFileDetails($c, $ids)) {
    io.printf("  %s|pad=14 %s\n", $member.publishedFileId, $member.title);
}
