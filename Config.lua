-- Config.lua
local Config = {}

-- Make Config available globally before any early returns
_G.Config = Config

-- Define DEFAULT settings that will never be overwritten by saved variables
-- This table is used to initialize any missing fields in saved settings
local DEFAULT_SETTINGS = {
    totalGold = 0,
    dailyGold = 0,
    totalTradesCompleted = 0,
    lastUpdateDate = nil,

    BanList = {},
    KeywordBanList = {},

    IntentKeywords = {"wtb", "wtf", "want to buy", "looking for", "need", "seeking", "buying", "purchasing", "lf",
                      "can anyone make", "can you make", "can anyone do", "can you do"},
    DestinationKeywords = { -- Alliance Cities
    "darn", "darnassuss", "darnas", "darrna", "darnaas", "darnassus", "darnasuss", "darna", "darnasus", "sw",
    "stormwind", "storm wind", "if", "ironforge", "iron forge", "exodar", "exo", "theramore", "thera", "tmore",
    -- Horde Cities
    "org", "orgrimmar", "orgri", "orgim", "tb", "thunder bluff", "thunderbluff", "thunder", "uc", "undercity",
    "under city", "silvermoon", "silver moon", "sm", "silv", "stonard", "ston", -- Neutral TBC
    "shattrath", "shatt", "shat", "shath"},
    ServiceKeywords = {"portal", "port", "prt", "portla", "pportal", "protal", "pport", "teleport", "tp", "tele"},
    FoodKeywords = {"food"},
    WaterKeywords = {"water"},

    inviteMessage = "[Thic-Portals] Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star.",
    inviteMessageWithoutDestination = "[Thic-Portals] Good day! Please specify a destination and I will create a portal for you.",
    tipMessage = "[Thic-Portals] Thank you for your tip, enjoy your journey - safe travels!",
    noTipMessage = "[Thic-Portals] Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!",

    commonPhrases = {"wtb mage port", "wtb mage portal", "wtb portal", "wtb port", -- Alliance destinations
    "wtb portal darnassus", "wtb portal darnasus", "wtb portal darna", "wtb portal darn", "wtb darnassus port",
                     "wtb darnasus port", "wtb darn port", "wtb darna port", "wtb portal stormwind", "wtb portal sw",
                     "wtb sw port", "wtb stormwind port", "wtb portal ironforge", "wtb portal if", "wtb if port",
                     "wtb ironforge port", "wtb portal exodar", "wtb exodar port", "wtb portal exo",
                     "wtb portal theramore", "wtb theramore port", -- Horde destinations
    "wtb portal orgrimmar", "wtb portal org", "wtb org port", "wtb orgrimmar port", "wtb portal thunder bluff",
                     "wtb portal tb", "wtb tb port", "wtb thunder bluff port", "wtb portal undercity", "wtb portal uc",
                     "wtb uc port", "wtb undercity port", "wtb portal silvermoon", "wtb portal sm",
                     "wtb silvermoon port", "wtb sm port", "wtb portal stonard", "wtb stonard port", -- TBC neutral
    "wtb portal shattrath", "wtb portal shatt", "wtb shattrath port", "wtb shatt port"},

    inviteCooldown = 300,
    distanceInferringClose = 50,
    distanceInferringTravelled = 1000,
    consecutiveLeavesWithoutPayment = 0,
    leaveWithoutPaymentThreshold = 2,
    maxSimultaneousTickets = 15,

    addonEnabled = false,
    disableGlobalChannels = false,
    soundEnabled = true,
    debugMode = false,
    approachMode = false,
    enableFoodWaterSupport = false,
    disableSmartMatching = false,
    requireDestination = false,
    removeRealmFromInviteCommand = false,
    optionsPanelHidden = true,
    hideIcon = false,
    disableAFKProtection = false,

    foodItems = {{
        name = "Conjured Sweet Roll",
        itemId = 8076,
        spellName = "Conjure Food",
        rank = 6,
        price = 2500
    }, {
        name = "Conjured Cinnamon Roll",
        itemId = 22895,
        spellName = "Conjure Food",
        rank = 7,
        price = 2500
    }, {
        name = "Conjured Croissant",
        itemId = 22019,
        spellName = "Conjure Food",
        rank = 8,
        price = 3000
    }, {
        name = "Conjured Mana Strudel",
        itemId = 34062,
        spellName = "Conjure Food",
        rank = 9,
        price = 3500
    }},
    waterItems = {{
        name = "Conjured Sparkling Water",
        itemId = 8078,
        spellName = "Conjure Water",
        rank = 6,
        price = 2500
    }, {
        name = "Conjured Crystal Water",
        itemId = 8079,
        spellName = "Conjure Water",
        rank = 7,
        price = 2500
    }, {
        name = "Conjured Mountain Spring Water",
        itemId = 22018,
        spellName = "Conjure Water",
        rank = 8,
        price = 3000
    }, {
        name = "Conjured Glacier Water",
        itemId = 34063,
        spellName = "Conjure Water",
        rank = 9,
        price = 3500
    }},

    -- Legacy price structure (kept for backward compatibility)
    prices = {
        food = {
            ["Conjured Sweet Roll"] = 2500,
            ["Conjured Cinnamon Roll"] = 2500,
            ["Conjured Croissant"] = 3000,
            ["Conjured Mana Strudel"] = 3500
        },
        water = {
            ["Conjured Sparkling Water"] = 2500,
            ["Conjured Crystal Water"] = 2500,
            ["Conjured Mountain Spring Water"] = 3000,
            ["Conjured Glacier Water"] = 3500
        }
    },

    toggleButtonPosition = {
        point = "CENTER",
        x = 0,
        y = 200
    }
}

-- Initialize ThicPortalSettings with defaults if it doesn't exist
-- This will be overwritten by saved variables when they load
if not ThicPortalSettings then
    ThicPortalSettings = DEFAULT_SETTINGS
end

-- Initialize Config.Settings immediately to ensure it's always available
Config.Settings = DEFAULT_SETTINGS

-- An object storing many of the addon's gold and trade settings (Version 1.2.2)
ThicPortalsSaved = false
-- Initialize saved variables (Version 1.2.2)
InviteMessage = false
InviteMessageWithoutDestination = false
TipMessage = false
NoTipMessage = false
-- List variables (Version 1.2.2)
BanList = false
ApproachMode = false
HideIcon = false
IntentKeywords = false
DestinationKeywords = false
ServiceKeywords = false
-- Temporary settings, not persisted via variables (Version 1.2.2)
addonEnabled = false
soundEnabled = true
debugMode = false

-- New Variables >1.2.2
Config.currentTraderName = nil
Config.currentTraderRealm = nil
Config.currentTraderMoney = nil
Config.Portals = { -- Alliance Portals
"Portal: Darnassus", "Portal: Stormwind", "Portal: Ironforge", "Portal: Exodar", -- TBC
"Portal: Theramore", -- Horde Portals
"Portal: Orgrimmar", "Portal: Thunder Bluff", "Portal: Undercity", "Portal: Silvermoon", -- TBC
"Portal: Stonard", -- Neutral TBC Portal
"Portal: Shattrath" -- TBC
}
-- List of currently alive portals
Config.CurrentAlivePortals = {}

-- Check if AceGUI is available
local AceGUI = LibStub("AceGUI-3.0")

if not AceGUI then
    print("Error: AceGUI-3.0 is not loaded properly.")
    return Config
end

-- Initialize saved variables
function Config.initializeSavedVariables()
    -- Merge saved settings with defaults
    -- If ThicPortalSettings is loaded from saved vars, merge it with defaults
    -- Otherwise use defaults
    if type(ThicPortalSettings) == "table" then
        -- Merge saved settings into Config.Settings
        Config.Settings = ThicPortalSettings
    else
        -- No saved settings, use defaults
        Config.Settings = DEFAULT_SETTINGS
        ThicPortalSettings = DEFAULT_SETTINGS
    end

    if type(ThicPortalsSaved) ~= "table" then
        print("ThicPortalsSaved is not a table. Initializing.")

        ThicPortalsSaved = {}
    else
        for key, value in pairs(ThicPortalsSaved) do
            print(key, value)
        end
    end

    -- Migrate old saved variables into the new structure if they exist
    if Config.Settings.totalGold == 0 then
        Config.Settings.totalGold = ThicPortalsSaved and ThicPortalsSaved.totalGold or 0
    end
    if Config.Settings.dailyGold == 0 then
        Config.Settings.dailyGold = ThicPortalsSaved and ThicPortalsSaved.dailyGold or 0
    end
    if Config.Settings.totalTradesCompleted == 0 then
        Config.Settings.totalTradesCompleted = ThicPortalsSaved and ThicPortalsSaved.totalTradesCompleted or 0
    end
    --
    if Config.Settings.lastUpdateDate == nil then
        Config.Settings.lastUpdateDate = ThicPortalsSaved and ThicPortalsSaved.lastUpdateDate or date("%Y-%m-%d")
    end
    --
    Config.Settings.BanList = BanList or Config.Settings.BanList
    Config.Settings.IntentKeywords = IntentKeywords or Config.Settings.IntentKeywords
    Config.Settings.DestinationKeywords = DestinationKeywords or Config.Settings.DestinationKeywords
    Config.Settings.ServiceKeywords = ServiceKeywords or Config.Settings.ServiceKeywords
    --
    Config.Settings.inviteMessage = InviteMessage or Config.Settings.inviteMessage
    Config.Settings.inviteMessageWithoutDestination = InviteMessageWithoutDestination or
                                                          Config.Settings.inviteMessageWithoutDestination
    Config.Settings.tipMessage = TipMessage or Config.Settings.tipMessage
    Config.Settings.noTipMessage = NoTipMessage or Config.Settings.noTipMessage
    --
    Config.Settings.hideIcon = HideIcon or Config.Settings.hideIcon
    Config.Settings.ApproachMode = ApproachMode or Config.Settings.ApproachMode

    if not Config.Settings.toggleButtonPosition then
        Config.Settings.toggleButtonPosition = DEFAULT_SETTINGS.toggleButtonPosition
    end
    if not Config.Settings.enableFoodWaterSupport then
        Config.Settings.enableFoodWaterSupport = DEFAULT_SETTINGS.enableFoodWaterSupport
    end
    if not Config.Settings.disableSmartMatching then
        Config.Settings.disableSmartMatching = DEFAULT_SETTINGS.disableSmartMatching
    end
    if not Config.Settings.requireDestination then
        Config.Settings.requireDestination = ThicPortalSettings.requireDestination
    end
    if not Config.Settings.removeRealmFromInviteCommand then
        Config.Settings.removeRealmFromInviteCommand = DEFAULT_SETTINGS.removeRealmFromInviteCommand
    end
    if not Config.Settings.disableGlobalChannels then
        Config.Settings.disableGlobalChannels = DEFAULT_SETTINGS.disableGlobalChannels
    end
    if not Config.Settings.disableAFKProtection then
        Config.Settings.disableAFKProtection = DEFAULT_SETTINGS.disableAFKProtection
    end
    if not Config.Settings.FoodKeywords then
        Config.Settings.FoodKeywords = DEFAULT_SETTINGS.FoodKeywords
    end
    if not Config.Settings.WaterKeywords then
        Config.Settings.WaterKeywords = DEFAULT_SETTINGS.WaterKeywords
    end

    -- Override addonEnabled to false on startup
    Config.Settings.addonEnabled = false
    -- Override consecutiveLeavesWithoutPayment to 0 on startup
    Config.Settings.consecutiveLeavesWithoutPayment = 0
    -- Override optionsPanelHidden to true on startup
    Config.Settings.optionsPanelHidden = true

    -- Added in 2.0.3
    if not Config.Settings.KeywordBanList then
        Config.Settings.KeywordBanList = DEFAULT_SETTINGS.KeywordBanList or {}
    end
    if not Config.Settings.prices then
        Config.Settings.prices = DEFAULT_SETTINGS.prices or {
            food = {
                ["Conjured Muffin"] = 500,
                ["Conjured Bread"] = 750,
                ["Conjured Rye"] = 1000,
                ["Conjured Pumpernickel"] = 1500,
                ["Conjured Sourdough"] = 2000,
                ["Conjured Sweet Roll"] = 2500,
                ["Conjured Cinnamon Roll"] = 2500,
                ["Conjured Croissant"] = 3000,
                ["Conjured Mana Strudel"] = 3500
            },
            water = {
                ["Conjured Water"] = 500,
                ["Conjured Fresh Water"] = 750,
                ["Conjured Purified Water"] = 1000,
                ["Conjured Spring Water"] = 1500,
                ["Conjured Mineral Water"] = 2000,
                ["Conjured Sparkling Water"] = 2500,
                ["Conjured Crystal Water"] = 2500,
                ["Conjured Mountain Spring Water"] = 3000,
                ["Conjured Glacier Water"] = 3500
            }
        }
    end

    -- Initialize foodItems and waterItems structures (smart detection support)
    -- Always use defaults to ensure we have the latest structure with spellName+rank
    Config.Settings.foodItems = DEFAULT_SETTINGS.foodItems
    Config.Settings.waterItems = DEFAULT_SETTINGS.waterItems

    if not Config.Settings.maxSimultaneousTickets then
        Config.Settings.maxSimultaneousTickets = DEFAULT_SETTINGS.maxSimultaneousTickets or 15
    end

    -- Remove old global variables if needed (Version 1.2.2)
    ThicPortalsSaved = nil
    BanList = nil
    IntentKeywords = nil
    DestinationKeywords = nil
    ServiceKeywords = nil
    InviteMessage = nil
    InviteMessageWithoutDestination = nil
    TipMessage = nil
    NoTipMessage = nil
    hideIcon = nil
    ApproachMode = nil
end

return Config
