#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# core example - building a client, verbose mode, and the generic escape hatch.
#
# Read-only. A key is optional here; without one only the keyless
# endpoints answer.
#   STEAM_API_KEY=... jennifer run examples/core.j

use io;
use json;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
io.printf("key configured: %t\n", steam.hasKey($c));

# every builder returns a copy - keep the result
$c = steam.withCountry($c, "DE");
$c = steam.withLanguage($c, "german");
$c = steam.withCurrency($c, steam.CURRENCY_EUR);
$c = steam.withTimeout($c, 10000);
$c = steam.withRetries($c, 3);
$c = steam.setVerbose($c, true);

# verbose prints one line per request, with the key redacted
def info as steam.ServerInfo init steam.serverInfo($c);
io.printf("Steam clock: %s\n", $info.serverTimeString);

# the escape hatch: any interface, any method, decoded but not folded
def raw as json.Value init steam.call(
    $c,
    "ISteamUserStats",
    "GetNumberOfCurrentPlayers",
    1,
    {"appid": "730"});
io.printf("CS2 players right now: %d\n", json.asInt($raw, "/response/player_count"));
