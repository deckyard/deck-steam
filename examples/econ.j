#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# econ example - trade offers and a game's item-store prices.
#
# Read-only, but every call here reads the private trading state of
# whichever account owns the API key.
#   STEAM_API_KEY=... jennifer run examples/econ.j

use io;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
if (not steam.hasKey($c)) {
    io.printf("set STEAM_API_KEY first - trade offers are private to the key's account\n");
    exit 1;
}

# the cheap poll: counts only
def summary as steam.TradeOffersSummary init steam.tradeOffersSummary($c, 0);
io.printf("pending: %d received, %d sent\n", $summary.pendingReceived, $summary.pendingSent);
io.printf("escrow:  %d received, %d sent\n", $summary.escrowReceived, $summary.escrowSent);

if ($summary.pendingReceived == 0) {
    io.printf("nothing waiting\n");
} else {
    def offers as steam.TradeOffers init steam.tradeOffers($c, false, true, true);
    for (def o in $offers.received) {
        io.printf("\noffer %s from %s\n", $o.tradeOfferId, $o.otherSteamId);
        io.printf("  state    %s\n", steam.tradeOfferStateName($o.state));
        io.printf("  giving   %d items\n", len($o.toGive));
        io.printf("  getting  %d items\n", len($o.toReceive));
        if (steam.isOneSided($o)) {
            io.printf("  note     one-sided - a gift, or a scam\n");
        }
        if ($o.message != "") {
            io.printf("  message  %s\n", $o.message);
        }
    }
}

#   mutating calls are deliberately not part of this deck - accepting or
#   declining an offer needs the mobile confirmation flow, not the Web API

io.printf("\nTeam Fortress 2 item store:\n");
for (def a in steam.assetPrices($c, 440)) {
    io.printf("  %s|pad=28 %s\n", $a.name, steam.currencyCode($c.currency));
}
