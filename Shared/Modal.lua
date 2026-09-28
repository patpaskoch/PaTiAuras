-- PaTiShared: settings modal with sections, label/control rows and a footer.
-- Build it top to bottom: AddSection / AddRow / AddControl, then Finish.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local Modal = {}
local SECTION_HEIGHT = 14

function Modal:AddSection(text)
    if self.sections > 0 then self.cursor = self.cursor - UI.Spacing.MD end
    self.sections = self.sections + 1
    local label = self:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    label:SetPoint("TOPLEFT", UI.Spacing.LG, self.cursor)
    label:SetTextColor(UI.Color("TextMuted"))
    UI.BindText(label, function() return string.upper(UI.Text(text) or "") end)
    self.cursor = self.cursor - SECTION_HEIGHT - UI.Spacing.SM
    return label
end

-- Label left, control right-aligned on the same line.
function Modal:AddRow(text, control)
    local height = control:GetHeight()
    control:SetPoint("TOPRIGHT", self, "TOPRIGHT", -UI.Spacing.LG, self.cursor)
    local label = self:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetPoint("LEFT", self, "TOPLEFT", UI.Spacing.LG, self.cursor - height / 2)
    label:SetPoint("RIGHT", control, "LEFT", -UI.Spacing.MD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetTextColor(UI.Color("Text"))
    UI.BindText(label, text)
    self.cursor = self.cursor - height - UI.Spacing.SM
    return label
end

-- Full-width control, e.g. a checkbox.
function Modal:AddControl(control)
    control:SetPoint("TOPLEFT", self, "TOPLEFT", UI.Spacing.LG, self.cursor)
    self.cursor = self.cursor - control:GetHeight() - UI.Spacing.SM
    return control
end

-- Two short controls side by side (e.g. checkboxes); right may be nil.
function Modal:AddControls(left, right)
    left:SetPoint("TOPLEFT", self, "TOPLEFT", UI.Spacing.LG, self.cursor)
    local height = left:GetHeight()
    if right then
        right:SetPoint("TOPLEFT", self, "TOPLEFT", self:GetWidth() / 2, self.cursor)
        height = math.max(height, right:GetHeight())
    end
    self.cursor = self.cursor - height - UI.Spacing.SM
end

-- A small muted label that groups the following controls inside a section.
function Modal:AddLabel(text)
    local label = self:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
    label:SetPoint("TOPLEFT", UI.Spacing.LG, self.cursor - UI.Spacing.XS)
    UI.BindText(label, text)
    self.cursor = self.cursor - SECTION_HEIGHT - UI.Spacing.XS
    return label
end

-- onDefaults nil = no "Restore Defaults" button.
function Modal:Finish(onDefaults)
    self.cursor = self.cursor - UI.Spacing.MD
    local divider = self:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", UI.Spacing.LG, self.cursor)
    divider:SetPoint("TOPRIGHT", -UI.Spacing.LG, self.cursor)
    divider:SetHeight(1)
    divider:SetColorTexture(UI.Color("Border"))

    local close = UI.CreateButton(self, "CLOSE", nil, function() self:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -UI.Spacing.LG, UI.Spacing.LG)
    if onDefaults then
        local defaults = UI.CreateButton(self, "RESTORE_DEFAULTS", nil, function() onDefaults(); self:Refresh() end)
        defaults:SetPoint("BOTTOMLEFT", UI.Spacing.LG, UI.Spacing.LG)
    end
    self:SetHeight(-self.cursor + UI.Spacing.LG + UI.Sizes.ButtonHeight + UI.Spacing.LG)
end

-- Controls with a Refresh method (dropdowns, checkboxes) re-read their value when the modal opens.
-- Also finds controls inside container frames (e.g. two dropdowns in one row).
local function refreshChildren(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.Refresh then child:Refresh() else refreshChildren(child) end
    end
end

function Modal:Refresh()
    refreshChildren(self)
end

-- name: global name, needed for ESC (e.g. "PaTiHealSettings"); title: see UI.Text.
function UI.CreateModal(name, title, width)
    local modal = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    for key, fn in pairs(Modal) do modal[key] = fn end
    modal:SetWidth(width or UI.Sizes.ModalWidth)
    modal:SetPoint("CENTER", 0, 80)
    modal:SetFrameStrata("DIALOG")
    modal:SetToplevel(true)
    modal:SetClampedToScreen(true)
    modal:EnableMouse(true)
    UI.ApplyBackdrop(modal, "Panel", "BorderStrong")
    modal:Hide()
    tinsert(UISpecialFrames, name)
    modal:SetScript("OnShow", function(self) self:Refresh() end)
    modal:SetScript("OnHide", UI.HidePopup)

    local headerHeight = UI.Sizes.HeaderHeight + UI.Spacing.MD
    local titleText = modal:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
    titleText:SetPoint("LEFT", modal, "TOPLEFT", UI.Spacing.LG, -headerHeight / 2)
    UI.BindText(titleText, title)
    modal.title = titleText

    local close = CreateFrame("Button", nil, modal)
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", modal, "TOPRIGHT", -UI.Spacing.SM, -headerHeight / 2)
    local lines = { UI.Line(close, 11, 45), UI.Line(close, 11, -45) }
    local function paintClose(hovered)
        local r, g, b = UI.Color(hovered and "Text" or "TextMuted")
        for _, line in ipairs(lines) do line:SetColorTexture(r, g, b, 1) end
    end
    close:SetScript("OnEnter", function() paintClose(true) end)
    close:SetScript("OnLeave", function() paintClose(false) end)
    close:SetScript("OnClick", function() modal:Hide() end)
    UI.SetTooltip(close, "CLOSE")
    paintClose(false)

    local divider = modal:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", 1, -headerHeight)
    divider:SetPoint("TOPRIGHT", -1, -headerHeight)
    divider:SetHeight(1)
    divider:SetColorTexture(UI.Color("Border"))

    modal.sections = 0
    modal.cursor = -headerHeight - UI.Spacing.LG
    return modal
end
