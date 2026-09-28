-- PaTiAuras spell ranks (pure parts of SpellBook.lua). Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local NAMES = { [331] = "Heilende Welle", [332] = "Heilende Welle", [547] = "Heilende Welle", [1064] = "Kettenheilung" }

local function load(entries)
    wow.install()
    _G.C_Spell = { GetSpellInfo = function(id) return NAMES[id] and { name = NAMES[id] } end }
    _G.C_SpellBook = nil
    _G.GetNumSpellTabs = function() return 1 end
    _G.GetSpellTabInfo = function() return "General", nil, 0, #entries end
    _G.GetSpellBookItemInfo = function(index) return entries[index].kind or "SPELL", entries[index].id end
    _G.GetSpellBookItemName = function(index) return NAMES[entries[index].id], entries[index].subtext end
    local Spells = wow.loadAddonFile("SpellBook.lua", {}).Spells
    Spells.Rescan()
    return Spells
end

local BOOK = {
    { id = 547, subtext = "Rang 3" }, { id = 331, subtext = "Rang 1" }, { id = 332, subtext = "Rang 2" },
    { id = 1064, subtext = "" },
}

describe("Spells ranks", function()
    it("groups the spellbook into families sorted by rank", function()
        local ranks = load(BOOK).Ranks(331)
        assert.equal(3, #ranks)
        assert.same({ 1, 2, 3 }, { ranks[1].rank, ranks[2].rank, ranks[3].rank })
    end)

    it("casts the highest rank by plain name and a chosen rank as Name(Rank n)", function()
        local Spells = load(BOOK)
        assert.equal("Heilende Welle", Spells.CastName(331))
        assert.equal("Heilende Welle", Spells.CastName(331, 0))
        assert.equal("Heilende Welle(Rang 2)", Spells.CastName(331, 2))
        assert.equal("Heilende Welle", Spells.CastName(331, 9), "unknown rank falls back to the highest")
    end)

    it("treats spells without rank text as rankless", function()
        assert.equal(0, #load(BOOK).Ranks(1064))
    end)

    it("ignores spells that are not learned yet (FUTURESPELL)", function()
        local book = { { id = 331, subtext = "Rang 1" }, { id = 332, subtext = "Rang 2", kind = "FUTURESPELL" } }
        assert.equal(1, #load(book).Ranks(331))
    end)

    it("collects all rank IDs of a family for aura matching", function()
        assert.same({ [331] = true, [332] = true, [547] = true }, load(BOOK).FamilyIDs(331))
    end)

    it("knows a spell by name when a higher rank's ID is in the spellbook", function()
        assert.is_true(load({ { id = 547, subtext = "Rang 3" } }).IsKnown(331))
    end)
end)
