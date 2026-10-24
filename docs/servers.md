# Servers - game server accounts

A dedicated server needs a game server account and its login token to keep
a stable identity in the server browser. `IGameServersService` reads the
accounts registered to the API key's owner; register them at
<https://steamcommunity.com/dev/managegameservers>. As in
[econ](econ.md), no parameter names an account.

```jennifer
for (def s in steam.gameServerAccounts($c)) {
    io.printf("%s app %d - %s\n", $s.steamId, $s.appId, $s.memo);
}
```

## The token is a password

`GameServerAccount.loginToken` is what the server process authenticates
with; whoever holds it can impersonate the server. Verbose mode redacts
`login_token`; redact it in your own logs too:

```jennifer
io.printf("token %s...\n", strings.substring($s.loginToken, 0, 4));
```

## A server that stops appearing

`isUsableServerAccount` is false when the account is deleted or its token
has expired; Steam expires a token unused for a long time without notice.
`queryLoginToken` checks one token directly:

```jennifer
def status as steam.LoginTokenStatus init steam.queryLoginToken($c, $token);
io.printf("banned %t, expires %d\n", $status.banned, $status.expires);
```

Valve bans server accounts for abusive listing; the ban follows the account,
not the address.

`gameServerInfo(c, steamId)` reads the public record (id and app) of any
server account, for checking someone else's registration.

See [`examples/servers.j`](https://github.com/deckyard/deck-steam/blob/main/examples/servers.j).
