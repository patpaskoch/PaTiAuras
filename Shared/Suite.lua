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
