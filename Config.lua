-- PaTiAuras: saved settings (PaTiAurasDB) — defaults and migration, no WoW API calls (tests/config_spec.lua).
local _, ns = ...
local Config = {}
ns.Config = Config

Config.SCHEMA = 2
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
}

-- Schema 1 had one switch per category besides the per-aura watch list; schema 2 has only the watch list.
Config.OLD_CATEGORY_SETTINGS = { personal = "showPersonal", procs = "showProcs", group = "showGroup",
    healing = "showHealing", weapon = "showWeapon" }

-- Fills missing values, keeps every existing one (also false). watch[key] = false hides one aura.
-- profile: your class profile (Watch.ClassProfile) — schema 1 → 2 turns a switched-off category into
-- watch[key] = false for each of its entries (once), so nothing the player had hidden comes back.
function Config.Migrate(db, profile)
    db = db or {}
    for key, value in pairs(Config.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    if type(db.watch) ~= "table" then db.watch = {} end
    if db.seen == nil then db.seen = {} end -- aura keys already offered in the "new auras" dialog
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
