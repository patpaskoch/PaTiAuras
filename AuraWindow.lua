-- PaTiAuras: main window. Text lines with small icons in a grid of 1–3 columns, no headers (owner 2026-10-06):
-- group buffs first, then the own list in its order. Group lines and own-list lines carry secure click buttons
-- (see below); everything else is plain frames.
local _, ns = ...
local UI, L, Auras, Watch, Spells = ns.UI, ns.UI.L, ns.Auras, ns.Watch, ns.Spells

local AuraWindow = {}
ns.AuraWindow = AuraWindow

local WIDTH, LINE, ICON = 230, 20, 16
local PAD = UI.Spacing.MD
local LINE_WIDTH = WIDTH - 2 * PAD -- one line = one column width (vertical layout: the whole window)
local CELL_WIDTH, GRID_GAP = 160, UI.Spacing.LG -- grid of 2–3 columns: width of one line, space between columns
local VALUE_SPACE = 60 -- right part of an entry line reserved for its value (time, "4 / 5", status)
local TICK_SECONDS = 0.5 -- timer texts only; state changes come from UNIT_AURA

local window = UI.CreateWindow("PaTiAurasFrame", "PaTiAuras", WIDTH, UI.Sizes.HeaderHeight + 40)
AuraWindow.frame = window
local lines = {}

local ALERT_ALPHA = 0.18 -- red tint of a missing line: visible, text stays readable

local function newLine(index)
    local line = CreateFrame("Frame", nil, window)
    line:SetSize(LINE_WIDTH, LINE)
    line:EnableMouse(true)
    line.icon = UI.StyleAuraIcon(CreateFrame("Frame", nil, line), ICON)
    line.icon:SetPoint("LEFT")
    line.name = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    line.name:SetJustifyH("LEFT")
    line.name:SetWordWrap(false)
    line.value = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    line.value:SetPoint("RIGHT")
    -- A missing buff/imbue line is tinted red with a red bar on the left (owner wish 2026-10-06: see at a glance
    -- what is missing). Slightly wider than the line, so the bar sits left of the icon.
    line.alert = line:CreateTexture(nil, "BACKGROUND")
    line.alert:SetPoint("TOPLEFT", -UI.Spacing.XS, 0)
    line.alert:SetPoint("BOTTOMRIGHT", UI.Spacing.XS, 0)
    UI.Paint(line.alert, "SetColorTexture", "Danger", ALERT_ALPHA)
    line.alertBar = line:CreateTexture(nil, "BORDER")
    line.alertBar:SetPoint("TOPLEFT", line.alert, "TOPLEFT")
    line.alertBar:SetPoint("BOTTOMLEFT", line.alert, "BOTTOMLEFT")
    line.alertBar:SetWidth(2)
    UI.Paint(line.alertBar, "SetColorTexture", "Danger")
    line.alert:Hide()
    line.alertBar:Hide()
    UI.SetTooltip(line, function() return line.tooltipLines end)
    lines[index] = line
    return line
end

local MESSAGE_LINES = 3 -- status/hint texts wrap instead of being cut off with "..."

-- Resets a line to one of three looks: "header", "entry" (icon + name + value) or "message" (full-width muted
-- text that wraps onto up to MESSAGE_LINES lines).
local function prepare(index, kind)
    local line = lines[index] or newLine(index)
    local message = kind == "message"
    line.kind, line.tooltipLines = kind, nil
    line.icon:SetShown(kind == "entry")
    line.name:ClearAllPoints()
    if message then
        line.name:SetPoint("TOPLEFT")
        line.name:SetPoint("TOPRIGHT")
    else
        line.name:SetPoint("LEFT", kind == "entry" and ICON + UI.Spacing.SM or 0, 0)
        line.name:SetPoint("RIGHT", line, "RIGHT", -VALUE_SPACE, 0)
    end
    line.name:SetWordWrap(message)
    if line.name.SetMaxLines then line.name:SetMaxLines(message and MESSAGE_LINES or 1) end
    line.name:SetFontObject(kind == "header" and UI.Fonts.Label or UI.Fonts.Text)
    line.name:SetTextColor(UI.Color((kind == "header" or message) and "TextMuted" or "Text"))
    line.value:SetText("")
    line.alert:Hide()
    line.alertBar:Hide()
    line:Show()
    return line
end

-- Height of a laid-out line: one row, or as many rows as a wrapped message needs (up to MESSAGE_LINES).
local function lineHeight(line)
    if line.kind ~= "message" then return LINE end
    local textHeight = line.name:GetStringHeight() or 0
    return math.max(LINE, math.ceil(textHeight) + UI.Spacing.SM)
end

-- Click-to-buff ----------------------------------------------------------------------------------
-- One SecureActionButtonTemplate over each group buff line. A click casts the single-target buff on the unit in
-- the button's attributes, without changing your target. Attributes (unit, spell) can only be set out of combat:
-- in combat the button keeps the target it had when combat started (shown in the tooltip); the next missing
-- member is set after PLAYER_REGEN_ENABLED. Secure children make the window protected, so its size, position and
-- visibility also change only out of combat. The group section is drawn first, so its rows never move in combat.
local MAX_GROUP_BUFFS = 4
local securePending = false
local buffButtons = {}
for index = 1, MAX_GROUP_BUFFS do
    local button = CreateFrame("Button", "PaTiAurasBuff" .. index, window, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown") -- as PaTiLead's secure buttons (single firing: NOT YET VERIFIED)
    button:SetSize(LINE_WIDTH, LINE)
    button:SetFrameLevel((window:GetFrameLevel() or 0) + 5) -- above the (lazily created) line frames
    local highlight = button:CreateTexture(nil, "HIGHLIGHT") -- hover only while enabled
    highlight:SetAllPoints()
    UI.Paint(highlight, "SetColorTexture", "Accent", 0.12)
    UI.SetTooltip(button, function() return button.tooltipLines end)
    button:Hide()
    buffButtons[index] = button
end

-- One SecureActionButtonTemplate over each WEAPON and SELF line (owner wishes 2026-10-02), actions from
-- Auras.LineActions: left-click casts a missing weapon imbue, right-click removes an active own buff, proc or imbue.
-- Armed only out of combat; lines without an action get no button. In combat the buttons keep what they had when
-- combat started, and the lines keep their order (Auras.MergeRows), so a button never sits over another line.
local MAX_LINE_BUTTONS = 12 -- one per own-list slot (Config.OWN_SLOTS)
local lineButtons = {}
for index = 1, MAX_LINE_BUTTONS do
    local button = CreateFrame("Button", "PaTiAurasLine" .. index, window, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetSize(LINE_WIDTH, LINE)
    button:SetFrameLevel((window:GetFrameLevel() or 0) + 5)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    UI.Paint(highlight, "SetColorTexture", "Accent", 0.12)
    UI.SetTooltip(button, function() return button.tooltipLines end)
    button:Hide()
    lineButtons[index] = button
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- Single-target spell name for the click, or nil if you do not know it (then the row only displays).
local function clickSpell(entry)
    if Watch.testMode or not Spells.IsKnown(entry.spellID) then return nil end
    return Spells.CastName(entry.spellID)
end

-- What a click on a WEAPON/SELF line may do now (test mode: nothing).
local function lineActions(item)
    if Watch.testMode then return {} end
    local castName = item.entry.castable and clickSpell(item.entry) or nil
    return Auras.LineActions(item, castName, isSecret)
end

-- A secure button exactly over its line: same position (line.left / line.top in the window) and width.
local function coverLine(button, line)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + line.left, -line.top)
    button:SetWidth(line:GetWidth())
end

-- Out of combat only: position, attributes and enabled state of the buff buttons.
-- groupLines: the shown GROUP lines, in the order of groupList. clickLines: { { item, line } } of the shown
-- WEAPON/SELF/TRACKING lines. Buttons follow the lines, in both category layouts.
local function applySecure(groupList, groupLines, clickLines)
    if InCombatLockdown() then securePending = true; return end
    for index, button in ipairs(lineButtons) do
        local shown = clickLines[index]
        local actions = shown and not shown.gone and lineActions(shown.item) or {}
        local attributes = Auras.ClickAttributes(actions)
        for _, key in ipairs(Auras.CLICK_ATTRIBUTES) do button:SetAttribute(key, attributes[key]) end
        button.boundActions = actions
        if attributes.unit then
            coverLine(button, shown.line)
            button:Show()
        else
            button:Hide()
        end
    end
    for index, button in ipairs(buffButtons) do
        local item = groupList[index]
        if item then
            local spell = item.target and clickSpell(item.entry)
            coverLine(button, groupLines[index])
            button:SetAttribute("unit", spell and item.target.unit or nil)
            button:SetAttribute("type1", spell and "spell" or nil)
            button:SetAttribute("spell1", spell)
            button:SetEnabled(spell ~= nil) -- everyone buffed / spell unknown / test mode: a click does nothing
            button.boundSpell, button.boundName = spell, spell and item.target.name
            button:Show()
        else
            button:SetAttribute("type1", nil)
            button:Hide()
        end
    end
    securePending = false
end

-- MISSING in red (owner wish 2026-10-04): a missing buff or weapon imbue is the line to act on.
local STATE_COLOR = { ACTIVE = "Text", EXPIRING = "Warning", MISSING = "Danger", UNKNOWN = "TextMuted" }

local function detail(entry, result)
    local list = { entry.name, L.TIP_STATUS:format(L["STATUS_" .. result.state]) }
    if result.remaining then list[#list + 1] = L.TIP_REMAINING:format(UI.FormatRemaining(result.remaining)) end
    if result.count and result.count > 0 then list[#list + 1] = L.TIP_CHARGES:format(result.count) end
    return list
end

-- Tooltip of a WEAPON/SELF line: state, slot, "another imbue is on", and what a left/right click does. In combat
-- the button keeps the actions it had when combat started; say so instead of promising them.
local function lineTooltip(item, button)
    local entry, result = item.entry, item.result
    local tip = detail(entry, result)
    if entry.category == "weapon" and entry.spellID then
        tip[#tip + 1] = L.TIP_WEAPON_SLOT:format(L[entry.slot == "OFFHAND" and "OFF_HAND" or "MAIN_HAND"])
    end
    if result.wrong then
        tip[#tip + 1] = entry.category == "tracking" and L.TIP_OTHER_TRACKING or L.TIP_OTHER_IMBUE
    end
    local combat = InCombatLockdown()
    local actions = combat and (button and button.boundActions or {}) or lineActions(item)
    if actions.cast then tip[#tip + 1] = L.TIP_CLICK_CAST:format(actions.cast) end
    if actions.cancelSpell or actions.cancelSlot then tip[#tip + 1] = L.TIP_RIGHT_CANCEL:format(entry.name) end
    if combat and (actions.cast or actions.cancelSpell or actions.cancelSlot) then
        tip[#tip + 1] = L.TIP_COMBAT_CLICK_FIXED
    end
    return tip
end

local function valueText(entry, result, db)
    return Auras.IconText(entry, result, db, UI.FormatRemaining) or L["STATUS_" .. result.state]
end

-- Builds all lines from Watch data. Returns true if any shown value has a running timer.
-- Tooltip of a group buff line: buffed count, who misses it, who is offline/dead, and whom a click buffs.
local function groupTooltip(item, button)
    local summary = item.summary
    local tip = { item.entry.name, L.TIP_BUFFED:format(summary.have, summary.total) }
    if #summary.missing > 0 then tip[#tip + 1] = L.TIP_MISSING_ON:format(table.concat(summary.missing, ", ")) end
    if #summary.away > 0 then tip[#tip + 1] = L.TIP_AWAY:format(table.concat(summary.away, ", ")) end
    if #summary.missing == 0 then tip[#tip + 1] = L.TIP_ALL_BUFFED end
    if InCombatLockdown() then
        -- The button keeps the target it had before combat; say so instead of guessing.
        if button and button.boundSpell then
            tip[#tip + 1] = L.TIP_CLICK_NEXT:format(button.boundSpell, button.boundName)
            tip[#tip + 1] = L.TIP_COMBAT_FIXED
        end
    elseif item.target and clickSpell(item.entry) then
        tip[#tip + 1] = L.TIP_CLICK_NEXT:format(clickSpell(item.entry), item.target.name)
    end
    return tip
end

-- The own-list lines in list order, rows { key, item } (Auras.ShowOwn decides what shows). Out of combat: what is
-- shown now (remembered); in combat: the remembered lines in the same order (Auras.MergeRows) — their secure
-- buttons cannot move until combat ends.
local frozenRows
local function ownRows(db)
    local rows = {}
    for _, item in ipairs(Watch.Own(db)) do
        if Auras.ShowOwn(item, db) then rows[#rows + 1] = { key = item.entry.key, item = item } end
    end
    if InCombatLockdown() and frozenRows then return Auras.MergeRows(frozenRows, rows) end
    frozenRows = rows
    return rows
end

-- The group buff lines: all, or with "only missing" the incomplete ones. In combat the set of combat start stays
-- (their secure buttons cannot move), so a line does not vanish when the last member gets the buff.
local frozenGroup
local function groupItems(db)
    local list, keys = {}, {}
    local combat = InCombatLockdown() and frozenGroup
    for _, item in ipairs(Watch.Group(db)) do
        local shown
        if combat then
            shown = frozenGroup[item.entry.key]
        else
            shown = not db.onlyMissing or #item.summary.missing > 0
        end
        if shown then
            list[#list + 1] = item
            keys[item.entry.key] = true
        end
    end
    if not combat then frozenGroup = keys end
    return list
end

-- Columns in use: out of combat db.columns, in combat the ones of combat start (secure buttons cannot move).
local appliedColumns = 1

-- Places lines 1..count in the grid (Auras.GridCell), group lines first. A lone message spans one column and wraps.
-- Sets line.left / line.top. Returns the content width and height.
local function placeLines(count)
    local top = UI.Sizes.HeaderHeight + UI.Spacing.SM
    local cell = appliedColumns == 1 and LINE_WIDTH or CELL_WIDTH
    if count == 1 and lines[1].kind == "message" then
        local line = lines[1]
        line:SetWidth(LINE_WIDTH)
        local height = lineHeight(line)
        line:SetHeight(height)
        line.left, line.top = 0, top
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", PAD, -top)
        return LINE_WIDTH, top + height
    end
    for index = 1, count do
        local line = lines[index]
        local column, row = Auras.GridCell(index, appliedColumns)
        line.left, line.top = column * (cell + GRID_GAP), top + row * LINE
        line:SetSize(cell, LINE)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", PAD + line.left, -line.top)
    end
    local width, height = Auras.GridSize(count, appliedColumns, cell, LINE, GRID_GAP)
    return width, top + height
end

function AuraWindow.Render(db)
    if not InCombatLockdown() then appliedColumns = db.columns end
    local count, timers = 0, false
    local groupList, groupLines, clickLines = {}, {}, {}
    local function add(kind)
        count = count + 1
        return prepare(count, kind)
    end

    if db.collapsed then
        groupList = {} -- collapsed: header only; applySecure({}) hides the buff buttons (out of combat)
    elseif not db.enabled then
        add("message").name:SetText(L.DISABLED)
    else
        -- Group buffs first: their lines start at the top left and never move in combat.
        groupList = groupItems(db)
        for index, item in ipairs(groupList) do
            local line, summary = add("entry"), item.summary
            local incomplete = #summary.missing > 0
            line.icon:SetAura(item.entry.icon, incomplete and db.showMissing and "MISSING" or "ACTIVE")
            line.name:SetText(item.entry.name)
            line.value:SetText(("%d / %d"):format(summary.have, summary.total))
            line.value:SetTextColor(UI.Color(incomplete and db.showMissing and "Warning" or "Text"))
            line.tooltipLines = groupTooltip(item, buffButtons[index])
            if buffButtons[index] then buffButtons[index].tooltipLines = line.tooltipLines end
            groupLines[index] = line
        end

        -- Then the own list in its order (buffs, procs, weapon imbues, tracking), as click lines.
        for _, row in ipairs(ownRows(db)) do
            local item = row.item
            local line, result = add("entry"), item.result
            line.icon:SetAura(result.icon or item.entry.icon, result.state)
            line.name:SetText(item.entry.name)
            line.value:SetText(row.gone and "–" or valueText(item.entry, result, db))
            line.value:SetTextColor(UI.Color(STATE_COLOR[result.state]))
            local missing = result.state == "MISSING" and not row.gone
            line.alert:SetShown(missing)
            line.alertBar:SetShown(missing)
            local button = lineButtons[#clickLines + 1]
            line.tooltipLines = lineTooltip(item, button)
            if button then button.tooltipLines = line.tooltipLines end
            clickLines[#clickLines + 1] = { item = item, line = line, gone = row.gone }
            timers = timers or result.remaining ~= nil
        end

        if count == 0 then
            local nothing = #Watch.entries.own == 0 and #Watch.entries.group == 0
            add("message").name:SetText(nothing and L.NOTHING_WATCHED or L.NOTHING_MISSING)
        end
    end

    for index = count + 1, #lines do lines[index]:Hide() end
    local width, height = placeLines(count)
    applySecure(groupList, groupLines, clickLines)
    if InCombatLockdown() then
        securePending = true -- the protected window keeps its size until combat ends
    else
        window:SetSize(math.max(WIDTH, width + 2 * PAD), height + PAD)
    end
    return timers
end

-- Redraws every TICK_SECONDS while a timer is visible; stops by itself otherwise.
local ticker = CreateFrame("Frame", nil, UIParent)
ticker:Hide()
local elapsed = 0
function AuraWindow.Update(db)
    local timers = AuraWindow.Render(db)
    if AuraWindow.afterUpdate then AuraWindow.afterUpdate() end -- e.g. PaTiAlerts report (set by PaTiAuras.lua)
    ticker.db = db
    ticker:SetShown(timers and db.showTimers and window:IsShown())
end
ticker:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < TICK_SECONDS then return end
    elapsed = 0
    AuraWindow.Update(self.db)
end)

-- True while buff buttons or the window size wait for the end of combat.
function AuraWindow.HasPendingSecure() return securePending end
