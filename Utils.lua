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

-- Find every distinct keyword in message order. Longer overlapping phrases win,
-- so "thunder bluff" is not also reported as "thunder".
function Utils.findAllKeywordPositions(message, keywordList)
    if not message or not keywordList then
        return {}
    end

    local padded = " " .. message:lower() .. " "
    local hits = {}

    for _, keyword in ipairs(keywordList) do
        local pattern = "%f[%w]" .. escapePattern(keyword:lower()) .. "%f[%W]"
        local searchFrom = 1

        while true do
            local startPos, endPos = string.find(padded, pattern, searchFrom)
            if not startPos then
                break
            end

            table.insert(hits, {
                position = startPos,
                finish = endPos,
                keyword = keyword
            })
            searchFrom = startPos + 1
        end
    end

    table.sort(hits, function(a, b)
        if a.position ~= b.position then
            return a.position < b.position
        end
        return a.finish > b.finish
    end)

    local results = {}
    local seen = {}
    local consumedUpTo = 0

    for _, hit in ipairs(hits) do
        if hit.position > consumedUpTo then
            -- Consume the full match even when this keyword was already reported.
            -- Otherwise a repeated "thunder bluff" can leak its shorter
            -- overlapping "thunder" alias into the results.
            consumedUpTo = hit.finish

            local normalizedKeyword = hit.keyword:lower()
            if not seen[normalizedKeyword] then
                seen[normalizedKeyword] = true
                table.insert(results, {
                    position = hit.position,
                    keyword = hit.keyword
                })
            end
        end
    end

    return results
end

local DESTINATION_MARKERS = {
    ["to"] = true,
    ["2"] = true,
    ["too"] = true
}

local ORIGIN_MARKERS = {
    ["from"] = true,
    ["in"] = true,
    ["at"] = true,
    ["im"] = true,
    ["i'm"] = true
}

local function classifyPrecedingText(text)
    if not text then
        return 0
    end

    -- Arrows are often written without spaces, as in "sw->if".
    if text:match("%-%>%s*$") or text:match("=%>%s*$") or text:match(">>%s*$") or
        text:match(">%s*$") then
        return 1
    end

    local word = text:match("([%w']+)[%p%s]*$")
    if DESTINATION_MARKERS[word] then
        return 1
    elseif ORIGIN_MARKERS[word] then
        return -1
    end

    return 0
end

-- Choose the city the customer wants to reach rather than whichever city is
-- listed first in the settings. The third return value identifies messages
-- that only state an origin, so a follow-up like "I'm in SW" cannot retarget
-- an existing ticket.
function Utils.findRequestedDestination(message, keywordList)
    if not message or not keywordList then
        return nil, nil, false
    end

    local candidates = Utils.findAllKeywordPositions(message, keywordList)
    if #candidates == 0 then
        return nil, nil, false
    end

    local padded = " " .. message:lower() .. " "
    local best = nil
    local bestScore = -2

    for _, candidate in ipairs(candidates) do
        local score = classifyPrecedingText(padded:sub(1, candidate.position - 1))

        if score > bestScore or (score == bestScore and score > 0) then
            bestScore = score
            best = candidate
        end
    end

    return best.position, best.keyword, bestScore < 0
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

function Utils.getMatchingPortal(destination)
    local portal = {
        matched = false,
        spellID = 10059,
        spellName = "Portal: Stormwind",
        locationName = "Stormwind"
    }

    if not destination then
        return portal
    end

    -- Use the destination value to initially find the absolute spell match (Portal: Stormwind or Portal: Ironforge or ...)
    -- If no match is found, return nil

    -- Destination could be "if, "ironforge", "sw", "stormwind", "darn", "darna", "darnas", "darnasuss", ... - we need to take account for typos, abbreviations, etc.
    -- The best bet is to check every letter of the destination word and check if it matches in the destination part of the Portal: MATCH spell name
    -- The official spell destination name with the most matches is the correct one
    -- If there are multiple matching names, we can use the one with the most matches

    -- Example: destination = "darn" produces "Portal: Darnassus" as the best match

    -- Config.Portals = {
    --     "Portal: Darnassus",
    --     "Portal: Stormwind",
    --     "Portal: Ironforge",
    --     "Portal: Orgrimmar",
    --     "Portal: Thunder Bluff",
    --     "Portal: Undercity",
    -- }

    local destinationLength = string.len(destination)
    local bestMatch = nil
    local maxMatches = 0
    for _, portalName in ipairs(Config.Portals) do
        local spellName = portalName:match("Portal: (.+)")
        local spellDestination = spellName:lower()

        local matches = 0
        for i = 1, destinationLength do
            local letter = destination:sub(i, i)
            if spellDestination:find(letter) then
                matches = matches + 1
            end
        end

        if matches > maxMatches then
            maxMatches = matches
            bestMatch = portalName
        end
    end

    if bestMatch then
        Utils.debugPrint("Best match for destination: " .. bestMatch)

        local spellID = nil

        if bestMatch == "Portal: Darnassus" then
            spellID = 11419
        elseif bestMatch == "Portal: Stormwind" then
            spellID = 10059
        elseif bestMatch == "Portal: Ironforge" then
            spellID = 11416
        elseif bestMatch == "Portal: Orgrimmar" then
            spellID = 11417
        elseif bestMatch == "Portal: Thunder Bluff" then
            spellID = 11420
        elseif bestMatch == "Portal: Undercity" then
            spellID = 11418
        elseif bestMatch == "Portal: Exodar" then
            spellID = 32266
        elseif bestMatch == "Portal: Theramore" then
            spellID = 49360
        elseif bestMatch == "Portal: Silvermoon" then
            spellID = 32267
        elseif bestMatch == "Portal: Stonard" then
            spellID = 49361
        elseif bestMatch == "Portal: Shattrath" then
            -- Both Alliance and Horde can portal to Shattrath, but they have different spell IDs, so we need to check the player's faction first
            local englishFaction, _ = UnitFactionGroup("player")
            if englishFaction == "Alliance" then
                spellID = 33691
            elseif englishFaction == "Horde" then
                spellID = 35717
            end
        end

        portal = {
            matched = true,
            spellID = spellID,
            spellName = bestMatch,
            locationName = bestMatch:match("Portal: (.+)")
        }
    end

    return portal
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
