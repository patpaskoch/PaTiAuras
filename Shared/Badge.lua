-- PaTiShared: small status badge, e.g. TEST / WARNING / OFFLINE.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- text: see UI.Text; colorName: a status token (Warning, Danger, Success, Accent).
function UI.CreateBadge(parent, text, colorName)
    local badge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    badge:SetHeight(14)
    local r, g, b = UI.Color(colorName or "Warning")
    badge:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = UI.Sizes.Border })
    badge:SetBackdropColor(r, g, b, 0.15)
    badge:SetBackdropBorderColor(r, g, b, 0.6)

    local label = badge:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    label:SetPoint("CENTER", 0, 0)
    label:SetTextColor(r, g, b, 1)
    label.patiAfterText = function(self)
        badge:SetWidth(math.ceil(UI.TextWidth(self)) + 2 * UI.Spacing.SM)
    end
    UI.BindText(label, text)
    badge.label = label
    return badge
end
