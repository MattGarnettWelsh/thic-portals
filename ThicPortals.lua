-- ThicPortals.lua

local ThicPortals = {}

Config = _G.Config
InviteTrade = _G.InviteTrade
UI = _G.UI
Events = _G.Events
Utils = _G.Utils

local frame = CreateFrame("Frame")

-- Register event handlers
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UI_INFO_MESSAGE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Set the event handler function
frame:SetScript("OnEvent", Events.onEvent)

-- Slash command handler function
function handleCommand(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")

    if command == "on" then
        Config.Settings.addonEnabled = true
        print("|cff87CEEB[Thic-Portals]|r Addon enabled.")
        UI.addonEnabledCheckbox:SetValue(true)
    elseif command == "off" then
        Config.Settings.addonEnabled = false
        print("|cff87CEEB[Thic-Portals]|r Addon disabled.")
        UI.addonEnabledCheckbox:SetValue(false)
    elseif command == "show" then
        UI.showToggleButton()
        print("|cff87CEEB[Thic-Portals]|r Addon management icon displayed.")
    elseif command == "reset" then
        UI.resetToggleButtonPosition()
        print("|cff87CEEB[Thic-Portals]|r Addon management icon position reset.")
    elseif command == "msg" then
        Config.Settings.inviteMessage = rest
        print("|cff87CEEB[Thic-Portals]|r Invite message set to: " .. rest)
    elseif command == "debug" then
        if rest == "on" then
            Config.Settings.debugMode = true
            print("|cff87CEEB[Thic-Portals]|r Debug mode enabled.")
        elseif rest == "off" then
            Config.Settings.debugMode = false
            print("|cff87CEEB[Thic-Portals]|r Debug mode disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Usage: /Tp debug on/off - Enable or disable debug mode")
        end
    elseif command == "keywords" then
        local action, keywordType, keyword = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        if action and keywordType and keyword and keyword ~= "" then
            local keywordTable
            if keywordType == "intent" then
                keywordTable = Config.Settings.IntentKeywords
            elseif keywordType == "destination" then
                keywordTable = Config.Settings.DestinationKeywords
            elseif keywordType == "service" then
                keywordTable = Config.Settings.ServiceKeywords
            else
                print("|cff87CEEB[Thic-Portals]|r Invalid keyword type. Use 'intent', 'destination', or 'service'.")
                return
            end
            if action == "add" then
                table.insert(keywordTable, keyword)
                print("|cff87CEEB[Thic-Portals]|r Added keyword to " .. keywordType .. ": " .. keyword)
            elseif action == "remove" then
                for i, k in ipairs(keywordTable) do
                    if k == keyword then
                        table.remove(keywordTable, i)
                        print("|cff87CEEB[Thic-Portals]|r Removed keyword from " .. keywordType .. ": " .. keyword)
                        break
                    end
                end
            else
                print("|cff87CEEB[Thic-Portals]|r Invalid action. Use 'add' or 'remove'.")
            end
        else
            print("|cff87CEEB[Thic-Portals]|r Usage: /Tp keywords add/remove intent/destination/service [keyword]")
        end
    elseif command == "cooldown" then
        local seconds = tonumber(rest)
        if seconds then
            Config.Settings.inviteCooldown = seconds
            print("|cff87CEEB[Thic-Portals]|r Invite cooldown set to " .. seconds .. " seconds.")
        else
            print("|cff87CEEB[Thic-Portals]|r Usage: /Tp cooldown [seconds] - Set the invite cooldown period")
        end
    elseif command == "help" then
        print("|cff87CEEB[Thic-Portals]|r Usage:")
        print("/Tp show - Show the addon button")
        print("/Tp on - Enable the addon")
        print("/Tp off - Disable the addon")
        print("/Tp msg [message] - Set the invite message")
        print("/Tp debug on/off - Enable or disable debug mode")
        print("/Tp author - The creator")
        print("/Tp help - Show this help message")
        print("/Tp keywords add/remove intent/destination/service [keyword] - Add or remove a keyword")
        print("/Tp cooldown [seconds] - Set the invite cooldown period")
    elseif command == "author" then
        print("|cff87CEEB[Thic-Portals]|r This addon was created by [Thic-Ashbringer EU].")
    else
        print("|cff87CEEB[Thic-Portals]|r Invalid command. Type /Tp help for usage instructions.")
    end
end

-- Add slash command
SLASH_TP1 = "/Tp"

SlashCmdList["TP"] = function(msg)
    handleCommand(msg)
end

return ThicPortals