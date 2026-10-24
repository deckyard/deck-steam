#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# servers example - game server accounts and their login tokens.
#
# Read-only, and reads the key owner's own server accounts. The tokens
# printed here are secrets; this example truncates them.
#   STEAM_API_KEY=... jennifer run examples/servers.j

use io;
use strings;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
if (not steam.hasKey($c)) {
    io.printf("set STEAM_API_KEY first\n");
    exit 1;
}

def accounts as list of steam.GameServerAccount init steam.gameServerAccounts($c);
if (len($accounts) == 0) {
    io.printf("this account has registered no game servers\n");
    io.printf("  create one at https://steamcommunity.com/dev/managegameservers\n");
    exit 0;
}

for (def s in $accounts) {
    def usable as string init "expired or deleted";
    if (steam.isUsableServerAccount($s)) {
        $usable = "usable";
    }
    io.printf("%s  app %d|pad=6|align=left %s\n", $s.steamId, $s.appId, $usable);
    io.printf("  memo   %s\n", $s.memo);
    io.printf("  token  %s...\n", strings.substring($s.loginToken, 0, 4));

    def status as steam.LoginTokenStatus init steam.queryLoginToken($c, $s.loginToken);
    io.printf("  banned %t, expires %d\n", $status.banned, $status.expires);
}
