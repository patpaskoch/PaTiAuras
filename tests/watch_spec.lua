-- PaTiAuras profiles + Watch together (profile registration, buff families, group states).
-- Run via PaTiAdmin/tools/check.sh. WoW APIs are mocked with plain tables; frames are not involved.
local wow = require("wow_api")

local NAMES = {
    [588] = "Inneres Feuer", [1243] = "Machtwort: Seelenstärke", [21562] = "Gebet der Seelenstärke",
    [14752] = "Göttlicher Willen", [27681] = "Gebet der Willenskraft", [976] = "Schattenschutz",
    [27683] = "Gebet des Schattenschutzes", [24398] = "Wasserschild", [974] = "Erdschild", [61295] = "Springflut",
    [53390] = "Flutwellen",
}

local world -- per test: class, known spells, units and their auras

local function aura(name, spellId, extra)
    local data = { name = name, spellId = spellId, applications = 0, expirationTime = 0, sourceUnit = "party1" }
    for key, value in pairs(extra or {}) do data[key] = value end
    return data
end

local function setup(class, known)
    wow.install()
    world = { class = class, known = known or {}, units = {}, inGroup = true }
    _G.UnitClass = function() return class, class end
    _G.C_Spell = { GetSpellInfo = function(id) return NAMES[id] and { name = NAMES[id] } end, GetSpellTexture = function() return 1 end }
    _G.C_SpellBook = { IsSpellKnown = function(id) return world.known[id] == true end }
    _G.GetNumSpellTabs, _G.issecretvalue, _G.UnitAura = nil, nil, nil
    _G.GetTime = function() return 1000 end
    _G.IsInGroup = function() return world.inGroup end
    _G.UnitExists = function(unit) return world.units[unit] ~= nil end
    _G.UnitName = function(unit) return world.units[unit].name end
    _G.UnitIsConnected = function(unit) return not world.units[unit].offline end
    _G.UnitIsDeadOrGhost = function(unit) return world.units[unit].dead == true end
    _G.UnitIsVisible = function(unit) return not world.units[unit].far end
    _G.C_UnitAuras = { GetAuraDataByIndex = function(unit, index)
        local u = world.units[unit]
        return u and u.auras and u.auras[index]
    end }
    local ns = {}
    for _, file in ipairs({ "Shared/Locales/enUS.lua", "Shared/Locale.lua", "Locales/enUS.lua", "Config.lua", "SpellBook.lua",
        "Auras.lua", "AuraScan.lua", "Profiles/Shaman.lua", "Profiles/Priest.lua", "Watch.lua" }) do
        wow.loadAddonFile(file, ns)
    end
    ns.Watch.testMode = false
    return ns, ns.Config.Migrate(nil)
end

local ALL_PRIEST = { [588] = true, [1243] = true, [21562] = true, [14752] = true, [27681] = true, [976] = true, [27683] = true }

local function groupLine(ns, db, key)
    for _, item in ipairs(ns.Watch.Group(db)) do
        if item.entry.key == key then return item.summary end
    end
end

describe("Priest profile", function()
    it("is registered for PRIEST (no more 'Profile none')", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        assert.equal("Priest", ns.Watch.ClassProfile().name)
        ns.Watch.Rebuild(db)
        assert.same({ personal = 1, procs = 0, group = 3, healing = 0 }, ns.Watch.Count())
    end)

    it("counts the Prayer version as the same buff as the single-target spell", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243) } },
            party1 = { name = "Tank", auras = { aura("Gebet der Seelenstärke", 21564) } }, -- another rank of the Prayer
            party2 = { name = "Mage", auras = {} },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local fortitude = groupLine(ns, db, "FORTITUDE")
        assert.equal(2, fortitude.have)
        assert.equal(3, fortitude.total)
        assert.same({ "Mage" }, fortitude.missing)
    end)

    it("handles Divine Spirit and Shadow Protection families the same way", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = { aura("Gebet der Willenskraft", 27681), aura("Schattenschutz", 976) } },
            party1 = { name = "Tank", auras = { aura("Göttlicher Willen", 14752), aura("Gebet des Schattenschutzes", 27683) } },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.equal(2, groupLine(ns, db, "DIVINE_SPIRIT").have)
        assert.equal(2, groupLine(ns, db, "SHADOW_PROTECTION").have)
    end)

    it("leaves offline and dead members out and follows joins/leaves", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = {} },
            party1 = { name = "Weg", offline = true },
            party2 = { name = "Tot", dead = true },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local fortitude = groupLine(ns, db, "FORTITUDE")
        assert.equal(1, fortitude.total)
        assert.same({ "Du" }, fortitude.missing)
        assert.same({ "Weg", "Tot" }, fortitude.away)
        world.units.party3 = { name = "Neu", auras = { aura("Gebet der Seelenstärke", 21562) } } -- joins
        world.units.party1 = nil                                                               -- leaves
        ns.Watch.RefreshAll()
        fortitude = groupLine(ns, db, "FORTITUDE")
        assert.equal(1, fortitude.have)
        assert.equal(2, fortitude.total)
        assert.same({ "Tot" }, fortitude.away)
    end)

    it("shows Inner Fire as personal aura, missing or active", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = { player = { name = "Du", auras = {} } }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.equal("MISSING", ns.Watch.Self(db)[1].result.state)
        world.units.player.auras = { aura("Inneres Feuer", 588, { sourceUnit = "player", applications = 20, expirationTime = 1600 }) }
        ns.Watch.RefreshUnit("player")
        local innerFire = ns.Watch.Self(db)[1]
        assert.equal("INNER_FIRE", innerFire.entry.key)
        assert.equal("ACTIVE", innerFire.result.state)
        assert.equal(20, innerFire.result.count)
    end)

    it("offers a group buff when only its Prayer version is known", function()
        local ns, db = setup("PRIEST", { [588] = true, [21562] = true })
        ns.Watch.Rebuild(db)
        assert.equal(1, ns.Watch.Count().group)
        assert.equal("FORTITUDE", ns.Watch.entries.group[1].key)
    end)

    it("shows group buffs solo, with yourself as the only member and click target", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.inGroup = false
        world.units = { player = { name = "Du", auras = {} } }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local fortitude = ns.Watch.Group(db)[1]
        assert.equal(0, fortitude.summary.have)
        assert.equal(1, fortitude.summary.total)
        assert.equal("player", fortitude.target.unit)
        world.units.player.auras = { aura("Machtwort: Seelenstärke", 1243) }
        ns.Watch.RefreshUnit("player")
        fortitude = ns.Watch.Group(db)[1]
        assert.equal(1, fortitude.summary.have)
        assert.is_nil(fortitude.target)
    end)
end)

describe("Click-to-buff target", function()
    local function target(ns, db, key)
        for _, item in ipairs(ns.Watch.Group(db)) do
            if item.entry.key == key then return item.target end
        end
    end

    it("points at the next missing member, one after another as buffs land", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243) } },
            party1 = { name = "A", auras = { aura("Gebet der Seelenstärke", 21562) } },
            party2 = { name = "C", auras = {} },
            party3 = { name = "D", auras = {} },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.equal("party2", target(ns, db, "FORTITUDE").unit)
        world.units.party2.auras = { aura("Machtwort: Seelenstärke", 1243) } -- first click landed
        ns.Watch.RefreshUnit("party2")
        assert.equal("party3", target(ns, db, "FORTITUDE").unit)
        world.units.party3.auras = { aura("Machtwort: Seelenstärke", 1243) }
        ns.Watch.RefreshUnit("party3")
        assert.is_nil(target(ns, db, "FORTITUDE"))                         -- 4/4: nothing to cast
    end)

    it("never targets offline, dead or out-of-sight members", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243) } },
            party1 = { name = "Weg", offline = true },
            party2 = { name = "Tot", dead = true },
            party3 = { name = "Fern", far = true, auras = {} },
            party4 = { name = "Da", auras = {} },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.equal("party4", target(ns, db, "FORTITUDE").unit)
        world.units.party4 = nil -- leaves the group
        ns.Watch.RefreshAll()
        assert.is_nil(target(ns, db, "FORTITUDE"))
    end)

    it("never picks a target when aura data is unreadable (UNKNOWN, not MISSING)", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243, { expirationTime = 1010 }) } },
        }
        _G.C_UnitAuras = { GetAuraDataByIndex = function() error("restricted") end }
        world.units.party1 = { name = "X" }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.is_nil(target(ns, db, "FORTITUDE"))
    end)
end)

describe("Test mode profile", function()
    it("uses the class profile, and the generic one for classes without a profile", function()
        local ns, db = setup("PRIEST", {})
        ns.Watch.testMode = true
        ns.Watch.Rebuild(db)
        assert.equal("Priest", ns.Watch.profile.name)
        assert.equal(3, ns.Watch.Count().group)
        ns = setup("WARRIOR", {})
        ns.Watch.testMode = true
        ns.Watch.Rebuild(ns.Config.Migrate(nil))
        assert.equal("Test", ns.Watch.profile.name)
    end)
end)

describe("Shaman profile (regression)", function()
    it("still tracks Water Shield, Tidal Waves, Earth Shield and Riptide", function()
        local ns, db = setup("SHAMAN", { [24398] = true, [974] = true, [61295] = true })
        ns.Watch.Rebuild(db)
        assert.equal("Restoration Shaman", ns.Watch.profile.name)
        assert.same({ personal = 1, procs = 1, group = 0, healing = 2 }, ns.Watch.Count())
    end)
end)
