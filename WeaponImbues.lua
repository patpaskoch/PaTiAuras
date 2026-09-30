-- PaTiAuras: temporary weapon enchants (Shaman weapon imbues). They are no UNIT_AURA auras, so they have their own
-- adapter; Watch turns them into the same ACTIVE / MISSING / EXPIRING / UNKNOWN results as every other entry.
-- V1 watches "is there an imbue on this weapon" per slot, not which one: how the Forever client identifies an imbue
-- (enchant ID, name) is not confirmed yet (docs/WOW_API_COMPAT.md). Display only — PaTiAuras never casts an imbue.
--
-- Two enchant APIs, each with its own parser, one priority chain (owner test 2026-09-30: calling
-- C_Item.GetWeaponEnchantInfo() without a slot and reading it like the old tuple gave UNKNOWN with and without Rockbiter):
--   1. GetWeaponEnchantInfo()            classic tuple for both hands in one call (ParseLegacy)
--   2. C_Item.GetWeaponEnchantInfo(slot) per weapon slot, only if 1 is missing or answers nothing (ParseModern);
--      its slot values and fields are unconfirmed in this client, so it is used only with Enum.WeaponSlot.
local _, ns = ...
local Auras = ns.Auras

local WeaponImbues = {}
ns.WeaponImbues = WeaponImbues

WeaponImbues.SLOTS = { MAINHAND = 16, OFFHAND = 17 } -- inventory slot IDs
local WEAPON_CLASS = 2 -- item class "Weapon": shields and held-in-off-hand items cannot be imbued

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function pack(...) return { n = select("#", ...), ... } end
local function plainNumber(value)
    if isSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- true = a weapon that can carry an imbue, false = empty slot or no weapon (shield), nil = cannot tell.
-- The main-hand slot only ever holds weapons, so an item there is enough; the off hand needs the item class.
local function weaponIn(slot, slotID)
    if not GetInventoryItemID then return nil end
    local ok, itemID = pcall(GetInventoryItemID, "player", slotID)
    if not ok or isSecret(itemID) then return nil end
    if itemID == nil then return false end
    if slot == "MAINHAND" then return true end
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

-- One slot from the classic tuple: has (true/1), ms left, charges, enchant ID. A secret "has" is unreadable.
local function legacySlot(has, expiration, charges, enchantID, now)
    if isSecret(has) then return { readable = false } end
    local raw = { readable = true, has = has == true or has == 1 }
    if raw.has then
        local left = plainNumber(expiration)
        if left and left > 0 then raw.expiresAt = now + left / 1000 end
        raw.charges, raw.enchantID = plainNumber(charges), plainNumber(enchantID)
    end
    return raw
end

-- Pure: GetWeaponEnchantInfo() return values (without pcall's ok) → { MAINHAND, OFFHAND }, or nil if it said nothing.
function WeaponImbues.ParseLegacy(values, now)
    if type(values) ~= "table" or (values.n or #values) == 0 then return nil end
    return {
        MAINHAND = legacySlot(values[1], values[2], values[3], values[4], now),
        OFFHAND = legacySlot(values[5], values[6], values[7], values[8], now),
    }
end

-- Is this modern enchant entry a temporary one (an imbue), not a permanent enchant? By its type when readable
-- (Enum.ItemEnchantType.Temporary/Imbue if the client has it, or a type name), else by "has time left".
local function isTemporary(info)
    local kind = info.enchantType
    if not isSecret(kind) and kind ~= nil then
        local enum = Enum and Enum.ItemEnchantType
        if type(kind) == "number" and enum then return kind == enum.Temporary or kind == enum.Imbue end
        if type(kind) == "string" then
            local upper = kind:upper()
            return upper:find("TEMP", 1, true) ~= nil or upper:find("IMBUE", 1, true) ~= nil
        end
    end
    local left = plainNumber(info.timeLeft)
    return left ~= nil and left > 0
end

-- Pure: one C_Item.GetWeaponEnchantInfo(slot) result → raw slot. Accepts one entry table or a list of entries;
-- picks the temporary (imbue) entry, never a permanent enchant. timeLeft is taken as milliseconds like the classic
-- API (ASSUMPTION — /pa auras prints the raw values). A nil answer = no imbue on that slot.
function WeaponImbues.ParseModern(result, now)
    if result == nil then return { readable = true, has = false } end
    if isSecret(result) or type(result) ~= "table" then return { readable = false } end
    local entries = result[1] ~= nil and result or { result }
    for _, info in ipairs(entries) do
        if type(info) == "table" then
            if isSecret(info.hasEnchant) then return { readable = false } end
            if info.hasEnchant ~= false and isTemporary(info) then
                local raw = { readable = true, has = true, charges = plainNumber(info.charges),
                    enchantID = plainNumber(info.enchantID) }
                local left = plainNumber(info.timeLeft)
                if left and left > 0 then raw.expiresAt = now + left / 1000 end
                return raw
            end
        end
    end
    return { readable = true, has = false }
end

-- Weapon slot index for the modern API, only if the client names it (Enum.WeaponSlot); no guessed numbers.
local function modernSlot(slot)
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return nil end
    local slots = Enum and Enum.WeaponSlot
    if not slots then return nil end
    if slot == "MAINHAND" then return slots.MainHand or slots.Mainhand end
    return slots.OffHand or slots.Offhand
end

local function readLegacy(now)
    if not GetWeaponEnchantInfo then return nil end
    local values = pack(pcall(GetWeaponEnchantInfo))
    if values[1] ~= true then return nil end
    return WeaponImbues.ParseLegacy({ n = values.n - 1, unpack(values, 2, values.n) }, now)
end

local function readModern(now)
    if modernSlot("MAINHAND") == nil then return nil end
    local result = {}
    for _, slot in ipairs({ "MAINHAND", "OFFHAND" }) do
        local index = modernSlot(slot)
        local ok, value = false, nil
        if index ~= nil then ok, value = pcall(C_Item.GetWeaponEnchantInfo, index) end
        result[slot] = ok and WeaponImbues.ParseModern(value, now) or { readable = false }
    end
    return result
end

-- Which API answers now: "GetWeaponEnchantInfo", "C_Item.GetWeaponEnchantInfo" or "none".
function WeaponImbues.Source(now)
    if readLegacy(now or 0) then return "GetWeaponEnchantInfo" end
    if readModern(now or 0) then return "C_Item.GetWeaponEnchantInfo" end
    return "none"
end

-- { MAINHAND = raw, OFFHAND = raw }, raw = { readable, has, expiresAt?, charges?, enchantID?, weapon, icon }.
-- A missing API, an error or an empty answer is unreadable (→ UNKNOWN), never "no imbue". Read fresh every time:
-- nothing is cached, so a weapon swap never keeps an old state.
function WeaponImbues.Read(now)
    local result = readLegacy(now) or readModern(now)
        or { MAINHAND = { readable = false }, OFFHAND = { readable = false } }
    for slot, slotID in pairs(WeaponImbues.SLOTS) do
        result[slot].weapon = weaponIn(slot, slotID)
        result[slot].icon = iconOf(slotID)
    end
    return result
end

-- Plain facts for /pa auras and /pa debug (no secret value is formatted): the API chain and per slot what it read.
function WeaponImbues.Describe(now)
    local function plain(value) if isSecret(value) then return "secret" end return tostring(value) end
    local lines = { ("Weapon API: %s · GetWeaponEnchantInfo %s · C_Item.GetWeaponEnchantInfo %s · Enum.WeaponSlot %s"):format(
        WeaponImbues.Source(now), GetWeaponEnchantInfo and "yes" or "no",
        (C_Item and C_Item.GetWeaponEnchantInfo) and "yes" or "no", (Enum and Enum.WeaponSlot) and "yes" or "no") }
    if GetWeaponEnchantInfo then
        local values = pack(pcall(GetWeaponEnchantInfo))
        local shown = {}
        for index = 2, math.min(values.n, 9) do shown[#shown + 1] = plain(values[index]) end
        lines[#lines + 1] = ("  GetWeaponEnchantInfo(): ok=%s, %d values: %s"):format(tostring(values[1]), values.n - 1,
            table.concat(shown, ", "))
    end
    local weapons = WeaponImbues.Read(now)
    for _, slot in ipairs({ "MAINHAND", "OFFHAND" }) do
        local raw = weapons[slot]
        lines[#lines + 1] = ("  %s: weapon=%s readable=%s hasImbue=%s timeLeft=%s charges=%s enchantID=%s"):format(slot,
            tostring(raw.weapon), tostring(raw.readable), tostring(raw.has),
            raw.expiresAt and (math.floor(raw.expiresAt - now) .. "s") or "-", tostring(raw.charges),
            tostring(raw.enchantID))
    end
    return lines
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
