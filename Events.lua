-- Events.lua
local Config = _G.Config
local InviteTrade = _G.InviteTrade
local UI = _G.UI
local Utils = _G.Utils
local Events = {}

_G.Events = Events

Events.pendingInvites = {} -- Table to store pending invites with all relevant data

-- Example structure:
-- Events.pendingInvites["PlayerName"] = {
--     name = "PlayerName",
--     fullName = "PlayerName-Realm",
--     class = "Warrior",
--     destination = "Darna",
--     hasJoined = false,
--     hasPaid = false,
--     ticketFrame = nil, -- Reference to the ticket frame for this player
--     targetted = false, -- Whether this player is currently targeted
-- }

local function printEvent(event)
    if Config.Settings and Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r " .. event .. " event fired.")
    end
end

-- Function to handle consecutive leaves without payment
local function handleConsecutiveLeavesWithoutPayment()
    Config.Settings.consecutiveLeavesWithoutPayment = Config.Settings.consecutiveLeavesWithoutPayment + 1
    print("|cff87CEEB[Thic-Portals]|r Consecutive players who have left the party without payment: " ..
              Config.Settings.consecutiveLeavesWithoutPayment)

    if Config.Settings.consecutiveLeavesWithoutPayment >= Config.Settings.leaveWithoutPaymentThreshold then
        print(
            "|cff87CEEB[Thic-Portals]|r Two people in a row left without payment - you are likely AFK. Shutting down the addon.")
        if Config.Settings.addonEnabled then
            UI.toggleAddonEnabledState()
        end
    end
end

-- Event handler function
function Events.onEvent(self, event, ...)
    if event == "VARIABLES_LOADED" then
        printEvent(event)

        -- Initialize saved variables
        Config.initializeSavedVariables()

        -- Print gold info to the console
        Utils.printGoldInformation()

        -- Create the in-game toggle button for the addon
        UI.createToggleButton()

        -- Create the in-game options panel for the addon
        UI.createOptionsPanel()
        UI.hideOptionsPanel()

        -- Create the global interface options panel
        UI.createInterfaceOptionsPanel()

        return
    end

    -- If the addon is disabled, don't do anything
    if not Config.Settings.addonEnabled then
        return
    end

    local checkGlobal = false

    if event == "CHAT_MSG_CHANNEL" then
        if not Config.Settings.disableGlobalChannels then
            checkGlobal = true
        else
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r Global channels disabled. Skipping global channel message.")
            end
        end
    end

    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_PARTY" or
        checkGlobal then
        printEvent(event)

        local args = {...}

        if args[12] then
            local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(
                args[12])
            local message, nameAndServer = args[1], args[2]

            -- Check if addon is enabled
            if message and name then
                -- If name is not "Thicfury" or "Thic", return
                -- if not (name == "Thicfury" or name == "Thic") then
                --     if Config.Settings.debugMode then
                --         print("|cff87CEEB[Thic-Portals]|r Ignoring message from: " .. name)
                --     end
                --     return
                -- end

                local destinationOnly = false

                -- If we are running approach mode, when we are handling say/whisper messages, we should evaluate destination only for a match
                if Config.Settings.ApproachMode and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_SAY") then
                    destinationOnly = true
                end

                -- Handle the invite and message logic
                InviteTrade.handleInviteAndMessage(nameAndServer, name, englishClass, message, destinationOnly)
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        printEvent(event)

        -- Collect senders to remove after iteration to avoid table modification during loop
        local toRemove = {}
        for sender, inviteData in pairs(Events.pendingInvites) do
            if UnitInParty(sender) and not inviteData.hasJoined then
                inviteData.hasJoined = true

                FlashClientIcon() -- Flash the WoW icon in the taskbar

                UI.showPaginatedTicketWindow(sender, inviteData.destination)

                if inviteData.destination then
                    local message = Utils.replacePlaceholders(Config.Settings.inviteMessage, inviteData.destination)
                    SendChatMessage(message, "WHISPER", nil, inviteData.fullName)
                else
                    SendChatMessage(Config.Settings.inviteMessageWithoutDestination, "WHISPER", nil, inviteData.fullName)
                end
                if Config.Settings.enableFoodWaterSupport then
                    InviteTrade.sendFoodAndWaterStockMessage(inviteData.name, inviteData.class)
                end

                InviteTrade.markSelfWithStar()
                InviteTrade.watchForPlayerProximity(sender)
            elseif not UnitInParty(sender) and inviteData.hasJoined then
                table.insert(toRemove, sender)
            end
        end

        -- Now process removals
        for _, sender in ipairs(toRemove) do
            local inviteData = Events.pendingInvites[sender]
            if inviteData and inviteData.ticketFrame then
                inviteData.ticketFrame:Hide()
            end
            Events.pendingInvites[sender] = nil
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r " .. sender ..
                          " has left the party and has been removed from tracking.")
            end
            if not (inviteData and inviteData.hasPaid) and not Config.Settings.disableAFKProtection then
                handleConsecutiveLeavesWithoutPayment()
            end
        end

        -- Update the ticket window after removals
        if UI and UI.ticketList then
            local numTickets = #UI.ticketList or 0

            UI.updateTicketList()

            if numTickets > 0 and UI.ticketFrame then
                -- If current index is out of bounds, move to next available
                if UI.currentTicketIndex > numTickets then
                    UI.currentTicketIndex = numTickets
                end

                UI.updateTicketFrame()

            elseif UI.ticketFrame then
                UI.ticketFrame:Hide()
            end
        end

    elseif event == "TRADE_SHOW" then
        printEvent(event)

        -- Reset the counter when a trade is initiated
        Events.resetConsecutiveLeavesWithoutPaymentCounter()

        -- Store the name of the player when the trade window is opened
        Events.storeCurrentTrader()

    elseif event == "TRADE_MONEY_CHANGED" then
        printEvent(event)

        Events.updateTradeMoney()

    elseif event == "TRADE_ACCEPT_UPDATE" then
        printEvent(event)

        Events.updateTradeMoney()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local spellName = GetSpellInfo(spellID)
            for _, portalName in ipairs(Config.Portals) do
                if spellName:lower() == portalName:lower() then
                    if Config.Settings.debugMode then
                        print("|cff87CEEB[Thic-Portals]|r Portal to " .. spellName .. " successfully cast!")
                    end

                    Config.CurrentAlivePortals[spellName] = true

                    for spellName, cast in pairs(Config.CurrentAlivePortals or {}) do
                        print(" - " .. spellName .. ": " .. tostring(cast))
                    end

                    -- Redraw the ticket window
                    UI.updateTicketFrame()

                    -- Add a timer for a minute's time to remove the portal from the list
                    C_Timer.After(60, function()
                        Config.CurrentAlivePortals[spellName] = nil

                        if Config.Settings.debugMode then
                            print("|cff87CEEB[Thic-Portals]|r Portal to " .. spellName ..
                                      " has been removed from the list of active portals.")
                        end
                    end)

                    break
                end
            end
        end

    elseif event == "UI_INFO_MESSAGE" then
        printEvent(event)

        local type, msg = ...
        if (msg == ERR_TRADE_COMPLETE) then
            Events.handleTradeComplete()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UI.ticketFrame and UI.ticketFrame:IsShown() then
            -- Clear existing targetted flags
            for _, inviteData in pairs(Events.pendingInvites) do
                inviteData.targetted = false
            end

            -- Get the name and realm of the current target
            local targetName, targetRealm = UnitName("target", true)
            if targetName then
                -- Check if the target is in the pending invites
                for sender, inviteData in pairs(Events.pendingInvites) do
                    if inviteData.name == targetName then
                        inviteData.targetted = true
                        if Config.Settings.debugMode then
                            print("|cff87CEEB[Thic-Portals]|r Target set to: " .. targetName)
                        end

                        break
                    end
                end
            end

            -- Refresh the ticket frame in case we need to change the trade icon
            -- from "target" to "trade" or vice versa
            UI.updateTicketFrame()
        end
    end
end

-- Function to reset the consecutive leaves without payment counter
function Events.resetConsecutiveLeavesWithoutPaymentCounter()
    Config.Settings.consecutiveLeavesWithoutPayment = 0
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Trade initiated. Resetting consecutive leaves without payment counter.")
    end
end

-- Function to store the current trader's information
function Events.storeCurrentTrader()
    Config.currentTraderName, Config.currentTraderRealm = UnitName("NPC", true)
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Current trader: " .. (Config.currentTraderName or "Unknown"))
    end
end

-- Function to update trade money
function Events.updateTradeMoney()
    Config.currentTraderMoney = GetTargetTradeMoney()
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Current trade money: " .. (Config.currentTraderMoney or "Unknown"))
    end
end

-- Function to handle trade completion
function Events.handleTradeComplete()
    if Config.currentTraderName then
        if Events.pendingInvites[Config.currentTraderName] then
            if InviteTrade.checkTradeTip() then
                -- Send them a thank you!
                local message = Utils.replacePlaceholders(Config.Settings.tipMessage,
                    Events.pendingInvites[Config.currentTraderName].destination)
                SendChatMessage(message, "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)
            else
                local message = Utils.replacePlaceholders(Config.Settings.noTipMessage,
                    Events.pendingInvites[Config.currentTraderName].destination)
                SendChatMessage(message, "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)
            end

            Events.pendingInvites[Config.currentTraderName].hasPaid = true
            Config.currentTraderName = nil
            Config.currentTraderMoney = nil
            Config.currentTraderRealm = nil
        else
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r No pending invite found for current trader, ignoring transaction.")
            end
        end
    elseif Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r No current trader found.")
    end
end

return Events
