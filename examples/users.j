#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# users example - profiles, friends, bans, and vanity names.
#
# Read-only. Needs a Web API key:
#   STEAM_API_KEY=... STEAM_ACCOUNT=gabelogannewell jennifer run examples/users.j

use io;
use os;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
if (not steam.hasKey($c)) {
    io.printf("set STEAM_API_KEY first - get one at https://steamcommunity.com/dev/apikey\n");
    exit 1;
}

def wanted as string init os.getEnv("STEAM_ACCOUNT");
if ($wanted == "") {
    $wanted = "gabelogannewell";
}

# a vanity name, a profile URL, or an id in any notation all work here
def id as string init steam.resolveAccount($c, $wanted);

def p as steam.PlayerSummary init steam.playerSummary($c, $id);
io.printf("%s (%s)\n", $p.personaName, $p.steamId);
io.printf("  state      %s\n", steam.personaStateName($p.personaState));
io.printf("  visibility %s\n", steam.visibilityName($p.communityVisibilityState));
io.printf("  profile    %s\n", $p.profileUrl);
if (steam.isInGame($p)) {
    io.printf("  playing    %s\n", $p.gameExtraInfo);
}
if (steam.isPublic($p) and $p.realName != "") {
    io.printf("  real name  %s\n", $p.realName);
}

def bans as steam.PlayerBan init steam.playerBan($c, $id);
io.printf("bans: %d VAC, %d game, economy %s\n", $bans.vacBans, $bans.gameBans, $bans.economyBan);

def friends as list of steam.Friend init steam.friendList($c, $id);
io.printf("%d friends\n", len($friends));

def groups as list of string init steam.userGroups($c, $id);
io.printf("%d groups\n", len($groups));
