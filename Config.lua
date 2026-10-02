-- PaTiAuras: saved settings (PaTiAurasDB) — defaults and migration, no WoW API calls (tests/config_spec.lua).
local _, ns = ...
local Config = {}
ns.Config = Config

Config.SCHEMA = 3
Config.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }

-- Position (point, relativePoint, x, y) is written by the PaTiShared window, not listed here.
Config.DEFAULTS = {
    opacity = 0.75, -- panel body opacity (PaTiShared window; 0.3–1)
    enabled = true,
    collapsed = false,
    locked = false,
    scale = 1,
    language = "auto",
    showTimers = true,
    showCharges = true, -- charges and stacks (both are the aura's application count)
    showMissing = true,
    showExpiring = true,
    categoryLayout = "vertical", -- "vertical" | "horizontal" (Auras.CATEGORY_LAYOUTS); new key, no schema step
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
    for key, value in pairs(Config.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- A broken scale would make SetScale fail on login: only a sane number is kept (saved values elsewhere stay).
    if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = Config.DEFAULTS.scale end
    if db.categoryLayout ~= "vertical" and db.categoryLayout ~= "horizontal" then db.categoryLayout = "vertical" end
    if type(db.watch) ~= "table" then db.watch = {} end
    if type(db.seen) ~= "table" then db.seen = {} end -- aura keys already offered in the "new auras" dialog
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
