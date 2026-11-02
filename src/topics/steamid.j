# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# steam - Steam id parsing, conversion, and profile URLs.
# Spliced into steam.j via include - not a standalone module.

/**
 * Lowest 64-bit id of the individual-account block: a personal id is this
 * number plus the 32-bit account id.
 */
export def const INDIVIDUAL_BASE as int init 76561197960265728;

/**
 * Lowest 64-bit id of the group (clan) block.
 */
export def const CLAN_BASE as int init 103582791429521408;

/**
 * Universe of a normal, public Steam account.
 */
export def const UNIVERSE_PUBLIC as int init 1;

/**
 * Highest universe Steam issues.
 *
 * The universe field is eight bits wide, but only 1-5 name a real universe.
 * A larger value overflows the 64-bit id when shifted into the top bits, and
 * `<<` wraps silently where `*` raises, so ids are bounded by this, not by
 * the field width.
 */
export def const UNIVERSE_MAX as int init 5;

/**
 * Account type of a person's account.
 */
export def const ACCOUNT_INDIVIDUAL as int init 1;

/**
 * Account type of a multiseat (cyber-cafe) account.
 */
export def const ACCOUNT_MULTISEAT as int init 2;

/**
 * Account type of a persistent game server.
 */
export def const ACCOUNT_GAME_SERVER as int init 3;

/**
 * Account type of an anonymous game server.
 */
export def const ACCOUNT_ANON_GAME_SERVER as int init 4;

/**
 * Account type of a content server.
 */
export def const ACCOUNT_CONTENT_SERVER as int init 6;

/**
 * Account type of a group / clan.
 */
export def const ACCOUNT_CLAN as int init 7;

/**
 * Account type of a chat room.
 */
export def const ACCOUNT_CHAT as int init 8;

/**
 * Account type of an anonymous user.
 */
export def const ACCOUNT_ANON_USER as int init 10;

/**
 * The fields of a 64-bit Steam id. `parseSteamId` and `toSteamId64` convert
 * between the two without loss.
 *
 * @field id64 {string} the canonical 17-digit decimal id
 * @field universe {int} which Steam universe (1 = public)
 * @field accountType {int} what kind of account (1 = individual, 7 = group)
 * @field instance {int} the instance bits (1 for a desktop account)
 * @field accountId {int} the 32-bit account number (the "friend id")
 */
export def struct SteamId {
    id64 as string,
    universe as int,
    accountType as int,
    instance as int,
    accountId as int
};

/**
 * Take a 64-bit Steam id apart.
 *
 * @param id64 {string} a 17-digit decimal Steam id
 * @return {SteamId} its universe, type, instance, and account number
 * @throws {Error} kind "steam" when the text is not a 64-bit Steam id
 * @example
 *   def p as steam.SteamId init steam.parseSteamId("76561197960287930");
 *   io.printf("account %d\n", $p.accountId);
 */
export func parseSteamId(id64 as string) {
    def value as int init steamIdNumber($id64);
    return SteamId{
        id64: convert.toString($value),
        universe: ($value >> 56) & 0xff,
        accountType: ($value >> 52) & 0xf,
        instance: ($value >> 32) & 0xfffff,
        accountId: $value & 0xffffffff
    };
}

/**
 * Put a 64-bit Steam id back together from its parts.
 *
 * Fields are checked against the values Steam issues, not against the width
 * of their bit-fields, so the result always passes `parseSteamId`.
 *
 * @param parts {SteamId} the pieces; `id64` is ignored and recomputed
 * @return {string} the 17-digit decimal id
 * @throws {Error} kind "steam" when a field is outside the range Steam uses
 */
export func toSteamId64(parts as SteamId) {
    ensureRange($parts.universe, UNIVERSE_PUBLIC, UNIVERSE_MAX, "universe");
    ensureRange($parts.accountType, 0, ACCOUNT_ANON_USER, "account type");
    ensureRange($parts.instance, 0, 0xfffff, "instance");
    ensureRange($parts.accountId, 0, 0xffffffff, "account id");
    def value as int init ($parts.universe << 56) |
        ($parts.accountType << 52) | ($parts.instance << 32) | $parts.accountId;
    return convert.toString($value);
}

/**
 * Whether the text is a 64-bit Steam id of a personal account.
 *
 * Checks the type bits, not the length: a game-server id is 17 digits too.
 * `isSteamId` accepts any account type.
 *
 * @param text {string} the candidate
 * @return {bool} true for an individual-account id64
 */
export func isSteamId64(text as string) {
    if (not isSteamId($text)) {
        return false;
    }
    return parseSteamId($text).accountType == ACCOUNT_INDIVIDUAL;
}

/**
 * Whether the text is a 64-bit Steam id of any account type.
 *
 * Accepts 17 to 20 digits (a personal id has 17, a group or chat id 18)
 * whose universe is 1-5 and whose account type is at most 10.
 *
 * @param text {string} the candidate
 * @return {bool} true when the digits decode to a real universe and type
 */
export func isSteamId(text as string) {
    def digits as string init strings.trim($text);
    if (len($digits) < 17 or len($digits) > 20 or not isDigits($digits)) {
        return false;
    }
    def value as int init parseIntOrZero($digits);
    if ($value <= 0) {
        return false;
    }
    def universe as int init ($value >> 56) & 0xff;
    if ($universe < UNIVERSE_PUBLIC or $universe > UNIVERSE_MAX) {
        return false;
    }
    return (($value >> 52) & 0xf) <= ACCOUNT_ANON_USER;
}

/**
 * The 32-bit account number ("friend id") of a 64-bit id.
 *
 * @param id64 {string} a 64-bit Steam id
 * @return {int} the account number
 * @throws {Error} kind "steam" when the text is not a 64-bit Steam id
 */
export func accountId(id64 as string) {
    return parseSteamId($id64).accountId;
}

/**
 * The 64-bit id of the personal account with this account number.
 *
 * @param account {int} a 32-bit account number
 * @return {string} the 17-digit decimal id
 * @throws {Error} kind "steam" when the number is out of range
 */
export func steamId64FromAccountId(account as int) {
    ensureRange($account, 1, 0xffffffff, "account id");
    return convert.toString(INDIVIDUAL_BASE + $account);
}

/**
 * Render a 64-bit id in the classic `STEAM_1:Y:Z` form, as server logs and
 * RCON print it. `Y` is the low bit of the account number, `Z` the rest.
 *
 * @param id64 {string} a 64-bit Steam id of a personal account
 * @return {string} e.g. "STEAM_1:0:11101"
 * @throws {Error} kind "steam" when the id is not a personal account
 * @example
 *   steam.toSteamId2("76561197960287930");   # STEAM_1:0:11101
 */
export func toSteamId2(id64 as string) {
    def parts as SteamId init parseSteamId($id64);
    requireIndividual($parts, "STEAM_ ids");
    return "STEAM_" + convert.toString($parts.universe) + ":" +
        convert.toString($parts.accountId % 2) + ":" +
        convert.toString($parts.accountId // 2);
}

/**
 * Render a 64-bit id in the modern `[U:1:W]` form, as `status` prints it.
 * The letter names the account type: a group renders as `[g:1:W]`.
 *
 * @param id64 {string} any 64-bit Steam id
 * @return {string} e.g. "[U:1:22202]"
 * @throws {Error} kind "steam" when the text is not a 64-bit Steam id
 */
export func toSteamId3(id64 as string) {
    def parts as SteamId init parseSteamId($id64);
    return "[" + typeLetter($parts.accountType) + ":" +
        convert.toString($parts.universe) + ":" +
        convert.toString($parts.accountId) + "]";
}

/**
 * Read a classic `STEAM_X:Y:Z` id into a 64-bit id. `STEAM_0`, which
 * pre-2010 servers printed for the public universe, reads as universe 1.
 *
 * @param text {string} the classic form
 * @return {string} the 17-digit decimal id
 * @throws {Error} kind "steam" when the text is not in that form
 */
export func fromSteamId2(text as string) {
    def raw as string init strings.trim($text);
    if (not strings.startsWith(strings.upper($raw), "STEAM_")) {
        raiseError("\"" + $raw + "\" is not a STEAM_X:Y:Z id");
    }
    def fields as list of string init strings.split(strings.substring($raw, 6), ":");
    if (len($fields) != 3) {
        raiseError("\"" + $raw + "\" is not a STEAM_X:Y:Z id");
    }
    def universe as int init requireNumber($fields[0], "universe", $raw);
    if ($universe == 0) {
        $universe = UNIVERSE_PUBLIC;
    }
    def parity as int init requireNumber($fields[1], "parity", $raw);
    if ($parity != 0 and $parity != 1) {
        raiseError("the Y part of \"" + $raw + "\" must be 0 or 1");
    }
    def half as int init requireNumber($fields[2], "account half", $raw);
    # doubled below, so bound it first - the multiply would raise, not wrap
    ensureRange($half, 0, 0xffffffff // 2, "account half");
    return toSteamId64(SteamId{
        id64: "",
        universe: $universe,
        accountType: ACCOUNT_INDIVIDUAL,
        instance: 1,
        accountId: $half * 2 + $parity
    });
}

/**
 * Read a modern `[U:1:W]` id into a 64-bit id. The brackets are optional;
 * a trailing instance (`[U:1:W:2]`) is honoured.
 *
 * @param text {string} the modern form
 * @return {string} the 17-digit decimal id
 * @throws {Error} kind "steam" when the text is not in that form
 */
export func fromSteamId3(text as string) {
    def raw as string init strings.trim($text);
    def body as string init $raw;
    if (strings.startsWith($body, "[") and strings.endsWith($body, "]")) {
        $body = strings.substring($body, 1, len($body) - 1);
    }
    def fields as list of string init strings.split($body, ":");
    if (len($fields) < 3 or len($fields) > 4) {
        raiseError("\"" + $raw + "\" is not a [U:1:W] id");
    }
    def kind as int init letterType($fields[0], $raw);
    def universe as int init requireNumber($fields[1], "universe", $raw);
    def account as int init requireNumber($fields[2], "account id", $raw);
    def instance as int init defaultInstance($kind);
    if (len($fields) == 4) {
        $instance = requireNumber($fields[3], "instance", $raw);
    }
    return toSteamId64(SteamId{
        id64: "",
        universe: $universe,
        accountType: $kind,
        instance: $instance,
        accountId: $account
    });
}

/**
 * Convert an id in any of the three notations to the 64-bit id. Every
 * `steamId` argument in this deck goes through it.
 *
 * @param text {string} an id in any of the three notations
 * @return {string} the canonical 17-digit decimal id
 * @throws {Error} kind "steam" when none of the three forms fit
 * @example
 *   steam.normalizeSteamId("[U:1:22202]");   # 76561197960287930
 */
export func normalizeSteamId(text as string) {
    def raw as string init strings.trim($text);
    if ($raw == "") {
        raiseError("a Steam id is required");
    }
    if (strings.startsWith(strings.upper($raw), "STEAM_")) {
        return fromSteamId2($raw);
    }
    if (strings.contains($raw, ":")) {
        return fromSteamId3($raw);
    }
    if (isSteamId($raw)) {
        return convert.toString(parseIntOrZero($raw));
    }
    raiseError("\"" + $raw + "\" is not a Steam id (expected 76561..., " +
        "STEAM_1:0:..., or [U:1:...])");
}

/**
 * Whether `normalizeSteamId` would accept the text.
 *
 * @param text {string} the candidate
 * @return {bool} true when it parses as a Steam id in any notation
 */
export func looksLikeSteamId(text as string) {
    try {
        normalizeSteamId($text);
        return true;
    } catch (e) {
        return false;
    }
}

/**
 * The community profile URL of an account.
 *
 * @param id64 {string} a Steam id in any notation
 * @return {string} e.g. "https://steamcommunity.com/profiles/76561197960287930"
 * @throws {Error} kind "steam" when the id does not parse
 */
export func profileUrl(id64 as string) {
    return COMMUNITY_BASE + "/profiles/" + normalizeSteamId($id64);
}

/**
 * The community URL of a custom (vanity) profile name.
 *
 * The name is percent-encoded, so a slash or space in it cannot change the
 * path. `resolveVanityUrl` turns the name into a 64-bit id.
 *
 * @param vanity {string} the custom URL segment, e.g. "gabelogannewell"
 * @return {string} e.g. "https://steamcommunity.com/id/gabelogannewell"
 * @throws {Error} kind "steam" when the name is blank
 */
export func vanityProfileUrl(vanity as string) {
    return COMMUNITY_BASE + "/id/" + uri.encode(ensureText($vanity, "vanity name"));
}

/**
 * The community URL of a group.
 *
 * @param id64 {string} a 64-bit group id
 * @return {string} e.g. "https://steamcommunity.com/gid/103582791429521412"
 * @throws {Error} kind "steam" when the id does not parse
 */
export func groupUrl(id64 as string) {
    return COMMUNITY_BASE + "/gid/" + normalizeSteamId($id64);
}

/**
 * The name of an account type.
 *
 * @param accountType {int} the type bits, e.g. from `parseSteamId`
 * @return {string} e.g. "individual", or "unknown" for a reserved value
 */
export func accountTypeName(accountType as int) {
    match ($accountType) {
        when 0 { return "invalid"; }
        when 1 { return "individual"; }
        when 2 { return "multiseat"; }
        when 3 { return "game server"; }
        when 4 { return "anonymous game server"; }
        when 5 { return "pending"; }
        when 6 { return "content server"; }
        when 7 { return "group"; }
        when 8 { return "chat"; }
        when 9 { return "peer-to-peer super seeder"; }
        when 10 { return "anonymous user"; }
        else { return "unknown"; }
    }
}

/**
 * Parse a 64-bit Steam id into a number.
 *
 * @param id64 {string} the decimal id
 * @return {int} the numeric id
 * @throws {Error} kind "steam" when the text is not a 64-bit Steam id
 * @internal
 */
func steamIdNumber(id64 as string) {
    def digits as string init strings.trim($id64);
    if (not isSteamId($digits)) {
        raiseError("\"" + $digits + "\" is not a 64-bit Steam id");
    }
    return parseIntOrZero($digits);
}

/**
 * Normalize whatever notation the caller passed, for the request layer.
 *
 * @param text {string} an id in any notation
 * @return {string} the canonical 17-digit decimal id
 * @throws {Error} kind "steam" when it does not parse
 * @internal
 */
func ensureSteamId(text as string) {
    return normalizeSteamId($text);
}

/**
 * Whether every character is an ASCII digit.
 *
 * @param text {string} the candidate
 * @return {bool} true for a non-empty run of digits
 * @internal
 */
func isDigits(text as string) {
    return regex.matches("^[0-9]+$", $text);
}

/**
 * Refuse an out-of-range field of a Steam id.
 *
 * @param value {int} the field value
 * @param low {int} smallest accepted value
 * @param high {int} largest accepted value
 * @param what {string} the field name, for the message
 * @throws {Error} kind "steam" when the value is outside the range
 * @internal
 */
func ensureRange(value as int, low as int, high as int, what as string) {
    if ($value < $low or $value > $high) {
        raiseError("the " + $what + " must be between " + convert.toString($low) +
            " and " + convert.toString($high) + ", got " + convert.toString($value));
    }
}

/**
 * Refuse an id that does not belong to a person.
 *
 * @param parts {SteamId} the parsed id
 * @param what {string} the notation being produced, for the message
 * @throws {Error} kind "steam" when the id is not an individual account
 * @internal
 */
func requireIndividual(parts as SteamId, what as string) {
    if ($parts.accountType != ACCOUNT_INDIVIDUAL) {
        raiseError($what + " only exist for personal accounts, but " + $parts.id64 +
            " is a " + accountTypeName($parts.accountType) + " id");
    }
}

/**
 * Parse a numeric field of a textual Steam id.
 *
 * A field too large for a 64-bit integer is refused rather than folded to
 * zero, which would parse on into a plausible but wrong id.
 *
 * @param text {string} the field
 * @param what {string} the field name, for the message
 * @param whole {string} the id being parsed, for the message
 * @return {int} the number
 * @throws {Error} kind "steam" when the field is not a number, or is too big
 * @internal
 */
func requireNumber(text as string, what as string, whole as string) {
    def digits as string init strings.trim($text);
    if (not isDigits($digits)) {
        raiseError("the " + $what + " of \"" + $whole + "\" is not a number");
    }
    try {
        return convert.toInt($digits);
    } catch (e) {
        raiseError("the " + $what + " of \"" + $whole + "\" is too large to be a Steam id");
    }
}

/**
 * The `[X:1:W]` letter that stands for an account type.
 *
 * @param accountType {int} the type bits
 * @return {string} the one-character tag
 * @internal
 */
func typeLetter(accountType as int) {
    match ($accountType) {
        when 0 { return "I"; }
        when 1 { return "U"; }
        when 2 { return "M"; }
        when 3 { return "G"; }
        when 4 { return "A"; }
        when 5 { return "P"; }
        when 6 { return "C"; }
        when 7 { return "g"; }
        when 8 { return "T"; }
        when 10 { return "a"; }
        else { return "i"; }
    }
}

/**
 * The account type a `[X:1:W]` letter stands for.
 *
 * @param letter {string} the one-character tag
 * @param whole {string} the id being parsed, for the message
 * @return {int} the type bits
 * @throws {Error} kind "steam" when the letter names no type
 * @internal
 */
func letterType(letter as string, whole as string) {
    match (strings.trim($letter)) {
        when "I", "i" { return 0; }
        when "U" { return ACCOUNT_INDIVIDUAL; }
        when "M" { return ACCOUNT_MULTISEAT; }
        when "G" { return ACCOUNT_GAME_SERVER; }
        when "A" { return ACCOUNT_ANON_GAME_SERVER; }
        when "P" { return 5; }
        when "C" { return ACCOUNT_CONTENT_SERVER; }
        when "g" { return ACCOUNT_CLAN; }
        when "T", "L", "c" { return ACCOUNT_CHAT; }
        when "a" { return ACCOUNT_ANON_USER; }
        else { raiseError("\"" + $whole + "\" starts with an unknown account-type letter"); }
    }
}

/**
 * The instance bits an account type carries by default.
 *
 * @param accountType {int} the type bits
 * @return {int} 1 for a desktop personal account, 0 otherwise
 * @internal
 */
func defaultInstance(accountType as int) {
    if ($accountType == ACCOUNT_INDIVIDUAL or $accountType == ACCOUNT_MULTISEAT) {
        return 1;
    }
    return 0;
}
