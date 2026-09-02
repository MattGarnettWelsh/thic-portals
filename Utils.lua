-- Events.lua
local Config = _G.Config

-- Utils.lua
local Utils = {}

-- Function to calculate the distance between two points using the Pythagorean theorem
function Utils.calculateDistance(playerX, playerY, targetX, targetY)
    return math.sqrt((playerX - targetX) ^ 2 + (playerY - targetY) ^ 2)
end

-- Function to check if a value equals another value in a table
function Utils.keywordInTable(keyword, keywordList)
    keyword = keyword:lower()
    for _, phrase in ipairs(keywordList) do
        if keyword == phrase:lower() then
            return true
        end
    end
    return false
end

-- Helper function to escape Lua pattern special characters
local function escapePattern(text)
    return text:gsub("([^%w])", "%%%1")
end

-- Function to check if a message contains any exact keyword/phrase match.
function Utils.messageHasPhraseOrKeyword(message, keywordList)
    -- Pad the message with spaces at the beginning and end.
    message = " " .. message:lower() .. " "
    for _, phrase in ipairs(keywordList) do
        if phrase:sub(1, 1) == "%" and phrase:sub(-1) == "%" then
            -- Contains style search: remove the leading and trailing '%' characters.
            local substring = phrase:sub(2, -2):lower()
            if string.find(message, substring, 1, true) then
                return substring
            end
        else
            -- Use frontier patterns to ensure whole word/phrase matching.
            local escapedPhrase = escapePattern(phrase:lower())
            local pattern = "%f[%w]" .. escapedPhrase .. "%f[%W]"
            if string.find(message, pattern) then
                return phrase
            end
        end
    end
    return false
end

-- Function to find if a message contains any keyword from a list and return the position and matched keyword
function Utils.findKeywordPosition(message, keywordList)
    -- Pad the message with spaces at the beginning and end.
    message = " " .. message:lower() .. " "
    for _, keyword in ipairs(keywordList) do
        local pattern = "%f[%w]" .. keyword:lower() .. "%f[%W]"
        local position = string.find(message, pattern)
        if position then
            return position, keyword
        end
    end
    return nil, nil
end

-- Function to replace placeholders in messages with actual values
function Utils.replacePlaceholders(message, destination)
    if not message then
        return message
    end

    -- Replace %destination% with the actual destination
    if destination then
        message = string.gsub(message, "%%destination%%", destination)
    end

    return message
end

-- Function to update the distance label in the UI based on the distance between two players
function Utils.updateDistanceLabel(sender, distanceLabel)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        -- Only update if the label is still for the correct sender
        if UI.ticketFrame and UI.ticketFrame.currentSender ~= sender then
            ticker:Cancel()
            return
        end
        if UnitInParty(sender) then
            local playerX, playerY, playerInstanceID = UnitPosition("player")
            local targetX, targetY, targetInstanceID = UnitPosition(sender)

            if playerInstanceID == targetInstanceID then
                local distance = Utils.calculateDistance(playerX, playerY, targetX, targetY)
                distanceLabel:SetText(string.format("Distance: %.1f yards", distance))
            else
                distanceLabel:SetText("Distance: Unknown")
            end
        else
            distanceLabel:SetText("Distance: N/A")
            ticker:Cancel() -- Cancel the ticker if the player is no longer in the party
        end
    end)
end

-- Function to calculate the required height for text
function Utils.calculateTextHeight(fontString, text, width)
    fontString:SetWidth(width)
    fontString:SetText(text)
    fontString:SetWordWrap(true)
    local height = fontString:GetStringHeight()
    return height
end

-- Function to add tip to rolling total
function Utils.addTipToRollingTotal(gold, silver, copper)
    local totalCopper = gold * 10000 + silver * 100 + copper

    Config.Settings.totalGold = Config.Settings.totalGold + totalCopper
    Config.Settings.dailyGold = Config.Settings.dailyGold + totalCopper

    Utils.printGoldInformation()
end

-- Function to print gold information
function Utils.printGoldInformation()
    Utils.print(string.format("Total trades completed: %d", Config.Settings.totalTradesCompleted))
    Utils.print(string.format("Total gold earned: %dg %ds %dc",
        math.floor(Config.Settings.totalGold / 10000), math.floor((Config.Settings.totalGold % 10000) / 100),
        Config.Settings.totalGold % 100))
    Utils.print(string.format("Gold earned today: %dg %ds %dc",
        math.floor(Config.Settings.dailyGold / 10000), math.floor((Config.Settings.dailyGold % 10000) / 100),
        Config.Settings.dailyGold % 100))
end

-- Function to reset daily gold if needed
function Utils.resetDailyGoldIfNeeded()
    local currentDate = date("%Y-%m-%d")
    if Config.Settings.lastUpdateDate ~= currentDate then
        Config.Settings.dailyGold = 0
        Config.Settings.lastUpdateDate = currentDate
        Utils.print("Daily gold counter reset for a new day.")
    end
end

-- Function to increment trades completed
function Utils.incrementTradesCompleted()
    Config.Settings.totalTradesCompleted = Config.Settings.totalTradesCompleted + 1
end

-- Function to check if the player is within range using the UnitPosition API
function Utils.isPlayerWithinRange(sender, range)
    local playerX, playerY, playerInstanceID = UnitPosition("player")
    local targetX, targetY, targetInstanceID = UnitPosition(sender)

    if playerInstanceID == targetInstanceID then
        local distance = Utils.calculateDistance(playerX, playerY, targetX, targetY)
        return distance <= range -- Example threshold for being "travelled"
    end

    return false
end

-- Function to check if a player is on the ban list
function Utils.isPlayerBanned(player)
    for _, bannedPlayer in ipairs(Config.Settings.BanList) do
        if bannedPlayer == player then
            return true
        end
    end
    return false
end

-- Every shipped destination keyword mapped to the city it names. The previous
-- letter-frequency heuristic sent common aliases such as "org" to Ironforge.
Utils.DestinationAliases = {
    darn = "Darnassus",
    darnassuss = "Darnassus",
    darnas = "Darnassus",
    darrna = "Darnassus",
    darnaas = "Darnassus",
    darnassus = "Darnassus",
    darnasuss = "Darnassus",
    darna = "Darnassus",
    darnasus = "Darnassus",
    sw = "Stormwind",
    stormwind = "Stormwind",
    ["storm wind"] = "Stormwind",
    ["if"] = "Ironforge",
    ironforge = "Ironforge",
    ["iron forge"] = "Ironforge",
    exodar = "Exodar",
    exo = "Exodar",
    theramore = "Theramore",
    thera = "Theramore",
    tmore = "Theramore",
    org = "Orgrimmar",
    orgrimmar = "Orgrimmar",
    orgri = "Orgrimmar",
    orgim = "Orgrimmar",
    tb = "Thunder Bluff",
    ["thunder bluff"] = "Thunder Bluff",
    thunderbluff = "Thunder Bluff",
    thunder = "Thunder Bluff",
    uc = "Undercity",
    undercity = "Undercity",
    ["under city"] = "Undercity",
    silvermoon = "Silvermoon",
    ["silver moon"] = "Silvermoon",
    sm = "Silvermoon",
    silv = "Silvermoon",
    stonard = "Stonard",
    ston = "Stonard",
    shattrath = "Shattrath",
    shatt = "Shattrath",
    shat = "Shattrath",
    shath = "Shattrath"
}

Utils.PortalSpells = {
    Darnassus = {spellID = 11419},
    Stormwind = {spellID = 10059},
    Ironforge = {spellID = 11416},
    Exodar = {spellID = 32266},
    Theramore = {spellID = 49360},
    Orgrimmar = {spellID = 11417},
    ["Thunder Bluff"] = {spellID = 11420},
    Undercity = {spellID = 11418},
    Silvermoon = {spellID = 32267},
    Stonard = {spellID = 49361},
    Shattrath = {
        byFaction = {
            Alliance = 33691,
            Horde = 35717
        }
    }
}

function Utils.resolveCanonicalDestination(destination)
    if not destination then
        return nil
    end

    return Utils.DestinationAliases[destination:lower()]
end

-- Preserve support for custom destination keywords by retaining the old
-- heuristic as a fallback for aliases not present in the shipped map.
local function matchPortalByHeuristic(destination)
    local bestMatch = nil
    local maxMatches = 0

    for _, portalName in ipairs(Config.Portals) do
        local spellDestination = portalName:match("Portal: (.+)"):lower()
        local matches = 0

        for i = 1, #destination do
            if spellDestination:find(destination:sub(i, i), 1, true) then
                matches = matches + 1
            end
        end

        if matches > maxMatches then
            maxMatches = matches
            bestMatch = portalName
        end
    end

    return bestMatch and bestMatch:match("Portal: (.+)") or nil
end

function Utils.getMatchingPortal(destination)
    local defaultPortal = {
        matched = false,
        spellID = 10059,
        spellName = "Portal: Stormwind",
        locationName = "Stormwind"
    }

    if not destination then
        return defaultPortal
    end

    local canonical = Utils.resolveCanonicalDestination(destination) or
                          matchPortalByHeuristic(destination)
    local spell = canonical and Utils.PortalSpells[canonical]

    if not spell then
        return defaultPortal
    end

    local spellID = spell.spellID
    if not spellID and spell.byFaction then
        spellID = spell.byFaction[UnitFactionGroup("player")]
    end

    Utils.debugPrint("Destination \"" .. destination .. "\" resolved to " .. canonical)

    return {
        matched = true,
        spellID = spellID,
        spellName = "Portal: " .. canonical,
        locationName = canonical
    }
end

-- Convert the copper value to a gold, silver, and copper formatted string
function Utils.formatCopperValue(totalCost)
    local gold = math.floor(totalCost / 10000)
    local silver = math.floor((totalCost % 10000) / 100)
    local copper = totalCost % 100

    local formattedString = ""

    if gold > 0 then
        formattedString = string.format("%dg", gold)
    end

    if silver > 0 then
        if #formattedString > 0 then
            formattedString = formattedString .. " "
        end
        formattedString = formattedString .. string.format("%ds", silver)
    end

    if copper > 0 then
        if #formattedString > 0 then
            formattedString = formattedString .. " "
        end
        formattedString = formattedString .. string.format("%dc", copper)
    end

    return formattedString
end

-- Function to check if a spell rank is known by the player
function Utils.isSpellRankKnown(spellBaseName, rank)
    if not spellBaseName or not rank then
        return false
    end

    -- In Classic, we need to iterate through all spell slots
    local i = 1
    local maxSpells = 1024 -- Safe upper limit

    while i <= maxSpells do
        local spellName, spellSubName = GetSpellBookItemName(i, BOOKTYPE_SPELL)

        if not spellName then
            break
        end

        -- Check if the spell name matches what we're looking for
        if spellName == spellBaseName then
            -- spellSubName contains rank info like "Rank 7"
            if spellSubName then
                local rankNum = tonumber(spellSubName:match("(%d+)"))
                if rankNum and rankNum >= rank then
                    -- If the player knows this rank or higher, they can conjure this item
                    return true
                end
            elseif not spellSubName and rank == 1 then
                -- Some spells don't have ranks, treat as rank 1
                return true
            end
        end

        i = i + 1
    end

    return false
end

-- Function to get available food items (that the mage can conjure)
function Utils.getAvailableFoodItems()
    local availableItems = {}
    for _, item in ipairs(Config.Settings.foodItems or {}) do
        if Utils.isSpellRankKnown(item.spellName, item.rank) then
            table.insert(availableItems, item)
        end
    end
    return availableItems
end

-- Function to get available water items (that the mage can conjure)
function Utils.getAvailableWaterItems()
    local availableItems = {}
    for _, item in ipairs(Config.Settings.waterItems or {}) do
        if Utils.isSpellRankKnown(item.spellName, item.rank) then
            table.insert(availableItems, item)
        end
    end
    return availableItems
end

-- Function to get the highest tier food item the player has in inventory
function Utils.getHighestTierFoodInInventory()
    local availableFood = Utils.getAvailableFoodItems()
    -- Iterate in reverse order (highest tier first)
    for i = #availableFood, 1, -1 do
        local item = availableFood[i]
        local count = GetItemCount(item.itemId, false)
        if count > 0 then
            return item, count
        end
    end
    return nil, 0
end

-- Function to get the highest tier water item the player has in inventory
function Utils.getHighestTierWaterInInventory()
    local availableWater = Utils.getAvailableWaterItems()
    -- Iterate in reverse order (highest tier first)
    for i = #availableWater, 1, -1 do
        local item = availableWater[i]
        local count = GetItemCount(item.itemId, false)
        if count > 0 then
            return item, count
        end
    end
    return nil, 0
end

function Utils.print(message)
    print("|cff87CEEB[Thic-Portals]|r " .. message)
end

function Utils.debugPrint(message)
    if Config.Settings.debugMode then
        Utils.print(message)
    end
end

_G.Utils = Utils

return Utils
