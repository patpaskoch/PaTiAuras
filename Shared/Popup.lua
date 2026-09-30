-- PaTiShared: small list popup used by the header menu and dropdowns (own frames, no UIDropDownMenu).
-- Every row starts with a marker: the item's icon, or a small dot, so all lists read the same way.
local addonName, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local popup
local rows = {}
local DOT = 4

function UI.HidePopup()
    if popup then popup:Hide() end
end

local function createPopup()
    popup = CreateFrame("Frame", addonName .. "Popup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    UI.ApplyBackdrop(popup, "Panel", "BorderStrong")
    popup:Hide()
    tinsert(UISpecialFrames, popup:GetName())
    -- Close on any click outside; a click on the anchor itself toggles via ShowPopup.
    popup:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
    popup:SetScript("OnHide", function(self) self:UnregisterAllEvents(); self.anchor = nil end)
    popup:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end
    end)
end

local function getRow(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Button", nil, popup)
    row:SetHeight(UI.Sizes.MenuRowHeight)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(UI.Color("PanelHover"))
    row.hover:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(UI.Sizes.IconMedium, UI.Sizes.IconMedium)
    row.icon:SetPoint("LEFT", UI.Spacing.MD, 0)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(DOT, DOT)
    row.dot:SetPoint("CENTER", row.icon, "CENTER")
    row.label = row:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnEnter", function(self) if self:IsEnabled() then self.hover:Show() end end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item.keepOpen then UI.HidePopup() end
        if item.onClick then item.onClick(item) end
        if item.keepOpen and popup:IsShown() and popup.render then popup.render() end -- multi-select: stay open, repaint
    end)
    UI.SetTooltip(row, nil)
    rows[index] = row
    return row
end

-- items: list (or a function returning it, re-read after each keepOpen click) of
-- { text, icon?, checked?, disabled?, tooltip?, onClick(item), keepOpen?, header? }.
-- keepOpen: the click toggles and the popup stays open (multi-select lists). header: a muted, not clickable title.
-- align "RIGHT" (menu, opens leftwards) or "LEFT" (dropdown). Clicking the same anchor again closes.
local render
function UI.ShowPopup(anchor, items, minWidth, align)
    if not popup then createPopup() end
    if popup:IsShown() and popup.anchor == anchor then popup:Hide(); return end
    popup.render = function() render(anchor, type(items) == "function" and items() or items, minWidth, align) end
    popup.render()
end

render = function(anchor, items, minWidth, align)

    local pad, height = UI.Spacing.SM, UI.Sizes.MenuRowHeight
    local textLeft = UI.Spacing.MD + UI.Sizes.IconMedium + UI.Spacing.MD

    -- First pass: content and natural width (label anchored on one side only).
    local width = (minWidth or 0) - 2 * pad
    for index, item in ipairs(items) do
        local row = getRow(index)
        row.item = item
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", textLeft, 0)
        row.label:SetText(UI.Text(item.text) or "")
        local color = (item.disabled or item.header) and "TextMuted" or item.checked and "Accent" or "Text"
        row.label:SetTextColor(UI.Color(color))
        row.label:SetFontObject(item.header and UI.Fonts.Label or UI.Fonts.Text)
        row.icon:SetTexture(item.icon)
        row.icon:SetShown(item.icon ~= nil and not item.header)
        row.icon:SetDesaturated(item.disabled == true)
        row.dot:SetColorTexture(UI.Color(item.checked and "Accent" or "TextMuted"))
        row.dot:SetShown(item.icon == nil and not item.header)
        row:SetEnabled(not item.disabled and not item.header)
        row.patiTooltip = item.tooltip
        width = math.max(width, math.ceil(UI.TextWidth(row.label)) + textLeft + UI.Spacing.LG)
    end
    -- Second pass: fixed width, truncate long labels.
    for index = 1, #items do
        local row = rows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pad, -pad - (index - 1) * height)
        row:SetWidth(width)
        row.label:SetPoint("RIGHT", -UI.Spacing.MD, 0)
        row:Show()
    end
    for index = #items + 1, #rows do rows[index]:Hide() end

    popup:SetSize(width + 2 * pad, #items * height + 2 * pad)
    popup:ClearAllPoints()
    if align == "LEFT" then
        popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -UI.Spacing.XS)
    else
        popup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -UI.Spacing.XS)
    end
    popup.anchor = anchor
    popup:Show()
    popup:Raise()
end
