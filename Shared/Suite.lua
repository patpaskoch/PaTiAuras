-- PaTiShared: what PaTi windows share at runtime — panel opacity, a tiny window registry and snapping.
-- PaTiShared is embedded: every addon has its own copy and its own `ns.UI`. So the registry cannot live in `ns`;
-- it is the one shared table `_G.PaTiSuiteWindows[addonName] = main window frame` (frames only: no settings, no
-- gameplay data, no functions). Any copy may create it. Nothing here makes one addon need another.
local addonName, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- Panel body opacity (the header stays opaque). Choices offered in the settings; saved as db.opacity.
UI.OPACITY = { min = 0.3, max = 1, default = 0.75 }
UI.OPACITY_STEPS = { 0.3, 0.4, 0.5, 0.6, 0.75, 0.9, 1 }
UI.SNAP_DISTANCE = 12 -- screen pixels: edges closer than this snap together at the end of a drag

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

-- Pure: how far to move rect `me` so one of its edges meets an edge of `others`. Rects: { left, right, bottom, top }
-- in screen pixels. Edge to edge (side by side / stacked) and, for windows next to each other, the parallel edge
-- (same top, same left …). Only offsets up to `distance` count; the smallest wins per axis. Returns dx, dy.
function UI.SnapDelta(me, others, distance)
    local bestX, bestY
    local function pick(best, delta)
        if math.abs(delta) <= distance and (best == nil or math.abs(delta) < math.abs(best)) then return delta end
        return best
    end
    for _, other in ipairs(others) do
        -- Only windows that touch or overlap on the other axis are neighbours.
        local besideEachOther = me.bottom <= other.top + distance and me.top >= other.bottom - distance
        local aboveEachOther = me.left <= other.right + distance and me.right >= other.left - distance
        if besideEachOther then
            bestX = pick(bestX, other.right - me.left)   -- my left edge to its right edge
            bestX = pick(bestX, other.left - me.right)   -- my right edge to its left edge
            bestY = pick(bestY, other.top - me.top)      -- same top
            bestY = pick(bestY, other.bottom - me.bottom) -- same bottom
        end
        if aboveEachOther then
            bestY = pick(bestY, other.bottom - me.top)   -- my top edge to its bottom edge (I am below)
            bestY = pick(bestY, other.top - me.bottom)   -- my bottom edge to its top edge (I am above)
            bestX = pick(bestX, other.left - me.left)    -- same left
            bestX = pick(bestX, other.right - me.right)  -- same right
        end
    end
    return bestX or 0, bestY or 0
end

-- Screen rectangle of a frame, or nil if it has no position yet.
function UI.ScreenRect(frame)
    local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not (left and right and bottom and top) then return nil end
    local scale = frame:GetEffectiveScale()
    return { left = left * scale, right = right * scale, bottom = bottom * scale, top = top * scale }
end
