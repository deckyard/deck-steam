#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# stats example - achievements, per-game statistics, and live player counts.
#
# The player count and the global rarity table are keyless; the per-account
# achievement record is not.
#   STEAM_API_KEY=... STEAM_ACCOUNT=... STEAM_APPID=620 jennifer run examples/stats.j

use io;
use os;
use convert;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();

def appId as int init 620;
if (os.getEnv("STEAM_APPID") != "") {
    $appId = convert.toInt(os.getEnv("STEAM_APPID"));
}

# keyless: how busy is it right now, and which achievements are rare
io.printf("app %d: %d players in game\n", $appId, steam.currentPlayers($c, $appId));

def rarity as list of steam.AchievementRarity init steam.globalAchievementRarity($c, $appId);
if (len($rarity) > 0) {
    io.printf("\nrarest achievements:\n");
    for (def r in steam.rarest($rarity, 5)) {
        io.printf("  %s|pad=40 %f|prec=2|pad=6%%\n", $r.name, $r.percent);
    }
}

def wanted as string init os.getEnv("STEAM_ACCOUNT");
if (not steam.hasKey($c) or $wanted == "") {
    io.printf("\nset STEAM_API_KEY and STEAM_ACCOUNT for the per-account part\n");
    exit 0;
}
def id as string init steam.resolveAccount($c, $wanted);

def record as steam.PlayerAchievements init steam.playerAchievements($c, $id, $appId);
io.printf(
    "\n%s: %d of %d unlocked (%f|prec=0%%)\n",
    $record.gameName,
    steam.unlockedCount($record.achievements),
    len($record.achievements),
    steam.completionPercent($record.achievements));

for (def a in steam.lockedAchievements($record.achievements)) {
    io.printf("  still locked: %s\n", $a.apiName);
}

for (def s in steam.userStats($c, $id, $appId)) {
    io.printf("  stat %s|pad=32 %d\n", $s.name, $s.value);
}
