-- PaTiAuras aura reading: unreadable data must become UNKNOWN, never MISSING. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local SETTINGS = { enabled = true, showTimers = true, showCharges = true, showMissing = true, showExpiring = true, watch = {} }
local RIPTIDE = { key = "RIPTIDE", ids = { [61295] = true }, names = { ["Springflut"] = true } }

local function load()
    local ns = wow.loadAddonFile("Auras.lua", {})
    return wow.loadAddonFile("AuraScan.lua", ns)
end

local function withAuras(fn)
    wow.install()
    _G.UnitAura = nil
    _G.issecretvalue = nil
    _G.C_UnitAuras = { GetAuraDataByIndex = fn }
end

describe("AuraScan.Read", function()
    it("reads plain aura data", function()
        withAuras(function(_, index)
            if index == 1 then return { name = "Springflut", spellId = 61295, applications = 0, expirationTime = 1008, sourceUnit = "player" } end
        end)
        local ns = load()
        local auras = ns.AuraScan.Read("party1", "HELPFUL")
        assert.equal(1, #auras)
        assert.equal("ACTIVE", ns.Auras.Evaluate(RIPTIDE, auras, 1000, SETTINGS).state)
    end)

    it("turns a failing API call into UNKNOWN instead of MISSING", function()
        withAuras(function() error("attempt to compare a secret value") end)
        local ns = load()
        local auras = ns.AuraScan.Read("party1", "HELPFUL")
        assert.equal("UNKNOWN", ns.Auras.Evaluate(RIPTIDE, auras, 1000, SETTINGS).state)
        assert.matches("secret value", ns.AuraScan.lastError)
    end)

    it("flags secret fields without comparing them", function()
        local secret = setmetatable({}, { __eq = function() error("compared a secret value") end })
        withAuras(function(_, index) if index == 1 then return { name = secret, spellId = secret } end end)
        _G.issecretvalue = function(value) return value == nil and false or rawequal(value, secret) end
        local ns = load()
        local auras = ns.AuraScan.Read("party1", "HELPFUL")
        assert.is_true(auras[1].secret)
        assert.equal("UNKNOWN", ns.Auras.Evaluate(RIPTIDE, auras, 1000, SETTINGS).state)
        _G.issecretvalue = nil
    end)

    it("reports a missing aura as MISSING when everything is readable", function()
        withAuras(function() return nil end)
        local ns = load()
        assert.equal("MISSING", ns.Auras.Evaluate(RIPTIDE, ns.AuraScan.Read("party1", "HELPFUL"), 1000, SETTINGS).state)
    end)
end)
