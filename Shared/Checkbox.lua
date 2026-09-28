-- PaTiShared: on/off option  [■] Label
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local BOX = 14

-- options.get() -> boolean; options.set(boolean)
function UI.CreateCheckbox(parent, text, options)
    local check = CreateFrame("Button", nil, parent)
    check:SetHeight(UI.Sizes.ButtonHeight)
    check.options = options

    local box = CreateFrame("Frame", nil, check, "BackdropTemplate")
    box:SetSize(BOX, BOX)
    box:SetPoint("LEFT")
    UI.ApplyBackdrop(box, "Background", "BorderStrong")
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(UI.Color("Accent"))

    local label = check:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetPoint("LEFT", box, "RIGHT", UI.Spacing.MD, 0)
    label:SetTextColor(UI.Color("Text"))
    label.patiAfterText = function(self)
        check:SetWidth(BOX + UI.Spacing.MD + math.ceil(UI.TextWidth(self)))
    end
    UI.BindText(label, text)
    check.label = label

    function check:Refresh()
        fill:SetShown(self.options.get() and true or false)
    end

    check:SetScript("OnEnter", function() box:SetBackdropBorderColor(UI.Color("Accent")) end)
    check:SetScript("OnLeave", function() box:SetBackdropBorderColor(UI.Color("BorderStrong")) end)
    check:SetScript("OnClick", function(self)
        self.options.set(not self.options.get())
        self:Refresh()
    end)
    check:Refresh()
    return check
end
