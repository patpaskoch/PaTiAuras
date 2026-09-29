-- PaTiAuras: aura reading (WoW API adapter) and the fake auras of test mode.
-- Output is always plain tables in the shape Auras.Matches expects; unreadable data is flagged, never guessed.
local _, ns = ...
local AuraScan = {}
ns.AuraScan = AuraScan

-- Restricted ("secret") values must not be compared or calculated with; treat them as unreadable.
local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function plain(value)
    if isSecret(value) then return nil end
    return value
end

local function auraAt(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not data then return nil end
        return data.name, data.icon, data.applications, data.dispelName, data.expirationTime, data.sourceUnit, data.spellId
    end
    if UnitAura then
        local name, icon, count, dispelType, _, expiration, source, _, _, spellId = UnitAura(unit, index, filter)
        return name, icon, count, dispelType, expiration, source, spellId
    end
    return nil
end

local function readAuras(unit, filter)
    local auras = {}
    for index = 1, 40 do
        local name, icon, count, dispelType, expiration, source, spellId = auraAt(unit, index, filter)
        if not isSecret(name) and name == nil then break end -- check secrecy before any comparison
        local fromPlayer
        if not isSecret(source) then fromPlayer = source == "player" end
        auras[#auras + 1] = {
            name = plain(name), spellId = plain(spellId), icon = plain(icon), count = plain(count),
            dispelType = plain(dispelType), expiration = plain(expiration), timerSecret = isSecret(expiration),
            fromPlayer = fromPlayer, secret = isSecret(name) or isSecret(spellId),
        }
    end
    return auras
end

-- One placeholder for "these auras could not be read": Auras.Evaluate turns it into UNKNOWN, never MISSING.
AuraScan.UNREADABLE = { secret = true }

-- filter: e.g. "HELPFUL". Never errors. If reading fails part-way (e.g. a restricted value raised an error),
-- the result is { UNREADABLE } — an empty list would wrongly claim that every watched aura is missing.
function AuraScan.Read(unit, filter)
    local ok, auras = pcall(readAuras, unit, filter)
    if ok then return auras end
    AuraScan.lastError = tostring(auras)
    return { AuraScan.UNREADABLE }
end

function AuraScan.ApiName()
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then return "C_UnitAuras" end
    return UnitAura and "UnitAura" or "none"
end

-- Test mode ------------------------------------------------------------------------------------

AuraScan.TEST_PROFILE = {
    name = "Test",
    personal = { { key = "WATER_SHIELD", spellID = 24398, expiring = true, showCount = true, clickable = true } },
    procs = { { key = "TIDAL_WAVES", spellID = 53390, showCount = true } },
    healing = { { key = "EARTH_SHIELD", spellID = 974, showCount = true }, { key = "RIPTIDE", spellID = 61295 } },
    group = { { key = "FORTITUDE", spellID = 1243, nameKey = "TEST_GROUP_BUFF", expiring = true } },
    weapon = { { key = "MAIN_HAND_IMBUE", slot = "MAINHAND", nameKey = "MAIN_HAND", expiring = true },
        { key = "OFF_HAND_IMBUE", slot = "OFFHAND", nameKey = "OFF_HAND", expiring = true } },
}

-- Per unit: entry key -> { count?, remaining? }. Water Shield on the player and Fortitude on party2 are missing
-- on purpose; party4 is offline in the test party data.
-- Covers the Shaman, Priest and generic test profiles (keys of the other profiles are simply unused).
-- Priest: Inner Fire expiring, Fortitude missing on party2, Divine Spirit missing on party3, Shadow Protection
-- only on you; party4 is offline and never counts as missing.
local TEST_AURAS = {
    player = { TIDAL_WAVES = { count = 2 }, FORTITUDE = { remaining = 1500 }, INNER_FIRE = { count = 18, remaining = 25 },
        DIVINE_SPIRIT = { remaining = 1500 }, SHADOW_PROTECTION = { remaining = 500 } },
    party1 = { EARTH_SHIELD = { count = 5 }, RIPTIDE = { remaining = 7 }, FORTITUDE = { remaining = 1500 },
        DIVINE_SPIRIT = { remaining = 1500 }, RENEW = { remaining = 11 }, POWER_WORD_SHIELD = { remaining = 22 },
        PRAYER_OF_MENDING = { count = 4 } },
    party2 = { DIVINE_SPIRIT = { remaining = 900 } },
    party3 = { FORTITUDE = { remaining = 20 } },
}
-- Fake party: names are L keys; party4 is offline so the "offline before missing" rule is visible.
AuraScan.TEST_UNITS = {
    player = { nameKey = "TEST_YOU" }, party1 = { nameKey = "TEST_TANK" }, party2 = { nameKey = "TEST_MAGE" },
    party3 = { nameKey = "TEST_PRIEST" }, party4 = { nameKey = "TEST_HUNTER", state = "OFFLINE" },
}

-- Fake helpful auras for `unit`, built for the given entries.
function AuraScan.TestAuras(unit, entryLists, now)
    local helpful = {}
    for _, list in pairs(entryLists) do
        for _, entry in ipairs(list) do
            local fake = (TEST_AURAS[unit] or {})[entry.key]
            if fake then
                helpful[#helpful + 1] = { name = entry.name, spellId = entry.spellID, icon = entry.icon, count = fake.count,
                    expiration = fake.remaining and now + fake.remaining, fromPlayer = true }
            end
        end
    end
    return helpful
end
