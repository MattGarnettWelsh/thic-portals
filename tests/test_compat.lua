local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[/\\])") or "./"
local addonDirectory = scriptDirectory .. ".."

local clientGlobals = {
    "C_ChatInfo", "C_PartyInfo", "C_Spell", "C_SpellBook", "C_Item", "Enum",
    "SendChatMessage", "DoEmote", "UninviteUnit",
    "GetSpellBookItemName", "GetSpellInfo", "GetSpellTexture", "GetItemCount"
}

-- Loads Compat.lua against a simulated client, with every client global cleared
-- first so nothing leaks between clients.
local function loadCompat(client)
    for _, name in ipairs(clientGlobals) do
        _G[name] = client[name]
    end
    return dofile(addonDirectory .. "/Compat.lua")
end

-- Forever: the C_* forms only, with the deprecation fallbacks disabled.
local calls = {}
local Compat = loadCompat({
    C_ChatInfo = {
        SendChatMessage = function(message, chatType, languageID, target)
            calls.chat = {message, chatType, languageID, target}
        end,
        PerformEmote = function(emoteName, targetName)
            calls.emote = {emoteName, targetName}
            return true
        end,
        InChatMessagingLockdown = function()
            return calls.lockdown
        end
    },
    C_PartyInfo = {
        UninviteUnit = function(name)
            calls.uninvite = name
        end
    },
    C_Spell = {
        GetSpellInfo = function(spellID)
            return spellID == 10059 and {name = "Portal: Stormwind"} or nil
        end,
        GetSpellTexture = function()
            return 135748, 135748
        end
    },
    C_SpellBook = {
        GetSpellBookItemName = function(index, bank)
            assert(bank == 0, "the player spell bank should be requested")
            return index == 1 and "Conjure Water" or nil, "Rank 8"
        end
    },
    C_Item = {
        GetItemCount = function()
            return 20
        end
    },
    Enum = {SpellBookSpellBank = {Player = 0}}
})

Compat.sendChatMessage("hi", "WHISPER", nil, "Thic")
assert(calls.chat[1] == "hi" and calls.chat[2] == "WHISPER" and calls.chat[4] == "Thic")
assert(Compat.performEmote("thank", "Thic") == true)
assert(calls.emote[1] == "thank" and calls.emote[2] == "Thic")
Compat.uninviteUnit("Thic")
assert(calls.uninvite == "Thic")
assert(not Compat.inChatMessagingLockdown())
calls.lockdown = true
assert(Compat.inChatMessagingLockdown())

local spellName, subName = Compat.getSpellBookItemName(1)
assert(spellName == "Conjure Water" and subName == "Rank 8")
assert(Compat.getSpellName(10059) == "Portal: Stormwind")
assert(Compat.getSpellName(32266) == nil)
assert(select("#", Compat.getSpellName(10059)) == 1)
assert(Compat.getSpellTexture(10059) == 135748)
assert(Compat.getItemCount(231778, false) == 20)

-- An older client: the original globals only, and no lockdown API.
local legacyCalls = {}
Compat = loadCompat({
    SendChatMessage = function(message)
        legacyCalls.chat = message
    end,
    DoEmote = function(emoteName)
        legacyCalls.emote = emoteName
        return true
    end,
    UninviteUnit = function(name)
        legacyCalls.uninvite = name
    end,
    GetSpellInfo = function()
        return "Portal: Stormwind", nil, 135748
    end
})

Compat.sendChatMessage("hi", "WHISPER", nil, "Thic")
assert(legacyCalls.chat == "hi")
assert(Compat.performEmote("thank", "Thic") == true and legacyCalls.emote == "thank")
Compat.uninviteUnit("Thic")
assert(legacyCalls.uninvite == "Thic")
assert(Compat.inChatMessagingLockdown() == false)
assert(select("#", Compat.getSpellName(10059)) == 1)

-- UnitPosition returns nil inside instances, and the range check must survive it.
_G.Config = {Settings = {}}
local Utils = dofile(addonDirectory .. "/Utils.lua")

_G.UnitPosition = function()
    return nil
end
assert(Utils.isPlayerWithinRange("Thic", 50) == false)

_G.UnitPosition = function(unit)
    if unit == "player" then
        return 10, 10, 0, 1
    end
    return 13, 14, 0, 1
end
assert(Utils.isPlayerWithinRange("Thic", 50) == true)
assert(Utils.isPlayerWithinRange("Thic", 2) == false)

-- Close coordinates on another map are not in range. Z is always 0, so only the
-- fourth return can tell the two maps apart.
_G.UnitPosition = function(unit)
    if unit == "player" then
        return 10, 10, 0, 0
    end
    return 13, 14, 0, 1
end
assert(Utils.isPlayerWithinRange("Thic", 50) == false)

print("compat: Forever, legacy and instance position cases passed")
