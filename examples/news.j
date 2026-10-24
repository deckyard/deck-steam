#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# news example - a game's news feed, rendered for a terminal.
#
# Read-only and keyless.
#   jennifer run examples/news.j
#   STEAM_APPID=730 jennifer run examples/news.j

use io;
use os;
use convert;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();

def appId as int init 440;
if (os.getEnv("STEAM_APPID") != "") {
    $appId = convert.toInt(os.getEnv("STEAM_APPID"));
}

# every feed, including third-party outlets
for (def item in steam.newsForApp($c, $appId, 5, 0)) {
    def body as string init steam.plainText($item.contents);
    io.printf("%s\n", $item.title);
    io.printf("  %s | %s\n", $item.feedLabel, $item.url);
    io.printf("  %s\n\n", steam.summarize($body, 160));
}

# just what the developer posted themselves
io.printf("--- developer announcements only ---\n");
for (def item in steam.newsForAppFeeds($c, $appId, 3, 0, steam.FEED_ANNOUNCEMENTS)) {
    io.printf("%s\n  %s\n", $item.title, steam.summarize(steam.plainText($item.contents), 100));
}
