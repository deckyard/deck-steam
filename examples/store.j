#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# store example - storefront records, regional pricing, and the front page.
#
# Read-only and keyless. STEAM_COUNTRY decides the currency and availability.
#   STEAM_COUNTRY=DE jennifer run examples/store.j

use io;
use strings;
use convert;

import "../src/steam.j" as steam;

def c as steam.Client init steam.clientFromEnv();

def d as steam.AppDetails init steam.appDetails($c, 620);
io.printf("%s (%s, %s)\n", $d.name, $d.kind, $d.releaseDate);
io.printf("  by         %s\n", strings.join($d.developers, ", "));
io.printf("  genres     %s\n", strings.join($d.genres, ", "));
io.printf(
    "  platforms  win=%t mac=%t linux=%t\n",
    $d.platforms.windows,
    $d.platforms.mac,
    $d.platforms.linux);
io.printf(
    "  metacritic %d, %d recommendations, %d achievements\n",
    $d.metacriticScore,
    $d.recommendations,
    $d.achievementCount);
io.printf("  %s\n", steam.plainText($d.shortDescription));

if ($d.isFree) {
    io.printf("  price      free to play\n");
} elseif (steam.isDiscounted($d.price)) {
    io.printf(
        "  price      %s (was %s, %s)\n",
        $d.price.finalFormatted,
        $d.price.initialFormatted,
        steam.discountLabel($d.price));
} else {
    io.printf("  price      %s\n", $d.price.finalFormatted);
}

# one request for a whole wishlist
io.printf("\nwishlist:\n");
for (def p in steam.appPrices($c, [620, 440, 730, 400])) {
    if (not $p.found) {
        io.printf("  %d|pad=7  (no storefront record)\n", $p.appId);
    } elseif ($p.free) {
        io.printf("  %d|pad=7  free to play\n", $p.appId);
    } else {
        io.printf(
            "  %d|pad=7  %s|pad=12 %s\n",
            $p.appId,
            $p.price.finalFormatted,
            steam.discountLabel($p.price));
    }
}

# the front page: largeCapsules is often empty outside a sale, so show the
# per-platform list instead
def front as steam.FeaturedLists init steam.featured($c);
io.printf("\nfeatured for Linux right now:\n");
for (def f in $front.linux) {
    def tag as string init "";
    if ($f.discounted) {
        $tag = "-" + convert.toString($f.discountPercent) + "%";
    }
    io.printf("  %s|pad=46 %s %s\n", $f.name, $f.currency, $tag);
}
