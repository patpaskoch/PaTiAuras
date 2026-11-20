-- PaTiShared: standard gameplay window with header [ Title  TEST          ••• ].
-- The window only looks and moves; what the menu entries do is decided by the addon.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local Window = {}

-- db: the addon's SavedVariables table (uses db.point/relativePoint/x/y, db.locked, db.opacity).
-- Old saves with only x/y are read as CENTER offsets; saves without opacity get the default. An old db.snapWindows
-- (snapping existed briefly) is simply ignored.
function Window:Attach(db, defaultX, defaultY)
    self.db = db
    self:ClearAllPoints()
    local point, relativePoint, x, y = UI.WindowPosition(db, defaultX, defaultY) -- a broken save cannot break SetPoint
    self:SetPoint(point, UIParent, relativePoint, x, y)
    self:KeepTopSoon()
    self:ApplyTheme() -- this addon's saved theme (db.theme), before the opacity that depends on its colours
    self:ApplyOpacity()
    self:PaintMenuButton()
end

-- Panel body opacity from db.opacity and header opacity from db.headerOpacity. Only backgrounds: texts, icons and
-- bars stay as they are. Neither a backdrop colour nor a texture alpha is protected, so this is fine in combat.
function Window:ApplyOpacity()
    local r, g, b, a = UI.Color("Background")
    self:SetBackdropColor(r, g, b, a * UI.ClampOpacity(self.db and self.db.opacity))
    local header = UI.ClampHeaderOpacity(self.db and self.db.headerOpacity)
    for _, texture in ipairs(self.headerTextures or {}) do texture:SetAlpha(header) end
end

-- This addon's theme from db.theme (invalid → default; written back so the save stays clean).
function Window:ApplyTheme()
    if not self.db then return end
    self.db.theme = UI.SetTheme(self.db.theme)
end

-- For the optional PaTiSuite control panel: switch this addon to theme `id`. The addon stores it itself in its own
-- db.theme (PaTiSuite never writes another addon's SavedVariables). Returns false before the addon has loaded its DB.
function Window:SetSuiteTheme(id)
    if not self.db then return false end
    self.db.theme = UI.ResolveTheme(id)
    self:ApplyTheme()
    return true
end

-- For the optional PaTiSuite control panel. The addon may set window.suiteSetShown(shown) → true / false (blocked,
-- e.g. secure children in combat) and window.suiteIsShown() (e.g. "shown unless hidden by the player").
function Window:SetSuiteShown(shown)
    if self.suiteSetShown then return self.suiteSetShown(shown) ~= false end
    if InCombatLockdown() and self:IsProtected() then return false end
    self:SetShown(shown)
    return true
end

function Window:IsSuiteShown()
    if self.suiteIsShown then return self.suiteIsShown() == true end
    return self:IsShown()
end

-- The top edge stays where it is when the window grows or shrinks (owner 2026-11-20: PaTiAlerts jumped in combat as
-- rows came and went). A window anchored at its centre grows up and down; anchored at its top-left corner only the
-- bottom edge moves. Re-anchors to TOPLEFT of UIParent without moving the window. Returns false when it cannot now
-- (not laid out yet, or a protected window in combat).
function Window:AnchorTopLeft()
    if InCombatLockdown() and self.IsProtected and self:IsProtected() then return false end
    local point = self:GetPoint()
    local left, top = self:GetLeft(), self:GetTop()
    if not left or not top then return false end
    if point ~= "TOPLEFT" then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    return true
end

-- After Attach: one frame later (the addon has applied its scale by then), or when the window is first shown.
function Window:KeepTopSoon()
    local function done() return self:AnchorTopLeft() and (self:SavePosition() or true) end
    if not self.keepTopWaiter then
        self.keepTopWaiter = CreateFrame("Frame")
        self:HookScript("OnShow", function() if self.keepTopPending and done() then self.keepTopPending = nil end end)
    end
    self.keepTopPending = true
    self.keepTopWaiter:SetScript("OnUpdate", function(waiter)
        waiter:SetScript("OnUpdate", nil)
        if done() then self.keepTopPending = nil end
    end)
end

function Window:SavePosition()
    if not self.db then return end
    local point, _, relativePoint, x, y = self:GetPoint()
    self.db.point, self.db.relativePoint, self.db.x, self.db.y = point, relativePoint, x, y
end

-- Display-only windows (no secure children) may also be dragged in combat; secure windows never (protected).
function Window:SetCombatMovable(movable)
    self.combatMovable = movable == true
end

function Window:IsLocked()
    return self.db and self.db.locked or false
end

-- Owner 2026-11-07: locking or unlocking answers with a chat line, so the player knows it worked (the ••• menu
-- closes at once and a locked window looks the same). Only on a real change: loading the saved state stays quiet.
function UI.LockMessage(title, locked)
    return ("|cff68caff%s:|r %s"):format(title, locked and UI.L.WINDOW_LOCKED or UI.L.WINDOW_UNLOCKED)
end

function Window:SetLocked(locked)
    local changed = self.db ~= nil and (self.db.locked == true) ~= (locked == true)
    if self.db then self.db.locked = locked end
    self:PaintMenuButton()
    if changed then print(UI.LockMessage(self.title:GetText() or "", locked)) end
end

-- getItems() returns popup items (see UI.ShowPopup); it runs on every open, so texts and states are current.
function Window:SetMenu(getItems)
    self.getMenuItems = getItems
end

function Window:SetTestMode(on)
    if on and not self.testBadge then
        self.testBadge = UI.CreateBadge(self.header, "TEST", "Warning")
        self.testBadge:SetPoint("LEFT", self.title, "RIGHT", UI.Spacing.SM, 0)
    end
    if self.testBadge then self.testBadge:SetShown(on) end
end

-- The window's own menu entry with one of these texts ("COLLAPSE"/"EXPAND", "HIDE"), or nil. The circles run exactly
-- that entry, so each addon's rules (e.g. not in combat) stay the same.
function Window:MenuEntry(...)
    local wanted = {}
    for _, text in ipairs({ ... }) do wanted[text] = true end
    for _, item in ipairs(self.getMenuItems and self.getMenuItems() or {}) do
        if wanted[item.text] then return item end
    end
    return nil
end

-- Three small icons at the right of the header (owner 2026-11-20): gear = menu, chevron = collapse/expand, X = hide.
-- Not coloured: muted, brighter under the mouse. Shown only while the mouse is over the window; an icon whose entry
-- the window does not offer stays faint and does nothing. (The name stays PaintMenuButton: SetLocked and Attach
-- call it.)
function Window:PaintMenuButton()
    local controls = self.headerControls
    if not controls then return end
    controls:SetShown(self.hovered == true)
    for _, icon in ipairs(controls.circles) do
        local item = icon.entry and icon.entry(self)
        local usable = icon.kind == "MENU" or item ~= nil
        local r, g, b = UI.Color(icon:IsMouseOver() and usable and "Text" or "TextMuted")
        for _, part in ipairs(icon.parts) do part:SetVertexColor(r, g, b, 1) end
        if icon.hole then icon.hole:SetVertexColor(UI.Color("Background")) end
        icon:SetAlpha(usable and 1 or 0.35)
        if icon.kind == "COLLAPSE" then icon:PointChevron(item and item.text == "EXPAND") end
    end
end

-- Icon drawing from plain bars (WHITE8X8, rotated) and a disc: no texture files needed, any theme colour.
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function bar(icon, width, height, angle, x, y)
    local part = icon:CreateTexture(nil, "ARTWORK")
    part:SetTexture(UI.WHITE)
    part:SetSize(width, height)
    part:SetPoint("CENTER", x or 0, y or 0)
    if angle ~= 0 and part.SetRotation then part:SetRotation(math.rad(angle)) end
    icon.parts[#icon.parts + 1] = part
    return part
end

local function drawGear(icon)
    for _, angle in ipairs({ 0, 45, 90, 135 }) do bar(icon, 3, 13, angle) end -- eight teeth
    local disc = icon:CreateTexture(nil, "ARTWORK", nil, 1)
    disc:SetTexture(DISC)
    disc:SetSize(9, 9)
    disc:SetPoint("CENTER")
    icon.parts[#icon.parts + 1] = disc
    icon.hole = icon:CreateTexture(nil, "ARTWORK", nil, 2)
    icon.hole:SetTexture(DISC)
    icon.hole:SetSize(4, 4)
    icon.hole:SetPoint("CENTER")
end

local function drawCross(icon)
    bar(icon, 2, 12, 45)
    bar(icon, 2, 12, -45)
end

-- Chevron: "v" (collapse) or "^" (expand) from two bars.
local function drawChevron(icon)
    icon.left = bar(icon, 2, 8, 0)
    icon.right = bar(icon, 2, 8, 0)
    function icon:PointChevron(up)
        if self.chevronUp == up then return end
        self.chevronUp = up
        local tilt = up and -45 or 45
        for side, part in pairs({ [-1] = self.left, [1] = self.right }) do
            part:ClearAllPoints()
            part:SetPoint("CENTER", side * 2.5, 0)
            if part.SetRotation then part:SetRotation(math.rad(side * -tilt)) end
        end
    end
    icon:PointChevron(false)
end

-- name: global frame name (e.g. "PaTiHealFrame"); title: see UI.Text.
function UI.CreateWindow(name, title, width, height)
    local window = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    for key, fn in pairs(Window) do window[key] = fn end
    window:SetSize(width, height)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    UI.ApplyBackdrop(window, "Background", "Border")

    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(UI.Sizes.HeaderHeight)
    header:EnableMouse(true)
    -- Own opaque background: the header stays readable when the body is made more transparent. Two pieces, so the
    -- window's rounded top corners stay free (UI.ApplyBackdrop): a one-pixel band inside the border and the rest.
    local headerBand = header:CreateTexture(nil, "BACKGROUND")
    headerBand:SetPoint("TOPLEFT", 2, -UI.Sizes.Border)
    headerBand:SetPoint("TOPRIGHT", -2, -UI.Sizes.Border)
    headerBand:SetHeight(1)
    UI.Paint(headerBand, "SetColorTexture", "Background")
    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetPoint("TOPLEFT", UI.Sizes.Border, -2)
    headerBackground:SetPoint("BOTTOMRIGHT", -UI.Sizes.Border, 0)
    UI.Paint(headerBackground, "SetColorTexture", "Background")
    window.headerTextures = { headerBand, headerBackground } -- see ApplyOpacity (db.headerOpacity)
    header:RegisterForDrag("LeftButton")
    -- Windows with secure children cannot be moved in combat; display-only ones may opt in (SetCombatMovable).
    header:SetScript("OnDragStart", function()
        local protected = window.IsProtected and window:IsProtected()
        if not UI.CanMoveWindow(window:IsLocked(), InCombatLockdown(), window.combatMovable, protected) then return end
        window:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        window:SetUserPlaced(false) -- position lives in the addon's DB, not in WoW's layout cache
        window:AnchorTopLeft() -- the top edge stays put when the window grows (see AnchorTopLeft)
        window:SavePosition()
    end)
    window.header = header

    local titleText = header:CreateFontString(nil, "OVERLAY", UI.WindowHeader.TitleFont)
    titleText:SetPoint("LEFT", UI.Spacing.MD, 0)
    UI.Paint(titleText, "SetTextColor", UI.WindowHeader.TitleColor)
    titleText:SetAlpha(UI.WindowHeader.TitleAlpha) -- the TEST badge is its own frame: it stays fully visible
    UI.BindText(titleText, title)
    window.title = titleText

    -- Header icons (see PaintMenuButton), left to right: menu (gear), collapse (chevron), hide (X). The menu icon is
    -- the leftmost, so header buttons an addon places left of window.menuButton (PaTiHeal's Mana) never sit under the
    -- others.
    local ICON, ICON_GAP, HOVER_CHECK = 14, 10, 0.1 -- more room between the icons (owner 2026-11-20)
    local controls = CreateFrame("Frame", nil, header)
    controls:SetPoint("RIGHT", -UI.Spacing.SM, 0)
    controls:SetSize(3 * ICON + 2 * ICON_GAP, UI.Sizes.HeaderHeight)
    controls.circles = {}
    local specs = {
        { kind = "MENU", tip = "MORE", draw = drawGear },
        { kind = "COLLAPSE", tip = "COLLAPSE", draw = drawChevron,
            entry = function(w) return w:MenuEntry("COLLAPSE", "EXPAND") end },
        { kind = "HIDE", tip = "HIDE", draw = drawCross, entry = function(w) return w:MenuEntry("HIDE") end },
    }
    for index, spec in ipairs(specs) do
        local circle = CreateFrame("Button", nil, controls)
        circle:SetSize(ICON, ICON)
        circle:SetPoint("LEFT", (index - 1) * (ICON + ICON_GAP), 0)
        circle.parts = {}
        spec.draw(circle)
        circle.kind, circle.entry = spec.kind, spec.entry
        circle:SetScript("OnClick", function(self)
            GameTooltip:Hide()
            if self.kind == "MENU" then
                UI.ShowPopup(self, window.getMenuItems and window.getMenuItems() or {}, 140, "RIGHT")
                return
            end
            local item = self.entry(window)
            if item and item.onClick then item.onClick(item) end
            window:PaintMenuButton()
        end)
        circle:HookScript("OnEnter", function() window:PaintMenuButton() end)
        circle:HookScript("OnLeave", function() window:PaintMenuButton() end)
        UI.SetTooltip(circle, function()
            if circle.kind == "COLLAPSE" then
                local item = circle.entry(window)
                return UI.Text(item and item.text or "COLLAPSE")
            end
            return UI.Text(spec.tip)
        end)
        controls.circles[index] = circle
        if spec.kind == "MENU" then window.menuButton = circle end
    end
    window.headerControls = controls
    -- Hover: a small check a few times a second while the window is shown (OnEnter/OnLeave of the window do not
    -- fire for its children, so they cannot tell "mouse over the window" alone).
    local since = 0
    controls:GetParent():HookScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < HOVER_CHECK then return end
        since = 0
        local over = window:IsMouseOver() or false
        if over ~= window.hovered then
            window.hovered = over
            window:PaintMenuButton()
        end
    end)
    -- Theme change: the body colour carries the panel opacity, the circles their colours.
    UI.OnThemeChanged(function()
        window:ApplyOpacity()
        window:PaintMenuButton()
    end)
    window:PaintMenuButton()
    UI.RegisterWindow(window) -- the addon's main window (one per addon)
    return window
end
