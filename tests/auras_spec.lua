-- PaTiAuras aura state logic. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Auras.lua", {}).Auras
end

local function entry(fields)
    local result = { key = "RIPTIDE", ids = { [61295] = true }, names = { ["Springflut"] = true } }
    for key, value in pairs(fields or {}) do result[key] = value end
    return result
end

local NOW = 1000

local function defaults()
    return { enabled = true, showTimers = true, showCharges = true, showMissing = true, showExpiring = true, watch = {} }
end

describe("Auras.Evaluate", function()
    local Auras, settings
    before_each(function()
        Auras = load()
        settings = defaults()
    end)

    it("finds an aura by spell ID and reports remaining time and charges", function()
        local result = Auras.Evaluate(entry(), { { spellId = 61295, expiration = NOW + 8, count = 0 } }, NOW, settings)
        assert.equal("ACTIVE", result.state)
        assert.equal(8, result.remaining)
    end)

    it("finds another rank by its name", function()
        local result = Auras.Evaluate(entry(), { { name = "Springflut", spellId = 61299 } }, NOW, settings)
        assert.equal("ACTIVE", result.state)
    end)

    it("reports MISSING when the aura is absent", function()
        assert.equal("MISSING", Auras.Evaluate(entry(), { { name = "Other" } }, NOW, settings).state)
    end)

    it("reports UNKNOWN instead of MISSING when auras are unreadable (secret values)", function()
        assert.equal("UNKNOWN", Auras.Evaluate(entry(), { { secret = true } }, NOW, settings).state)
    end)

    it("marks EXPIRING below the threshold only for entries that allow it", function()
        local auras = { { spellId = 61295, expiration = NOW + 10 } }
        assert.equal("EXPIRING", Auras.Evaluate(entry({ expiring = true }), auras, NOW, settings).state)
        assert.equal("ACTIVE", Auras.Evaluate(entry(), auras, NOW, settings).state)
        settings.showExpiring = false
        assert.equal("ACTIVE", Auras.Evaluate(entry({ expiring = true }), auras, NOW, settings).state)
    end)

    it("ignores other players' auras for 'mine' entries", function()
        local auras = { { spellId = 61295, fromPlayer = false } }
        assert.equal("MISSING", Auras.Evaluate(entry({ mine = true }), auras, NOW, settings).state)
        assert.equal("ACTIVE", Auras.Evaluate(entry(), auras, NOW, settings).state)
    end)

    it("does not calculate with a secret timer", function()
        local result = Auras.Evaluate(entry(), { { spellId = 61295, timerSecret = true } }, NOW, settings)
        assert.equal("ACTIVE", result.state)
        assert.is_nil(result.remaining)
    end)
end)

describe("Auras.IconText", function()
    it("prefers charges for counting entries, else the remaining time", function()
        local Auras = load()
        local settings = defaults()
        local format = function(seconds) return seconds .. "s" end
        assert.equal("5", Auras.IconText(entry({ showCount = true }), { state = "ACTIVE", count = 5, remaining = 300 }, settings, format))
        assert.equal("7s", Auras.IconText(entry(), { state = "ACTIVE", remaining = 7 }, settings, format))
        settings.showTimers = false
        assert.is_nil(Auras.IconText(entry(), { state = "ACTIVE", remaining = 7 }, settings, format))
        assert.is_nil(Auras.IconText(entry(), { state = "MISSING" }, settings, format))
    end)
end)

describe("Auras.Summarize", function()
    it("counts buffed members and leaves offline/dead members out", function()
        local summary = load().Summarize({
            { name = "Du", result = { state = "ACTIVE" } },
            { name = "Tank", result = { state = "EXPIRING" } },
            { name = "Mage", result = { state = "MISSING" } },
            { name = "Priest", result = { state = "UNKNOWN" } },
            { name = "Hunter", unitState = "OFFLINE", result = { state = "MISSING" } },
        })
        assert.equal(2, summary.have)
        assert.equal(4, summary.total)
        assert.same({ "Mage" }, summary.missing)
        assert.equal(1, summary.unknown)
        assert.same({ "Hunter" }, summary.away)
    end)
end)

describe("Auras.IsWatched", function()
    it("watches entries unless switched off, and nothing when disabled", function()
        local Auras = load()
        local settings = defaults()
        settings.watch.RIPTIDE = false
        assert.is_false(Auras.IsWatched(settings, { key = "RIPTIDE" }))
        assert.is_true(Auras.IsWatched(settings, { key = "EARTH_SHIELD" }))
        settings.enabled = false
        assert.is_false(Auras.IsWatched(settings, { key = "EARTH_SHIELD" }))
    end)
end)

describe("Auras.NextTarget", function()
    it("returns the first reachable, living member with the buff MISSING", function()
        local next = load().NextTarget({
            { unit = "player", result = { state = "ACTIVE" } },
            { unit = "party1", unitState = "OFFLINE", result = { state = "MISSING" } },
            { unit = "party2", reachable = false, result = { state = "MISSING" } },
            { unit = "party3", result = { state = "UNKNOWN" } },
            { unit = "party4", result = { state = "MISSING" } },
        })
        assert.equal("party4", next.unit)
    end)

    it("returns nil when nobody needs the buff", function()
        assert.is_nil(load().NextTarget({ { unit = "player", result = { state = "EXPIRING" } } }))
    end)
end)

describe("Auras.Alerts (for the optional PaTiAlerts)", function()
    local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })
    local function isSecret(value) return rawequal(value, SECRET) end
    local TEXTS = { missing = "missing", expiring = "expiring", imbueMissing = "imbue missing", imbueExpiring = "imbue expiring" }
    local function item(key, category, state, name)
        return { entry = { key = key, category = category, name = name or key }, result = { state = state } }
    end

    it("sends MISSING and EXPIRING buffs and weapon imbues as WARNING", function()
        local Auras = wow.loadAddonFile("Auras.lua", {}).Auras
        local alerts = Auras.Alerts({ item("WATER_SHIELD", "personal", "MISSING", "Wasserschild"),
            item("MAIN_HAND_IMBUE", "weapon", "MISSING", "Waffenhand"), item("INNER_FIRE", "personal", "EXPIRING") },
            TEXTS, true, isSecret)
        assert.same({ id = "aura:WATER_SHIELD", priority = "WARNING", kind = "AURA_MISSING", text = "Wasserschild",
            detail = "missing" }, alerts[1])
        assert.same({ id = "weapon:MAIN_HAND_IMBUE", priority = "WARNING", kind = "WEAPON_IMBUE_MISSING",
            text = "Waffenhand", detail = "imbue missing" }, alerts[2])
        assert.equal("AURA_EXPIRING", alerts[3].kind)
    end)

    it("sends nothing for ACTIVE (the alert disappears), UNKNOWN (never 'missing') and procs", function()
        local Auras = wow.loadAddonFile("Auras.lua", {}).Auras
        assert.same({}, Auras.Alerts({ item("A", "personal", "ACTIVE"), item("B", "personal", "UNKNOWN"),
            item("C", "weapon", "UNKNOWN"), item("D", "weapon", "ACTIVE"), item("E", "procs", "EXPIRING") }, TEXTS, true, isSecret))
    end)

    it("follows showMissing and never sends a name that is not a plain string", function()
        local Auras = wow.loadAddonFile("Auras.lua", {}).Auras
        assert.same({}, Auras.Alerts({ item("A", "personal", "MISSING") }, TEXTS, false, isSecret))
        assert.same({}, Auras.Alerts({ item("A", "personal", "MISSING", SECRET) }, TEXTS, true, isSecret))
    end)
end)

describe("Auras.GroupAlerts (pure)", function()
    local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })
    local function isSecret(value) return rawequal(value, SECRET) end
    local TEXTS = { missing = "Missing", missingOn = "Missing on %d" }
    local function group(name, missing, total)
        return { entry = { key = "FORTITUDE", name = name }, summary = { missing = missing, total = total } }
    end

    it("never sends a secret or empty name; nothing when nobody lacks the buff", function()
        local Auras = wow.loadAddonFile("Auras.lua", {}).Auras
        assert.same({}, Auras.GroupAlerts({ group(SECRET, { "A" }, 2), group("", { "A" }, 2) }, TEXTS, true, isSecret))
        assert.same({}, Auras.GroupAlerts({ group("Fort", {}, 3) }, TEXTS, true, isSecret))
        assert.equal("Missing on 1", Auras.GroupAlerts({ group("Fort", { "A" }, 3) }, TEXTS, true, isSecret)[1].detail)
    end)
end)
