-- PaTiAuras: saved settings (PaTiAurasDB) — defaults and migration, no WoW API calls (tests/config_spec.lua).
local _, ns = ...
local Config = {}
ns.Config = Config

Config.SCHEMA = 3
Config.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }

-- Position (point, relativePoint, x, y) is written by the PaTiShared window, not listed here.
Config.DEFAULTS = {
    opacity = 0.75, -- panel body opacity (PaTiShared window; 0.3–1)
    theme = "default", -- "default" | "woforever" | "dracula" (PaTiShared UI.THEMES; colours only)
    enabled = true,
    collapsed = false,
    locked = false,
    scale = 1,
    language = "auto",
    showTimers = true,
    showCharges = true, -- charges and stacks (both are the aura's application count)
    showMissing = true,
    showExpiring = true,
    onlyMissing = false, -- show only missing/expiring own lines and incomplete group buffs (owner 2026-10-06)
    columns = 1, -- grid columns 1–3 (owner 2026-10-06); replaces categoryLayout, which stays saved but unused
    categoryLayout = "vertical", -- before 2026-10-06; only read once to pick the first columns value
}

-- Schema 1 had one switch per category besides the per-aura watch list; schema 2 has only the watch list.
Config.OLD_CATEGORY_SETTINGS = { personal = "showPersonal", procs = "showProcs", group = "showGroup",
    healing = "showHealing", weapon = "showWeapon" }

-- Schema 2 watched weapon slots, not imbues: these keys (watch/seen) are replaced in schema 3.
Config.OLD_WEAPON_SLOTS = { MAIN_HAND_IMBUE = "MAINHAND", OFF_HAND_IMBUE = "OFFHAND" }

-- Fills missing values, keeps every existing one (also false). watch[key] = false hides one aura.
-- profile: your class profile (Watch.ClassProfile) — schema 1 → 2 turns a switched-off category into
-- watch[key] = false for each of its entries (once), so nothing the player had hidden comes back.
function Config.Migrate(db, profile)
    if type(db) ~= "table" then db = {} end -- nil or a broken save (string, number …): start fresh
    -- Columns replace the category layout (2026-10-06): "horizontal" (one column per category) becomes 2 columns.
    if db.columns == nil and db.categoryLayout == "horizontal" then db.columns = 2 end
    for key, value in pairs(Config.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- A broken scale would make SetScale fail on login: only a sane number is kept (saved values elsewhere stay).
    if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = Config.DEFAULTS.scale end
    -- Theme: one of the three PaTiShared themes; a typo or an old value falls back to the default look.
    if db.theme ~= "default" and db.theme ~= "woforever" and db.theme ~= "dracula" then db.theme = "default" end
    if db.categoryLayout ~= "vertical" and db.categoryLayout ~= "horizontal" then db.categoryLayout = "vertical" end
    if db.columns ~= 1 and db.columns ~= 2 and db.columns ~= 3 then db.columns = Config.DEFAULTS.columns end
    if type(db.watch) ~= "table" then db.watch = {} end
    if type(db.seen) ~= "table" then db.seen = {} end -- aura keys already offered in the "new auras" dialog
    -- Own buff list (owner 2026-10-06): nil = not edited yet, the class profile's self buffs are used (Watch.OwnDefs).
    if db.ownBuffs ~= nil then db.ownBuffs = Config.OwnSlots(db.ownBuffs) end
    db.imbues = Config.CleanImbues(db.imbues)
    if type(db.schema) ~= "number" then db.schema = nil end -- a broken schema counts as "before schema 2"
    if (db.schema or 1) < 2 then
        for category, setting in pairs(Config.OLD_CATEGORY_SETTINGS) do
            if db[setting] == false then
                for _, def in ipairs(profile and profile[category] or {}) do
                    if db.watch[def.key] == nil then db.watch[def.key] = false end
                end
            end
        end
    end
    for _, setting in pairs(Config.OLD_CATEGORY_SETTINGS) do db[setting] = nil end
    if (db.schema or 1) < 3 then
        -- Schema 3 watches concrete imbues (e.g. Rockbiter) instead of "an imbue on the main/off hand". A slot the
        -- player had switched off stays off: its concrete imbues start unwatched and already offered (no dialog).
        -- A slot that was watched picks no imbue by itself — the "new auras" dialog asks.
        for oldKey, slot in pairs(Config.OLD_WEAPON_SLOTS) do
            if db.watch[oldKey] == false then
                for _, def in ipairs(profile and profile.weapon or {}) do
                    if def.slot == slot and def.spellID and db.watch[def.key] == nil then
                        db.watch[def.key] = false
                        db.seen[def.key] = true
                    end
                end
            end
            db.watch[oldKey], db.seen[oldKey] = nil, nil
        end
    end
    db.schema = Config.SCHEMA
    return db
end

-- "Restore Defaults": all settings back, position, changelog marker and seen auras kept.
function Config.RestoreDefaults(db)
    for key, value in pairs(Config.DEFAULTS) do db[key] = value end
    db.watch = {}
    return db
end

-- Profile entries not yet offered in the "new auras" dialog (first start, newly learned spell, profile update).
function Config.NewDefs(defs, seen)
    local new = {}
    for _, def in ipairs(defs) do
        if not seen[def.key] then new[#new + 1] = def end
    end
    return new
end

-- Own buff list ---------------------------------------------------------------------------------
-- The player's list of own buffs to watch (settings → Watch → Own buffs): Config.OWN_SLOTS spell IDs in display
-- order, 0 = empty. Same list rules as PaTiRota's skill slots (small deliberate copy, addons stay independent).
Config.OWN_SLOTS = 12

local function validID(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end

-- Any saved value → a clean list: Config.OWN_SLOTS entries, broken ones empty, a spell only in its first slot.
function Config.OwnSlots(old)
    old = type(old) == "table" and old or {}
    local slots, seen = {}, {}
    for index = 1, Config.OWN_SLOTS do
        local id = validID(old[index]) and old[index] or 0
        if id ~= 0 and seen[id] then id = 0 end
        seen[id] = true
        slots[index] = id
    end
    return slots
end

-- Puts spell `id` (0 = empty) into slot `index`; if it was in another slot, that slot gets the old value (swap).
function Config.SetSlot(slots, index, id)
    if id ~= 0 then
        for other, value in ipairs(slots) do
            if value == id and other ~= index then slots[other] = slots[index] end
        end
    end
    slots[index] = id
    return slots
end

-- Moves the spell in slot `from` to slot `to` (arrows: to = from ± 1; drag and drop: any slot), the ones in
-- between shift by one. Returns true if it moved.
function Config.MoveTo(slots, from, to)
    if from == to or not slots[from] or not slots[to] then return false end
    table.insert(slots, to, table.remove(slots, from))
    return true
end

-- Learned weapon imbues (OwnList.ApplyLearned): { [spellID] = { slot = MAINHAND|OFFHAND, enchantIDs = { n … } } }.
function Config.CleanImbues(imbues)
    if type(imbues) ~= "table" then return nil end
    local clean = {}
    for id, record in pairs(imbues) do
        local slot = type(record) == "table" and record.slot
        if validID(id) and (slot == "MAINHAND" or slot == "OFFHAND") and type(record.enchantIDs) == "table" then
            local enchantIDs = {}
            for _, enchantID in ipairs(record.enchantIDs) do
                if validID(enchantID) then enchantIDs[#enchantIDs + 1] = enchantID end
            end
            clean[id] = { slot = slot, enchantIDs = enchantIDs }
        end
    end
    return clean
end

-- Display mode (settings "Show"): "all", "missing" (only missing/expiring) or "active" (missing hidden).
Config.MAX_COLUMNS = 3
function Config.ShowMode(db)
    if not db.showMissing then return "active" end
    return db.onlyMissing and "missing" or "all"
end

function Config.SetShowMode(db, mode)
    db.showMissing = mode ~= "active"
    db.onlyMissing = mode == "missing"
end
