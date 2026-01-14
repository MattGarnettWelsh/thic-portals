-- Config.lua
local Config = {}

-- Make Config available globally before any early returns
_G.Config = Config

local AceGUI = LibStub("AceGUI-3.0") -- Use LibStub to load AceGUI

if not AceGUI then
    print("Error: AceGUI-3.0 is not loaded properly.")
    return Config
end

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
Config.Portals = {"Portal: Darnassus", "Portal: Stormwind", "Portal: Ironforge", "Portal: Orgrimmar",
                  "Portal: Thunder Bluff", "Portal: Undercity"}
-- List of currently alive portals
Config.CurrentAlivePortals = {}
-- Define default settings - these will be used if the saved variables are not found
ThicPortalSettings = {
    totalGold = 0,
    dailyGold = 0,
    totalTradesCompleted = 0,
    lastUpdateDate = nil,

    BanList = {},
    KeywordBanList = {},

    IntentKeywords = {"wtb", "wtf", "want to buy", "looking for", "need", "seeking", "buying", "purchasing", "lf",
                      "can anyone make", "can you make", "can anyone do", "can you do"},
    DestinationKeywords = {"darn", "darnassuss", "darnas", "darrna", "darnaas", "darnassus", "darnasuss", "dalaran",
                           "darna", "darnasus", "sw", "stormwind", "if", "ironforge"},
    ServiceKeywords = {"portal", "port", "prt", "portla", "pportal", "protal", "pport", "teleport", "tp", "tele"},
    FoodKeywords = {"food"},
    WaterKeywords = {"water"},

    inviteMessage = "[Thic-Portals] Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star.",
    inviteMessageWithoutDestination = "[Thic-Portals] Good day! Please specify a destination and I will create a portal for you.",
    tipMessage = "[Thic-Portals] Thank you for your tip, enjoy your journey - safe travels!",
    noTipMessage = "[Thic-Portals] Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!",

    commonPhrases = {"wtb mage port", "wtb mage portal", "wtb portal darnassus", "wtb portal darnasus",
                     "wtb portal darna", "wtb portal darn", "wtb darnassus port", "wtb darnasus port", "wtb darn port",
                     "wtb darna port", "wtb portal", "wtb port"},

    inviteCooldown = 300,
    distanceInferringClose = 50,
    distanceInferringTravelled = 1000,
    consecutiveLeavesWithoutPayment = 0,
    leaveWithoutPaymentThreshold = 2,

    addonEnabled = false,
    disableGlobalChannels = false,
    soundEnabled = true,
    debugMode = false,
    approachMode = false,
    enableFoodWaterSupport = false,
    disableSmartMatching = false,
    removeRealmFromInviteCommand = false,
    optionsPanelHidden = true,
    hideIcon = false,
    disableAFKProtection = false,

    prices = {
        food = {
            ["Conjured Cinnamon Roll"] = 2500,
            ["Conjured Sweet Roll"] = 2500
        },
        water = {
            ["Conjured Crystal Water"] = 2500,
            ["Conjured Sparkling Water"] = 2500
        }
    },

    toggleButtonPosition = {
        point = "CENTER",
        x = 0,
        y = 200
    }
}

-- Initialize saved variables
function Config.initializeSavedVariables()
    -- Define default settings
    Config.Settings = ThicPortalSettings

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
        Config.Settings.toggleButtonPosition = ThicPortalSettings.ToggleButtonPosition
    end
    if not Config.Settings.enableFoodWaterSupport then
        Config.Settings.enableFoodWaterSupport = ThicPortalSettings.enableFoodWaterSupport
    end
    if not Config.Settings.disableSmartMatching then
        Config.Settings.disableSmartMatching = ThicPortalSettings.disableSmartMatching
    end
    if not Config.Settings.removeRealmFromInviteCommand then
        Config.Settings.removeRealmFromInviteCommand = ThicPortalSettings.removeRealmFromInviteCommand
    end
    if not Config.Settings.disableGlobalChannels then
        Config.Settings.disableGlobalChannels = ThicPortalSettings.disableGlobalChannels
    end
    if not Config.Settings.disableAFKProtection then
        Config.Settings.disableAFKProtection = ThicPortalSettings.disableAFKProtection
    end
    if not Config.Settings.FoodKeywords then
        Config.Settings.FoodKeywords = ThicPortalSettings.FoodKeywords
    end
    if not Config.Settings.WaterKeywords then
        Config.Settings.WaterKeywords = ThicPortalSettings.WaterKeywords
    end

    -- Override addonEnabled to false on startup
    Config.Settings.addonEnabled = false
    -- Override consecutiveLeavesWithoutPayment to 0 on startup
    Config.Settings.consecutiveLeavesWithoutPayment = 0
    -- Override optionsPanelHidden to true on startup
    Config.Settings.optionsPanelHidden = true

    -- Added in 2.0.3
    if not Config.Settings.KeywordBanList then
        Config.Settings.KeywordBanList = ThicPortalSettings.KeywordBanList or {}
    end
    if not Config.Settings.prices then
        Config.Settings.prices = ThicPortalSettings.prices or {
            food = {
                ["Conjured Cinnamon Roll"] = 2500, -- 25 silver
                ["Conjured Sweet Roll"] = 2500 -- 25 silver
            },
            water = {
                ["Conjured Crystal Water"] = 2500, -- 25 silver
                ["Conjured Sparkling Water"] = 2500 -- 25 silver
            }
        }
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
