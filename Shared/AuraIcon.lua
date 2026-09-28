-- PaTiShared: the look of aura/buff icons (icon, 1px status border, corner text) and timer text.
-- Styles a frame the addon created — also secure buttons; this file never creates secure frames.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- state: "ACTIVE" | "MISSING" | "EXPIRING" | "UNKNOWN". Missing/unknown are dimmed (a quiet empty slot),
-- expiring gets a Warning border; nothing blinks. border: optional {r, g, b} (e.g. a debuff type colour).
local function setAura(frame, texture, state, text, border)
    local dim = state == "MISSING" or state == "UNKNOWN"
    frame.auraIcon:SetTexture(texture or QUESTION_MARK)
    frame.auraIcon:SetDesaturated(dim)
    frame.auraIcon:SetAlpha(dim and 0.45 or 1)
    if border then
        frame.auraBorder:SetColorTexture(border[1], border[2], border[3], 1)
    else
        frame.auraBorder:SetColorTexture(UI.Color(state == "EXPIRING" and "Warning" or "BorderStrong"))
    end
    frame.auraText:SetText(text or "")
end

function UI.StyleAuraIcon(frame, size)
    frame:SetSize(size, size)
    frame.auraBorder = frame:CreateTexture(nil, "BACKGROUND")
    frame.auraBorder:SetAllPoints()
    frame.auraIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.auraIcon:SetPoint("TOPLEFT", 1, -1)
    frame.auraIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.auraIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the built-in icon border
    frame.auraText = frame:CreateFontString(nil, "OVERLAY", UI.Fonts.Number)
    frame.auraText:SetPoint("BOTTOMRIGHT", 2, -1)
    frame.SetAura = setAura
    setAura(frame, nil, "UNKNOWN")
    return frame
end

-- 8s · 4m · 2h. seconds must be a plain number (never a secret value).
function UI.FormatRemaining(seconds)
    if seconds >= 3600 then return ("%dh"):format(math.floor(seconds / 3600)) end
    if seconds >= 60 then return ("%dm"):format(math.floor(seconds / 60)) end
    return ("%ds"):format(math.max(0, math.floor(seconds)))
end
