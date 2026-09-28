-- PaTiAuras: saved settings (PaTiAurasDB) — defaults and migration, no WoW API calls (tests/config_spec.lua).
local _, ns = ...
local Config = {}
ns.Config = Config

Config.SCHEMA = 1
Config.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }

-- Position (point, relativePoint, x, y) is written by the PaTiShared window, not listed here.
Config.DEFAULTS = {
    enabled = true,
    locked = false,
    scale = 1,
    language = "auto",
    showPersonal = true,
    showGroup = true,
    showHealing = true,
    showProcs = true,
    showTimers = true,
    showCharges = true, -- charges and stacks (both are the aura's application count)
    showMissing = true,
    showExpiring = true,
}

-- Fills missing values, keeps every existing one (also false). watch[key] = false hides one aura.
function Config.Migrate(db)
    db = db or {}
    for key, value in pairs(Config.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    if db.watch == nil then db.watch = {} end
    db.schema = Config.SCHEMA
    return db
end

-- "Restore Defaults": all settings back, position and changelog marker kept.
function Config.RestoreDefaults(db)
    for key, value in pairs(Config.DEFAULTS) do db[key] = value end
    db.watch = {}
    return db
end
