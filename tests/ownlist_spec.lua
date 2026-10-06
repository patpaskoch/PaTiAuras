-- PaTiAuras own list (OwnList.lua): kinds of listed spells and learning weapon imbues on cast.
-- Run via PaTiAdmin/tools/check.sh. Pure logic, no WoW API.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("OwnList.lua", {}).OwnList
end

local PROFILE = {
    personal = { { key = "LIGHTNING_SHIELD", spellID = 324 } },
    procs = { { key = "TIDAL_WAVES", spellID = 53390 } },
    weapon = { { key = "ROCKBITER_WEAPON", spellID = 8017, slot = "MAINHAND", enchantIDs = { 29 } } },
    tracking = { { key = "FIND_HERBS", spellID = 2383, slot = "TRACKING" } },
}

local function kinds(list)
    local out = {}
    for _, item in ipairs(list) do out[#out + 1] = item.def.key .. "=" .. item.category end
    return out
end

describe("OwnList.Classify", function()
    it("profile spells keep their kind; anything else is a buff on you (OWN:<id>); zeros are skipped", function()
        local OwnList = load()
        local list = OwnList.Classify({ 8017, 0, 324, 53390, 2383, 588 }, {}, PROFILE)
        assert.same({ "ROCKBITER_WEAPON=weapon", "LIGHTNING_SHIELD=personal", "TIDAL_WAVES=procs",
            "FIND_HERBS=tracking", "OWN:588=personal" }, kinds(list))
        assert.is_true(list[5].def.castable)
    end)

    it("the proc mark wins over the profile (true = proc, false = buff)", function()
        local OwnList = load()
        local list = OwnList.Classify({ 588, 53390 }, { ownProcs = { [588] = true, [53390] = false } }, PROFILE)
        assert.same({ "OWN:588=procs", "TIDAL_WAVES=personal" }, kinds(list))
    end)

    it("a learned imbue is a weapon entry on its hand; a profile imbue adds the learned IDs to its own", function()
        local OwnList = load()
        local db = { imbues = { [8024] = { slot = "OFFHAND", enchantIDs = { 5 } }, [8017] = { slot = "MAINHAND",
            enchantIDs = { 503 } } } }
        local list = OwnList.Classify({ 8024, 8017 }, db, PROFILE)
        assert.same({ "OWN:8024=weapon", "ROCKBITER_WEAPON=weapon" }, kinds(list))
        assert.same({ "OFFHAND", { 5 } }, { list[1].def.slot, list[1].def.enchantIDs })
        assert.same({ 29, 503 }, list[2].def.enchantIDs)
        assert.same({ 29 }, PROFILE.weapon[1].enchantIDs) -- the profile itself is not changed
    end)
end)

describe("Learning a weapon imbue on cast", function()
    local function same(a, b) return a == b end
    local KINDS = { [8024] = "personal", [324] = "personal", [53390] = "procs", [2383] = "tracking" }

    it("a listed buff/imbue cast is noted with the weapons as they were; procs and tracking are not", function()
        local OwnList = load()
        local weapons = { MAINHAND = { enchantID = 29, expiresAt = 100 } }
        local note = OwnList.NoteCast(8024, { 324, 8024 }, KINDS, same, weapons, 50)
        assert.same({ id = 8024, at = 50, before = { MAINHAND = { enchantID = 29, expiresAt = 100 }, OFFHAND = {} } },
            note)
        assert.is_nil(OwnList.NoteCast(53390, { 53390 }, KINDS, same, weapons, 50))
        assert.is_nil(OwnList.NoteCast(2383, { 2383 }, KINDS, same, weapons, 50))
        assert.is_nil(OwnList.NoteCast(999, { 324 }, KINDS, same, weapons, 50)) -- not on the list
    end)

    it("another rank of a listed spell counts (sameSpell)", function()
        local OwnList = load()
        local note = OwnList.NoteCast(8030, { 8024 }, KINDS, function(a, b) return a == 8024 and b == 8030 end, {}, 1)
        assert.equal(8024, note.id)
    end)

    it("learns the hand whose enchant ID changed; nothing while unchanged; drops the note when too old", function()
        local OwnList = load()
        local note = { id = 8024, at = 10, before = { MAINHAND = { enchantID = 29, expiresAt = 100 }, OFFHAND = {} } }
        assert.is_nil(OwnList.Learn(note, { MAINHAND = { enchantID = 29, expiresAt = 100 } }, 11))
        assert.same({ "MAINHAND", 5 }, { OwnList.Learn(note, { MAINHAND = { enchantID = 5, expiresAt = 400 } }, 12) })
        assert.same({ nil, true }, { OwnList.Learn(note, {}, 10 + OwnList.LEARN_SECONDS + 1) })
    end)

    it("a refreshed imbue (same ID, later end time) is learned; a secret ID or two changed hands are not", function()
        local OwnList = load()
        local note = { id = 8024, at = 10, before = { MAINHAND = { enchantID = 5, expiresAt = 100 }, OFFHAND = {} } }
        assert.same({ "MAINHAND", 5 }, { OwnList.Learn(note, { MAINHAND = { enchantID = 5, expiresAt = 400 } }, 11) })
        assert.is_nil(OwnList.Learn(note, { MAINHAND = { enchantID = nil, expiresAt = 400 } }, 11))
        assert.is_nil(OwnList.Learn(note, { MAINHAND = { enchantID = 6, expiresAt = 400 },
            OFFHAND = { enchantID = 7, expiresAt = 400 } }, 11))
    end)

    it("ApplyLearned saves hand and enchant ID once; a new rank adds its ID", function()
        local OwnList = load()
        local db = {}
        assert.is_true(OwnList.ApplyLearned(db, 8024, "MAINHAND", 5))
        assert.is_false(OwnList.ApplyLearned(db, 8024, "MAINHAND", 5))
        assert.is_true(OwnList.ApplyLearned(db, 8024, "MAINHAND", 6))
        assert.same({ [8024] = { slot = "MAINHAND", enchantIDs = { 5, 6 } } }, db.imbues)
    end)
end)
