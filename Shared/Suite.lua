-- PaTiShared: what PaTi windows share at runtime — panel opacity and a tiny window registry.
-- PaTiShared is embedded: every addon has its own copy and its own `ns.UI`. So the registry cannot live in `ns`;
-- it is the one shared table `_G.PaTiSuiteWindows[addonName] = main window frame` (frames only: no settings, no
-- gameplay data, no functions). Any copy may create it. Nothing here makes one addon need another.
-- (Window snapping was removed on 2026-09-30: it did not work in the client and is not needed.)
local addonName, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- Panel body opacity (the header stays opaque). Choices offered in the settings; saved as db.opacity.
UI.OPACITY = { min = 0.3, max = 1, default = 0.75 }
UI.OPACITY_STEPS = { 0.3, 0.4, 0.5, 0.6, 0.75, 0.9, 1 }

-- Pure: a usable opacity (missing, odd or out-of-range values → default / clamped).
function UI.ClampOpacity(value)
    if type(value) ~= "number" or value ~= value then return UI.OPACITY.default end
    return math.max(UI.OPACITY.min, math.min(UI.OPACITY.max, value))
end

-- The shared registry (created on first use by whichever PaTi addon loads first).
function UI.WindowRegistry()
    local registry = _G.PaTiSuiteWindows
    if type(registry) ~= "table" then
        registry = {}
        _G.PaTiSuiteWindows = registry
    end
    return registry
end

-- Registers this addon's main window under the addon's folder name.
function UI.RegisterWindow(frame)
    UI.WindowRegistry()[addonName] = frame
end

-- Saved window position (hardening 2026-10-02) ------------------------------------------------------------------------
-- A broken save (odd anchor name, a string or NaN as offset) would make SetPoint fail and the window would not load.
local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local MAX_OFFSET = 10000 -- far beyond any screen; SetClampedToScreen keeps a valid but off-screen window visible

local function offset(value, default)
    if type(value) ~= "number" or value ~= value or math.abs(value) > MAX_OFFSET then return default end
    return value
end

-- Pure: point, relativePoint, x, y to anchor the window with. A broken anchor or offset falls back to the default
-- position (CENTER + defaultX/defaultY) as a whole — mixing a saved point with a default offset could put it anywhere.
function UI.WindowPosition(db, defaultX, defaultY)
    db = type(db) == "table" and db or {}
    local point, relativePoint = db.point or "CENTER", db.relativePoint or "CENTER"
    local x, y = offset(db.x, nil), offset(db.y, nil)
    if not ANCHORS[point] or not ANCHORS[relativePoint] or (db.x ~= nil and x == nil) or (db.y ~= nil and y == nil) then
        return "CENTER", "CENTER", defaultX or 0, defaultY or 0
    end
    return point, relativePoint, x or defaultX or 0, y or defaultY or 0
end

-- Pure: may the player drag the window now? Never while locked. In combat only a window the addon declared
-- combat-movable (no secure children, window:SetCombatMovable) that WoW does not report as protected — moving a
-- protected frame in combat is forbidden.
function UI.CanMoveWindow(locked, inCombat, combatMovable, protected)
    if locked then return false end
    if not inCombat then return true end
    return combatMovable == true and protected ~= true
end
