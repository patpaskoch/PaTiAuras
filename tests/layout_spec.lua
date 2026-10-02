-- PaTiAuras category layout (vertical / horizontal) and its setting. Run via PaTiAdmin/tools/check.sh.
-- The window code (frames, secure buttons) is tested in game; this covers the pure placement it relies on.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Auras.lua", {}).Auras
end

local function loadConfig()
    return wow.loadAddonFile("Config.lua", {}).Config
end

local COLUMN, GAP, WIDE = 214, 12, 2000
-- Typical blocks: GROUP (header + 3), WEAPON (header + 1), SELF (header + 2), TRACKING (header + 1); line = 20 px.
local function blocks()
    return { { key = "SECTION_GROUP", height = 80 }, { key = "SECTION_WEAPON", height = 40 },
        { key = "SECTION_SELF", height = 60 }, { key = "SECTION_TRACKING", height = 40 } }
end

describe("Auras.PlaceBlocks", function()
    it("vertical: one block in line order, exactly the layout of before (x 0, y 0)", function()
        local origins, width, height = load().PlaceBlocks({ { key = "ALL", height = 220 } }, "vertical", COLUMN, GAP,
            WIDE)
        assert.same({ x = 0, y = 0 }, origins.ALL)
        assert.equal(COLUMN, width)
        assert.equal(220, height)
    end)

    it("vertical with several blocks stacks them without gaps", function()
        local origins, width, height = load().PlaceBlocks(blocks(), "vertical", COLUMN, GAP, WIDE)
        assert.same({ 0, 80, 120, 180 }, { origins.SECTION_GROUP.y, origins.SECTION_WEAPON.y, origins.SECTION_SELF.y,
            origins.SECTION_TRACKING.y })
        assert.equal(COLUMN, width)
        assert.equal(220, height)
    end)

    it("horizontal: one column per category side by side; the window is as tall as the tallest column", function()
        local origins, width, height = load().PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, WIDE)
        assert.same({ x = 0, y = 0 }, origins.SECTION_GROUP)
        assert.same({ x = COLUMN + GAP, y = 0 }, origins.SECTION_WEAPON)
        assert.same({ x = 2 * (COLUMN + GAP), y = 0 }, origins.SECTION_SELF)
        assert.same({ x = 3 * (COLUMN + GAP), y = 0 }, origins.SECTION_TRACKING)
        assert.equal(4 * COLUMN + 3 * GAP, width)
        assert.equal(80, height)
    end)

    it("horizontal on a narrow screen wraps into a second row of columns below the tallest of the first", function()
        local origins, width, height = load().PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, 2 * COLUMN + GAP)
        assert.same({ x = 0, y = 0 }, origins.SECTION_GROUP)
        assert.same({ x = COLUMN + GAP, y = 0 }, origins.SECTION_WEAPON)
        assert.same({ x = 0, y = 80 + GAP }, origins.SECTION_SELF)
        assert.same({ x = COLUMN + GAP, y = 80 + GAP }, origins.SECTION_TRACKING)
        assert.equal(2 * COLUMN + GAP, width)
        assert.equal(80 + GAP + 60, height)
    end)

    it("a screen narrower than one column still shows every column (one per row)", function()
        local origins = load().PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, 100)
        assert.same({ 0, 0, 0, 0 }, { origins.SECTION_GROUP.x, origins.SECTION_WEAPON.x, origins.SECTION_SELF.x,
            origins.SECTION_TRACKING.x })
        assert.equal(80 + GAP + 40 + GAP + 60 + GAP, origins.SECTION_TRACKING.y)
    end)

    it("different column sizes and a single (or no) category", function()
        local Auras = load()
        local origins, width, height = Auras.PlaceBlocks({ { key = "SECTION_SELF", height = 20 } }, "horizontal",
            COLUMN, GAP, WIDE)
        assert.same({ x = 0, y = 0 }, origins.SECTION_SELF)
        assert.same({ COLUMN, 20 }, { width, height })
        local none, noWidth, noHeight = Auras.PlaceBlocks({}, "horizontal", COLUMN, GAP, WIDE)
        assert.same({}, none)
        assert.same({ 0, 0 }, { noWidth, noHeight })
    end)

    it("GROUP (secure buff buttons) starts at the top left in both layouts", function()
        local Auras = load()
        assert.same({ x = 0, y = 0 }, Auras.PlaceBlocks(blocks(), "vertical", COLUMN, GAP, WIDE).SECTION_GROUP)
        assert.same({ x = 0, y = 0 }, Auras.PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, WIDE).SECTION_GROUP)
    end)
end)

describe("Combat: frozen layout (secure buttons cannot move)", function()
    it("known columns keep their origin even when a column grows in combat", function()
        local Auras = load()
        local origins, _, height = Auras.PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, 2 * COLUMN + GAP)
        local frozen = { origins = origins, height = height }
        local grown = blocks()
        grown[2].height = 100 -- WEAPON taller (e.g. a new line): SELF below it must not move
        local again = Auras.PlaceBlocks(grown, "horizontal", COLUMN, GAP, 2 * COLUMN + GAP, frozen)
        assert.same(origins.SECTION_SELF, again.SECTION_SELF)
        assert.same(origins.SECTION_TRACKING, again.SECTION_TRACKING)
    end)

    it("a category that appears in combat goes below everything, the others stay", function()
        local Auras = load()
        local start = { blocks()[1], blocks()[3] } -- GROUP + SELF at combat start
        local origins, _, height = Auras.PlaceBlocks(start, "horizontal", COLUMN, GAP, WIDE)
        local now = { blocks()[1], blocks()[3], { key = "SECTION_TRACKING", height = 40 } }
        local again = Auras.PlaceBlocks(now, "horizontal", COLUMN, GAP, WIDE, { origins = origins, height = height })
        assert.same(origins.SECTION_GROUP, again.SECTION_GROUP)
        assert.same(origins.SECTION_SELF, again.SECTION_SELF)
        assert.same({ x = 0, y = 80 }, again.SECTION_TRACKING)
    end)

    it("switching the layout in combat keeps the combat-start origins (frozen wins over the new layout)", function()
        local Auras = load()
        local origins, _, height = Auras.PlaceBlocks(blocks(), "horizontal", COLUMN, GAP, WIDE)
        local again = Auras.PlaceBlocks(blocks(), "vertical", COLUMN, GAP, WIDE, { origins = origins, height = height })
        for key, origin in pairs(origins) do assert.same(origin, again[key]) end
    end)
end)

describe("Auras.ColumnWidth (long localized names)", function()
    it("never narrower than the vertical width", function()
        assert.equal(214, load().ColumnWidth({ 120, 150 }, 214, 320))
    end)

    it("grows for a long name so nothing is cut off, up to the maximum", function()
        local Auras = load()
        assert.equal(260, Auras.ColumnWidth({ 120, 259.4 }, 214, 320)) -- e.g. a long German name + its value
        assert.equal(320, Auras.ColumnWidth({ 500 }, 214, 320)) -- beyond: "…", full name in the tooltip
        assert.equal(214, Auras.ColumnWidth({}, 214, 320)) -- empty category list
    end)
end)

describe("Setting: Display → Category layout", function()
    it("new characters and old saves keep the vertical layout (no surprise for existing installs)", function()
        local Config = loadConfig()
        assert.equal("vertical", Config.Migrate(nil).categoryLayout)
        assert.equal("vertical", Config.Migrate({ schema = 3, watch = {} }).categoryLayout)
    end)

    it("a saved horizontal layout stays; an unknown value becomes vertical", function()
        local Config = loadConfig()
        assert.equal("horizontal", Config.Migrate({ schema = 3, categoryLayout = "horizontal" }).categoryLayout)
        assert.equal("vertical", Config.Migrate({ schema = 3, categoryLayout = "diagonal" }).categoryLayout)
        assert.equal("vertical", Config.Migrate({ schema = 3, categoryLayout = 42 }).categoryLayout)
    end)

    it("Restore Defaults goes back to vertical; the layout list matches the setting values", function()
        assert.equal("vertical", loadConfig().RestoreDefaults({ categoryLayout = "horizontal" }).categoryLayout)
        assert.same({ "vertical", "horizontal" }, load().CATEGORY_LAYOUTS)
    end)
end)
