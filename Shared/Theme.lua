-- PaTiShared: design tokens. Embedded per addon; writes only into the addon namespace.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- Themes (owner wish 2026-10-03): the same semantic colour tokens in three looks. A theme changes colours only —
-- never layout, sizes, fonts, secure frames or behaviour. {r, g, b, a}. Every theme defines every token
-- (tests/theme_spec.lua checks completeness and text contrast).
UI.THEMES = {
    -- The PaTi look as it always was.
    default = {
        Background   = {0.06, 0.07, 0.08, 0.92}, -- window body
        Panel        = {0.11, 0.12, 0.14, 1.00}, -- rows, controls, modal body
        PanelHover   = {0.16, 0.17, 0.20, 1.00},
        Border       = {1.00, 1.00, 1.00, 0.10},
        BorderStrong = {1.00, 1.00, 1.00, 0.22},
        Accent       = {0.41, 0.79, 1.00, 1.00}, -- PaTi blue (|cff68caff)
        Text         = {0.92, 0.92, 0.92, 1.00},
        TextMuted    = {0.60, 0.62, 0.66, 1.00},
        Warning      = {0.95, 0.72, 0.20, 1.00},
        Danger       = {0.85, 0.25, 0.22, 1.00},
        Success      = {0.30, 0.75, 0.40, 1.00},
        Health       = {0.18, 0.64, 0.30, 1.00},
        Mana         = {0.16, 0.42, 0.90, 1.00},
    },
    -- Warm dark brown, gold and bronze: a calm classic fantasy look.
    woforever = {
        Background   = {0.09, 0.06, 0.04, 0.94},
        Panel        = {0.16, 0.11, 0.07, 1.00},
        PanelHover   = {0.23, 0.16, 0.10, 1.00},
        Border       = {0.72, 0.53, 0.27, 0.40}, -- bronze
        BorderStrong = {0.86, 0.67, 0.33, 0.80}, -- gold
        Accent       = {0.95, 0.76, 0.35, 1.00}, -- gold
        Text         = {0.96, 0.91, 0.80, 1.00}, -- parchment
        TextMuted    = {0.72, 0.63, 0.50, 1.00},
        Warning      = {0.98, 0.66, 0.18, 1.00},
        Danger       = {0.85, 0.24, 0.16, 1.00},
        Success      = {0.47, 0.74, 0.30, 1.00},
        Health       = {0.30, 0.62, 0.22, 1.00},
        Mana         = {0.24, 0.44, 0.86, 1.00},
    },
    -- Dracula palette: dark background, purple accent, pink highlights, cyan mana; semantic colours stay semantic.
    dracula = {
        Background   = {0.157, 0.165, 0.212, 0.94}, -- #282a36
        Panel        = {0.204, 0.212, 0.271, 1.00},
        PanelHover   = {0.267, 0.278, 0.353, 1.00}, -- #44475a
        Border       = {0.384, 0.447, 0.643, 0.45}, -- #6272a4
        BorderStrong = {1.000, 0.475, 0.776, 0.60}, -- #ff79c6 (pink), hover/active outlines
        Accent       = {0.741, 0.576, 0.976, 1.00}, -- #bd93f9 (purple)
        Text         = {0.973, 0.973, 0.949, 1.00}, -- #f8f8f2
        TextMuted    = {0.66, 0.69, 0.82, 1.00},
        Warning      = {1.000, 0.722, 0.424, 1.00}, -- #ffb86c
        Danger       = {1.000, 0.333, 0.333, 1.00}, -- #ff5555
        Success      = {0.314, 0.980, 0.482, 1.00}, -- #50fa7b
        Health       = {0.26, 0.78, 0.40, 1.00},
        Mana         = {0.545, 0.914, 0.992, 1.00}, -- #8be9fd (cyan)
    },
}
UI.THEME_ORDER = { "default", "woforever", "dracula" }

-- The active colour set. Kept as UI.Colors so code that reads it directly still works.
UI.Colors = UI.THEMES.default
local activeTheme = "default"

UI.Spacing = { XS = 2, SM = 4, MD = 8, LG = 12 }

UI.Sizes = {
    Border       = 1,
    HeaderHeight = 22,
    ButtonHeight = 22,
    IconSmall    = 12,
    IconMedium   = 16,
    ModalWidth   = 380,
    MenuRowHeight = 26, -- popup/menu rows: roomier than buttons for easy reading
    AuraIcon     = 16,
}

-- Blizzard font objects only: they carry the client's CJK fallbacks.
UI.Fonts = {
    Title = "GameFontNormal",
    Label = "GameFontNormalSmall",
    Text  = "GameFontHighlightSmall",
    Muted = "GameFontDisableSmall",
    Number = "NumberFontNormalSmall", -- timers and stack counts on icons
}

-- Main window header (UI.CreateWindow): the addon name orients, it should not draw the eye away from the gameplay
-- content (owner 2026-10-02). Smaller font, muted colour, reduced alpha for the title and the ••• button at rest.
-- Only the main window header — modal titles, warnings, bars and aura texts keep their own look.
UI.WindowHeader = {
    TitleFont = "GameFontHighlightSmall",
    TitleColor = "TextMuted",
    TitleAlpha = 0.75,
    MenuAlpha = 0.75, -- ••• at rest (locked windows: 0.4 until hovered)
}

UI.WHITE = "Interface\\Buttons\\WHITE8X8"

function UI.Color(name)
    local c = UI.Colors[name] or UI.THEMES.default[name]
    return c[1], c[2], c[3], c[4]
end

-- Pure: a known theme id, anything else (nil, typo, old save) → "default".
function UI.ResolveTheme(id)
    if type(id) == "string" and UI.THEMES[id] then return id end
    return "default"
end

function UI.GetTheme() return activeTheme end

-- Static colours: UI.Paint(object, "SetColorTexture", "Accent"[, alpha]) colours now and again after every theme
-- change. Methods: SetColorTexture, SetTextColor, SetVertexColor, SetStatusBarColor, SetBackdropColor,
-- SetBackdropBorderColor. alpha (optional) replaces the token's alpha. Weak keys: a gone object is forgotten.
local painted = setmetatable({}, { __mode = "k" })

local function applyPaint(object, method, entry)
    local r, g, b, a = UI.Color(entry.color)
    object[method](object, r, g, b, entry.alpha or a)
end

function UI.Paint(object, method, colorName, alpha)
    local entries = painted[object] or {}
    painted[object] = entries
    entries[method] = { color = colorName, alpha = alpha }
    applyPaint(object, method, entries[method])
end

-- Dynamic colours (hover, states) are recomputed by the code that sets them; it registers here to repaint.
local themeListeners = {}
function UI.OnThemeChanged(fn) themeListeners[#themeListeners + 1] = fn end

-- Switches this addon's colours to theme `id` (invalid → default) and repaints. Called by the addon from its own
-- saved setting (window:Attach, the settings, PaTiSuite through window:SetSuiteTheme). A failing listener goes to
-- WoW's error handler; the others still run.
function UI.SetTheme(id)
    local resolved = UI.ResolveTheme(id)
    if resolved == activeTheme then return resolved end
    activeTheme = resolved
    UI.Colors = UI.THEMES[resolved]
    for object, entries in pairs(painted) do
        for method, entry in pairs(entries) do applyPaint(object, method, entry) end
    end
    for _, fn in ipairs(themeListeners) do
        local ok, err = pcall(fn, resolved)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    return resolved
end

-- Flat background with a 1px border (follows the theme).
function UI.ApplyBackdrop(frame, background, border)
    frame:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = UI.Sizes.Border })
    UI.Paint(frame, "SetBackdropColor", background or "Background")
    UI.Paint(frame, "SetBackdropBorderColor", border or "Border")
end
-- Thin rotated line; UI icons (×, ▾) are drawn from these instead of font glyphs the WoW font lacks.
function UI.Line(parent, length, degrees, x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(length, 1.5)
    line:SetPoint("CENTER", x or 0, y or 0)
    line:SetColorTexture(1, 1, 1, 1)
    line:SetRotation(math.rad(degrees))
    return line
end

-- Width of a font string's text regardless of its anchors.
function UI.TextWidth(fontString)
    if fontString.GetUnboundedStringWidth then return fontString:GetUnboundedStringWidth() end
    return fontString:GetStringWidth()
end
