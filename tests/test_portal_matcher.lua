local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[/\\])") or "./"
local addonDirectory = scriptDirectory .. ".."

local expectedCity = {
    darn = "Darnassus", darnassuss = "Darnassus", darnas = "Darnassus",
    darrna = "Darnassus", darnaas = "Darnassus", darnassus = "Darnassus",
    darnasuss = "Darnassus", darna = "Darnassus", darnasus = "Darnassus",
    sw = "Stormwind", stormwind = "Stormwind", ["storm wind"] = "Stormwind",
    ["if"] = "Ironforge", ironforge = "Ironforge", ["iron forge"] = "Ironforge",
    exodar = "Exodar", exo = "Exodar", theramore = "Theramore", thera = "Theramore",
    tmore = "Theramore", org = "Orgrimmar", orgrimmar = "Orgrimmar",
    orgri = "Orgrimmar", orgim = "Orgrimmar", tb = "Thunder Bluff",
    ["thunder bluff"] = "Thunder Bluff", thunderbluff = "Thunder Bluff",
    thunder = "Thunder Bluff", uc = "Undercity", undercity = "Undercity",
    ["under city"] = "Undercity", silvermoon = "Silvermoon",
    ["silver moon"] = "Silvermoon", sm = "Silvermoon", silv = "Silvermoon",
    stonard = "Stonard", ston = "Stonard", shattrath = "Shattrath",
    shatt = "Shattrath", shat = "Shattrath", shath = "Shattrath"
}

_G.Config = {
    Settings = {debugMode = false},
    Portals = {
        "Portal: Darnassus", "Portal: Stormwind", "Portal: Ironforge",
        "Portal: Exodar", "Portal: Theramore", "Portal: Orgrimmar",
        "Portal: Thunder Bluff", "Portal: Undercity", "Portal: Silvermoon",
        "Portal: Stonard", "Portal: Shattrath"
    }
}

_G.UnitFactionGroup = function()
    return "Alliance"
end

local Utils = dofile(addonDirectory .. "/Utils.lua")
local count = 0

for keyword, expected in pairs(expectedCity) do
    count = count + 1
    local portal = Utils.getMatchingPortal(keyword)
    assert(portal.matched, keyword .. " should resolve to a portal")
    assert(portal.locationName == expected,
        string.format("%q: expected %s, got %s", keyword, expected, tostring(portal.locationName)))
    assert(portal.spellID ~= nil, keyword .. " should have a spell ID")
end

assert(count == 41, "expected all 41 shipped aliases")
assert(Utils.getMatchingPortal("org").locationName == "Orgrimmar", "org must not resolve to Ironforge")
assert(Utils.getMatchingPortal("orgri").locationName == "Orgrimmar", "orgri must not resolve to Ironforge")
assert(Utils.getMatchingPortal("sm").locationName == "Silvermoon", "sm must not resolve to Stormwind")
assert(Utils.getMatchingPortal("ston").locationName == "Stonard", "ston must not resolve to Stormwind")

assert(Utils.getMatchingPortal("shatt").spellID == 33691, "Alliance Shattrath spell ID")
_G.UnitFactionGroup = function()
    return "Horde"
end
assert(Utils.getMatchingPortal("shatt").spellID == 35717, "Horde Shattrath spell ID")

local custom = Utils.getMatchingPortal("stormwynd")
assert(custom.matched and custom.locationName == "Stormwind",
    "custom keywords should retain the heuristic fallback")

print(string.format("portal matcher: %d aliases, four regressions, faction split and custom fallback passed", count))
