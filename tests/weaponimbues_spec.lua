-- PaTiAuras weapon imbues: adapter with mocked enchant/inventory APIs and the pure state rules.
-- Run via PaTiAdmin/tools/check.sh. What the Forever client really returns is a manual test.
local wow = require("wow_api")

local SECRET = setmetatable({}, { __lt = function() error("secret compared") end, __le = function() error("secret compared") end,
    __eq = function() error("secret compared") end })

local function load()
    wow.install()
    _G.issecretvalue = function(value) return rawequal(value, SECRET) end
    _G.C_Item = nil
    _G.Enum = nil
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

    it("reads the classic tuple first even when C_Item.GetWeaponEnchantInfo exists (owner test 2026-09-30)", function()
        local WeaponImbues = load()
        -- The bug: the modern API was called without a slot and read like the tuple → UNKNOWN with and without Rockbiter.
        _G.C_Item = { GetWeaponEnchantInfo = function(slot) if slot == nil then error("slot expected") end end }
        _G.GetWeaponEnchantInfo = function() return 1, 20000, 0, 5, nil end -- 1/nil flags as in older clients
        local main, off = states(WeaponImbues, 0)
        assert.equal("EXPIRING", main.state) -- 20 s left, below Auras.EXPIRING_SECONDS
        assert.equal("MISSING", off.state)
        assert.equal("GetWeaponEnchantInfo", WeaponImbues.Source(0))
    end)

    it("follows Rockbiter on / off / on again with a weapon in the main hand", function()
        local WeaponImbues = load()
        local rockbiter = false
        _G.GetWeaponEnchantInfo = function()
            if rockbiter then return true, 300000, 0, 3021, false, 0, 0, 0 end
            return false, 0, 0, 0, false, 0, 0, 0
        end
        assert.equal("MISSING", (states(WeaponImbues, 0)).state)
        rockbiter = true
        local main, _, weapons = states(WeaponImbues, 0)
        assert.equal("ACTIVE", main.state)
        assert.equal(300, main.remaining)
        assert.equal(3021, weapons.MAINHAND.enchantID)
        rockbiter = false
        assert.equal("MISSING", (states(WeaponImbues, 0)).state)
        rockbiter = true
        assert.equal("ACTIVE", (states(WeaponImbues, 0)).state)
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
        items[17] = 1002
        _G.GetItemInfoInstant = function() return nil end
        local main
        main, off = states(WeaponImbues, 0)
        assert.equal("MISSING", main.state) -- the main-hand slot only holds weapons: no item class needed
        assert.equal("UNKNOWN", off.state) -- off hand: weapon or shield? cannot tell → never "missing"
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

describe("WeaponImbues modern fallback (C_Item.GetWeaponEnchantInfo(slot))", function()
    local function setupModern(answers)
        local WeaponImbues = load()
        _G.Enum = { WeaponSlot = { MainHand = 0, OffHand = 1 }, ItemEnchantType = { Permanent = 0, Temporary = 1 } }
        _G.C_Item = { GetWeaponEnchantInfo = function(slot)
            local answer = answers[slot]
            if answer == "error" then error("boom") end
            return answer
        end }
        return WeaponImbues
    end

    it("is used only when the classic API is missing, and picks the imbue, not a permanent enchant", function()
        local WeaponImbues = setupModern({
            [0] = { { hasEnchant = true, enchantType = 0, enchantID = 1900 },
                { hasEnchant = true, enchantType = 1, timeLeft = 600000, charges = 0, enchantID = 3021 } },
            [1] = { { hasEnchant = true, enchantType = 0, enchantID = 1900 } }, -- permanent only
        })
        local main, off, weapons = states(WeaponImbues, 0)
        assert.equal("ACTIVE", main.state)
        assert.equal(600, main.remaining)
        assert.equal(3021, weapons.MAINHAND.enchantID)
        assert.equal("MISSING", off.state)
        assert.equal("C_Item.GetWeaponEnchantInfo", WeaponImbues.Source(0))
    end)

    it("accepts a single entry table, reads nil as 'no imbue' and an error or secret flag as UNKNOWN", function()
        local WeaponImbues = setupModern({ [0] = { hasEnchant = true, timeLeft = 20000 }, [1] = nil })
        local main, off = states(WeaponImbues, 0)
        assert.equal("EXPIRING", main.state)
        assert.equal("MISSING", off.state)
        WeaponImbues = setupModern({ [0] = "error", [1] = { { hasEnchant = SECRET } } })
        main, off = states(WeaponImbues, 0)
        assert.same({ "UNKNOWN", "UNKNOWN" }, { main.state, off.state })
    end)

    it("never guesses slot numbers: without Enum.WeaponSlot it stays UNKNOWN", function()
        local WeaponImbues = setupModern({ [0] = { hasEnchant = true, timeLeft = 20000 } })
        _G.Enum = nil
        assert.equal("UNKNOWN", (states(WeaponImbues, 0)).state)
    end)

    it("/pa debug: names each raw tuple field with type, the source and the final state; never formats secrets", function()
        local WeaponImbues = load()
        _G.GetWeaponEnchantInfo = function() return SECRET, SECRET, 0, 0, false, 0, 0, nil end
        local lines = WeaponImbues.Describe(0, SETTINGS)
        assert.truthy(lines[1]:find("Weapon API: source=GetWeaponEnchantInfo", 1, true))
        assert.truthy(lines[2]:find("ok=true, 8 values: hasMainHand=secret, mainHandMsLeft=secret", 1, true))
        assert.truthy(lines[2]:find("hasOffHand=false(boolean)", 1, true))
        assert.truthy(lines[2]:find("offHandEnchantID=nil(nil)", 1, true)) -- a trailing nil still counts
        assert.truthy(lines[3]:find("MAINHAND slot=16 item=1001(number) weapon=true · source=GetWeaponEnchantInfo "
            .. "· readable=false hasImbue=nil", 1, true))
        assert.truthy(lines[3]:find("→ state=UNKNOWN", 1, true))
        assert.truthy(lines[4]:find("OFFHAND slot=17", 1, true))
        assert.truthy(lines[4]:find("→ state=MISSING", 1, true))
        assert.equal(4, #lines)
    end)

    it("/pa auras: also every modern answer (no slot, Enum slot, slot ID), your buffs and the weapon tooltip", function()
        load()
        _G.GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end
        _G.Enum = { WeaponSlot = { MainHand = 0, OffHand = 1 } }
        _G.C_Item = { GetWeaponEnchantInfo = function(slot)
            if slot == nil then error("slot expected") end
            return { hasEnchant = slot == 16, timeLeft = SECRET, enchantID = 3021 }
        end }
        _G.C_TooltipInfo = { GetInventoryItem = function() return { lines = { { leftText = "Axt" },
            { leftText = "Waffe des Felsbeißers (30 Min.)" }, { leftText = SECRET } } } end }
        local ns = { AuraScan = { Read = function() return { { name = "Wasserschild", spellId = 24398 }, { secret = true } } end } }
        wow.loadAddonFile("Auras.lua", ns)
        wow.loadAddonFile("WeaponImbues.lua", ns)
        local text = table.concat(ns.WeaponImbues.Describe(0, SETTINGS, true), "\n")
        assert.truthy(text:find("C_Item.GetWeaponEnchantInfo(): ok=false error=", 1, true))
        assert.truthy(text:find("C_Item.GetWeaponEnchantInfo(Enum MAINHAND): ok=true, 1 values: "
            .. "#1={enchantID=3021(number), hasEnchant=false(boolean), timeLeft=secret}", 1, true))
        assert.truthy(text:find("C_Item.GetWeaponEnchantInfo(16) probe: ok=true, 1 values: "
            .. "#1={enchantID=3021(number), hasEnchant=true(boolean), timeLeft=secret}", 1, true))
        assert.truthy(text:find("Player buffs (2): Wasserschild[24398], secret", 1, true))
        assert.truthy(text:find("Main hand tooltip 2: Waffe des Felsbeißers (30 Min.)", 1, true))
        assert.truthy(text:find("Main hand tooltip 3: secret", 1, true))
        _G.C_TooltipInfo = nil
    end)
end)
