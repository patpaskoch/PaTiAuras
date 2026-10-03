-- PaTiShared: the one button style of the suite.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local function paint(button, hovered)
    local enabled = button:IsEnabled()
    button:SetBackdropColor(UI.Color(enabled and hovered and "PanelHover" or "Panel"))
    button:SetBackdropBorderColor(UI.Color(enabled and hovered and "BorderStrong" or "Border"))
    button.label:SetTextColor(UI.Color(enabled and "Text" or "TextMuted"))
end

-- Positions the label; dx/dy = 1/-1 while pressed. Components may replace this.
local function layoutLabel(button, dx, dy)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", UI.Spacing.MD + dx, dy)
    button.label:SetPoint("RIGHT", -UI.Spacing.MD + dx, dy)
end

-- Gives a button the suite look. Works on a button the addon created itself — also a secure one, e.g.
-- CreateFrame("Button", name, parent, "SecureActionButtonTemplate,BackdropTemplate"). Never touches OnClick,
-- clicks registration or attributes. text: see UI.Text. width nil = fit the text (follows language changes).
function UI.StyleButton(button, text, width)
    button:SetSize(width or 80, UI.Sizes.ButtonHeight)
    UI.ApplyBackdrop(button, "Panel", "Border")

    local label = button:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetWordWrap(false)
    button.label = label
    button.LayoutLabel = layoutLabel
    button:LayoutLabel(0, 0)
    if not width then
        label.patiAfterText = function(self)
            button:SetWidth(math.max(60, math.ceil(UI.TextWidth(self)) + 2 * UI.Spacing.LG))
        end
    end
    if text then UI.BindText(label, text) end

    button:SetScript("OnEnter", function(self) paint(self, true) end)
    button:SetScript("OnLeave", function(self) paint(self, false) end)
    UI.OnThemeChanged(function() paint(button, button:IsMouseOver()) end) -- hover state colours follow the theme
    button:SetScript("OnEnable", function(self) paint(self, self:IsMouseOver()) end)
    button:SetScript("OnDisable", function(self) paint(self, false); self:LayoutLabel(0, 0) end)
    button:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:LayoutLabel(1, -1) end end)
    button:SetScript("OnMouseUp", function(self) self:LayoutLabel(0, 0) end)
    paint(button, false)
    return button
end

-- A plain (non-secure) suite button.
function UI.CreateButton(parent, text, width, onClick)
    local button = UI.StyleButton(CreateFrame("Button", nil, parent, "BackdropTemplate"), text, width)
    button:RegisterForClicks("LeftButtonUp")
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end
