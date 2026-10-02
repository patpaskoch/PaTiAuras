-- PaTiAuras: temporary weapon enchants (Shaman weapon imbues). They are no UNIT_AURA auras, so they have their own
-- adapter; Watch turns them into the same ACTIVE / MISSING / EXPIRING / UNKNOWN results as every other entry.
-- A concrete imbue (e.g. Rockbiter) is recognised by its owner-observed enchant IDs (Profiles/Shaman.lua, Evaluate).
-- This file only reads and evaluates; casting a missing imbue is a player click on the line's fixed secure button
-- (AuraWindow.lua, Auras.LineActions) — never automatic.
--
-- Two enchant APIs, each with its own parser; per hand the first readable answer wins:
--   1. C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.X) per weapon slot (ParseModern). Forever, owner's /pa auras
--      2026-10-02 with Rockbiter on: an entry hasEnchant=true, timeLeft=3524825 (ms), enchantType=3 = Imbue in
--      Enum.ItemEnchantType (None 0, Permanent 1, Temporary 2, Imbue 3).
--      Used only with Enum.WeaponSlot (no guessed numbers).
--   2. GetWeaponEnchantInfo()             classic tuple (ParseLegacy), only where 1 is missing or unreadable: in the
--      same test it said hasMainHand=false while Rockbiter was on, so it must never override a readable 1.
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

-- Is this modern enchant entry a temporary one (an imbue)? true / false, or nil when that cannot be read.
-- A positive time left is the reliable signal (Forever reports the active imbue with enchantType=3 = Imbue in
-- Enum.ItemEnchantType). Without time left only a readable type decides: Temporary/Imbue (enum or name) = yes;
-- Permanent, None, an unknown number or no type = no (a permanent enchant has no time left).
local function isTemporary(info)
    local left, kind = plainNumber(info.timeLeft), info.enchantType
    if left and left > 0 then return true end
    if isSecret(info.timeLeft) or isSecret(kind) then return nil end
    local enum = Enum and Enum.ItemEnchantType
    if type(kind) == "number" and enum then return kind == enum.Temporary or kind == enum.Imbue end
    if type(kind) == "string" then
        local upper = kind:upper()
        return upper:find("TEMP", 1, true) ~= nil or upper:find("IMBUE", 1, true) ~= nil
    end
    return false
end

-- Pure: one C_Item.GetWeaponEnchantInfo(slot) result → raw slot. Accepts one entry table or a list of entries;
-- picks the temporary (imbue) entry, never a permanent enchant. timeLeft is milliseconds (Forever: 3524825 for a
-- fresh Rockbiter ≈ 58.7 min). A nil answer = no imbue on that slot. If no entry is surely an imbue but one could
-- not be read (secret values), the slot is unreadable (→ UNKNOWN), never "no imbue".
function WeaponImbues.ParseModern(result, now)
    if result == nil then return { readable = true, has = false } end
    if isSecret(result) or type(result) ~= "table" then return { readable = false } end
    local entries = result[1] ~= nil and result or { result }
    local unclear = false
    for _, info in ipairs(entries) do
        if type(info) == "table" then
            if isSecret(info.hasEnchant) then return { readable = false } end
            local temporary = info.hasEnchant ~= false and isTemporary(info)
            if temporary then
                local raw = { readable = true, has = true, charges = plainNumber(info.charges),
                    enchantID = plainNumber(info.enchantID), iconID = plainNumber(info.enchantIconID) }
                local left = plainNumber(info.timeLeft)
                if left and left > 0 then raw.expiresAt = now + left / 1000 end
                return raw
            end
            if temporary == nil then unclear = true end
        end
    end
    if unclear then return { readable = false } end
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

local MODERN, LEGACY = "C_Item.GetWeaponEnchantInfo", "GetWeaponEnchantInfo"

-- Which API is asked first now: "C_Item.GetWeaponEnchantInfo", "GetWeaponEnchantInfo" or "none".
function WeaponImbues.Source(now)
    if readModern(now or 0) then return MODERN end
    if readLegacy(now or 0) then return LEGACY end
    return "none"
end

-- { MAINHAND = raw, OFFHAND = raw }, raw = { readable, has, expiresAt?, charges?, enchantID?, source, weapon, icon }.
-- Per hand the modern answer wins when it is readable. Without the modern API the classic tuple decides. If the
-- modern API exists but this hand was unreadable, the tuple may only confirm an imbue: its "no imbue" was wrong in
-- Forever, so that stays UNKNOWN, never MISSING. A missing API, an error or an empty answer is unreadable too.
-- Read fresh every time: nothing is cached, so a weapon swap never keeps an old state.
local function pick(fromModern, fromLegacy)
    if fromModern and fromModern.readable then fromModern.source = MODERN; return fromModern end
    if fromLegacy and (not fromModern or (fromLegacy.readable and fromLegacy.has)) then
        fromLegacy.source = LEGACY
        return fromLegacy
    end
    return { readable = false, source = fromModern and MODERN or "none" }
end

function WeaponImbues.Read(now)
    local modern, legacy = readModern(now), readLegacy(now)
    local result = {}
    for slot, slotID in pairs(WeaponImbues.SLOTS) do
        local raw = pick(modern and modern[slot], legacy and legacy[slot])
        raw.weapon = weaponIn(slot, slotID)
        raw.icon = iconOf(slotID)
        result[slot] = raw
    end
    return result
end

-- Diagnostics for /pa debug and /pa auras --------------------------------------------------------
-- Owner test 2026-09-30: with Rockbiter on, Main Hand still reads "Missing". Which return value really changes is
-- unknown, so these lines print everything both APIs return (plus player buffs and the weapon tooltip), to compare
-- "without Rockbiter" against "with Rockbiter" in game. No secret value is ever formatted or compared.

local LEGACY_FIELDS = { "hasMainHand", "mainHandMsLeft", "mainHandCharges", "mainHandEnchantID",
    "hasOffHand", "offHandMsLeft", "offHandCharges", "offHandEnchantID" }
local MAX_FIELDS, MAX_LINES = 12, 20

-- One value as text with its type ("1(number)" and "true(boolean)" read differently); tables one level deep.
local function describeValue(value, depth)
    if isSecret(value) then return "secret" end
    if type(value) ~= "table" then return ("%s(%s)"):format(tostring(value), type(value)) end
    if (depth or 0) >= 2 then return "{…}" end
    local keys = {}
    for key in pairs(value) do
        if not isSecret(key) and (type(key) == "string" or type(key) == "number") then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for index = 1, math.min(#keys, MAX_FIELDS) do
        parts[#parts + 1] = tostring(keys[index]) .. "=" .. describeValue(value[keys[index]], (depth or 0) + 1)
    end
    if #keys > MAX_FIELDS then parts[#parts + 1] = ("+%d more"):format(#keys - MAX_FIELDS) end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- "ok=true, 2 values: #1=…, #2=…" for one pcall(fn, ...) result.
local function describeCall(labels, ok, ...)
    local count = select("#", ...)
    if not ok then return ("ok=false error=%s"):format(describeValue((...))) end
    local parts = {}
    for index = 1, count do
        parts[#parts + 1] = ("%s=%s"):format(labels and labels[index] or ("#" .. index),
            describeValue((select(index, ...))))
    end
    return ("ok=true, %d values: %s"):format(count, count > 0 and table.concat(parts, ", ") or "(nothing)")
end

local function itemText(slotID)
    if not GetInventoryItemID then return "?" end
    local ok, itemID = pcall(GetInventoryItemID, "player", slotID)
    return ok and describeValue(itemID) or "error"
end

-- The per-slot result the window uses: API, weapon, parsed values, final state.
local function slotLines(lines, now, settings)
    local weapons = WeaponImbues.Read(now)
    for _, slot in ipairs({ "MAINHAND", "OFFHAND" }) do
        local raw = weapons[slot]
        local result = WeaponImbues.Evaluate(raw, now, settings or {})
        local slotID = WeaponImbues.SLOTS[slot]
        lines[#lines + 1] = ("  %s slot=%d item=%s weapon=%s · source=%s · readable=%s hasImbue=%s timeLeft=%s "
            .. "charges=%s enchantID=%s → state=%s"):format(slot, slotID, itemText(slotID), tostring(raw.weapon),
            tostring(raw.source), tostring(raw.readable), tostring(raw.has),
            raw.expiresAt and (math.floor(raw.expiresAt - now) .. "s") or "-", tostring(raw.charges),
            tostring(raw.enchantID), result and result.state or "no line (no weapon)")
    end
end

-- The raw modern answers: without a slot, with Enum.WeaponSlot and with the inventory slot IDs (probes, read-only).
local function modernLines(lines)
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return end
    lines[#lines + 1] = "  Enum.WeaponSlot " .. describeValue(Enum and Enum.WeaponSlot)
        .. " · Enum.ItemEnchantType " .. describeValue(Enum and Enum.ItemEnchantType)
    local probes = { { "()" } }
    for _, slot in ipairs({ "MAINHAND", "OFFHAND" }) do
        local index = modernSlot(slot)
        if index ~= nil then probes[#probes + 1] = { ("(Enum %s)"):format(slot), index } end
        probes[#probes + 1] = { ("(%d) probe"):format(WeaponImbues.SLOTS[slot]), WeaponImbues.SLOTS[slot] }
    end
    for _, probe in ipairs(probes) do
        local call = probe[2] == nil and pack(pcall(C_Item.GetWeaponEnchantInfo))
            or pack(pcall(C_Item.GetWeaponEnchantInfo, probe[2]))
        lines[#lines + 1] = ("  C_Item.GetWeaponEnchantInfo%s: %s"):format(probe[1],
            describeCall(nil, unpack(call, 1, call.n)))
    end
end

-- Is the imbue perhaps an aura on you? Your buffs by name and spell ID.
local function buffLines(lines)
    local AuraScan = ns.AuraScan
    if not AuraScan then return end
    local names = {}
    for _, aura in ipairs(AuraScan.Read("player", "HELPFUL")) do
        if aura.secret then names[#names + 1] = "secret"
        else names[#names + 1] = ("%s[%s]"):format(tostring(aura.name), tostring(aura.spellId)) end
        if #names >= MAX_LINES then break end
    end
    lines[#lines + 1] = ("  Player buffs (%d): %s"):format(#names, #names > 0 and table.concat(names, ", ") or "none")
end

-- The main-hand tooltip (an imbue usually adds a line like "Rockbiter (30 min)").
local function tooltipLines(lines)
    local getter = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if not getter then lines[#lines + 1] = "  Main hand tooltip: C_TooltipInfo not available"; return end
    local ok, data = pcall(getter, "player", WeaponImbues.SLOTS.MAINHAND)
    if not ok or isSecret(data) or type(data) ~= "table" or isSecret(data.lines) or type(data.lines) ~= "table" then
        lines[#lines + 1] = "  Main hand tooltip: unreadable"
        return
    end
    for index, line in ipairs(data.lines) do
        if index > MAX_LINES then break end
        local text = type(line) == "table" and line.leftText
        lines[#lines + 1] = ("  Main hand tooltip %d: %s"):format(index,
            isSecret(text) and "secret" or tostring(text))
    end
end

-- The watched concrete imbues: wanted spell and enchant IDs against what the slot shows. desired: Watch.Weapon
-- items { entry, result, raw }. With `detailed`, also the learned spells whose icon equals the active enchant's
-- icon — to confirm the spell ID of an observed imbue (diagnostics only, never used for detection).
local function desiredLines(lines, now, desired, detailed)
    local Spells = ns.Spells
    for _, item in ipairs(desired or {}) do
        local entry, raw = item.entry, item.raw or {}
        lines[#lines + 1] = ("  Desired %s: %s key=%s spellID=%s known=%s expectedEnchantIDs=%s · detected "
            .. "enchantID=%s timeLeft=%s iconID=%s → %s%s"):format(tostring(entry.slot), tostring(entry.name),
            tostring(entry.key),
            tostring(entry.spellID), tostring(entry.spellID ~= nil and Spells and Spells.IsKnown(entry.spellID)),
            table.concat(entry.enchantIDs or {}, "/"), tostring(raw.enchantID),
            raw.expiresAt and (math.floor(raw.expiresAt - now) .. "s") or "-", tostring(raw.iconID),
            item.result.state, item.result.wrong and " (another imbue)" or "")
        if detailed and raw.iconID and Spells and Spells.WithIcon then
            local found = {}
            for _, spell in ipairs(Spells.WithIcon(raw.iconID)) do
                found[#found + 1] = spell.name .. "[" .. spell.id .. "]"
            end
            lines[#lines + 1] = ("  Learned spells with icon %d: %s"):format(raw.iconID,
                #found > 0 and table.concat(found, ", ") or "none")
        end
    end
end

-- Plain facts for /pa debug (detailed = false) and /pa auras (detailed = true). settings: PaTiAurasDB.
-- desired: Watch.Weapon items (the watched concrete imbues), optional.
function WeaponImbues.Describe(now, settings, detailed, desired)
    local lines = { ("Weapon API: source=%s · GetWeaponEnchantInfo %s · C_Item.GetWeaponEnchantInfo %s · "
        .. "Enum.WeaponSlot %s"):format(WeaponImbues.Source(now), GetWeaponEnchantInfo and "yes" or "no",
        (C_Item and C_Item.GetWeaponEnchantInfo) and "yes" or "no", (Enum and Enum.WeaponSlot) and "yes" or "no") }
    if GetWeaponEnchantInfo then
        local call = pack(pcall(GetWeaponEnchantInfo))
        lines[#lines + 1] = "  GetWeaponEnchantInfo(): " .. describeCall(LEGACY_FIELDS, unpack(call, 1, call.n))
    end
    if detailed then modernLines(lines) end
    slotLines(lines, now, settings)
    desiredLines(lines, now, desired, detailed)
    if detailed then
        buffLines(lines)
        tooltipLines(lines)
    end
    return lines
end

local function listed(ids, id)
    for _, known in ipairs(ids or {}) do
        if known == id then return true end
    end
    return false
end

-- Pure: the watch result of one slot, or nil when there is nothing to watch (no weapon that can be imbued).
-- settings: PaTiAurasDB (showExpiring). Same threshold as all other buffs (Auras.EXPIRING_SECONDS).
-- entry: the watched profile entry. With `enchantIDs` (a concrete imbue, e.g. Rockbiter) the active temporary
-- enchant must be one of them: an ID of another known imbue (`otherIDs`) = MISSING with wrong = true; an ID nobody
-- mapped, or none readable = UNKNOWN (never a guess either way). Without `enchantIDs`: any imbue counts (generic).
function WeaponImbues.Evaluate(raw, now, settings, entry, otherIDs)
    if not raw or raw.weapon == false then return nil end
    local icon = entry and entry.icon or raw.icon
    if not raw.readable then return { state = "UNKNOWN", icon = icon } end
    if raw.has then
        local wanted = entry and entry.enchantIDs
        if wanted and not listed(wanted, raw.enchantID) then
            if raw.enchantID ~= nil and listed(otherIDs, raw.enchantID) then
                return { state = "MISSING", wrong = true, icon = icon }
            end
            return { state = "UNKNOWN", icon = icon }
        end
        local remaining = raw.expiresAt and math.max(0, raw.expiresAt - now)
        local state = "ACTIVE"
        if remaining and settings.showExpiring and remaining < Auras.EXPIRING_SECONDS then state = "EXPIRING" end
        return { state = state, remaining = remaining, count = raw.charges, icon = icon }
    end
    -- No imbue, but is it a weapon at all? Unknown (e.g. item class unreadable) must not claim "missing".
    if raw.weapon == nil then return { state = "UNKNOWN", icon = icon } end
    return { state = "MISSING", icon = icon }
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

-- Test mode: main hand imbued (18:42 left) with the first watched main-hand imbue (entries: Watch.entries.weapon),
-- off hand weapon without imbue.
function WeaponImbues.TestRead(now, entries)
    local enchantID
    for _, entry in ipairs(entries or {}) do
        if entry.slot == "MAINHAND" and entry.enchantIDs then enchantID = entry.enchantIDs[1]; break end
    end
    return {
        MAINHAND = { readable = true, has = true, expiresAt = now + 1122, weapon = true, enchantID = enchantID },
        OFFHAND = { readable = true, has = false, weapon = true },
    }
end
