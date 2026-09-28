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
        assert.equal(1, db.schema)
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
