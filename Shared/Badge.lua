-- PaTiShared: small status badge, e.g. TEST / WARNING / OFFLINE.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- text: see UI.Text; colorName: a status token (Warning, Danger, Success, Accent).
function UI.CreateBadge(parent, text, colorName)
    local badge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    badge:SetHeight(14)
    local color = colorName or "Warning"
    UI.ApplyBackdrop(badge, color, color) -- rounded like everything else; the tinted alphas follow
    UI.Paint(badge, "SetBackdropColor", color, 0.15)
    UI.Paint(badge, "SetBackdropBorderColor", color, 0.6)

    local label = badge:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    label:SetPoint("CENTER", 0, 0)
    UI.Paint(label, "SetTextColor", color, 1)
    label.patiAfterText = function(self)
        badge:SetWidth(math.ceil(UI.TextWidth(self)) + 2 * UI.Spacing.SM)
    end
    UI.BindText(label, text)
    badge.label = label
    return badge
end
