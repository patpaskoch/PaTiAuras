-- PaTiShared: design tokens. Embedded per addon; writes only into the addon namespace.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- {r, g, b, a}
UI.Colors = {
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
}

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

UI.WHITE = "Interface\\Buttons\\WHITE8X8"

function UI.Color(name)
    local c = UI.Colors[name]
    return c[1], c[2], c[3], c[4]
end

-- Flat background with a 1px border.
function UI.ApplyBackdrop(frame, background, border)
    frame:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = UI.Sizes.Border })
    frame:SetBackdropColor(UI.Color(background or "Background"))
    frame:SetBackdropBorderColor(UI.Color(border or "Border"))
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
