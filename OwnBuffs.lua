-- PaTiAuras: editor of the own list "My auras" (settings → Watch, owner 2026-10-06). Built on first open.
-- Config.OWN_SLOTS slots in display order: type a spell name or ID (Enter) or drag a spell from your spellbook onto a
-- slot; arrows or dragging the grip / icon reorder. Deliberate small copy of PaTiRota's slot list (addons stay
-- independent; fix bugs in both). The list changes lines with secure click buttons: changes only out of combat.
local _, ns = ...
local UI, L, Config, Spells = ns.UI, ns.UI.L, ns.Config, ns.Spells

local OwnBuffs = {}
ns.OwnBuffs = OwnBuffs

local app -- { db, profile, changed, combatBlocked, say } from PaTiAuras.lua
function OwnBuffs.Init(callbacks) app = callbacks end

local modal
local slotRows = {}

local EDIT_WIDTH, MOVE_WIDTH, ICON = 150, 28, 18
local PROC_WIDTH = 14 + 8 -- proc checkbox (PaTiShared box) and its gap
local CHEVRON = 6 -- arm length of the up/down chevron (same drawing as the PaTiShared dropdown arrow)
local GRIP, GRIP_LINES, GRIP_GAP = 16, 3, 4 -- drag grip: three short lines, 4 px apart

-- The saved list; the first edit turns the profile seed (Watch.OwnIDs) into a saved list.
local function slots()
    local db = app.db()
    if db.ownBuffs == nil then db.ownBuffs = Config.OwnSlots(ns.Watch.OwnIDs(db, app.profile())) end
    return db.ownBuffs
end

local function shownSlots()
    return Config.OwnSlots(ns.Watch.OwnIDs(app.db(), app.profile()))
end

-- What a slot's spell is (OwnList.Classify): "personal", "procs", "weapon" or "tracking"; nil for an empty slot.
local function kindOf(id)
    if id == 0 then return nil end
    local item = ns.OwnList.Classify({ id }, app.db(), app.profile())[1]
    return item and item.category
end

local function refreshSlots()
    local list = shownSlots()
    for slot, row in ipairs(slotRows) do
        local id = list[slot]
        if not row.edit:HasFocus() then row.edit:SetText(id ~= 0 and (Spells.Name(id) or tostring(id)) or "") end
        row.icon:SetTexture(id ~= 0 and Spells.Icon(id) or nil)
        row.up:SetEnabled(slot > 1)
        row.down:SetEnabled(slot < Config.OWN_SLOTS)
        -- The proc mark only for buffs and procs; imbues and tracking are recognised on their own.
        local kind = kindOf(id)
        row.proc:SetShown(kind == "personal" or kind == "procs")
        row.proc:Refresh()
    end
end

-- Every change: out of combat only (the window's click buttons follow the lines), then saved and rebuilt.
local function change(apply)
    if app.combatBlocked() then refreshSlots(); return end
    if apply(slots()) ~= false then app.changed() end
    refreshSlots()
end

local function setSlot(slot, id) change(function(list) Config.SetSlot(list, slot, id) end) end
local function moveTo(from, to) change(function(list) return Config.MoveTo(list, from, to) end) end
local function setProc(slot, on)
    change(function(list)
        local db = app.db()
        if type(db.ownProcs) ~= "table" then db.ownProcs = {} end
        db.ownProcs[list[slot]] = on
    end)
end

local function receiveDrag(slot)
    local id = Spells.FromCursor()
    if not id then return end
    if ClearCursor then ClearCursor() end
    setSlot(slot, id)
end

-- Reorder by dragging (grip or icon) onto another slot; the row under the mouse is lit while dragging.
local dragFrom

local function rowUnderMouse()
    for slot, row in ipairs(slotRows) do
        if row:IsMouseOver() then return slot end
    end
    return nil
end

local function showDropTarget()
    local target = rowUnderMouse()
    for slot, row in ipairs(slotRows) do row.drop:SetShown(slot == target and slot ~= dragFrom) end
end

local function endDrag(drop)
    if not dragFrom then return end
    local from, target = dragFrom, drop and rowUnderMouse()
    dragFrom = nil
    for _, row in ipairs(slotRows) do
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
        if shownSlots()[slot] == 0 then return end -- an empty slot has nothing to move
        dragFrom = slot
        row:SetAlpha(0.5)
        self:SetScript("OnUpdate", showDropTarget) -- only while dragging; removed in endDrag
    end)
    handle:SetScript("OnDragStop", function() endDrag(true) end)
    UI.SetTooltip(handle, function() return shownSlots()[slot] ~= 0 and L.OWN_DRAG_TIP or nil end)
    return handle
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
    return makeDraggable(grip, row, slot)
end

-- One slot row: [icon][spell name or ID ……][proc][^][v][≡]. Enter applies, Escape restores, empty + Enter clears.
local function slotRow(parent, slot)
    local row = CreateFrame("Frame", nil, parent)
    local width = ICON + UI.Spacing.SM + EDIT_WIDTH + PROC_WIDTH + 2 * (MOVE_WIDTH + UI.Spacing.XS) + UI.Spacing.XS + GRIP
    row:SetSize(width, UI.Sizes.ButtonHeight)
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
    local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    edit:SetSize(EDIT_WIDTH, UI.Sizes.ButtonHeight)
    edit:SetPoint("LEFT", row.icon, "RIGHT", UI.Spacing.SM, 0)
    edit:SetAutoFocus(false)
    edit:SetFontObject(UI.Fonts.Text)
    edit:SetTextInsets(UI.Spacing.SM + 2, UI.Spacing.SM, 0, 0)
    UI.ApplyBackdrop(edit, "Panel", "Border")
    edit:SetScript("OnEnterPressed", function(self)
        local id = Spells.Resolve(self:GetText())
        self:ClearFocus()
        if id then setSlot(slot, id) else app.say("OWN_NOT_FOUND", self:GetText()); refreshSlots() end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshSlots() end)
    edit:SetScript("OnReceiveDrag", function() receiveDrag(slot) end)
    edit:SetScript("OnMouseDown", function()
        if GetCursorInfo and GetCursorInfo() == "spell" then receiveDrag(slot) end
    end)
    row.edit = edit
    row.grip = gripButton(row, slot)
    row.grip:SetPoint("RIGHT")
    row.down = moveButton(row, "MOVE_DOWN", false, function() moveTo(slot, slot + 1) end)
    row.down:SetPoint("RIGHT", row.grip, "LEFT", -UI.Spacing.XS, 0)
    row.up = moveButton(row, "MOVE_UP", true, function() moveTo(slot, slot - 1) end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -UI.Spacing.XS, 0)
    row.proc = UI.CreateCheckbox(row, "", {
        get = function() return kindOf(shownSlots()[slot]) == "procs" end,
        set = function(on) setProc(slot, on) end,
    })
    row.proc:SetPoint("RIGHT", row.up, "LEFT", -UI.Spacing.SM, 0)
    UI.SetTooltip(row.proc, "OWN_PROC_TIP")
    UI.SetTooltip(edit, function() return { L.OWN_SLOT:format(slot), L.OWN_SLOT_TIP } end)
    return row
end

local function build()
    modal = UI.CreateModal("PaTiAurasOwnBuffs", "OWN_BUFFS", 440)
    modal:AddNote("OWN_BUFFS_TITLE", nil, "OWN_BUFFS_TEXT", 4)
    modal.cursor = modal.cursor - UI.Spacing.MD -- breathing room between the note and the list (as in PaTiRota)
    for slot = 1, Config.OWN_SLOTS do
        slotRows[slot] = slotRow(modal, slot)
        modal:AddRow(function() return L.OWN_SLOT:format(slot) end, slotRows[slot])
    end
    modal:Finish()
    modal:HookScript("OnShow", refreshSlots)
    modal:HookScript("OnHide", function() endDrag(false) end) -- closed mid-drag: nothing moves
end

function OwnBuffs.Open()
    if not modal then build() end
    modal:Show()
end

-- Number of spells in the list (settings button label).
function OwnBuffs.Count()
    local count = 0
    for _, id in ipairs(shownSlots()) do
        if id ~= 0 then count = count + 1 end
    end
    return count
end
