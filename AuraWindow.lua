-- PaTiAuras: main window. Calm sections (GROUP, WEAPON, SELF, HEALING) of text lines with small icons.
-- The group and weapon lines carry secure click-to-buff buttons (see below); everything else is plain frames.
local _, ns = ...
local UI, L, Auras, Watch, Spells = ns.UI, ns.UI.L, ns.Auras, ns.Watch, ns.Spells

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

local MESSAGE_LINES = 3 -- status/hint texts wrap instead of being cut off with "..."

-- Resets a line to one of four looks: "header", "entry" (icon + name + value), "unit" (name + icons) or
-- "message" (full-width muted text that wraps onto up to MESSAGE_LINES lines).
local function prepare(index, kind)
    local line = lines[index] or newLine(index)
    local message = kind == "message"
    line.kind, line.tooltipLines = kind, nil
    line.icon:SetShown(kind == "entry")
    for _, icon in ipairs(line.unitIcons) do icon:Hide() end
    line.name:ClearAllPoints()
    if message then
        line.name:SetPoint("TOPLEFT")
        line.name:SetPoint("TOPRIGHT")
    else
        line.name:SetPoint("LEFT", kind == "entry" and ICON + UI.Spacing.SM or 0, 0)
        line.name:SetPoint("RIGHT", line, "RIGHT", -60, 0)
    end
    line.name:SetWordWrap(message)
    if line.name.SetMaxLines then line.name:SetMaxLines(message and MESSAGE_LINES or 1) end
    line.name:SetFontObject(kind == "header" and UI.Fonts.Label or UI.Fonts.Text)
    line.name:SetTextColor(UI.Color((kind == "header" or message) and "TextMuted" or "Text"))
    line.value:SetText("")
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
    button:RegisterForClicks("AnyUp", "AnyDown") -- as PaTiGroup's secure buttons
    button:SetSize(WIDTH - 2 * PAD, LINE)
    button:SetFrameLevel((window:GetFrameLevel() or 0) + 5) -- above the (lazily created) line frames
    local highlight = button:CreateTexture(nil, "HIGHLIGHT") -- hover only while enabled
    highlight:SetAllPoints()
    local r, g, b = UI.Color("Accent")
    highlight:SetColorTexture(r, g, b, 0.12)
    UI.SetTooltip(button, function() return button.tooltipLines end)
    button:Hide()
    buffButtons[index] = button
end

local function groupRowTop(index) -- y of group line `index` (the section header is row 0)
    return UI.Sizes.HeaderHeight + UI.Spacing.SM + index * LINE
end

-- One SecureActionButtonTemplate over each weapon imbue line (owner wish 2026-10-02): while the watched imbue is
-- MISSING (also "another imbue is on"), a click casts that spell on yourself — one click, one cast, never by itself.
-- Armed only out of combat and only for a line that is shown; ACTIVE/EXPIRING/UNKNOWN lines get no button. In
-- combat the buttons keep what they had when combat started. The WEAPON section comes right after GROUP, so its
-- lines only move when the weapon itself is taken off.
local MAX_WEAPON_BUTTONS = 2 -- one per weapon slot
local weaponButtons = {}
for index = 1, MAX_WEAPON_BUTTONS do
    local button = CreateFrame("Button", "PaTiAurasWeapon" .. index, window, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetSize(WIDTH - 2 * PAD, LINE)
    button:SetFrameLevel((window:GetFrameLevel() or 0) + 5)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    local r, g, b = UI.Color("Accent")
    highlight:SetColorTexture(r, g, b, 0.12)
    UI.SetTooltip(button, function() return button.tooltipLines end)
    button:Hide()
    weaponButtons[index] = button
end

-- Single-target spell name for the click, or nil if you do not know it (then the row only displays).
local function clickSpell(entry)
    if Watch.testMode or not Spells.IsKnown(entry.spellID) then return nil end
    return Spells.CastName(entry.spellID)
end

-- Spell name for a weapon line's click, or nil (not castable, spell unknown, test mode, nothing missing).
local function weaponClickSpell(item)
    if not (item.entry.castable and item.result.state == "MISSING") then return nil end
    return clickSpell(item.entry)
end

-- Out of combat only: position, attributes and enabled state of the buff buttons.
-- weaponLines: { { item, line } } of the shown weapon lines (line.top = its y in the window).
local function applySecure(groupList, weaponLines)
    if InCombatLockdown() then securePending = true; return end
    for index, button in ipairs(weaponButtons) do
        local shown = weaponLines[index]
        local spell = shown and weaponClickSpell(shown.item)
        if spell then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -shown.line.top)
            button:SetAttribute("unit", "player") -- an imbue is cast on yourself, never on a party member
            button:SetAttribute("type1", "spell")
            button:SetAttribute("spell1", spell)
            button.boundSpell = spell
            button:Show()
        else
            button:SetAttribute("type1", nil)
            button:SetAttribute("spell1", nil)
            button.boundSpell = nil
            button:Hide()
        end
    end
    for index, button in ipairs(buffButtons) do
        local item = groupList[index]
        if item then
            local spell = item.target and clickSpell(item.entry)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -groupRowTop(index))
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

local STATE_COLOR = { ACTIVE = "Text", EXPIRING = "Warning", MISSING = "TextMuted", UNKNOWN = "TextMuted" }

local function detail(entry, result, target)
    local list = { entry.name, L.TIP_STATUS:format(L["STATUS_" .. result.state]) }
    if result.remaining then list[#list + 1] = L.TIP_REMAINING:format(UI.FormatRemaining(result.remaining)) end
    if result.count and result.count > 0 then list[#list + 1] = L.TIP_CHARGES:format(result.count) end
    if target then list[#list + 1] = L.TIP_TARGET:format(target) end
    return list
end

-- Tooltip of a weapon imbue line: state, slot, "another imbue is on", and what a click does. In combat the button
-- keeps the spell it had when combat started; say so instead of promising a cast.
local function weaponTooltip(item, button)
    local entry, result = item.entry, item.result
    local tip = detail(entry, result)
    if entry.spellID then
        tip[#tip + 1] = L.TIP_WEAPON_SLOT:format(L[entry.slot == "OFFHAND" and "OFF_HAND" or "MAIN_HAND"])
    end
    if result.wrong then tip[#tip + 1] = L.TIP_OTHER_IMBUE end
    if InCombatLockdown() then
        if button and button.boundSpell then
            tip[#tip + 1] = L.TIP_CLICK_CAST:format(button.boundSpell)
            tip[#tip + 1] = L.TIP_COMBAT_CLICK_FIXED
        end
    elseif weaponClickSpell(item) then
        tip[#tip + 1] = L.TIP_CLICK_CAST:format(entry.name)
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

function AuraWindow.Render(db)
    local count, timers = 0, false
    local groupList, weaponLines = {}, {}
    local function add(kind)
        count = count + 1
        return prepare(count, kind)
    end
    local function header(key)
        add("header").name:SetText(string.upper(L[key]))
    end

    if db.collapsed then
        groupList = {} -- collapsed: header only; applySecure({}) hides the buff buttons (out of combat)
    elseif not db.enabled then
        add("message").name:SetText(L.DISABLED)
    elseif not Watch.profile then
        add("message").name:SetText(L.NO_PROFILE)
    else
        -- GROUP first: its rows sit at fixed positions, so the secure buttons over them never need to move in combat.
        groupList = Watch.Group(db)
        if #groupList > 0 then header("SECTION_GROUP") end
        for index, item in ipairs(groupList) do
            local line, summary = add("entry"), item.summary
            local incomplete = #summary.missing > 0
            line.icon:SetAura(item.entry.icon, incomplete and db.showMissing and "MISSING" or "ACTIVE")
            line.name:SetText(item.entry.name)
            line.value:SetText(("%d / %d"):format(summary.have, summary.total))
            line.value:SetTextColor(UI.Color(incomplete and db.showMissing and "Warning" or "Text"))
            line.tooltipLines = groupTooltip(item, buffButtons[index])
            if buffButtons[index] then buffButtons[index].tooltipLines = line.tooltipLines end
        end

        -- WEAPON right after GROUP (its click buttons must not move in combat): one line per watched imbue, named by
        -- its spell for a concrete imbue (e.g. Rockbiter Weapon), by the slot for a generic one.
        local weaponList = {}
        for _, item in ipairs(Watch.Weapon(db)) do
            if item.result.state ~= "MISSING" or db.showMissing then weaponList[#weaponList + 1] = item end
        end
        if #weaponList > 0 then header("SECTION_WEAPON") end
        for index, item in ipairs(weaponList) do
            local line, result = add("entry"), item.result
            line.icon:SetAura(result.icon, result.state)
            line.name:SetText(item.entry.name)
            line.value:SetText(valueText(item.entry, result, db))
            line.value:SetTextColor(UI.Color(STATE_COLOR[result.state]))
            line.tooltipLines = weaponTooltip(item, weaponButtons[index])
            if weaponButtons[index] then weaponButtons[index].tooltipLines = line.tooltipLines end
            weaponLines[#weaponLines + 1] = { item = item, line = line }
            timers = timers or result.remaining ~= nil
        end

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

        if count == 0 then add("message").name:SetText(L.NOTHING_WATCHED) end
    end

    -- Stack the lines by their real height (a wrapped message may take up to three rows).
    local y = UI.Sizes.HeaderHeight + UI.Spacing.SM
    for index, line in ipairs(lines) do
        if index > count then
            line:Hide()
        else
            local height = lineHeight(line)
            line:SetHeight(height)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", PAD, -y)
            line.top = y
            y = y + height
        end
    end
    applySecure(groupList, weaponLines)
    if InCombatLockdown() then
        securePending = true -- the protected window keeps its size until combat ends
    else
        window:SetHeight(y + PAD)
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
