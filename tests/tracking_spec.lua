-- PaTiAuras profession tracking: adapter with mocked tracking APIs and the pure state rules. Run via
-- PaTiAdmin/tools/check.sh. What the Forever client really returns is a manual test (/pa auras).
local wow = require("wow_api")

local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })

local function load()
    wow.install()
    _G.issecretvalue = function(value) return rawequal(value, SECRET) end
    _G.C_Minimap, _G.GetNumTrackingTypes, _G.GetTrackingInfo, _G.GetTrackingTexture = nil, nil, nil, nil
    return wow.loadAddonFile("Tracking.lua", {}).Tracking
end

local HERBS = { name = "Kräutersuche", icon = 133939, ids = { [2383] = true } }

describe("Tracking.Evaluate", function()
    it("from the tracking list: on → ACTIVE; another on → MISSING (wrong); none on → MISSING", function()
        local Tracking = load()
        local read = { listRead = true, list = {
            { name = "Kräutersuche", spellID = 2383, active = true }, { name = "Mineraliensuche", spellID = 2580, active = false } } }
        assert.equal("ACTIVE", Tracking.Evaluate(HERBS, read).state)
        read.list[1].active, read.list[2].active = false, true
        local wrong = Tracking.Evaluate(HERBS, read)
        assert.same({ "MISSING", true }, { wrong.state, wrong.wrong })
        read.list[2].active = false
        assert.same({ "MISSING", nil }, { Tracking.Evaluate(HERBS, read).state, Tracking.Evaluate(HERBS, read).wrong })
    end)

    it("matches by name when the client gives no spell ID", function()
        local Tracking = load()
        local read = { listRead = true, list = { { name = "Kräutersuche", active = true } } }
        assert.equal("ACTIVE", Tracking.Evaluate(HERBS, read).state)
    end)

    it("an unreadable flag or a list without this tracking is never MISSING by guess", function()
        local Tracking = load()
        assert.equal("UNKNOWN", Tracking.Evaluate(HERBS,
            { listRead = true, list = { { name = "Kräutersuche", activeUnreadable = true } } }).state)
        assert.equal("UNKNOWN", Tracking.Evaluate(HERBS, { listRead = true, list = { { name = "Other", active = false } } }).state)
        assert.equal("UNKNOWN", Tracking.Evaluate(HERBS, { list = {} }).state)
    end)

    it("only the active texture (classic): same icon → ACTIVE, none → MISSING, other → MISSING, other type → UNKNOWN", function()
        local Tracking = load()
        assert.equal("ACTIVE", Tracking.Evaluate(HERBS, { list = {}, textureRead = true, texture = 133939 }).state)
        assert.equal("MISSING", Tracking.Evaluate(HERBS, { list = {}, textureRead = true, texture = nil }).state)
        assert.is_true(Tracking.Evaluate(HERBS, { list = {}, textureRead = true, texture = 136025 }).wrong)
        assert.equal("UNKNOWN", Tracking.Evaluate(HERBS,
            { list = {}, textureRead = true, texture = "Interface/Icons/INV_Misc_Flower_02" }).state)
    end)

    it("shown as a buff counts as ACTIVE", function()
        local Tracking = load()
        assert.equal("ACTIVE", Tracking.Evaluate(HERBS, { list = {} }, true).state)
    end)
end)

describe("Tracking.Read / ParseInfo", function()
    it("reads C_Minimap info tables and secret flags as unreadable", function()
        local Tracking = load()
        local infos = { { name = "Kräutersuche", texture = 133939, active = true, spellID = 2383 },
            { name = "Mineraliensuche", texture = 136025, active = SECRET, spellID = 2580 } }
        _G.C_Minimap = { GetNumTrackingTypes = function() return #infos end, GetTrackingInfo = function(i) return infos[i] end }
        local read = Tracking.Read()
        assert.is_true(read.listRead)
        assert.same({ true, nil }, { read.list[1].active, read.list[1].activeUnreadable })
        assert.same({ nil, true }, { read.list[2].active, read.list[2].activeUnreadable })
    end)

    it("reads the classic values (name, texture, active, type, subType, spellID) and 1/nil flags", function()
        local Tracking = load()
        _G.GetNumTrackingTypes = function() return 1 end
        _G.GetTrackingInfo = function() return "Kräutersuche", 133939, 1, "spell", nil, 2383 end
        local info = Tracking.Read().list[1]
        assert.same({ "Kräutersuche", 133939, true, 2383 }, { info.name, info.texture, info.active, info.spellID })
    end)

    it("an erroring API is unreadable, never 'nothing tracked'; GetTrackingTexture alone works", function()
        local Tracking = load()
        _G.GetNumTrackingTypes = function() error("restricted") end
        _G.GetTrackingInfo = function() end
        assert.is_nil(Tracking.Read().listRead)
        _G.GetTrackingTexture = function() return 133939 end
        local read = Tracking.Read()
        assert.same({ true, 133939 }, { read.textureRead, read.texture })
        assert.truthy(Tracking.Describe()[1]:find("GetTrackingTexture yes", 1, true))
    end)
end)
