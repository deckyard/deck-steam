#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# apps example - image URLs, version checks, servers, and the app catalogue.
#
# Read-only. Everything but the catalogue is keyless; the catalogue moved to
# IStoreService and needs a key, so it only runs when one is set.
#   jennifer run examples/apps.j
#   STEAM_API_KEY=... STEAM_SEARCH="portal 2" jennifer run examples/apps.j

use io;
use os;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();

def info as steam.ServerInfo init steam.serverInfo($c);
io.printf("Steam says it is %s\n\n", $info.serverTimeString);

# derived URLs need no request at all
io.printf("app 620:\n");
io.printf("  store   %s\n", steam.storePageUrl(620));
io.printf("  header  %s\n", steam.headerImageUrl(620));
io.printf("  capsule %s\n\n", steam.capsuleImageUrl(620));

# the version check a launcher runs before letting a player connect
def check as steam.VersionCheck init steam.upToDateCheck($c, 440, 1);
io.printf("TF2 client version 1 is current: %t\n", $check.upToDate);
io.printf("  required version %d - %s\n\n", $check.requiredVersion, $check.message);

# what Steam sees running at an address
def servers as list of steam.GameServer init steam.serversAtAddress($c, "208.78.164.10");
io.printf("%d servers at 208.78.164.10\n", len($servers));
for (def s in $servers) {
    io.printf("  %s runs app %d (%s)\n", $s.address, $s.appId, $s.gameDir);
}

# the catalogue needs a key: Valve retired the old keyless GetAppList
if (not steam.hasKey($c)) {
    io.printf("\nset STEAM_API_KEY to download the app catalogue\n");
    exit 0;
}

def term as string init os.getEnv("STEAM_SEARCH");
if ($term == "") {
    $term = "portal";
}

io.printf("\ndownloading the app catalogue...\n");
def catalogue as list of steam.App init steam.appList($c, 20);
io.printf("%d apps published\n\n", len($catalogue));

def hits as list of steam.App init steam.findApps($catalogue, $term);
io.printf("%d match \"%s\":\n", len($hits), $term);
for (def a in $hits) {
    io.printf("  %d|pad=8  %s\n", $a.appId, $a.name);
}

io.printf("\napp 620 is %s\n", steam.appById($catalogue, 620).name);
