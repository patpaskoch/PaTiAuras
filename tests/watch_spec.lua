-- PaTiAuras profiles + Watch together (profile registration, buff families, group states).
-- Run via PaTiAdmin/tools/check.sh. WoW APIs are mocked with plain tables; frames are not involved.
local wow = require("wow_api")

local NAMES = {
    [588] = "Inneres Feuer", [1243] = "Machtwort: Seelenstärke", [21562] = "Gebet der Seelenstärke",
    [14752] = "Göttlicher Willen", [27681] = "Gebet der Willenskraft", [976] = "Schattenschutz",
    [27683] = "Gebet des Schattenschutzes", [24398] = "Wasserschild", [974] = "Erdschild", [61295] = "Springflut",
    [53390] = "Flutwellen", [8017] = "Waffe des Felsbeißers", [8024] = "Waffe der Flammenzunge",
    [2383] = "Kräutersuche", [2580] = "Mineraliensuche",
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
        "Auras.lua", "AuraScan.lua", "WeaponImbues.lua", "Tracking.lua", "Profiles/Shaman.lua", "Profiles/Priest.lua",
        "Profiles/Tracking.lua", "Watch.lua" }) do
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
        assert.same({ personal = 1, procs = 0, group = 3, healing = 0, weapon = 0, tracking = 0 }, ns.Watch.Count()) -- healing IDs unknown to this mock client
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
    it("still tracks Water Shield, Tidal Waves, Earth Shield and Riptide, plus Rockbiter when known", function()
        local ns, db = setup("SHAMAN", { [24398] = true, [974] = true, [61295] = true, [8017] = true })
        ns.Watch.Rebuild(db)
        assert.equal("Restoration Shaman", ns.Watch.profile.name)
        assert.same({ personal = 1, procs = 1, group = 0, healing = 2, weapon = 1, tracking = 0 }, ns.Watch.Count())
    end)
end)

describe("Concrete weapon imbue: Rockbiter", function()
    local ROCKBITER = 8017
    local function weapon(ns, db)
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        return ns.Watch.Weapon(db)[1]
    end

    local function equip()
        _G.GetInventoryItemID = function(_, slot) return slot == 16 and 1 or nil end
        _G.GetInventoryItemTexture = function() return 1 end
        _G.GetItemInfoInstant = function(id) return id, "Weapon", "Axe", "INVTYPE_WEAPON", 1, 2, 0 end
    end

    -- Classic tuple (this test client has no C_Item): hasMainHand, ms left, charges, enchantID, off hand …
    local function mainHand(has, enchantID)
        _G.GetWeaponEnchantInfo = function() return has, has and 900000 or 0, 0, enchantID, false, 0, 0, 0 end
    end

    it("is offered only when you know the spell, and is named by its spell, not 'Main Hand'", function()
        local ns = setup("SHAMAN", {})
        local def = ns.Watch.ClassProfile().weapon[1]
        assert.is_false(ns.Watch.IsOffered(def, "weapon"))
        assert.same({ weapon = 0 }, { weapon = ns.Watch.Count().weapon })
        local db
        ns, db = setup("SHAMAN", { [ROCKBITER] = true })
        def = ns.Watch.ClassProfile().weapon[1]
        assert.is_true(ns.Watch.IsOffered(def, "weapon"))
        assert.equal("Waffe des Felsbeißers", ns.Watch.DefName(def))
        equip()
        mainHand(false, 0)
        assert.equal("Waffe des Felsbeißers", weapon(ns, db).entry.name)
        _G.GetWeaponEnchantInfo = nil
    end)

    it("ACTIVE only with its own enchant ID (29, owner-observed); none → MISSING; an unmapped ID → UNKNOWN", function()
        local ns, db = setup("SHAMAN", { [ROCKBITER] = true })
        equip()
        mainHand(true, 29)
        local item = weapon(ns, db)
        assert.equal("ACTIVE", item.result.state)
        assert.equal(900, item.result.remaining)
        mainHand(false, 0)
        assert.equal("MISSING", weapon(ns, db).result.state)
        mainHand(true, 5) -- some other temporary enchant nobody mapped: never counts as Rockbiter, never "missing"
        assert.equal("UNKNOWN", weapon(ns, db).result.state)
        mainHand(true, nil) -- ID unreadable
        assert.equal("UNKNOWN", weapon(ns, db).result.state)
        _G.GetWeaponEnchantInfo = nil
    end)

    it("no line without a weapon or while PaTiAuras is off; test mode shows it active without the API", function()
        local ns, db = setup("SHAMAN", { [ROCKBITER] = true })
        _G.GetInventoryItemID = function() return nil end
        mainHand(false, 0)
        assert.is_nil(weapon(ns, db))
        equip()
        db.enabled = false
        assert.is_nil(weapon(ns, db))
        db.enabled = true
        _G.GetWeaponEnchantInfo = function() error("test mode must not read the client") end
        ns.Watch.testMode = true
        assert.equal("ACTIVE", weapon(ns, db).result.state)
        ns.Watch.testMode = false
        _G.GetWeaponEnchantInfo = nil
    end)

    it("one wanted imbue per slot: switching one on switches the other off; another known imbue → MISSING", function()
        local ns, db = setup("SHAMAN", { [ROCKBITER] = true, [8024] = true })
        local profile = ns.Watch.ClassProfile()
        local flametongue = { key = "TEST_FLAMETONGUE", spellID = 8024, slot = "MAINHAND", enchantIDs = { 5 },
            castable = true }
        profile.weapon[2] = flametongue
        equip()
        mainHand(true, 5)
        local list = (function() ns.Watch.Rebuild(db); ns.Watch.RefreshAll(); return ns.Watch.Weapon(db) end)()
        assert.equal(1, #list) -- both watched by default: only the first per slot is the wanted one
        assert.equal("ROCKBITER_WEAPON", list[1].entry.key)
        assert.equal("MISSING", list[1].result.state)
        assert.is_true(list[1].result.wrong) -- Flametongue (ID 5) is on: known, but not the wanted imbue
        ns.Watch.SetWatched(db, flametongue, true, profile)
        assert.same({ false, true }, { db.watch.ROCKBITER_WEAPON, db.watch.TEST_FLAMETONGUE })
        assert.equal("ACTIVE", weapon(ns, db).result.state)
        ns.Watch.SetWatched(db, profile.weapon[1], false, profile) -- switching off touches nothing else
        assert.same({ false, true }, { db.watch.ROCKBITER_WEAPON, db.watch.TEST_FLAMETONGUE })
        profile.weapon[2] = nil
        _G.GetWeaponEnchantInfo = nil
    end)
end)

describe("Watch.IsOffered (what the new-auras dialog may show)", function()
    it("offers known spells or known variants, never unknown ones; procs always", function()
        local ns = setup("PRIEST", { [21562] = true })
        local profile = ns.Watch.ClassProfile()
        assert.is_true(ns.Watch.IsOffered(profile.group[1], "group"))      -- only Prayer of Fortitude known
        assert.is_false(ns.Watch.IsOffered(profile.group[2], "group"))     -- Divine Spirit unknown
        assert.is_false(ns.Watch.IsOffered(profile.personal[1], "personal")) -- Inner Fire unknown
        assert.is_true(ns.Watch.IsOffered({ key = "X", spellID = 1 }, "procs"))
    end)
end)

describe("Unit basics with secret values", function()
    it("replaces a secret name (tooltips concatenate names) and never reads a secret flag as offline", function()
        local ns, db = setup("PRIEST", ALL_PRIEST)
        local SECRET = setmetatable({}, { __eq = function() error("secret compared") end })
        _G.issecretvalue = function(value) return rawequal(value, SECRET) end
        _G.UnitIsConnected = function(unit) if unit == "party2" then return SECRET end return true end
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243) } },
            party2 = { name = SECRET, auras = {} },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local fortitude = groupLine(ns, db, "FORTITUDE")
        assert.same({ "Party member 2" }, fortitude.missing)
        assert.same({}, fortitude.away)
    end)
end)

describe("Priest healing auras", function()
    it("offers Renew, Power Word: Shield and Prayer of Mending; each can be switched off", function()
        NAMES[139], NAMES[17], NAMES[33076] = "Erneuerung", "Machtwort: Schild", "Gebet der Besserung"
        local known = { [139] = true, [17] = true, [33076] = true }
        for id in pairs(ALL_PRIEST) do known[id] = true end
        local ns, db = setup("PRIEST", known)
        ns.Watch.Rebuild(db)
        assert.equal(3, ns.Watch.Count().healing)
        db.watch.RENEW = false
        ns.Watch.Rebuild(db)
        assert.equal(2, ns.Watch.Count().healing)
        NAMES[139], NAMES[17], NAMES[33076] = nil, nil, nil
    end)

    it("shows only your own Renew on a member (mine), not another priest's", function()
        NAMES[139] = "Erneuerung"
        local known = { [139] = true }
        local ns, db = setup("PRIEST", known)
        world.units = {
            player = { name = "Du", auras = {} },
            party1 = { name = "Tank", auras = { aura("Erneuerung", 139, { sourceUnit = "party2" }) } },
            party2 = { name = "Other", auras = { aura("Erneuerung", 139, { sourceUnit = "player" }) } },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local names = {}
        for _, line in ipairs(ns.Watch.Healing(db)) do names[#names + 1] = line.name end
        assert.same({ "Other" }, names)
        NAMES[139] = nil
    end)
end)

describe("Watch.Choices (settings: what to watch)", function()
    it("offers only your class's entries the client knows, grouped self, procs, healing, weapon", function()
        local ns = setup("SHAMAN", { [24398] = true, [974] = true, [61295] = true, [8017] = true })
        local groups = {}
        for _, group in ipairs(ns.Watch.Choices(ns.Watch.ClassProfile())) do
            local keys = {}
            for _, def in ipairs(group.defs) do keys[#keys + 1] = def.key end
            groups[#groups + 1] = group.category .. ":" .. table.concat(keys, ",")
        end
        assert.same({ "personal:WATER_SHIELD", "procs:TIDAL_WAVES", "healing:EARTH_SHIELD,RIPTIDE",
            "weapon:ROCKBITER_WEAPON" }, groups)
    end)

    it("leaves out spells you do not know and IDs the client does not know", function()
        local ns = setup("PRIEST", { [588] = true }) -- only Inner Fire known
        local groups = ns.Watch.Choices(ns.Watch.ClassProfile())
        assert.equal(1, #groups)
        assert.equal("INNER_FIRE", groups[1].defs[1].key)
    end)

    it("switching one entry off hides exactly that entry", function()
        local ns, db = setup("SHAMAN", { [24398] = true, [974] = true, [61295] = true })
        ns.Watch.Rebuild(db)
        assert.equal(2, ns.Watch.Count().healing)
        db.watch.RIPTIDE = false
        ns.Watch.Rebuild(db)
        assert.equal(1, ns.Watch.Count().healing)
        assert.equal(1, ns.Watch.Count().personal)
    end)
end)

describe("Group buff alerts for PaTiAlerts (Watch.Group → Auras.GroupAlerts)", function()
    local TEXTS = { missing = "Missing", missingOn = "Missing on %d" }
    local function alerts(ns, db)
        return ns.Auras.GroupAlerts(ns.Watch.Group(db), TEXTS, db.showMissing, function() return false end)
    end
    local function alertFor(list, key)
        for _, alert in ipairs(list) do if alert.id == "group:" .. key then return alert end end
    end
    local FORT = { [1243] = true }

    it("solo: a watched buff you lack is one WARNING; active → no alert", function()
        local ns, db = setup("PRIEST", FORT)
        world.units = { player = { name = "Du", auras = {} } }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.same({ id = "group:FORTITUDE", priority = "WARNING", kind = "GROUP_AURA_MISSING",
            text = "Machtwort: Seelenstärke", detail = "Missing" }, alerts(ns, db)[1])
        world.units.player.auras = { aura("Machtwort: Seelenstärke", 1243, { expirationTime = 2000 }) }
        ns.Watch.RefreshAll()
        assert.same({}, alerts(ns, db))
    end)

    it("an unwatched buff and a buff you do not know never alert", function()
        local ns, db = setup("PRIEST", FORT) -- Divine Spirit / Shadow Protection not known
        world.units = { player = { name = "Du", auras = {} } }
        db.watch.FORTITUDE = false
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.same({}, alerts(ns, db))
    end)

    it("party: exactly one alert per buff with the number missing; offline and dead never count", function()
        local ns, db = setup("PRIEST", FORT)
        world.units = {
            player = { name = "Du", auras = { aura("Machtwort: Seelenstärke", 1243, { expirationTime = 2000 }) } },
            party1 = { name = "A", auras = {} },
            party2 = { name = "B", auras = {} },
            party3 = { name = "Weg", offline = true },
            party4 = { name = "Tot", dead = true },
        }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local list = alerts(ns, db)
        assert.equal(1, #list)
        assert.equal("Missing on 2", list[1].detail)
        world.units.party1.auras = { aura("Gebet der Seelenstärke", 21562, { expirationTime = 2000 }) }
        world.units.party2.auras = { aura("Machtwort: Seelenstärke", 1243, { expirationTime = 2000 }) }
        ns.Watch.RefreshAll()
        assert.is_nil(alertFor(alerts(ns, db), "FORTITUDE")) -- everyone has it → removed
    end)

    it("unreadable aura data (UNKNOWN) is never a missing alert; 'show missing' off sends nothing", function()
        local ns, db = setup("PRIEST", FORT)
        world.units = { player = { name = "Du" }, party1 = { name = "X" } }
        _G.C_UnitAuras = { GetAuraDataByIndex = function() error("restricted") end }
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        assert.same({}, alerts(ns, db))
        _G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
        ns.Watch.RefreshAll()
        assert.equal(1, #alerts(ns, db))
        db.showMissing = false
        assert.same({}, alerts(ns, db))
    end)
end)

describe("Weapon imbue: 0 or 1 wanted per slot — deselecting means no imbue (owner 2026-10-02)", function()
    local function equip()
        _G.GetInventoryItemID = function(_, slot) return slot == 16 and 1 or nil end
        _G.GetInventoryItemTexture = function() return 1 end
        _G.GetItemInfoInstant = function(id) return id, "Weapon", "Axe", "INVTYPE_WEAPON", 1, 2, 0 end
        _G.GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end -- Rockbiter missing
    end
    local function weaponList(ns, db)
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        return ns.Watch.Weapon(db)
    end
    local function alerts(ns, db)
        return ns.Auras.Alerts(weaponList(ns, db), { missing = "Fehlt", expiring = "x", imbueMissing = "Waffenbuff fehlt",
            imbueExpiring = "y" }, db.showMissing, function() return false end)
    end

    it("Rockbiter on → watched and missing (alert); off → no line, no alert (no generic fallback); on again → back", function()
        local ns, db = setup("SHAMAN", { [8017] = true })
        local profile = ns.Watch.ClassProfile()
        equip()
        assert.equal("MISSING", weaponList(ns, db)[1].result.state)
        assert.equal("Waffe des Felsbeißers", alerts(ns, db)[1].text)
        ns.Watch.SetWatched(db, profile.weapon[1], false, profile)
        assert.is_false(db.watch.ROCKBITER_WEAPON)
        assert.same({}, weaponList(ns, db)) -- nothing to show, so no click button either (AuraWindow arms per line)
        assert.same({}, alerts(ns, db))
        ns.Watch.SetWatched(db, profile.weapon[1], true, profile)
        assert.equal("MISSING", weaponList(ns, db)[1].result.state)
        assert.equal(1, #alerts(ns, db))
        _G.GetWeaponEnchantInfo = nil
    end)

    it("a deselected imbue stays off after /reload (migration) and every rebuild", function()
        local ns, db = setup("SHAMAN", { [8017] = true })
        local profile = ns.Watch.ClassProfile()
        equip()
        ns.Watch.SetWatched(db, profile.weapon[1], false, profile)
        db.seen.ROCKBITER_WEAPON = true
        db = ns.Config.Migrate(db, profile) -- what PLAYER_LOGIN does after /reload
        assert.is_false(db.watch.ROCKBITER_WEAPON)
        weaponList(ns, db)
        assert.same({}, weaponList(ns, db))
        assert.is_false(db.watch.ROCKBITER_WEAPON)
        _G.GetWeaponEnchantInfo = nil
    end)

    it("two imbues: A on → B on switches A off; B clicked again → none; nothing moves up by itself", function()
        local ns, db = setup("SHAMAN", { [8017] = true, [8024] = true })
        local profile = ns.Watch.ClassProfile()
        local a, b = profile.weapon[1], { key = "TEST_FLAMETONGUE", spellID = 8024, slot = "MAINHAND", enchantIDs = { 5 } }
        profile.weapon[2] = b
        equip()
        ns.Watch.SetWatched(db, a, true, profile)
        ns.Watch.SetWatched(db, b, true, profile)
        assert.same({ false, true }, { db.watch.ROCKBITER_WEAPON, db.watch.TEST_FLAMETONGUE })
        assert.equal("TEST_FLAMETONGUE", weaponList(ns, db)[1].entry.key)
        ns.Watch.SetWatched(db, b, false, profile)
        assert.same({ false, false }, { db.watch.ROCKBITER_WEAPON, db.watch.TEST_FLAMETONGUE })
        assert.same({}, weaponList(ns, db))
        profile.weapon[2] = nil
        _G.GetWeaponEnchantInfo = nil
    end)

    it("deselecting the default one with an undecided second imbue: none, not the second", function()
        local ns, db = setup("SHAMAN", { [8017] = true, [8024] = true })
        local profile = ns.Watch.ClassProfile()
        profile.weapon[2] = { key = "TEST_FLAMETONGUE", spellID = 8024, slot = "MAINHAND", enchantIDs = { 5 } }
        equip()
        assert.equal("ROCKBITER_WEAPON", weaponList(ns, db)[1].entry.key) -- both undecided: the first one
        ns.Watch.SetWatched(db, profile.weapon[1], false, profile)
        assert.same({}, weaponList(ns, db))
        db.watch = { TEST_FLAMETONGUE = true } -- an explicit choice wins over an undecided earlier entry
        assert.equal("TEST_FLAMETONGUE", weaponList(ns, db)[1].entry.key)
        profile.weapon[2] = nil
        _G.GetWeaponEnchantInfo = nil
    end)
end)

describe("Profession tracking in the watch (owner 2026-10-02)", function()
    it("is in every class profile, offered only when learned, 0 or 1 wanted, missing one is cast with a click", function()
        local ns, db = setup("SHAMAN", { [2383] = true, [2580] = true })
        local profile = ns.Watch.ClassProfile()
        assert.equal(ns.AuraTracking, profile.tracking)
        assert.equal(ns.AuraTracking, ns.AuraProfiles.PRIEST.tracking)
        local choices = {}
        for _, group in ipairs(ns.Watch.Choices(profile)) do
            if group.category == "tracking" then for _, def in ipairs(group.defs) do choices[#choices + 1] = def.key end end
        end
        assert.same({ "FIND_HERBS", "FIND_MINERALS" }, choices) -- treasure not learned: not offered
        _G.GetTrackingTexture = function() return nil end -- nothing tracked
        ns.Watch.Rebuild(db)
        ns.Watch.RefreshAll()
        local list = ns.Watch.Tracking(db)
        assert.equal(1, #list) -- both undecided: only the first is the wanted one
        assert.same({ "FIND_HERBS", "MISSING" }, { list[1].entry.key, list[1].result.state })
        local actions = ns.Auras.LineActions(list[1], "Kräutersuche", function() return false end)
        assert.same({ cast = "Kräutersuche" }, actions)
        ns.Watch.SetWatched(db, profile.tracking[2], true, profile) -- minerals wanted: herbs off
        assert.same({ false, true }, { db.watch.FIND_HERBS, db.watch.FIND_MINERALS })
        ns.Watch.SetWatched(db, profile.tracking[2], false, profile) -- none
        ns.Watch.Rebuild(db)
        assert.same({}, ns.Watch.Tracking(db))
        _G.GetTrackingTexture = nil
    end)
end)
