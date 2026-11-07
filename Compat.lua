-- Compat.lua
-- The single boundary between this addon and the client's API.
--
-- WoW: Forever (Classic+) runs vanilla content on Retail's API surface, so many
-- of the original globals are gone and the C_* namespaces answer instead. Classic
-- Era and TBC have moved part of the way there too. Each shim below resolves once
-- at load and hands back the ORIGINAL return shape, so callers never need to know
-- which client they are running on.
--
-- Two deliberate choices:
--
--  1. Detection is by feature, never by build number or interface version. When
--     Blizzard moves one of these again, the fallback chain still resolves.
--
--  2. The spell and item shims prefer the legacy global, with the C_* form as the
--     fallback, so Classic Era and TBC keep taking the path they already ship on.
--     The chat and party shims go the other way and prefer C_*: on every client
--     those globals are only wrappers from Blizzard's deprecation fallback addons,
--     which a CVar can disable and which are due to be removed.
local Compat = {}

_G.Compat = Compat

-- True when this client answers with the C_* namespaces rather than the
-- original globals. Useful for debug output; prefer the shims for real work.
Compat.usesModernSpellAPI = not GetSpellBookItemName

-- Returns: name, subName
-- subName carries the rank text ("Rank 7") that the food and water tier
-- detection in Utils depends on.
if GetSpellBookItemName then
    function Compat.getSpellBookItemName(index)
        return GetSpellBookItemName(index, BOOKTYPE_SPELL)
    end
else
    -- Enum.SpellBookSpellBank.Player is 0; fall back to the literal in case the
    -- enum is namespaced differently on this client.
    local playerBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0

    function Compat.getSpellBookItemName(index)
        if not (C_SpellBook and C_SpellBook.GetSpellBookItemName) then
            return nil
        end

        return C_SpellBook.GetSpellBookItemName(index, playerBank)
    end
end

-- Returns: the spell's name, or nil when the id is unknown to this client.
-- The old global returned seven values and the new one returns a table, so this
-- deliberately narrows to the only field the addon actually uses.
if GetSpellInfo then
    function Compat.getSpellName(spellID)
        return (GetSpellInfo(spellID))
    end
else
    function Compat.getSpellName(spellID)
        if not (C_Spell and C_Spell.GetSpellInfo) then
            return nil
        end

        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end
end

-- Returns: the icon texture for a spell, or nil.
if GetSpellTexture then
    function Compat.getSpellTexture(spellID)
        return (GetSpellTexture(spellID))
    end
else
    function Compat.getSpellTexture(spellID)
        if not (C_Spell and C_Spell.GetSpellTexture) then
            return nil
        end

        return C_Spell.GetSpellTexture(spellID)
    end
end

-- Returns: how many of an item the player is carrying.
if GetItemCount then
    function Compat.getItemCount(itemID, includeBank)
        return GetItemCount(itemID, includeBank)
    end
else
    function Compat.getItemCount(itemID, includeBank)
        if not (C_Item and C_Item.GetItemCount) then
            return 0
        end

        return C_Item.GetItemCount(itemID, includeBank)
    end
end

-- Sends a chat message. Same argument order as the old global.
if C_ChatInfo and C_ChatInfo.SendChatMessage then
    function Compat.sendChatMessage(message, chatType, languageID, target)
        C_ChatInfo.SendChatMessage(message, chatType, languageID, target)
    end
else
    function Compat.sendChatMessage(message, chatType, languageID, target)
        SendChatMessage(message, chatType, languageID, target)
    end
end

-- Performs an emote token such as "thank", optionally at a named player.
if C_ChatInfo and C_ChatInfo.PerformEmote then
    function Compat.performEmote(emoteName, targetName)
        return C_ChatInfo.PerformEmote(emoteName, targetName)
    end
else
    function Compat.performEmote(emoteName, targetName)
        return DoEmote(emoteName, targetName)
    end
end

-- Removes a player from the group.
if C_PartyInfo and C_PartyInfo.UninviteUnit then
    function Compat.uninviteUnit(name)
        C_PartyInfo.UninviteUnit(name)
    end
else
    function Compat.uninviteUnit(name)
        UninviteUnit(name)
    end
end

-- Returns: true while chat event payloads are secret values, which tainted code
-- cannot parse. This covers dungeons, raids, encounters and PvP matches. Clients
-- without the API have no such restriction.
if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    function Compat.inChatMessagingLockdown()
        return C_ChatInfo.InChatMessagingLockdown()
    end
else
    function Compat.inChatMessagingLockdown()
        return false
    end
end

return Compat
