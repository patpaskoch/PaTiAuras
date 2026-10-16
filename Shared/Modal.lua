-- PaTiShared: settings modal with sections, label/control rows and a footer.
-- Build it top to bottom: AddSection / AddRow / AddControl, then Finish.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local Modal = {}
local SECTION_HEIGHT = 14
local FOOTER = UI.Spacing.LG + UI.Sizes.ButtonHeight + UI.Spacing.LG -- Close / Restore Defaults below the content
local SCREEN_MARGIN = 40 -- a modal taller than the screen minus this scrolls (owner 2026-10-16)
local SCROLL_STEP = 40 -- px per mouse-wheel notch

-- Rows live on the scrolling content frame; controls the addon created on the modal itself move there.
local function adopt(modal, control)
    if control:GetParent() == modal then control:SetParent(modal.content) end
end

-- Sections are clearly apart (owner 2026-10-07): from the second one on, a gap, a thin divider line and another
-- gap come first; the title is in the accent colour so it reads as a heading, not as a muted label.
function Modal:AddSection(text)
    if self.sections > 0 then
        self.cursor = self.cursor - UI.Spacing.LG
        local divider = self.content:CreateTexture(nil, "BORDER")
        divider:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor)
        divider:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -UI.Spacing.LG, self.cursor)
        divider:SetHeight(1)
        UI.Paint(divider, "SetColorTexture", "Border")
        self.cursor = self.cursor - 1 - UI.Spacing.LG
    end
    self.sections = self.sections + 1
    local label = self.content:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    label:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor)
    UI.Paint(label, "SetTextColor", "Accent")
    UI.BindText(label, function() return string.upper(UI.Text(text) or "") end)
    self.cursor = self.cursor - SECTION_HEIGHT - UI.Spacing.MD
    return label
end

-- Label left, control right-aligned on the same line.
function Modal:AddRow(text, control)
    local height = control:GetHeight()
    adopt(self, control)
    control:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -UI.Spacing.LG, self.cursor)
    local label = self.content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetPoint("LEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor - height / 2)
    label:SetPoint("RIGHT", control, "LEFT", -UI.Spacing.MD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    UI.Paint(label, "SetTextColor", "Text")
    UI.BindText(label, text)
    self.cursor = self.cursor - height - UI.Spacing.SM
    return label
end

-- Full-width control, e.g. a checkbox.
function Modal:AddControl(control)
    adopt(self, control)
    control:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor)
    self.cursor = self.cursor - control:GetHeight() - UI.Spacing.SM
    return control
end

-- Two short controls side by side (e.g. checkboxes); right may be nil.
function Modal:AddControls(left, right)
    adopt(self, left)
    left:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor)
    local height = left:GetHeight()
    if right then
        adopt(self, right)
        right:SetPoint("TOPLEFT", self.content, "TOPLEFT", self:GetWidth() / 2, self.cursor)
        height = math.max(height, right:GetHeight())
    end
    self.cursor = self.cursor - height - UI.Spacing.SM
end

-- A small muted label that groups the following controls inside a section.
function Modal:AddLabel(text)
    local label = self.content:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
    label:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor - UI.Spacing.XS)
    UI.BindText(label, text)
    self.cursor = self.cursor - SECTION_HEIGHT - UI.Spacing.XS
    return label
end

-- A help note: slightly raised panel with an accent line on the left, a title, an optional highlighted line
-- (e.g. a menu path) and wrapped text. Help, not a warning: no warning colours, nothing blinks.
-- title/highlight/text: see UI.Text (highlight may be nil). minLines: body lines to reserve at least, so a
-- longer translation after a language switch still fits.
local NOTE_LINE = 13
function Modal:AddNote(title, highlight, text, minLines)
    local width = self:GetWidth() - 2 * UI.Spacing.LG
    local inner = width - 2 * UI.Spacing.MD - 2
    local note = CreateFrame("Frame", nil, self.content)
    note:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.Spacing.LG, self.cursor)
    note:SetWidth(width)
    local background = note:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    UI.Paint(background, "SetColorTexture", "PanelHover")
    local accent = note:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(2)
    UI.Paint(accent, "SetColorTexture", "Accent")

    local left = 2 + UI.Spacing.MD
    -- title nil: no heading line (e.g. the commands list, whose section title already says it).
    local anchor, height
    if title then
        anchor = note:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
        anchor:SetPoint("TOPLEFT", left, -UI.Spacing.MD)
        UI.Paint(anchor, "SetTextColor", "Text")
        UI.BindText(anchor, title)
        height = UI.Spacing.MD + 14
    else
        height = UI.Spacing.MD - UI.Spacing.SM -- the body below adds SM: MD above the first line
    end
    if highlight then
        local path = note:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
        path:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -UI.Spacing.SM)
        path:SetWidth(inner)
        path:SetJustifyH("LEFT")
        UI.Paint(path, "SetTextColor", "Accent")
        UI.BindText(path, highlight)
        anchor, height = path, height + UI.Spacing.SM + 14
    end
    local body = note:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    if anchor then
        body:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -UI.Spacing.SM)
    else
        body:SetPoint("TOPLEFT", left, -UI.Spacing.MD)
    end
    body:SetWidth(inner)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    UI.Paint(body, "SetTextColor", "TextMuted")
    UI.BindText(body, text)
    local bodyHeight = math.max(body:GetStringHeight() or 0, (minLines or 1) * NOTE_LINE)
    height = height + UI.Spacing.SM + bodyHeight + UI.Spacing.MD
    note:SetHeight(height)
    self.cursor = self.cursor - height - UI.Spacing.SM
    return note
end

-- onDefaults nil = no "Restore Defaults" button.
-- Commands section (owner 2026-10-07): the addon's slash commands, read from its HELP text ("/pa show, hide, …"),
-- each with a short meaning (shared CMD_<NAME> keys). Added by Finish for windows set up with AddWindowSettings.
local function commandLines()
    local help = UI.L.HELP
    local slash, rest = tostring(help):match("^(/%S+)%s+(.+)$")
    if not slash then return nil end
    local r, g, b = UI.Color("Text")
    local color = ("|cff%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    local lines = { ("• %s%s|r: %s"):format(color, slash, UI.L.CMD_TOGGLE_WINDOW) }
    for name in rest:gmatch("[^,%s]+") do
        local meaning = UI.L["CMD_" .. name:upper()]
        if meaning ~= "CMD_" .. name:upper() then
            lines[#lines + 1] = ("• %s%s %s|r: %s"):format(color, slash, name, meaning)
        end
    end
    return lines
end

-- Modal height: the whole content, at most the screen height minus a margin; the rest scrolls.
function Modal:FitHeight()
    local full = self.headerHeight + 1 + self.contentHeight + FOOTER
    local screen = UIParent:GetHeight()
    local limit = screen and screen > 0 and screen - 2 * SCREEN_MARGIN or full
    self.content:SetHeight(self.contentHeight)
    self:SetHeight(math.min(full, limit))
end

-- Commands section folded (owner 2026-10-16: the modal got too tall): the section title is a toggle "+" / "-"; it is
-- the last content, so unfolding only adds its height. Opens folded each time (nothing saved).
local function addCommands(modal, count)
    local title = modal:AddSection("COMMANDS")
    local top = modal.cursor
    local note = modal:AddNote(nil, nil, function() return table.concat(commandLines() or {}, "\n") end, count)
    local unfolded = top - modal.cursor
    modal.cursor = top
    note:Hide()
    local sign = modal.content:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    sign:SetPoint("LEFT", title, "RIGHT", UI.Spacing.SM, 0)
    UI.Paint(sign, "SetTextColor", "Accent")
    local toggle = CreateFrame("Button", nil, modal.content)
    toggle:SetPoint("TOPLEFT", title, "TOPLEFT", -UI.Spacing.XS, UI.Spacing.XS)
    toggle:SetPoint("BOTTOMRIGHT", sign, "BOTTOMRIGHT", UI.Spacing.XS, -UI.Spacing.XS)
    local folded
    local function setFolded(value)
        folded = value
        note:SetShown(not folded)
        sign:SetText(folded and "+" or "-")
        modal.contentHeight = modal.foldedHeight + (folded and 0 or unfolded)
        modal:FitHeight()
    end
    toggle:SetScript("OnClick", function() setFolded(not folded) end)
    toggle:SetScript("OnEnter", function() title:SetAlpha(0.8); sign:SetAlpha(0.8) end)
    toggle:SetScript("OnLeave", function() title:SetAlpha(1); sign:SetAlpha(1) end)
    modal:HookScript("OnShow", function() setFolded(true) end)
    sign:SetText("+")
    modal.setCommandsFolded = setFolded
end

function Modal:Finish(onDefaults)
    local lines = self.patiWindow and commandLines()
    if lines then addCommands(self, #lines) end
    self.cursor = self.cursor - UI.Spacing.MD
    self.foldedHeight = -self.cursor
    self.contentHeight = self.foldedHeight
    local divider = self:CreateTexture(nil, "BORDER")
    divider:SetPoint("BOTTOMLEFT", UI.Spacing.LG, FOOTER)
    divider:SetPoint("BOTTOMRIGHT", -UI.Spacing.LG, FOOTER)
    divider:SetHeight(1)
    UI.Paint(divider, "SetColorTexture", "Border")

    local close = UI.CreateButton(self, "CLOSE", nil, function() self:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -UI.Spacing.LG, UI.Spacing.LG)
    if onDefaults then
        local defaults = UI.CreateButton(self, "RESTORE_DEFAULTS", nil, function() onDefaults(); self:Refresh() end)
        defaults:SetPoint("BOTTOMLEFT", UI.Spacing.LG, UI.Spacing.LG)
    end
    self:FitHeight()
    self:HookScript("OnShow", function(modal) modal:FitHeight() end) -- the screen size may have changed
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

-- Opening a Blizzard panel (e.g. the spellbook) closes the frames in UISpecialFrames (owner 2026-10-06: the settings
-- vanished when the spellbook opened — but dragging a spell into a list needs both open). ESC must still close a
-- modal, so it stays in UISpecialFrames; a modal hidden while ShowUIPanel runs (same frame time) is shown again
-- right after it. Post-hook only (hooksecurefunc): nothing of Blizzard's panel code is replaced.
local hiddenAt = {} -- modal → GetTime() of its last hide
local panelHook = false
local function watchPanels()
    if panelHook or not hooksecurefunc or not ShowUIPanel then return end
    panelHook = true
    hooksecurefunc("ShowUIPanel", function()
        local now = GetTime()
        for modal, at in pairs(hiddenAt) do
            hiddenAt[modal] = nil
            if at == now then modal:Show() end
        end
    end)
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
    modal:SetScript("OnHide", function(self)
        UI.HidePopup()
        if GetTime then hiddenAt[self] = GetTime() end
    end)
    watchPanels()

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
    UI.OnThemeChanged(function() paintClose(close:IsMouseOver()) end)

    -- Drag the modal by its title bar (owner 2026-10-06); not saved, it opens centred again next time.
    modal:SetMovable(true)
    if modal.SetDontSavePosition then modal:SetDontSavePosition(true) end
    local grip = CreateFrame("Frame", nil, modal)
    grip:SetPoint("TOPLEFT")
    grip:SetPoint("RIGHT", close, "LEFT", -UI.Spacing.XS, 0)
    modal.headerClose, modal.headerGrip = close, grip
    grip:SetHeight(headerHeight)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() modal:StartMoving() end)
    grip:SetScript("OnDragStop", function() modal:StopMovingOrSizing() end)

    local divider = modal:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", 1, -headerHeight)
    divider:SetPoint("TOPRIGHT", -1, -headerHeight)
    divider:SetHeight(1)
    UI.Paint(divider, "SetColorTexture", "Border")

    -- Content scrolls (owner 2026-10-16: the PaTiHeal settings reached past the screen). Title bar and footer stay;
    -- the mouse wheel scrolls, a thin bar on the right shows where you are. Open popups close when it scrolls.
    local scroll = CreateFrame("ScrollFrame", nil, modal)
    scroll:SetPoint("TOPLEFT", 0, -headerHeight - 1)
    scroll:SetPoint("BOTTOMRIGHT", 0, FOOTER + 1)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(modal:GetWidth(), 1)
    scroll:SetScrollChild(content)
    local thumb = modal:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    UI.Paint(thumb, "SetColorTexture", "BorderStrong")
    thumb:Hide()
    local function paintThumb()
        local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
        if range <= 0 or view <= 0 then thumb:Hide(); return end
        local height = math.max(20, view * view / (view + range))
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -3, -(view - height) * scroll:GetVerticalScroll() / range)
        thumb:SetHeight(height)
        thumb:Show()
    end
    local function scrollTo(value)
        local range = scroll:GetVerticalScrollRange() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(range, value)))
        paintThumb()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        UI.HidePopup()
        scrollTo(scroll:GetVerticalScroll() - delta * SCROLL_STEP)
    end)
    scroll:SetScript("OnScrollRangeChanged", function() scrollTo(scroll:GetVerticalScroll()) end)
    scroll:SetScript("OnSizeChanged", paintThumb)
    modal:HookScript("OnShow", function() scrollTo(0) end) -- opens at the top

    modal.headerHeight, modal.scroll, modal.content = headerHeight, scroll, content
    modal.sections = 0
    modal.cursor = -UI.Spacing.LG -- from the content top
    return modal
end

-- The window settings every PaTi addon offers: theme (db.theme) and panel opacity (db.opacity).
-- window: a UI.CreateWindow window after Attach (uses window.db). Call inside the settings modal build.
-- onThemeChosen(id) (optional): called after the player picked a theme here (PaTiSuite passes it on to all windows).
-- The window's "Test Mode" menu entry (if it has one): { checked, onClick } as the addon builds it, or nil.
local function testMenuEntry(window)
    for _, item in ipairs(window.getMenuItems and window.getMenuItems() or {}) do
        if item.text == "TEST_MODE" then return item end
    end
    return nil
end

-- Test mode switch top right in the settings, next to the close button (owner 2026-10-07). It runs the window's
-- own "Test Mode" menu entry, so the addon's rules (e.g. not in combat) stay exactly the same.
local function addTestSwitch(modal, window)
    if not testMenuEntry(window) or not modal.headerClose then return end
    local switch = UI.CreateCheckbox(modal, "TEST_MODE", {
        get = function() local entry = testMenuEntry(window); return entry ~= nil and entry.checked == true end,
        set = function()
            local entry = testMenuEntry(window)
            if entry and entry.onClick then entry.onClick(entry) end
        end,
    })
    switch:SetPoint("RIGHT", modal.headerClose, "LEFT", -UI.Spacing.MD, 0)
    switch:SetFrameLevel(modal.headerGrip:GetFrameLevel() + 2) -- above the drag area of the title bar
    modal.headerGrip:SetPoint("RIGHT", switch, "LEFT", -UI.Spacing.XS, 0)
    modal:HookScript("OnShow", function() switch:Refresh() end)
end

function UI.AddWindowSettings(modal, window, width, onThemeChosen)
    modal.patiWindow = window -- Finish adds the commands section
    addTestSwitch(modal, window)
    modal:AddSection("WINDOW")
    local themes = {}
    for _, id in ipairs(UI.THEME_ORDER) do themes[#themes + 1] = { value = id, text = "THEME_" .. id:upper() } end
    modal:AddRow("THEME", UI.CreateDropdown(modal, width or 170, {
        items = function() return themes end,
        get = function() return UI.ResolveTheme(window.db.theme) end,
        set = function(id)
            window.db.theme = id
            window:ApplyTheme()
            if onThemeChosen then onThemeChosen(id) end
        end,
    }))
    local items = {}
    for _, value in ipairs(UI.OPACITY_STEPS) do
        items[#items + 1] = { value = value, text = function() return ("%d %%"):format(value * 100 + 0.5) end }
    end
    modal:AddRow("PANEL_OPACITY", UI.CreateDropdown(modal, width or 170, {
        items = function() return items end,
        get = function() return UI.ClampOpacity(window.db.opacity) end,
        set = function(value) window.db.opacity = value; window:ApplyOpacity() end,
    }))
end
