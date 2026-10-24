# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# White-box tests for the steam module: `jennifer test src/steam_test.j`.
# One test file per topic file, spliced in with `include`.
#
# Nothing here touches the network. Network verbs are covered up to the
# argument check that fails before the request (a keyless client, a bad
# id); the reply folders are tested against inline JSON fixtures.

use testing;
use maps;
use strings;

include "topics/core_test.j";
include "topics/steamid_test.j";
include "topics/users_test.j";
include "topics/player_test.j";
include "topics/stats_test.j";
include "topics/apps_test.j";
include "topics/news_test.j";
include "topics/store_test.j";
include "topics/market_test.j";
include "topics/workshop_test.j";
include "topics/econ_test.j";
include "topics/servers_test.j";
