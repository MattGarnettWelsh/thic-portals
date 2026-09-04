local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[/\\])") or "./"
local addonDirectory = scriptDirectory .. ".."

local keywords = {
    "sw", "stormwind", "if", "ironforge", "org", "shatt", "thunder",
    "thunder bluff", "silver moon"
}

_G.Config = {
    Settings = {
        debugMode = false,
        DestinationKeywords = keywords,
        IntentKeywords = {"wtb", "lf"},
        ServiceKeywords = {"portal", "port"},
        commonPhrases = {"wtb portal", "wtb port"},
        BanList = {},
        KeywordBanList = {},
        maxSimultaneousTickets = 15,
        inviteCooldown = 300,
        disableSmartMatching = false,
        requireDestination = true,
        soundEnabled = false,
        removeRealmFromInviteCommand = false
    }
}

local Utils = dofile(addonDirectory .. "/Utils.lua")

local cases = {
    {"wtb port from sw to if", "if"},
    {"sw to if pls", "if"},
    {"need tp to shatt from org", "shatt"},
    {"lf port if, in sw now", "if"},
    {"sw->if", "if"},
    {"sw=>if", "if"},
    {"sw>if", "if"},
    {"sw >> if", "if"},
    {"port to: ironforge", "ironforge"},
    {"port (from stormwind) to thunder bluff", "thunder bluff"},
    {"port silver moon", "silver moon", false},
    {"wtb portal in sw", "sw", true},
    {"wtb port in ironforge", "ironforge", true},
    {"lf mage port at if", "if", true},
    {"wtb port, im in sw", "sw", true},
    {"from org", "org", true},
    {"port please", nil, false}
}

for _, case in ipairs(cases) do
    local _, actual, originOnly = Utils.findRequestedDestination(case[1], keywords)
    assert(actual == case[2], string.format("%q: expected destination %s, got %s", case[1],
        tostring(case[2]), tostring(actual)))
    assert(originOnly == (case[3] or false), string.format("%q: expected originOnly=%s, got %s",
        case[1], tostring(case[3] or false), tostring(originOnly)))
end

local matches = Utils.findAllKeywordPositions("THUNDER BLUFF to SW and sw", keywords)
assert(#matches == 2, "overlapping and repeated keywords should each produce one choice")
assert(matches[1].keyword == "thunder bluff", "the longest overlapping keyword should win")
assert(matches[2].keyword == "sw", "choices should retain message order")

local repeatedOverlap = Utils.findAllKeywordPositions("thunder bluff then thunder bluff", keywords)
assert(#repeatedOverlap == 1 and repeatedOverlap[1].keyword == "thunder bluff",
    "a repeated long phrase must not leak its shorter overlapping alias")

_G.Events = {pendingInvites = {}}
_G.UI = {}
local InviteTrade = dofile(addonDirectory .. "/InviteTrade.lua")

for _, message in ipairs({
    "wtb portal in sw",
    "wtb port in ironforge",
    "lf mage port at if",
    "wtb port, im in sw"
}) do
    local matched, destination = InviteTrade.handleDestinationOnlyInvite(message)
    assert(matched and destination, message .. ": destination-only matching must accept the request")
end

local inviteCount = 0
InviteTrade.invitePlayer = function()
    inviteCount = inviteCount + 1
end
InviteTrade.createPendingInvite = function(playerName, _, _, message, destination)
    Events.pendingInvites[playerName] = {
        timestamp = 0,
        hasJoined = false,
        originalMessage = message,
        destination = destination
    }
end

InviteTrade.handleInviteAndMessage("Buyer-Realm", "Buyer", "MAGE", "wtb portal in sw", false)
assert(inviteCount == 1, "Require Destination must not reject an origin-worded portal request")
assert(Events.pendingInvites.Buyer.destination == "sw", "new request should retain the city fallback")

Events.pendingInvites.Buyer.hasJoined = true
Events.pendingInvites.Buyer.destination = "if"
Config.Settings.disableSmartMatching = true
Config.Settings.commonPhrases = {}
InviteTrade.handleInviteAndMessage("Buyer-Realm", "Buyer", "MAGE", "I'm in SW", false)
assert(Events.pendingInvites.Buyer.destination == "if", "origin-only follow-up must not retarget a ticket")

print(string.format("destination parser and invite integration: %d parser cases passed", #cases))
