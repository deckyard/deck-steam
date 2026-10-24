# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - white-box tests for the servers topic.
# Spliced into steam_test.j via include - run with:
#   jennifer test src/steam_test.j

func testIsUsableServerAccount() {
    def live as GameServerAccount init GameServerAccount{
        steamId: "85568392921481838",
        appId: 440,
        loginToken: "ABC",
        memo: "eu-1",
        deleted: false,
        expired: false,
        lastLogon: 1700000000
    };
    testing.assertTrue(isUsableServerAccount($live));
    def gone as GameServerAccount init $live;
    $gone.deleted = true;
    testing.assertFalse(isUsableServerAccount($gone));
    def stale as GameServerAccount init $live;
    $stale.expired = true;
    testing.assertFalse(isUsableServerAccount($stale));
}

func testServerCallsRefuseWithoutKey() {
    testing.assertThrows("keylessServerAccounts", "steam");
    testing.assertThrows("keylessServerInfo", "steam");
    testing.assertThrows("keylessTokenQuery", "steam");
}

func keylessServerAccounts() {
    gameServerAccounts(client(""));
}

func keylessServerInfo() {
    gameServerInfo(client(""), "76561197960287930");
}

func keylessTokenQuery() {
    queryLoginToken(client(""), "ABC");
}

func testQueryLoginTokenNeedsAToken() {
    testing.assertThrows("blankLoginToken", "steam");
}

func blankLoginToken() {
    queryLoginToken(client("k"), "   ");
}

func testGameServerInfoValidatesTheId() {
    testing.assertThrows("serverInfoForJunkId", "steam");
}

func serverInfoForJunkId() {
    gameServerInfo(client("k"), "not-an-id");
}
