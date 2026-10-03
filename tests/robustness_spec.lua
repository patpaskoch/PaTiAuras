-- PaTiAuras: SavedVariables robustness (hardening 2026-10-02). Broken or odd saves must never break the login:
-- Migrate returns a usable table, keeps valid values (also false) and is idempotent. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Config.lua", {}).Config
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = copy(inner) end
    return result
end

local function migrate(M, db) return M.Migrate(db) end

-- Inputs a corrupted or hand-edited SavedVariables file could contain.
local BROKEN = {
    { name = "nil" }, { name = "false", value = false }, { name = "true", value = true }, { name = "0", value = 0 },
    { name = "-1", value = -1 }, { name = "string", value = "foo" }, { name = "empty table", value = {} },
    { name = "string schema", value = { schema = "foo" } }, { name = "negative schema", value = { schema = -3 } },
    { name = "future schema", value = { schema = 99 } }, { name = "string scale", value = { scale = "big" } },
    { name = "negative scale", value = { scale = -1 } }, { name = "huge scale", value = { scale = 100 } },
    { name = "zero scale", value = { scale = 0 } }, { name = "nested junk", value = { scale = { 1 }, locked = { x = 1 },
        language = 42, opacity = "x", unknownKey = { deep = { deeper = true } } } },
}

describe("PaTiAuras Migrate robustness", function()
    for _, case in ipairs(BROKEN) do
        it("survives a broken save: " .. case.name, function()
            local M = load()
            local ok, db = pcall(migrate, M, copy(case.value))
            assert.truthy(ok, "Migrate raised an error: " .. tostring(db))
            assert.equal("table", type(db))
            assert.equal("number", type(db.scale))
            assert.truthy(db.scale >= 0.5 and db.scale <= 2, "scale out of range: " .. tostring(db.scale))
            assert.equal("number", type(db.schema))
            assert.truthy(db.theme == "default" or db.theme == "woforever" or db.theme == "dracula", "theme")
        end)
    end

    it("is idempotent: Migrate(Migrate(db)) gives the same table", function()
        local M = load()
        for _, case in ipairs(BROKEN) do
            local once = migrate(M, copy(case.value))
            assert.same(copy(once), migrate(M, copy(once)), "not idempotent for " .. case.name)
        end
    end)

    it("keeps valid saved values, also false, and a valid scale", function()
        local M = load()
        local db = migrate(M, { schema = M.SCHEMA, locked = false, collapsed = true, scale = 1.25, point = "TOPLEFT",
            x = 5 })
        assert.same({ false, true, 1.25, "TOPLEFT", 5 }, { db.locked, db.collapsed, db.scale, db.point, db.x })
    end)
end)

describe("PaTiAuras watch choices in a broken save", function()
    it("a broken watch or seen table is replaced; valid choices (also false) stay", function()
        local Config = load()
        local db = Config.Migrate({ schema = 3, watch = { ROCKBITER_WEAPON = false, FORTITUDE = true }, seen = "x" })
        assert.same({ ROCKBITER_WEAPON = false, FORTITUDE = true }, db.watch)
        assert.same({}, db.seen)
        assert.same({}, Config.Migrate({ schema = 3, watch = 7 }).watch)
    end)
end)

describe("Theme setting (db.theme)", function()
    it("new saves get the default theme; a saved theme stays; unknown values fall back to default", function()
        local M = load()
        assert.equal("default", migrate(M, nil).theme)
        assert.equal("dracula", migrate(M, { schema = M.SCHEMA, theme = "dracula" }).theme)
        assert.equal("woforever", migrate(M, { schema = M.SCHEMA, theme = "woforever" }).theme)
        for _, bad in ipairs({ "Dracula", "neon", 3, true, {} }) do
            assert.equal("default", migrate(M, { schema = M.SCHEMA, theme = bad }).theme)
        end
    end)

    it("Restore Defaults goes back to the default theme", function()
        local M = load()
        assert.equal("default", M.RestoreDefaults(migrate(M, { schema = M.SCHEMA, theme = "dracula" })).theme)
    end)
end)
