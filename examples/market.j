#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# market example - Community Market prices for a handful of items.
#
# Read-only and keyless. The endpoint is rate-limited hard, so this walks
# a short list with retries and backoff configured.
#   STEAM_CURRENCY=eur jennifer run examples/market.j

use io;
use os;
use strings;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();
if (strings.lower(os.getEnv("STEAM_CURRENCY")) == "eur") {
    $c = steam.withCurrency($c, steam.CURRENCY_EUR);
}
$c = steam.withRetries($c, 4);
$c = steam.withBackoff($c, 3000);

def wanted as list of string init ["Mann Co. Supply Crate Key", "Tour of Duty Ticket", "Name Tag"];

io.printf("Team Fortress 2 items, priced in %s:\n", steam.currencyCode($c.currency));
for (def name in $wanted) {
    def q as steam.MarketPrice init steam.priceOverview($c, 440, $name);
    if (not $q.found) {
        io.printf("  %s|pad=32 no listings\n", $name);
    } else {
        io.printf(
            "  %s|pad=32 %s|pad=8|align=right (median %s, %d sold today)\n",
            $name,
            $q.lowestPrice,
            $q.medianPrice,
            $q.volume);
        io.printf("  %s|pad=32 %s\n", "", steam.marketListingUrl(440, $name));
    }
}

io.printf("\nbrowse: %s\n", steam.marketSearchUrl(440, "crate key"));
