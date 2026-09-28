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
