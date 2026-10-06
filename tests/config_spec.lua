-- PaTiAuras settings. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Config.lua", {}).Config
end

describe("Config.Migrate", function()
    it("creates all defaults for a new character", function()
        local db = load().Migrate(nil)
        assert.is_true(db.enabled)
        assert.equal(1, db.scale)
        assert.equal("auto", db.language)
        assert.same({}, db.watch)
        assert.equal(3, db.schema)
    end)

    it("keeps saved values, also false, and the position", function()
        local db = load().Migrate({ showTimers = false, locked = true, scale = 1.25, x = 5, point = "TOPLEFT",
            watch = { RIPTIDE = false }, lastChangelog = "0.1.0" })
        assert.is_false(db.showTimers)
        assert.is_true(db.locked)
        assert.equal(1.25, db.scale)
        assert.equal(5, db.x)
        assert.equal("TOPLEFT", db.point)
        assert.is_false(db.watch.RIPTIDE)
        assert.equal("0.1.0", db.lastChangelog)
    end)
end)

describe("Config.RestoreDefaults", function()
    it("resets settings and watches but keeps position and changelog marker", function()
        local db = load().RestoreDefaults({ showTimers = false, scale = 1.5, x = 5, watch = { RIPTIDE = false },
            lastChangelog = "0.1.0" })
        assert.is_true(db.showTimers)
        assert.equal(1, db.scale)
        assert.same({}, db.watch)
        assert.equal(5, db.x)
        assert.equal("0.1.0", db.lastChangelog)
    end)
end)

describe("Config.NewDefs / seen", function()
    it("starts with nothing seen and keeps seen auras across Restore Defaults", function()
        local Config = load()
        local db = Config.Migrate({ watch = { RIPTIDE = false } })
        assert.same({}, db.seen)
        db.seen.INNER_FIRE = true
        Config.RestoreDefaults(db)
        assert.is_true(db.seen.INNER_FIRE)
    end)

    it("returns only the entries not offered before, in profile order", function()
        local defs = { { key = "INNER_FIRE" }, { key = "FORTITUDE" }, { key = "DIVINE_SPIRIT" } }
        local new = load().NewDefs(defs, { FORTITUDE = true })
        assert.equal(2, #new)
        assert.equal("INNER_FIRE", new[1].key)
        assert.equal("DIVINE_SPIRIT", new[2].key)
        assert.same({}, load().NewDefs(defs, { INNER_FIRE = true, FORTITUDE = true, DIVINE_SPIRIT = true }))
    end)
end)

describe("Collapse state", function()
    it("old saves get collapsed = false, a saved true stays, position is kept", function()
        local Config = load()
        assert.is_false(Config.Migrate({ x = 5 }).collapsed)
        local db = Config.Migrate({ x = 5, collapsed = true })
        assert.is_true(db.collapsed)
        assert.equal(5, db.x)
    end)

    it("Restore Defaults expands the window (documented) and keeps the position", function()
        local db = load().RestoreDefaults({ collapsed = true, x = 5 })
        assert.is_false(db.collapsed)
        assert.equal(5, db.x)
    end)
end)

describe("Schema 2: the watch list replaces the category switches", function()
    local PROFILE = {
        personal = { { key = "WATER_SHIELD" } }, procs = { { key = "TIDAL_WAVES" } },
        healing = { { key = "EARTH_SHIELD" }, { key = "RIPTIDE" } },
        weapon = { { key = "MAIN_HAND_IMBUE" }, { key = "OFF_HAND_IMBUE" } }, group = {},
    }

    it("turns a switched-off category into watch = false for each of its entries, once", function()
        local Config = load()
        local db = Config.Migrate({ schema = 1, showHealing = false, showWeapon = false, showPersonal = true,
            watch = { WATER_SHIELD = false } }, PROFILE)
        -- The slot keys of the switched-off weapon category are then replaced by schema 3 (no concrete imbue here).
        assert.same({ WATER_SHIELD = false, EARTH_SHIELD = false, RIPTIDE = false }, db.watch)
        assert.equal(3, db.schema)
        for _, key in ipairs({ "showPersonal", "showGroup", "showHealing", "showProcs", "showWeapon" }) do
            assert.is_nil(db[key])
        end
        db.watch.EARTH_SHIELD = true -- switched on again later: a second login must not undo that
        assert.is_true(Config.Migrate(db, PROFILE).watch.EARTH_SHIELD)
    end)

    it("keeps individual choices, position, language, scale, lock and collapse", function()
        local Config = load()
        local db = Config.Migrate({ schema = 1, collapsed = true, locked = true, scale = 0.9, language = "deDE",
            x = 3, watch = { RIPTIDE = false }, seen = { RIPTIDE = true }, showHealing = true }, PROFILE)
        assert.same({ true, true, 0.9, "deDE", 3 }, { db.collapsed, db.locked, db.scale, db.language, db.x })
        assert.same({ RIPTIDE = false }, db.watch)
        assert.same({ RIPTIDE = true }, db.seen)
    end)

    it("works without a class profile and for new characters", function()
        local Config = load()
        assert.same({}, Config.Migrate({ schema = 1, showHealing = false }, nil).watch)
        local db = Config.Migrate(nil, PROFILE)
        assert.same({}, db.watch)
        assert.is_nil(db.showHealing)
        local restored = Config.RestoreDefaults({ watch = { RIPTIDE = false }, seen = { RIPTIDE = true } })
        assert.same({}, restored.watch) -- Restore Defaults: everything watched again
        assert.same({ RIPTIDE = true }, restored.seen)
    end)
end)

describe("Window settings (panel opacity)", function()
    it("old saves get 75 %; a saved value stays; Restore Defaults resets it; an old snapWindows is ignored", function()
        local M = load()
        local db = M.Migrate({ x = 12, y = 34 })
        assert.equal(0.75, db.opacity)
        assert.equal(12, db.x)
        db = M.Migrate({ opacity = 0.4, snapWindows = false })
        assert.equal(0.4, db.opacity)
        db = M.RestoreDefaults({ opacity = 0.4, snapWindows = false, bindings = {}, bindingRanks = {}, watch = {} })
        assert.equal(0.75, db.opacity)
    end)
end)

describe("Schema 3: concrete weapon imbues replace the weapon slots", function()
    local PROFILE = { weapon = { { key = "ROCKBITER_WEAPON", spellID = 8017, slot = "MAINHAND", enchantIDs = { 29 } } } }

    it("a switched-off main hand keeps Rockbiter off and already offered (no dialog); slot keys are gone", function()
        local db = load().Migrate({ schema = 2, watch = { MAIN_HAND_IMBUE = false, OFF_HAND_IMBUE = false },
            seen = { MAIN_HAND_IMBUE = true, OFF_HAND_IMBUE = true, RIPTIDE = true } }, PROFILE)
        assert.same({ ROCKBITER_WEAPON = false }, db.watch)
        assert.same({ ROCKBITER_WEAPON = true, RIPTIDE = true }, db.seen)
        assert.equal(3, db.schema)
    end)

    it("a watched main hand picks no imbue by itself: Rockbiter stays unset and unseen (the dialog asks)", function()
        local db = load().Migrate({ schema = 2, watch = {}, seen = { MAIN_HAND_IMBUE = true } }, PROFILE)
        assert.same({}, db.watch)
        assert.same({}, db.seen)
    end)

    it("keeps an explicit Rockbiter choice, runs once, and works without a profile", function()
        local Config = load()
        local db = Config.Migrate({ schema = 2, watch = { MAIN_HAND_IMBUE = false, ROCKBITER_WEAPON = true } }, PROFILE)
        assert.same({ ROCKBITER_WEAPON = true }, db.watch)
        db.watch.ROCKBITER_WEAPON = false
        assert.is_false(Config.Migrate(db, PROFILE).watch.ROCKBITER_WEAPON)
        assert.same({}, Config.Migrate({ schema = 2, watch = { MAIN_HAND_IMBUE = false } }, nil).watch)
    end)
end)

describe("Own buff list (Config.OwnSlots / SetSlot / MoveTo)", function()
    it("Migrate leaves an unedited list nil and cleans a saved one", function()
        local Config = load()
        assert.is_nil(Config.Migrate({}).ownBuffs)
        local db = Config.Migrate({ ownBuffs = { 324, "x", 324, 1.5, 588 } })
        assert.same({ 324, 0, 0, 0, 588, 0, 0, 0, 0, 0 }, db.ownBuffs)
        assert.equal(Config.OWN_SLOTS, #Config.Migrate({ ownBuffs = "broken" }).ownBuffs)
    end)

    it("SetSlot swaps a spell that is already in another slot; MoveTo shifts the ones in between", function()
        local Config = load()
        local list = Config.OwnSlots({ 1, 2, 3 })
        Config.SetSlot(list, 3, 1)
        assert.same(Config.OwnSlots({ 3, 2, 1 }), list)
        assert.is_true(Config.MoveTo(list, 1, 3))
        assert.same(Config.OwnSlots({ 2, 1, 3 }), list)
        assert.is_false(Config.MoveTo(list, 1, 1))
        assert.is_false(Config.MoveTo(list, 1, 0)) -- arrow up from slot 1
        assert.is_false(Config.MoveTo(list, 10, 11)) -- arrow down from the last slot
    end)

    it("Restore Defaults keeps the own list", function()
        local Config = load()
        local db = Config.Migrate({ ownBuffs = { 324 } })
        Config.RestoreDefaults(db)
        assert.equal(324, db.ownBuffs[1])
    end)
end)
