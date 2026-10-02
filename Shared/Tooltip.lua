-- PaTiShared: short tooltips.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- Gap between the hovered element and its tooltip.
local TOOLTIP_GAP = UI.Spacing and UI.Spacing.MD or 8

-- Pure: on which side of the hovered element the tooltip goes, so it never covers it (owner wish 2026-10-02):
-- "RIGHT" for an element in the left half of the screen, "LEFT" in the right half. Screen pixels; nil → "RIGHT".
function UI.TooltipSide(elementCenterX, screenWidth)
    if type(elementCenterX) ~= "number" or type(screenWidth) ~= "number" then return "RIGHT" end
    return elementCenterX < screenWidth / 2 and "RIGHT" or "LEFT"
end

-- Next to the element, vertically centred; the Blizzard GameTooltip keeps itself on screen.
local function anchorTooltip(owner)
    local x = owner:GetCenter()
    local side = "RIGHT"
    if x and UIParent then
        side = UI.TooltipSide(x * owner:GetEffectiveScale(), UIParent:GetWidth() * UIParent:GetEffectiveScale())
    end
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if side == "RIGHT" then
        GameTooltip:SetPoint("LEFT", owner, "RIGHT", TOOLTIP_GAP, 0)
    else
        GameTooltip:SetPoint("RIGHT", owner, "LEFT", -TOOLTIP_GAP, 0)
    end
end

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
            anchorTooltip(self)
            GameTooltip:SetText(value[1], 1, 1, 1)
            local r, g, b = UI.Color("TextMuted")
            for index = 2, #value do GameTooltip:AddLine(value[index], r, g, b, true) end
        elseif value and value ~= "" then
            anchorTooltip(self)
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
