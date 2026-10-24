#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# player example - the library, playtime, level, and badges.
#
# Read-only. Needs a Web API key and an account whose game details are public:
#   STEAM_API_KEY=... STEAM_ACCOUNT=76561197960287930 jennifer run examples/player.j

use io;
use os;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
if (not steam.hasKey($c)) {
    io.printf("set STEAM_API_KEY first\n");
    exit 1;
}

def wanted as string init os.getEnv("STEAM_ACCOUNT");
if ($wanted == "") {
    io.printf("set STEAM_ACCOUNT to a Steam id or a vanity name\n");
    exit 1;
}
def id as string init steam.resolveAccount($c, $wanted);

io.printf("Steam level %d\n", steam.steamLevel($c, $id));

def lib as list of steam.OwnedGame init steam.ownedGames($c, $id, true, true);
if (len($lib) == 0) {
    io.printf("the library is empty or private\n");
    exit 0;
}

io.printf(
    "%d games, %f|prec=1 hours played in total\n",
    len($lib),
    steam.playtimeHours(steam.totalPlaytime($lib)));
io.printf("%d never launched\n", len(steam.unplayed($lib)));

io.printf("\nmost played:\n");
for (def g in steam.mostPlayed($lib, 10)) {
    io.printf("  %s|pad=44 %f|prec=1|pad=8 h\n", $g.name, steam.playtimeHours($g.playtimeForever));
}

def recent as list of steam.OwnedGame init steam.recentlyPlayedGames($c, $id, 5);
if (len($recent) > 0) {
    io.printf("\nlast two weeks:\n");
    for (def g in $recent) {
        io.printf(
            "  %s|pad=44 %f|prec=1|pad=8 h\n",
            $g.name,
            steam.playtimeHours($g.playtimeTwoWeeks));
    }
}

def col as steam.BadgeCollection init steam.badges($c, $id);
io.printf(
    "\n%d badges, %d XP (%d to the next level)\n",
    len($col.badges),
    $col.playerXp,
    $col.xpNeededToLevelUp);
