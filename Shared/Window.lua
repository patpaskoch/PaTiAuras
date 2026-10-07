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
    self:ApplyTheme() -- this addon's saved theme (db.theme), before the opacity that depends on its colours
    self:ApplyOpacity()
    self:PaintMenuButton()
end

-- Panel body opacity from db.opacity. Only the window background: header, texts, icons and bars stay as they are.
-- A backdrop colour is no protected property, so this is fine in combat.
function Window:ApplyOpacity()
    local r, g, b, a = UI.Color("Background")
    self:SetBackdropColor(r, g, b, a * UI.ClampOpacity(self.db and self.db.opacity))
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

function Window:SetLocked(locked)
    if self.db then self.db.locked = locked end
    self:PaintMenuButton()
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

-- The ••• button stays quiet until hovered (UI.WindowHeader.MenuAlpha; locked windows even quieter).
function Window:PaintMenuButton(hovered)
    local more = self.menuButton
    local r, g, b = UI.Color(hovered and "Text" or "TextMuted")
    for _, dot in ipairs(more.dots) do dot:SetColorTexture(r, g, b, 1) end
    more.hover:SetShown(hovered)
    local rest = self:IsLocked() and 0.4 or UI.WindowHeader.MenuAlpha
    more:SetAlpha(hovered and 1 or rest)
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
        window:SavePosition()
    end)
    window.header = header

    local titleText = header:CreateFontString(nil, "OVERLAY", UI.WindowHeader.TitleFont)
    titleText:SetPoint("LEFT", UI.Spacing.MD, 0)
    UI.Paint(titleText, "SetTextColor", UI.WindowHeader.TitleColor)
    titleText:SetAlpha(UI.WindowHeader.TitleAlpha) -- the TEST badge is its own frame: it stays fully visible
    UI.BindText(titleText, title)
    window.title = titleText

    local more = CreateFrame("Button", nil, header)
    more:SetSize(UI.Sizes.HeaderHeight, UI.Sizes.HeaderHeight)
    more:SetPoint("RIGHT", -UI.Spacing.XS, 0)
    more.hover = more:CreateTexture(nil, "BACKGROUND")
    more.hover:SetAllPoints()
    UI.Paint(more.hover, "SetColorTexture", "PanelHover")
    more.dots = {}
    for offset = -1, 1 do
        local dot = more:CreateTexture(nil, "ARTWORK")
        dot:SetSize(3, 3)
        dot:SetPoint("CENTER", offset * 5, 0)
        more.dots[#more.dots + 1] = dot
    end
    more:SetScript("OnEnter", function() window:PaintMenuButton(true) end)
    more:SetScript("OnLeave", function() window:PaintMenuButton(false) end)
    more:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        UI.ShowPopup(self, window.getMenuItems and window.getMenuItems() or {}, 140, "RIGHT")
    end)
    UI.SetTooltip(more, "MORE")
    window.menuButton = more
    -- Theme change: the body colour carries the panel opacity, the ••• dots their hover state.
    UI.OnThemeChanged(function()
        window:ApplyOpacity()
        window:PaintMenuButton(window.menuButton:IsMouseOver())
    end)
    window:PaintMenuButton()
    UI.RegisterWindow(window) -- the addon's main window (one per addon)
    return window
end
