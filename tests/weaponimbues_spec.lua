-- PaTiAuras weapon imbues: adapter with mocked enchant/inventory APIs and the pure state rules.
-- Run via PaTiAdmin/tools/check.sh. What the Forever client really returns is a manual test.
local wow = require("wow_api")

local SECRET = setmetatable({}, { __lt = function() error("secret compared") end, __le = function() error("secret compared") end,
    __eq = function() error("secret compared") end })

local function load()
    wow.install()
    _G.issecretvalue = function(value) return rawequal(value, SECRET) end
    _G.C_Item = nil
    _G.GetWeaponEnchantInfo = nil
    -- Default equipment: a weapon in both hands (item class 2).
    local items = { [16] = 1001, [17] = 1002 }
    _G.GetInventoryItemID = function(_, slot) return items[slot] end
    _G.GetInventoryItemTexture = function(_, slot) return items[slot] and ("icon" .. slot) or nil end
    _G.GetItemInfoInstant = function(id) return id, "Weapon", "Axe", "INVTYPE_WEAPON", 1, id == 1003 and 4 or 2, 0 end
    local ns = {}
    wow.loadAddonFile("Auras.lua", ns)
    wow.loadAddonFile("WeaponImbues.lua", ns)
    return ns.WeaponImbues, items
end

local SETTINGS = { showExpiring = true }

local function states(WeaponImbues, now)
    local weapons = WeaponImbues.Read(now)
    local main = WeaponImbues.Evaluate(weapons.MAINHAND, now, SETTINGS)
    local off = WeaponImbues.Evaluate(weapons.OFFHAND, now, SETTINGS)
    return main, off, weapons
end

describe("WeaponImbues adapter", function()
    it("reads main and off hand separately: imbue with timer vs. no imbue", function()
        local WeaponImbues = load()
        -- classic order: hasMain, mainExpiration (ms), mainCharges, mainID, hasOff, offExpiration, offCharges, offID
        _G.GetWeaponEnchantInfo = function() return true, 1200000, 0, 5, false, 0, 0, 0 end
        local main, off = states(WeaponImbues, 100)
        assert.equal("ACTIVE", main.state)
        assert.equal(1200, main.remaining)
        assert.equal("icon16", main.icon)
        assert.equal("MISSING", off.state)
    end)

    it("prefers C_Item.GetWeaponEnchantInfo and accepts 1/nil flags", function()
        local WeaponImbues = load()
        _G.GetWeaponEnchantInfo = function() error("must not be called") end
        _G.C_Item = { GetWeaponEnchantInfo = function() return 1, 20000, 0, 5, nil end }
        local main, off = states(WeaponImbues, 0)
        assert.equal("EXPIRING", main.state) -- 20 s left, below Auras.EXPIRING_SECONDS
        assert.equal("MISSING", off.state)
    end)

    it("is UNKNOWN, never MISSING, when the API is missing, errors or answers nothing", function()
        local WeaponImbues = load()
        local main, off = states(WeaponImbues, 0)
        assert.same({ "UNKNOWN", "UNKNOWN" }, { main.state, off.state })
        _G.GetWeaponEnchantInfo = function() error("restricted") end
        main, off = states(WeaponImbues, 0)
        assert.same({ "UNKNOWN", "UNKNOWN" }, { main.state, off.state })
        _G.GetWeaponEnchantInfo = function() end
        main = states(WeaponImbues, 0)
        assert.equal("UNKNOWN", main.state)
    end)

    it("treats a secret flag as UNKNOWN and a secret duration as ACTIVE without timer", function()
        local WeaponImbues = load()
        _G.GetWeaponEnchantInfo = function() return true, SECRET, SECRET, SECRET, SECRET, 0, 0, 0 end
        local main, off, weapons = states(WeaponImbues, 0)
        assert.equal("ACTIVE", main.state)
        assert.is_nil(main.remaining)
        assert.is_nil(weapons.MAINHAND.enchantID)
        assert.equal("UNKNOWN", off.state)
    end)

    it("shows nothing for an empty off hand or a shield, and UNKNOWN when the item class is unreadable", function()
        local WeaponImbues, items = load()
        _G.GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end
        items[17] = nil
        local _, off = states(WeaponImbues, 0)
        assert.is_nil(off)
        items[17] = 1003 -- class 4 = armor (shield)
        _, off = states(WeaponImbues, 0)
        assert.is_nil(off)
        _G.GetItemInfoInstant = function() return nil end
        local main = states(WeaponImbues, 0)
        assert.equal("UNKNOWN", main.state) -- no imbue, but cannot tell whether it is a weapon
    end)

    it("keeps no old state after a weapon swap: every read describes the current equipment", function()
        local WeaponImbues, items = load()
        _G.GetWeaponEnchantInfo = function() return true, 600000, 0, 5, true, 600000, 0, 6 end
        local _, off = states(WeaponImbues, 0)
        assert.equal("ACTIVE", off.state)
        items[17] = nil -- off hand weapon taken off
        _G.GetWeaponEnchantInfo = function() return true, 599000, 0, 5, false, 0, 0, 0 end
        _, off = states(WeaponImbues, 1)
        assert.is_nil(off)
    end)
end)

describe("WeaponImbues.Evaluate and Signature", function()
    it("follows showExpiring", function()
        local WeaponImbues = load()
        local raw = { readable = true, has = true, expiresAt = 10, weapon = true }
        assert.equal("EXPIRING", WeaponImbues.Evaluate(raw, 0, { showExpiring = true }).state)
        assert.equal("ACTIVE", WeaponImbues.Evaluate(raw, 0, { showExpiring = false }).state)
    end)

    it("changes when an imbue is applied or renewed, not with read jitter", function()
        local WeaponImbues = load()
        local a = WeaponImbues.Signature({ MAINHAND = { readable = true, has = true, expiresAt = 1000.2, weapon = true } })
        local b = WeaponImbues.Signature({ MAINHAND = { readable = true, has = true, expiresAt = 1000.6, weapon = true } })
        local renewed = WeaponImbues.Signature({ MAINHAND = { readable = true, has = true, expiresAt = 2800, weapon = true } })
        local gone = WeaponImbues.Signature({ MAINHAND = { readable = true, has = false, weapon = true } })
        assert.equal(a, b)
        assert.is_true(a ~= renewed)
        assert.is_true(a ~= gone)
    end)
end)
