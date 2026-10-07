-- PaTiAuras: spell and spellbook adapters. Deliberate copy of PaTiHeal/SpellBook.lua (addons stay independent;
-- fix bugs in both). All spell API calls live here and are guarded, because
-- Interface 16001 may offer modern (C_Spell/C_SpellBook) or classic APIs (docs/WOW_API_COMPAT.md).
local _, ns = ...
local Spells = {}
ns.Spells = Spells

local families = {} -- spell name -> { ranks = { { id, rank, subtext } ... } } from the spellbook

function Spells.Name(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    return GetSpellInfo and GetSpellInfo(id)
end

function Spells.Icon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

function Spells.IsKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    elseif C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id) == nil then
        return false
    end
    -- Higher ranks have other IDs: a spell is also known if its name is in the spellbook.
    local name = Spells.Name(id)
    return name ~= nil and families[name] ~= nil
end

-- Pure: groups spellbook entries { name, subtext, id } into families with numbered ranks, lowest first.
function Spells.BuildFamilies(entries)
    local result = {}
    for _, entry in ipairs(entries) do
        local family = result[entry.name] or { ranks = {} }
        result[entry.name] = family
        local rank = entry.subtext and tonumber(entry.subtext:match("%d+"))
        family.ranks[#family.ranks + 1] = { id = entry.id, rank = rank, subtext = entry.subtext }
        if entry.general then family.general = true end
    end
    for _, family in pairs(result) do
        table.sort(family.ranks, function(a, b) return (a.rank or 0) < (b.rank or 0) end)
    end
    return result
end

-- Learned spells from the spellbook (not "future" spells), modern API first, classic API as fallback.
local function spellbookEntries()
    local entries = {}
    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank then
        local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for line = 1, book.GetNumSpellBookSkillLines() do
            local info = book.GetSpellBookSkillLineInfo(line)
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
                if item and item.spellID and item.name and (not spellType or item.itemType == spellType) then
                    entries[#entries + 1] = { name = item.name, subtext = item.subName, id = item.spellID,
                        general = line == 1 }
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(index, "spell")
                local name, subtext = GetSpellBookItemName(index, "spell")
                if kind == "SPELL" and id and name then
                    entries[#entries + 1] = { name = name, subtext = subtext, id = id, general = tab == 1 }
                end
            end
        end
    end
    return entries
end

-- Call on login and SPELLS_CHANGED. Returns false if no spellbook API worked (ranks then stay hidden).
function Spells.Rescan()
    local ok, entries = pcall(spellbookEntries)
    families = Spells.BuildFamilies(ok and entries or {})
    return ok and #entries > 0
end

-- Numbered ranks of the family of `id` (empty if the client has no ranks for it).
function Spells.Ranks(id)
    local name = Spells.Name(id)
    local family = name and families[name]
    local ranks = {}
    for _, entry in ipairs(family and family.ranks or {}) do
        if entry.rank then ranks[#ranks + 1] = entry end
    end
    return ranks
end

-- All spell IDs of the family of `id` (for matching auras cast with any rank).
function Spells.FamilyIDs(id)
    local ids = { [id] = true }
    for _, entry in ipairs(Spells.Ranks(id)) do ids[entry.id] = true end
    return ids
end

-- Name for the secure `spell` attribute: plain name = highest known rank; "Name(Rank 3)" = that rank.
function Spells.CastName(id, rank)
    local name = Spells.Name(id)
    if not name or not rank or rank == 0 then return name end
    for _, entry in ipairs(Spells.Ranks(id)) do
        if entry.rank == rank then return name .. "(" .. entry.subtext .. ")" end
    end
    return name -- chosen rank no longer known: fall back to the highest
end

-- Diagnostics only (/pa auras): learned spells whose icon is `icon` — e.g. the enchantIconID of an active weapon
-- imbue — as { { id, name } }, lowest ID first. Helps confirm which spell ID belongs to an observed imbue.
function Spells.WithIcon(icon)
    local list = {}
    for name, family in pairs(families) do
        for _, entry in ipairs(family.ranks) do
            if Spells.Icon(entry.id) == icon then list[#list + 1] = { id = entry.id, name = name } end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- What the player typed (a name or an ID) → spell ID; "" → 0 (empty); nil if nothing matches. Same as PaTiRota.
function Spells.Resolve(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return 0 end
    local id = tonumber(text)
    if id then return Spells.Name(id) and id or nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(text)
        return info and info.spellID
    end
    if GetSpellInfo then return (select(7, GetSpellInfo(text))) end
    return nil
end

-- The spell on the mouse cursor (dragged from the spellbook onto a list slot), or nil. Same as PaTiRota.
function Spells.FromCursor()
    if not GetCursorInfo then return nil end
    local kind, index, bookType, spellID = GetCursorInfo()
    if kind ~= "spell" then return nil end
    if type(spellID) == "number" then return spellID end -- modern clients: the 4th value
    if type(index) ~= "number" then return nil end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        local item = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
        return item and item.spellID
    end
    if GetSpellBookItemInfo then
        local _, id = GetSpellBookItemInfo(index, bookType)
        return id
    end
    return nil
end

-- An attack spell (Shadow Bolt …)? true only when the client says so; unknown or missing API → false. Never errors.
function Spells.IsHarmful(id)
    if C_Spell and C_Spell.IsSpellHarmful then
        local ok, harmful = pcall(C_Spell.IsSpellHarmful, id)
        if ok then return harmful == true end
    end
    local name = Spells.Name(id)
    if IsHarmfulSpell and name then
        local ok, harmful = pcall(IsHarmfulSpell, name)
        if ok then return harmful == true or harmful == 1 end
    end
    return false
end

local function isPassive(id)
    local fn = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
    if not fn then return false end
    local ok, passive = pcall(fn, id)
    return ok and (passive == true or passive == 1)
end

-- Your learned spells for a pick list (owner 2026-10-07): one ID per spell (its highest rank), passive ones left
-- out, keep(id) filters further (optional). Spells of the first spellbook line ("General": Attack, professions …)
-- only when general(id) allows them (e.g. tracking). Sorted by name.
function Spells.Learned(keep, general)
    local list = {}
    for name, family in pairs(families) do
        local top = family.ranks[#family.ranks]
        local allowed = top and (not family.general or (general and general(top.id)))
        if allowed and not isPassive(top.id) and (not keep or keep(top.id)) then
            list[#list + 1] = { id = top.id, name = name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local ids = {}
    for index, entry in ipairs(list) do ids[index] = entry.id end
    return ids
end
