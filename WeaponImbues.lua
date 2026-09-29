-- PaTiAuras: temporary weapon enchants (Shaman weapon imbues). They are no UNIT_AURA auras, so they have their own
-- adapter; Watch turns them into the same ACTIVE / MISSING / EXPIRING / UNKNOWN results as every other entry.
-- V1 watches "is there an imbue on this weapon" per slot, not which one: how the Forever client identifies an imbue
-- (enchant ID, name) is not confirmed yet (docs/WOW_API_COMPAT.md). Display only — PaTiAuras never casts an imbue.
local _, ns = ...
local Auras = ns.Auras

local WeaponImbues = {}
ns.WeaponImbues = WeaponImbues

WeaponImbues.SLOTS = { MAINHAND = 16, OFFHAND = 17 } -- inventory slot IDs
local WEAPON_CLASS = 2 -- item class "Weapon": shields and held-in-off-hand items cannot be imbued

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function pack(...) return { n = select("#", ...), ... } end

-- The enchant API this client offers (modern namespace first), or nil.
function WeaponImbues.Api()
    if C_Item and C_Item.GetWeaponEnchantInfo then return C_Item.GetWeaponEnchantInfo, "C_Item.GetWeaponEnchantInfo" end
    if GetWeaponEnchantInfo then return GetWeaponEnchantInfo, "GetWeaponEnchantInfo" end
    return nil, "none"
end

-- true = a weapon that can carry an imbue, false = empty slot or no weapon (shield), nil = cannot tell.
local function weaponIn(slotID)
    if not GetInventoryItemID then return nil end
    local ok, itemID = pcall(GetInventoryItemID, "player", slotID)
    if not ok or isSecret(itemID) then return nil end
    if itemID == nil then return false end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not info then return nil end
    local okInfo, _, _, _, _, _, classID = pcall(info, itemID)
    if not okInfo or isSecret(classID) or type(classID) ~= "number" then return nil end
    return classID == WEAPON_CLASS
end

local function iconOf(slotID)
    if not GetInventoryItemTexture then return nil end
    local ok, texture = pcall(GetInventoryItemTexture, "player", slotID)
    if not ok or isSecret(texture) then return nil end
    return texture
end

-- One slot's values from GetWeaponEnchantInfo: has (true/1), expiration (ms left), charges, enchant ID.
-- Secret or odd values are dropped; a secret "has" makes the slot unreadable.
local function slotRaw(has, expiration, charges, enchantID, now)
    if isSecret(has) then return { readable = false } end
    local raw = { readable = true, has = has == true or has == 1 }
    if raw.has then
        if not isSecret(expiration) and type(expiration) == "number" and expiration > 0 then
            raw.expiresAt = now + expiration / 1000
        end
        if not isSecret(charges) and type(charges) == "number" then raw.charges = charges end
        if not isSecret(enchantID) and type(enchantID) == "number" then raw.enchantID = enchantID end
    end
    return raw
end

-- { MAINHAND = raw, OFFHAND = raw }, raw = { readable, has, expiresAt?, charges?, enchantID?, weapon, icon }.
-- A missing API, an error or an empty answer is unreadable (→ UNKNOWN), never "no imbue".
function WeaponImbues.Read(now)
    local api = WeaponImbues.Api()
    local result
    local values = api and pack(pcall(api))
    if values and values[1] == true and values.n > 1 then
        result = {
            MAINHAND = slotRaw(values[2], values[3], values[4], values[5], now),
            OFFHAND = slotRaw(values[6], values[7], values[8], values[9], now),
        }
    else
        result = { MAINHAND = { readable = false }, OFFHAND = { readable = false } }
    end
    for slot, slotID in pairs(WeaponImbues.SLOTS) do
        result[slot].weapon = weaponIn(slotID)
        result[slot].icon = iconOf(slotID)
    end
    return result
end

-- Pure: the watch result of one slot, or nil when there is nothing to watch (no weapon that can be imbued).
-- settings: PaTiAurasDB (showExpiring). Same threshold as all other buffs (Auras.EXPIRING_SECONDS).
function WeaponImbues.Evaluate(raw, now, settings)
    if not raw or raw.weapon == false then return nil end
    if not raw.readable then return { state = "UNKNOWN", icon = raw.icon } end
    if raw.has then
        local remaining = raw.expiresAt and math.max(0, raw.expiresAt - now)
        local state = "ACTIVE"
        if remaining and settings.showExpiring and remaining < Auras.EXPIRING_SECONDS then state = "EXPIRING" end
        return { state = state, remaining = remaining, count = raw.charges, icon = raw.icon }
    end
    -- No imbue, but is it a weapon at all? Unknown (e.g. item class unreadable) must not claim "missing".
    if raw.weapon == nil then return { state = "UNKNOWN", icon = raw.icon } end
    return { state = "MISSING", icon = raw.icon }
end

-- Pure: a short plain-value fingerprint, so the slow fallback check repaints only when something changed
-- (whole seconds: a renewed imbue changes it, read jitter does not).
function WeaponImbues.Signature(weapons)
    local parts = {}
    for _, slot in ipairs({ "MAINHAND", "OFFHAND" }) do
        local raw = weapons and weapons[slot] or {}
        parts[#parts + 1] = table.concat({ tostring(raw.readable), tostring(raw.has), tostring(raw.weapon),
            tostring(raw.enchantID), tostring(raw.expiresAt and math.floor(raw.expiresAt)) }, ":")
    end
    return table.concat(parts, "|")
end

-- Test mode: main hand imbued (18:42 left), off hand weapon without imbue.
function WeaponImbues.TestRead(now)
    return {
        MAINHAND = { readable = true, has = true, expiresAt = now + 1122, weapon = true },
        OFFHAND = { readable = true, has = false, weapon = true },
    }
end
