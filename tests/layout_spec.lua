-- PaTiAuras grid (1–3 columns, no headers) and the "Show" setting (owner 2026-10-06).
-- Run via PaTiAdmin/tools/check.sh.
-- The window code (frames, secure buttons) is tested in game; this covers the pure placement it relies on.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Auras.lua", {}).Auras
end

local function loadConfig()
    return wow.loadAddonFile("Config.lua", {}).Config
end

describe("Auras.GridCell / GridSize", function()
    it("one column: every line below the other (the layout of before)", function()
        local Auras = load()
        assert.same({ 0, 0 }, { Auras.GridCell(1, 1) })
        assert.same({ 0, 2 }, { Auras.GridCell(3, 1) })
        assert.same({ 200, 60 }, { Auras.GridSize(3, 1, 200, 20, 12) })
    end)

    it("two and three columns fill row by row", function()
        local Auras = load()
        assert.same({ { 0, 0 }, { 1, 0 }, { 0, 1 } }, { { Auras.GridCell(1, 2) }, { Auras.GridCell(2, 2) },
            { Auras.GridCell(3, 2) } })
        assert.same({ 2, 1 }, { Auras.GridCell(6, 3) })
        assert.same({ 2 * 160 + 12, 40 }, { Auras.GridSize(3, 2, 160, 20, 12) })
        assert.same({ 3 * 160 + 2 * 12, 40 }, { Auras.GridSize(5, 3, 160, 20, 12) })
    end)

    it("fewer lines than columns: only the used columns count; no line keeps one column wide", function()
        local Auras = load()
        assert.same({ 160, 20 }, { Auras.GridSize(1, 3, 160, 20, 12) })
        assert.same({ 160, 0 }, { Auras.GridSize(0, 3, 160, 20, 12) })
    end)
end)

describe("Auras.ShowOwn (Show: all / only missing / only active)", function()
    local function item(state, category)
        return { entry = { category = category or "personal" }, result = { state = state } }
    end
    local ALL = { showMissing = true, onlyMissing = false }
    local MISSING = { showMissing = true, onlyMissing = true }
    local ACTIVE = { showMissing = false, onlyMissing = false }

    it("all: everything", function()
        local Auras = load()
        for _, state in ipairs({ "ACTIVE", "EXPIRING", "MISSING", "UNKNOWN" }) do
            assert.is_true(Auras.ShowOwn(item(state), ALL), state)
        end
    end)

    it("only missing: missing and expiring; active procs too (they only exist while usable)", function()
        local Auras = load()
        assert.is_true(Auras.ShowOwn(item("MISSING"), MISSING))
        assert.is_true(Auras.ShowOwn(item("EXPIRING"), MISSING))
        assert.is_false(Auras.ShowOwn(item("ACTIVE"), MISSING))
        assert.is_false(Auras.ShowOwn(item("UNKNOWN"), MISSING))
        assert.is_true(Auras.ShowOwn(item("ACTIVE", "procs"), MISSING))
    end)

    it("only active: missing hidden", function()
        local Auras = load()
        assert.is_false(Auras.ShowOwn(item("MISSING"), ACTIVE))
        assert.is_true(Auras.ShowOwn(item("ACTIVE"), ACTIVE))
    end)
end)

describe("Settings: Show and Columns", function()
    it("Show is stored in showMissing/onlyMissing; old saves read as before", function()
        local Config = loadConfig()
        local db = Config.Migrate(nil)
        assert.equal("all", Config.ShowMode(db))
        Config.SetShowMode(db, "missing")
        assert.same({ true, true, "missing" }, { db.showMissing, db.onlyMissing, Config.ShowMode(db) })
        Config.SetShowMode(db, "active")
        assert.same({ false, false, "active" }, { db.showMissing, db.onlyMissing, Config.ShowMode(db) })
        assert.equal("active", Config.ShowMode(Config.Migrate({ showMissing = false })))
    end)

    it("columns: 1 for new characters, 2 for a saved horizontal layout, broken values back to 1", function()
        local Config = loadConfig()
        assert.equal(1, Config.Migrate(nil).columns)
        assert.equal(2, Config.Migrate({ categoryLayout = "horizontal" }).columns)
        assert.equal(3, Config.Migrate({ columns = 3, categoryLayout = "horizontal" }).columns)
        assert.equal(1, Config.Migrate({ columns = 7 }).columns)
        local db = Config.Migrate({ columns = 3 })
        Config.RestoreDefaults(db)
        assert.equal(1, db.columns)
    end)
end)
