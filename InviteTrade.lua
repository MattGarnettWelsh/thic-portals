-- InviteTrade.lua
local Config = _G.Config
local Utils = _G.Utils

local InviteTrade = {}

-- Function to play a sound when a match is found
local function playMatchSound()
    if Config.Settings.soundEnabled then
        PlaySoundFile("Interface\\AddOns\\ThicPortals\\Media\\Sounds\\invitesent.mp3", "Master")
    end
end

-- Function to match food and water requests
local function matchFoodAndWaterRequests(message)
    local isFoodRequested = false
    local isWaterRequested = false

    for foodKeyword in Config.Settings.FoodKeywords do
        if string.find(message:lower(), foodKeyword:lower()) then
            isFoodRequested = true
        end
    end

    for waterKeyword in Config.Settings.WaterKeywords do
        if string.find(message:lower(), waterKeyword:lower()) then
            isWaterRequested = true
        end
    end

    return isFoodRequested, isWaterRequested
end

-- Function to check if a player can be invited (based on cooldown)
local function stillOnCooldown(playerName)
    -- If the player is in the pending invites table and has not joined and the cooldown hasn't expired
    return Events.pendingInvites[playerName] and not Events.pendingInvites[playerName].hasJoined and
               (time() - Events.pendingInvites[playerName].timestamp) < Config.Settings.inviteCooldown
end

-- Function to update the destination of a pending invite
local function updatePendingInviteDestination(playerName, message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message,
        Config.Settings.DestinationKeywords)
    if destinationPosition and Events.pendingInvites[playerName] then
        Events.pendingInvites[playerName].destination = destinationKeyword

        if Events.pendingInvites[playerName].destinationValue then
            Events.pendingInvites[playerName].destinationValue:SetText(destinationKeyword)
        end

        print("|cff87CEEB[Thic-Portals]|r Updated destination for " .. playerName .. " to " .. destinationKeyword)

        if Events.pendingInvites[playerName].actionButton then
            -- Set the icon texture for the portal spell
            UI.setIconSpell(Events.pendingInvites[playerName], Events.pendingInvites[playerName].destination)
        end
    end
end

-- Function to handle sending an invite to a player
function InviteTrade.invitePlayer(sender)
    if Config.Settings.removeRealmFromInviteCommand then
        -- sender = Thicfury-Ashbringer for example, we want to remove the realm part
        sender = string.match(sender, "([^%-]+)")
    end

    -- Use the appropriate invite function based on the WoW version
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(sender)
    else
        InviteUnit(sender)
    end

    playMatchSound()

    print("|cff87CEEB[Thic-Portals]|r Invited " .. sender .. " to the group.")
end

-- Function to create a pending invite entry
function InviteTrade.createPendingInvite(playerName, playerClass, sender, message, destinationKeyword)
    Events.pendingInvites[playerName] = {
        timestamp = time(),
        class = playerClass,
        name = playerName,
        fullName = sender,
        destination = destinationKeyword,
        originalMessage = message,
        hasJoined = false,
        hasPaid = false,
        travelled = false
    }

    InviteTrade.setSenderExpiryTimer(playerName)
end

-- Function to handle invite and message for common phrases
function InviteTrade.handleCommonPhraseInvite(message)
    local phrase = Utils.messageHasPhraseOrKeyword(message, Config.Settings.commonPhrases)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message,
        Config.Settings.DestinationKeywords)

    if Config.Settings.debugMode then
        if phrase then
            print("|cff87CEEB[Thic-Portals]|r [Common-phrase-invite] Matched on common phrase: " .. phrase)
            print("|cff87CEEB[Thic-Portals]|r [Common-phrase-invite] Destination keyword: " ..
                      (destinationKeyword or "none"))
        else
            print("|cff87CEEB[Thic-Portals]|r [Common-phrase-invite] Failed to match via common phrase")
        end
    end

    return phrase, destinationKeyword
end

-- Function to handle invites with destination keywords
function InviteTrade.handleDestinationOnlyInvite(message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message,
        Config.Settings.DestinationKeywords)

    if Config.Settings.debugMode then
        if destinationPosition then
            print("|cff87CEEB[Thic-Portals]|r [Destination-only-invite] Matched on destination keyword: " ..
                      destinationKeyword)
        else
            print("|cff87CEEB[Thic-Portals]|r [Destination-only-invite] Failed to match via destination keyword")
        end
    end

    local matched = destinationPosition and true or false

    return matched, destinationKeyword
end

-- Function to handle advanced keyword detection invites
function InviteTrade.handleAdvancedKeywordInvite(message)
    local matched = false
    local destinationKeyword = nil

    local intentPosition, intentKeyword = Utils.findKeywordPosition(message, Config.Settings.IntentKeywords)
    if intentPosition then
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on intent keyword: " .. intentKeyword ..
                      " (position: " .. intentPosition .. ")")
        end

        local servicePosition, serviceKeyword = Utils.findKeywordPosition(message, Config.Settings.ServiceKeywords)
        local destinationPosition, destKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)

        if servicePosition and servicePosition > intentPosition then
            matched = true
            destinationKeyword = destKeyword

            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on service keyword: " ..
                          serviceKeyword .. " (position: " .. servicePosition .. ")")

                if destinationPosition then
                    print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on destination keyword: " ..
                              destKeyword .. " (position: " .. destinationPosition .. ")")
                else
                    print(
                        "|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Failed to match via advanced keyword matching - no destination keyword found.")
                end
            end
        else
            if Config.Settings.debugMode then
                print(
                    "|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Failed to match via advanced keyword matching - no service keyword found.")
            end
        end
    else
        if Config.Settings.debugMode then
            print(
                "|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Failed to match via advanced keyword matching - no intent keyword found.")
        end
    end

    return matched, destinationKeyword
end

-- Main function to handle invites and messages
function InviteTrade.handleInviteAndMessage(sender, playerName, playerClass, message, destinationOnly)
    -- Check if we've reached the maximum number of simultaneous tickets
    local currentTicketCount = 0
    for _ in pairs(Events.pendingInvites) do
        currentTicketCount = currentTicketCount + 1
    end

    if currentTicketCount >= Config.Settings.maxSimultaneousTickets then
        if Config.Settings.debugMode then
            print("[Thic-Portals] Maximum simultaneous tickets (" .. Config.Settings.maxSimultaneousTickets ..
                      ") reached. Ignoring invite for: " .. playerName)
        end
        return
    end

    -- Here we deal with the player ban list
    if Utils.isPlayerBanned(sender) then
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is on the ban list. No invite sent.")
        end
        return
    end

    -- Here we deal with the keyword ban list
    if Utils.messageHasPhraseOrKeyword(message, Config.Settings.KeywordBanList) then
        -- If debug mode
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " used a banned keyword. No invite sent.")
        end
        return
    end

    -- Here we deal with potential invite cooldowns, this should only return early if the player hasn't joined yet
    if stillOnCooldown(playerName) then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is still on invite cooldown.")
        return
    end

    -- Here we do our message matching
    local matched, destinationKeyword = InviteTrade.handleCommonPhraseInvite(message)

    if not Config.Settings.disableSmartMatching and not matched then
        if destinationOnly then
            matched, destinationKeyword = InviteTrade.handleDestinationOnlyInvite(message)
        else
            matched, destinationKeyword = InviteTrade.handleAdvancedKeywordInvite(message)
        end
    end

    if matched then
        if Config.Settings.requireDestination and not destinationKeyword then
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r Invite match found from " .. playerName .. ", but no (valid) destination keyword detected and Require Destination is enabled. Not sending invite.")
            end
            return
        end
        InviteTrade.invitePlayer(sender)
        InviteTrade.createPendingInvite(playerName, playerClass, sender, message, destinationKeyword)
    end

    -- Update pending invite destination if a destination keyword is found in the new message
    updatePendingInviteDestination(playerName, message)
end

-- Function to set an expiry timer for pending invites
function InviteTrade.setSenderExpiryTimer(playerName)
    C_Timer.After(180, function()
        if Events.pendingInvites[playerName] then
            print("|cff87CEEB[Thic-Portals]|r Invite for " .. playerName .. " expired.")
            Events.pendingInvites[playerName] = nil
        end
    end)
end

-- Function to mark yourself with a star when someone accepts the party invite
function InviteTrade.markSelfWithStar()
    SetRaidTarget("player", 1) -- 1 corresponds to the star raid marker
end

-- Function to watch for player's proximity to infer teleportation
function InviteTrade.watchForPlayerProximity(sender)
    local ticker
    local flagProximityReached = false

    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            if Utils.isPlayerWithinRange(sender, Config.Settings.distanceInferringClose) then
                if not flagProximityReached then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " is nearby and might be taking the portal.")
                    flagProximityReached = true
                end
            elseif flagProximityReached and
                not Utils.isPlayerWithinRange(sender, Config.Settings.distanceInferringTravelled) then
                if Config.Settings.debugMode then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has moved away, assuming they took the portal.")
                end

                if Events.pendingInvites[sender] then
                    Events.pendingInvites[sender].travelled = true
                end
                ticker:Cancel() -- Cancel the ticker when the player has moved away
            end
        else
            if Events.pendingInvites[sender] and Events.pendingInvites[sender].ticketFrame then
                Events.pendingInvites[sender].ticketFrame:Hide()
            end
            Events.pendingInvites[sender] = nil
            ticker:Cancel() -- Cancel the ticker if the player is no longer in the party
        end
    end)
end

-- Function to check if there was a tip in the trade
function InviteTrade.checkTradeTip()
    print("|cff87CEEB[Thic-Portals]|r Checking trade tip...");

    local copper = tonumber(Config.currentTraderMoney);
    local silver = math.floor((copper % 10000) / 100);
    local gold = math.floor(copper / 10000);
    local remainingCopper = copper % 100;

    print(
        string.format("|cff87CEEB[Thic-Portals]|r Received %dg %ds %dc from the trade.", gold, silver, remainingCopper));

    if gold > 0 or silver > 0 or remainingCopper > 0 then
        Utils.incrementTradesCompleted();
        Utils.resetDailyGoldIfNeeded();
        Utils.addTipToRollingTotal(gold, silver, remainingCopper);

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold > 8 then
            SendChatMessage("<3", "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "thank" to the player after they have accepted the trade
            DoEmote("thank", Config.currentTraderName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 69 or silver == 69 or remainingCopper == 69 then
            SendChatMessage("Nice (⌐□_□)", "WHISPER", nil,
                Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "flirt" to the player after they sent a 69 tip
            DoEmote("flirt", Config.currentTraderName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 4 and silver == 20 then
            SendChatMessage("420 blaze it (⌐□_□)-~", "WHISPER", nil,
                Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "silly" to the player after they sent a 420 tip
            DoEmote("silly", Config.currentTraderName)
        end

        return true
    else
        return false
    end
end

-- Function to also send mana users a message with water and food stockpiles and none mana users food stock
function InviteTrade.sendFoodAndWaterStockMessage(playerName, playerClass)
    -- Use the new smart detection to get the highest tier items in inventory
    local foodItem, foodCount = Utils.getHighestTierFoodInInventory()
    local waterItem, waterCount = Utils.getHighestTierWaterInInventory()

    local foodStock = nil
    local waterStock = nil

    -- Build food stock message if food is available
    if foodItem and foodCount > 0 then
        foodStock = foodCount .. " x " .. foodItem.name .. " (20x: " .. Utils.formatCopperValue(foodItem.price * 20) ..
                        ")"
    end

    -- Build water stock message if water is available
    if waterItem and waterCount > 0 then
        waterStock =
            waterCount .. " x " .. waterItem.name .. " (20x: " .. Utils.formatCopperValue(waterItem.price * 20) .. ")"
    end

    -- If the player has no food or water in their inventory, we will not advertise it
    if not foodStock and not waterStock then
        -- Print a warning to the player that they're out of stock
        print(
            "|cff87CEEB[Thic-Portals]|r You have run out of food and water stock. Please restock or disable food and water support.")
        return
    end

    local targetIsManaUser = false

    -- depending on the class of the player, we will advertise water or not
    if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "WARLOCK" or playerClass == "DRUID" or
        playerClass == "SHAMAN" or playerClass == "PALADIN" then
        targetIsManaUser = true
    end

    -- if debug mode log both food and water stock
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Food stock: " .. (foodStock or "none"))
        print("|cff87CEEB[Thic-Portals]|r Water stock: " .. (waterStock or "none"))
    end

    if targetIsManaUser then
        if waterStock and foodStock then
            SendChatMessage(
                "I have " .. waterStock .. " and " .. foodStock .. " in stock if you require it - just ask!", "WHISPER",
                nil, playerName)
        elseif waterStock or foodStock then
            local stock = waterStock or foodStock
            SendChatMessage("I have " .. stock .. " in stock if you require it - just ask!", "WHISPER", nil, playerName)
        end
    elseif foodStock then
        SendChatMessage("I have " .. foodStock .. " in stock if you require it - just ask!", "WHISPER", nil, playerName)
    end
end

_G.InviteTrade = InviteTrade

return InviteTrade
