-- PaTiShared: an ordered list of spell slots in a settings modal — the one way PaTi addons let the player fill and
-- sort spells (owner 2026-10-07: same look, help and handling everywhere; used by PaTiRota and PaTiAuras).
-- Row: [icon][spell name or ID ……][▾][^][v][≡]. Type a name or ID + Enter, pick from ▾, or drag a spell from the
-- spellbook onto a slot; empty + Enter clears it; the arrows or dragging the grip ≡ (or the icon) reorder.
-- Above the rows a help note lists this as short lines with highlighted keywords. The addon owns the data and
-- decides what a change does (e.g. only out of combat); this file only draws and reports.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local EDIT_WIDTH, MOVE_WIDTH, ICON, PICK = 150, 28, 18, 22 -- PICK: the arrow inside UI.CreateSpellField
local CHEVRON = 6 -- arm length of the up/down chevron (same drawing as the dropdown arrow)
local GRIP, GRIP_LINES, GRIP_GAP = 16, 3, 4 -- drag grip: three short lines, 4 px apart
local SHARED_HELP = { { "SLOT_HELP_ADD_KEY", "SLOT_HELP_ADD" }, { "SLOT_HELP_PICK_KEY", "SLOT_HELP_PICK" },
    { "SLOT_HELP_SORT_KEY", "SLOT_HELP_SORT" },
    { "SLOT_HELP_CLEAR_KEY", "SLOT_HELP_CLEAR" } }

-- Help lines "• Keyword: text" — FontStrings have no bold, so the keyword gets the normal text colour on the muted
-- note body. lines: { { keywordKey, textKey } }.
local function helpText(lines)
    local r, g, b = UI.Color("Text")
    local color = ("|cff%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    local out = {}
    for _, line in ipairs(lines) do
        out[#out + 1] = ("• %s%s:|r %s"):format(color, UI.Text(line[1]) or "", UI.Text(line[2]) or "")
    end
    return table.concat(out, "\n")
end

local function moveButton(parent, key, up, onClick)
    local button = UI.CreateButton(parent, nil, MOVE_WIDTH, onClick)
    local arrow = CreateFrame("Frame", nil, button)
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    local sign = up and 1 or -1
    local lines = { UI.Line(arrow, CHEVRON, 45 * sign, -2, 0), UI.Line(arrow, CHEVRON, -45 * sign, 2, 0) }
    local function paint()
        for _, line in ipairs(lines) do line:SetColorTexture(UI.Color(button:IsEnabled() and "Text" or "TextMuted")) end
    end
    button:HookScript("OnEnable", paint)
    button:HookScript("OnDisable", paint)
    UI.OnThemeChanged(paint)
    paint()
    UI.SetTooltip(button, key)
    return button
end

-- modal: a UI.CreateModal modal (call while building it). options:
--   count                 number of slots
--   title                 help note title (UI.Text)
--   help                  extra help lines after the shared ones: { { keywordKey, textKey }, … } (optional)
--   get()                 → the shown list of spell IDs (0 = empty)
--   set(slot, id)         put `id` (0 = clear) into `slot`
--   moveTo(from, to)      move one slot (arrows: to = from ± 1; dragging: any slot)
--   name(id), icon(id)    display of a spell
--   choices()             → spell IDs the ▾ of each row offers (UI.CreateSpellField)
--   resolve(text)         → spell ID, 0 for empty text, nil if nothing matches
--   fromCursor()          → the spell ID on the mouse cursor, or nil
--   notFound(text)        typed text matched nothing (the addon tells the player)
-- Returns { Refresh = function }. Refreshes on the modal's OnShow and cancels a drag on its OnHide.
function UI.AddSlotList(modal, options)
    local rows, dragFrom = {}, nil
    local list = {}

    local function refresh()
        local ids = options.get()
        for slot, row in ipairs(rows) do
            local id = ids[slot] or 0
            row.field:Refresh()
            row.icon:SetTexture(id ~= 0 and options.icon(id) or nil)
            row.up:SetEnabled(slot > 1)
            row.down:SetEnabled(slot < options.count)
        end
    end
    list.Refresh = refresh

    local function setSlot(slot, id) options.set(slot, id); refresh() end
    local function moveTo(from, to)
        if to >= 1 and to <= options.count and to ~= from then options.moveTo(from, to) end
        refresh()
    end

    -- Reorder by dragging (grip or icon) onto another slot; the row under the mouse is lit while dragging.
    local function rowUnderMouse()
        for slot, row in ipairs(rows) do
            if row:IsMouseOver() then return slot end
        end
        return nil
    end
    local function showDropTarget()
        local target = rowUnderMouse()
        for slot, row in ipairs(rows) do row.drop:SetShown(slot == target and slot ~= dragFrom) end
    end
    local function endDrag(drop)
        if not dragFrom then return end
        local from, target = dragFrom, drop and rowUnderMouse()
        dragFrom = nil
        for _, row in ipairs(rows) do
            row.handle:SetScript("OnUpdate", nil)
            row.grip:SetScript("OnUpdate", nil)
            row.drop:Hide()
            row:SetAlpha(1)
        end
        if target then moveTo(from, target) end
    end
    local function makeDraggable(handle, row, slot)
        handle:RegisterForDrag("LeftButton")
        handle:SetScript("OnDragStart", function(self)
            if (options.get()[slot] or 0) == 0 then return end -- an empty slot has nothing to move
            dragFrom = slot
            row:SetAlpha(0.5)
            self:SetScript("OnUpdate", showDropTarget) -- only while dragging; removed in endDrag
        end)
        handle:SetScript("OnDragStop", function() endDrag(true) end)
        UI.SetTooltip(handle, function() return (options.get()[slot] or 0) ~= 0 and UI.L.SLOT_DRAG_TIP or nil end)
    end

    local function gripButton(row, slot)
        local grip = CreateFrame("Button", nil, row)
        grip:SetSize(GRIP, UI.Sizes.ButtonHeight)
        local lines = {}
        for index = 1, GRIP_LINES do
            lines[index] = UI.Line(grip, GRIP - 4, 0, 0, (index - (GRIP_LINES + 1) / 2) * GRIP_GAP)
        end
        local function paint(hovered)
            for _, line in ipairs(lines) do line:SetColorTexture(UI.Color(hovered and "Text" or "TextMuted")) end
        end
        grip:SetScript("OnEnter", function() paint(true) end)
        grip:SetScript("OnLeave", function() paint(false) end)
        UI.OnThemeChanged(function() paint(grip:IsMouseOver()) end)
        paint(false)
        makeDraggable(grip, row, slot)
        return grip
    end

    local function slotRow(slot)
        local row = CreateFrame("Frame", nil, modal)
        row:SetSize(ICON + UI.Spacing.SM + EDIT_WIDTH + 3 * UI.Spacing.XS + PICK + 2 * MOVE_WIDTH + GRIP,
            UI.Sizes.ButtonHeight)
        row.drop = row:CreateTexture(nil, "BACKGROUND")
        row.drop:SetPoint("TOPLEFT", -UI.Spacing.XS, UI.Spacing.XS)
        row.drop:SetPoint("BOTTOMRIGHT", UI.Spacing.XS, -UI.Spacing.XS)
        UI.Paint(row.drop, "SetColorTexture", "Accent", 0.25)
        row.drop:Hide()
        row.handle = CreateFrame("Button", nil, row)
        row.handle:SetSize(ICON, ICON)
        row.handle:SetPoint("LEFT")
        makeDraggable(row.handle, row, slot)
        row.icon = row.handle:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints()
        row.field = UI.CreateSpellField(row, {
            width = EDIT_WIDTH,
            get = function() return options.get()[slot] or 0 end,
            set = function(id) setSlot(slot, id) end,
            choices = options.choices,
            name = options.name,
            icon = options.icon,
            resolve = options.resolve,
            fromCursor = options.fromCursor,
            notFound = function(text) options.notFound(text); refresh() end,
            tooltip = function() return { UI.L.SLOT:format(slot), UI.L.SLOT_TIP } end,
        })
        row.field:SetPoint("LEFT", row.handle, "RIGHT", UI.Spacing.SM, 0)
        row.grip = gripButton(row, slot)
        row.grip:SetPoint("RIGHT")
        row.down = moveButton(row, "MOVE_DOWN", false, function() moveTo(slot, slot + 1) end)
        row.down:SetPoint("RIGHT", row.grip, "LEFT", -UI.Spacing.XS, 0)
        row.up = moveButton(row, "MOVE_UP", true, function() moveTo(slot, slot - 1) end)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -UI.Spacing.XS, 0)
        return row
    end

    local help = {}
    for _, line in ipairs(SHARED_HELP) do help[#help + 1] = line end
    for _, line in ipairs(options.help or {}) do help[#help + 1] = line end
    modal:AddNote(options.title, nil, function() return helpText(help) end, #help + 1)
    modal.cursor = modal.cursor - UI.Spacing.MD -- breathing room between the note and the rows
    for slot = 1, options.count do
        rows[slot] = slotRow(slot)
        modal:AddRow(function() return UI.L.SLOT:format(slot) end, rows[slot])
    end
    modal:HookScript("OnShow", refresh)
    modal:HookScript("OnHide", function() endDrag(false) end) -- closed mid-drag: nothing moves
    return list
end
