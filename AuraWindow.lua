-- PaTiAuras: main window. Three calm sections (SELF, GROUP, HEALING) of text lines with small icons.
-- Plain frames only (no secure buttons in v0.1), so the window may resize and redraw in combat.
local _, ns = ...
local UI, L, Auras, Watch = ns.UI, ns.UI.L, ns.Auras, ns.Watch

local AuraWindow = {}
ns.AuraWindow = AuraWindow

local WIDTH, LINE, ICON, UNIT_ICONS = 230, 20, 16, 4
local PAD = UI.Spacing.MD
local TICK_SECONDS = 0.5 -- timer texts only; state changes come from UNIT_AURA

local window = UI.CreateWindow("PaTiAurasFrame", "PaTiAuras", WIDTH, UI.Sizes.HeaderHeight + 40)
AuraWindow.frame = window
local lines = {}

local function newLine(index)
    local line = CreateFrame("Frame", nil, window)
    line:SetSize(WIDTH - 2 * PAD, LINE)
    line:EnableMouse(true)
    line.icon = UI.StyleAuraIcon(CreateFrame("Frame", nil, line), ICON)
    line.icon:SetPoint("LEFT")
    line.name = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    line.name:SetJustifyH("LEFT")
    line.name:SetWordWrap(false)
    line.value = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    line.value:SetPoint("RIGHT")
    line.unitIcons = {}
    for slot = 1, UNIT_ICONS do
        local icon = UI.StyleAuraIcon(CreateFrame("Frame", nil, line), ICON)
        icon:SetPoint("RIGHT", -(slot - 1) * (ICON + UI.Spacing.XS), 0)
        icon:EnableMouse(true)
        UI.SetTooltip(icon, function() return icon.tooltipLines end)
        line.unitIcons[slot] = icon
    end
    UI.SetTooltip(line, function() return line.tooltipLines end)
    lines[index] = line
    return line
end

-- Resets a line to one of three looks: "header", "entry" (icon + name + value) or "unit" (name + icons).
local function prepare(index, kind)
    local line = lines[index] or newLine(index)
    line.kind, line.tooltipLines = kind, nil
    line.icon:SetShown(kind == "entry")
    for _, icon in ipairs(line.unitIcons) do icon:Hide() end
    line.name:ClearAllPoints()
    line.name:SetPoint("LEFT", kind == "entry" and ICON + UI.Spacing.SM or 0, 0)
    line.name:SetPoint("RIGHT", line, "RIGHT", -60, 0)
    line.name:SetFontObject(kind == "header" and UI.Fonts.Label or UI.Fonts.Text)
    line.name:SetTextColor(UI.Color(kind == "header" and "TextMuted" or "Text"))
    line.value:SetText("")
    line:Show()
    return line
end

local STATE_COLOR = { ACTIVE = "Text", EXPIRING = "Warning", MISSING = "TextMuted", UNKNOWN = "TextMuted" }

local function detail(entry, result, target)
    local list = { entry.name, L.TIP_STATUS:format(L["STATUS_" .. result.state]) }
    if result.remaining then list[#list + 1] = L.TIP_REMAINING:format(UI.FormatRemaining(result.remaining)) end
    if result.count and result.count > 0 then list[#list + 1] = L.TIP_CHARGES:format(result.count) end
    if target then list[#list + 1] = L.TIP_TARGET:format(target) end
    return list
end

local function valueText(entry, result, db)
    return Auras.IconText(entry, result, db, UI.FormatRemaining) or L["STATUS_" .. result.state]
end

-- Builds all lines from Watch data. Returns true if any shown value has a running timer.
function AuraWindow.Render(db)
    local count, timers = 0, false
    local function add(kind)
        count = count + 1
        return prepare(count, kind)
    end
    local function header(key)
        add("header").name:SetText(string.upper(L[key]))
    end

    if not db.enabled then
        add("header").name:SetText(L.DISABLED)
    elseif not Watch.profile then
        add("header").name:SetText(L.NO_PROFILE)
    else
        local selfList = Watch.Self(db)
        local visible = {}
        for _, item in ipairs(selfList) do
            if item.result.state ~= "MISSING" or db.showMissing then visible[#visible + 1] = item end
        end
        if #visible > 0 then header("SECTION_SELF") end
        for _, item in ipairs(visible) do
            local line, result = add("entry"), item.result
            line.icon:SetAura(result.icon or item.entry.icon, result.state)
            line.name:SetText(item.entry.name)
            line.value:SetText(valueText(item.entry, result, db))
            line.value:SetTextColor(UI.Color(STATE_COLOR[result.state]))
            line.tooltipLines = detail(item.entry, result)
            timers = timers or result.remaining ~= nil
        end

        local groupList = Watch.Group(db)
        if #groupList > 0 then header("SECTION_GROUP") end
        for _, item in ipairs(groupList) do
            local line, summary = add("entry"), item.summary
            local incomplete = #summary.missing > 0
            line.icon:SetAura(item.entry.icon, incomplete and db.showMissing and "MISSING" or "ACTIVE")
            line.name:SetText(item.entry.name)
            line.value:SetText(("%d / %d"):format(summary.have, summary.total))
            line.value:SetTextColor(UI.Color(incomplete and db.showMissing and "Warning" or "Text"))
            local tip = { item.entry.name }
            if incomplete then tip[#tip + 1] = L.TIP_MISSING_ON:format(table.concat(summary.missing, ", ")) end
            if #summary.away > 0 then tip[#tip + 1] = L.TIP_AWAY:format(table.concat(summary.away, ", ")) end
            if not incomplete then tip[#tip + 1] = L.TIP_ALL_BUFFED end
            line.tooltipLines = tip
        end

        local healingList = Watch.Healing(db)
        if #healingList > 0 then header("SECTION_HEALING") end
        for _, unitItem in ipairs(healingList) do
            local line = add("unit")
            line.name:SetText(unitItem.name)
            for slot, item in ipairs(unitItem.auras) do
                local icon = line.unitIcons[slot]
                if icon then
                    local result = item.result
                    icon:SetAura(result.icon or item.entry.icon, result.state,
                        Auras.IconText(item.entry, result, db, UI.FormatRemaining))
                    icon.tooltipLines = detail(item.entry, result, unitItem.name)
                    icon:Show()
                    timers = timers or result.remaining ~= nil
                end
            end
        end

        if count == 0 then add("header").name:SetText(L.NOTHING_WATCHED) end
    end

    for index, line in ipairs(lines) do
        if index > count then
            line:Hide()
        else
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", PAD, -UI.Sizes.HeaderHeight - UI.Spacing.SM - (index - 1) * LINE)
        end
    end
    window:SetHeight(UI.Sizes.HeaderHeight + UI.Spacing.SM + count * LINE + PAD)
    return timers
end

-- Redraws every TICK_SECONDS while a timer is visible; stops by itself otherwise.
local ticker = CreateFrame("Frame", nil, UIParent)
ticker:Hide()
local elapsed = 0
function AuraWindow.Update(db)
    local timers = AuraWindow.Render(db)
    ticker.db = db
    ticker:SetShown(timers and db.showTimers and window:IsShown())
end
ticker:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < TICK_SECONDS then return end
    elapsed = 0
    AuraWindow.Update(self.db)
end)
