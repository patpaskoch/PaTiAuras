-- PaTiAuras: editor of the own list "My auras" (settings → Watch, owner 2026-10-06). Built on first open.
-- Config.OWN_SLOTS slots in display order, edited with PaTiShared's slot list (UI.AddSlotList: type or drag spells,
-- arrows and grip to sort — the same in every addon). The list changes lines with secure click buttons: changes
-- only out of combat. Attack spells (e.g. Shadow Bolt) are refused: they never put a buff on you (owner 2026-10-07).
local _, ns = ...
local UI, L, Config, Spells = ns.UI, ns.UI.L, ns.Config, ns.Spells

local OwnBuffs = {}
ns.OwnBuffs = OwnBuffs

local app -- { db, profile, changed, combatBlocked, say } from PaTiAuras.lua
function OwnBuffs.Init(callbacks) app = callbacks end

local modal

-- The saved list; the first edit turns the profile seed (Watch.OwnIDs) into a saved list.
local function slots()
    local db = app.db()
    if db.ownBuffs == nil then db.ownBuffs = Config.OwnSlots(ns.Watch.OwnIDs(db, app.profile())) end
    return db.ownBuffs
end

local function shownSlots()
    return Config.OwnSlots(ns.Watch.OwnIDs(app.db(), app.profile()))
end

-- Every change: out of combat only (the window's click buttons follow the lines), then saved and rebuilt.
local function change(apply)
    if app.combatBlocked() then return end
    if apply(slots()) ~= false then app.changed() end
end

-- An attack spell cannot be a buff on you: refused with a note instead of a line that is always "missing".
local function acceptable(id)
    if id and id ~= 0 and Spells.IsHarmful(id) then
        app.say("OWN_HARMFUL", Spells.Name(id) or tostring(id))
        return false
    end
    return true
end

local function build()
    modal = UI.CreateModal("PaTiAurasOwnBuffs", "OWN_BUFFS", 440)
    UI.AddSlotList(modal, {
        count = Config.OWN_SLOTS,
        title = "OWN_BUFFS_TITLE",
        help = { { "OWN_HELP_IMBUE_KEY", "OWN_HELP_IMBUE" }, { "OWN_HELP_MISSING_KEY", "OWN_HELP_MISSING" } },
        get = shownSlots,
        set = function(slot, id) change(function(list) Config.SetSlot(list, slot, id) end) end,
        moveTo = function(from, to) change(function(list) return Config.MoveTo(list, from, to) end) end,
        name = Spells.Name,
        icon = Spells.Icon,
        resolve = function(text)
            local id = Spells.Resolve(text)
            return (id == nil or acceptable(id)) and id or nil
        end,
        fromCursor = function()
            local id = Spells.FromCursor()
            if not acceptable(id) then
                if ClearCursor then ClearCursor() end
                return nil
            end
            return id
        end,
        notFound = function(text)
            -- acceptable() already explained a refused attack spell; only an unknown name needs a note here.
            if Spells.Resolve(text) == nil then app.say("OWN_NOT_FOUND", text) end
        end,
    })
    modal:Finish()
end

function OwnBuffs.Open()
    if not modal then build() end
    modal:Show()
end

-- Number of spells in the list (settings button label).
function OwnBuffs.Count()
    local count = 0
    for _, id in ipairs(shownSlots()) do
        if id ~= 0 then count = count + 1 end
    end
    return count
end
