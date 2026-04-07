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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLS_CHANGED")
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
        Utils.print("Addon enabled.")
        UI.addonEnabledCheckbox:SetValue(true)
    elseif command == "off" then
        Config.Settings.addonEnabled = false
        Utils.print("Addon disabled.")
        UI.addonEnabledCheckbox:SetValue(false)
    elseif command == "show" then
        UI.showToggleButton()
        Utils.print("Addon management icon displayed.")
    elseif command == "reset" then
        UI.resetToggleButtonPosition()
        Utils.print("Addon management icon position reset.")
    elseif command == "msg" then
        Config.Settings.inviteMessage = rest
        Utils.print("Invite message set to: " .. rest)
    elseif command == "debug" then
        if rest == "on" then
            Config.Settings.debugMode = true
            Utils.print("Debug mode enabled.")
        elseif rest == "off" then
            Config.Settings.debugMode = false
            Utils.print("Debug mode disabled.")
        else
            Utils.print("Usage: /Tp debug on/off - Enable or disable debug mode")
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
                Utils.print("Invalid keyword type. Use 'intent', 'destination', or 'service'.")
                return
            end
            if action == "add" then
                table.insert(keywordTable, keyword)
                Utils.print("Added keyword to " .. keywordType .. ": " .. keyword)
            elseif action == "remove" then
                for i, k in ipairs(keywordTable) do
                    if k == keyword then
                        table.remove(keywordTable, i)
                        Utils.print("Removed keyword from " .. keywordType .. ": " .. keyword)
                        break
                    end
                end
            else
                Utils.print("Invalid action. Use 'add' or 'remove'.")
            end
        else
            Utils.print("Usage: /Tp keywords add/remove intent/destination/service [keyword]")
        end
    elseif command == "cooldown" then
        local seconds = tonumber(rest)
        if seconds then
            Config.Settings.inviteCooldown = seconds
            Utils.print("Invite cooldown set to " .. seconds .. " seconds.")
        else
            Utils.print("Usage: /Tp cooldown [seconds] - Set the invite cooldown period")
        end
    elseif command == "checkspells" then
        Utils.print("Scanning spellbook for Conjure spells...")
        local i = 1
        local foundFood = false
        local foundWater = false
        while i <= 1024 do
            local spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if not spellName then
                break
            end
            if spellName == "Conjure Food" or spellName == "Conjure Water" then
                Utils.print("Found: " .. spellName .. " (" .. (spellRank or "no rank") .. ")")
                if spellName == "Conjure Food" then
                    foundFood = true
                end
                if spellName == "Conjure Water" then
                    foundWater = true
                end
            end
            i = i + 1
        end
        if not foundFood and not foundWater then
            Utils.print("No Conjure spells found in spellbook!")
        end

        -- Debug: Check config structure
        if not Config.Settings.foodItems then
            Utils.print("ERROR: Config.Settings.foodItems is nil!")
        else
            Utils.print("Config has " .. #Config.Settings.foodItems .. " food items defined.")
            if #Config.Settings.foodItems > 0 then
                local item = Config.Settings.foodItems[1]
                Utils.print("Sample food item: name=" .. (item.name or "nil") .. ", spellName=" ..
                          (item.spellName or "nil") .. ", rank=" .. (item.rank or "nil"))
            end
        end

        if not Config.Settings.waterItems then
            Utils.print("ERROR: Config.Settings.waterItems is nil!")
        else
            Utils.print("Config has " .. #Config.Settings.waterItems .. " water items defined.")
        end

        local availableFood = Utils.getAvailableFoodItems()
        local availableWater = Utils.getAvailableWaterItems()
        Utils.print("Detected " .. #availableFood .. " food items and " .. #availableWater ..
                  " water items you can conjure.")

        -- Test the detection function directly
        local testResult = Utils.isSpellRankKnown("Conjure Food", 7)
        Utils.print("Direct test - isSpellRankKnown('Conjure Food', 7) = " .. tostring(testResult))
    elseif command == "help" then
        Utils.print("Usage:")
        print("/Tp show - Show the addon button")
        print("/Tp on - Enable the addon")
        print("/Tp off - Disable the addon")
        print("/Tp msg [message] - Set the invite message")
        print("/Tp debug on/off - Enable or disable debug mode")
        print("/Tp checkspells - Check what conjure spells are detected")
        print("/Tp author - The creator")
        print("/Tp help - Show this help message")
        print("/Tp keywords add/remove intent/destination/service [keyword] - Add or remove a keyword")
        print("/Tp cooldown [seconds] - Set the invite cooldown period")
    elseif command == "author" then
        Utils.print("This addon was created by [Thic-Ashbringer EU].")
    else
        Utils.print("Invalid command. Type /Tp help for usage instructions.")
    end
end

-- Add slash command
SLASH_TP1 = "/Tp"

SlashCmdList["TP"] = function(msg)
    handleCommand(msg)
end

return ThicPortals
