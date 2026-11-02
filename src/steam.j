# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * steam - a typed client for Valve's Steam Web API (`api.steampowered.com`),
 * the storefront (`store.steampowered.com`) and the Community Market
 * (`steamcommunity.com`).
 *
 * Replies fold into structs; a Steam id is accepted in any of its three
 * notations; arguments are checked before any request; every failure is
 * `Error{kind: "steam"}`. The topic files under `topics/` are spliced in
 * with `include`, so this file is the module boundary.
 *
 * @module steam
 * @version 0.1.0
 * @license LGPL-3.0-only
 * @see https://steamcommunity.com/dev
 * @see https://partner.steamgames.com/doc/webapi_overview
 * @example
 *   import "./steam.j" as steam;
 *
 *   def c as steam.Client init steam.client("YOUR-KEY");
 *   def p as steam.PlayerSummary init steam.playerSummary($c, "76561197960287930");
 *   io.printf("%s is %s\n", $p.personaName, steam.personaStateName($p.personaState));
 *
 *   def games as list of steam.OwnedGame init steam.ownedGames($c, $p.steamId, true, false);
 *   io.printf("owns %d games\n", len($games));
 */

use strings;
use lists;
use convert;
use math;
use json;
use io;
use os;
use regex;

import "rest.j" as rest;
import "http.j" as http;
import "uri.j" as uri;

include "topics/core.j";
include "topics/steamid.j";
include "topics/users.j";
include "topics/player.j";
include "topics/stats.j";
include "topics/apps.j";
include "topics/news.j";
include "topics/store.j";
include "topics/market.j";
include "topics/workshop.j";
include "topics/econ.j";
include "topics/servers.j";
