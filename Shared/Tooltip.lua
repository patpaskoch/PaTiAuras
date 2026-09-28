-- PaTiShared: short tooltips.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- text: L key, literal or function (see UI.Text); nil = no tooltip. Can be changed later.
-- A function may also return a list of lines: the first is the title, the rest are muted detail lines.
function UI.SetTooltip(frame, text)
    frame.patiTooltip = text
    if frame.patiTooltipHooked then return end
    frame.patiTooltipHooked = true
    frame:HookScript("OnEnter", function(self)
        local value = self.patiTooltip
        if type(value) == "function" then value = value() else value = UI.Text(value) end
        if type(value) == "table" then
            if not value[1] then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(value[1], 1, 1, 1)
            local r, g, b = UI.Color("TextMuted")
            for index = 2, #value do GameTooltip:AddLine(value[index], r, g, b, true) end
        elseif value and value ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(value, 1, 1, 1, 1, true)
        else
            return
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
