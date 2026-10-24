#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steamid example - converting between the three Steam id notations.
#
# Needs no API key and no network: every call here is arithmetic.
#   jennifer run examples/steamid.j

use io;

import "../src/steam.j" as steam;

def id as string init "76561197960287930";

io.printf("id64    %s\n", $id);
io.printf("classic %s\n", steam.toSteamId2($id));
io.printf("modern  %s\n", steam.toSteamId3($id));
io.printf("account %d\n", steam.accountId($id));
io.printf("profile %s\n", steam.profileUrl($id));

# all three notations are accepted wherever this deck takes an id
for (def written in ["76561197960287930", "STEAM_1:0:11101", "[U:1:22202]"]) {
    io.printf("%s|pad=20 -> %s\n", $written, steam.normalizeSteamId($written));
}

def parts as steam.SteamId init steam.parseSteamId($id);
io.printf(
    "universe %d, type %d (%s), instance %d\n",
    $parts.universe,
    $parts.accountType,
    steam.accountTypeName($parts.accountType),
    $parts.instance);

# a group id is 18 digits and is not an individual account
def group as string init "103582791429521412";
io.printf(
    "%s is a %s -> %s\n",
    $group,
    steam.accountTypeName(steam.parseSteamId($group).accountType),
    steam.toSteamId3($group));

# anything else is rejected rather than guessed at
io.printf("\"gabelogannewell\" is a Steam id: %t\n", steam.looksLikeSteamId("gabelogannewell"));
