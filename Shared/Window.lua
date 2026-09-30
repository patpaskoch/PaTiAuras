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
    self:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x or defaultX or 0, db.y or defaultY or 0)
    self:ApplyOpacity()
    self:PaintMenuButton()
end

-- Panel body opacity from db.opacity. Only the window background: header, texts, icons and bars stay as they are.
-- A backdrop colour is no protected property, so this is fine in combat.
function Window:ApplyOpacity()
    local r, g, b, a = UI.Color("Background")
    self:SetBackdropColor(r, g, b, a * UI.ClampOpacity(self.db and self.db.opacity))
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

-- Locked windows keep the ••• button quiet until hovered.
function Window:PaintMenuButton(hovered)
    local more = self.menuButton
    local r, g, b = UI.Color(hovered and "Text" or "TextMuted")
    for _, dot in ipairs(more.dots) do dot:SetColorTexture(r, g, b, 1) end
    more.hover:SetShown(hovered)
    more:SetAlpha((self:IsLocked() and not hovered) and 0.4 or 1)
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
    -- Own opaque background: the header stays readable when the body is made more transparent.
    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetPoint("TOPLEFT", UI.Sizes.Border, -UI.Sizes.Border)
    headerBackground:SetPoint("BOTTOMRIGHT", -UI.Sizes.Border, 0)
    headerBackground:SetColorTexture(UI.Color("Background"))
    header:RegisterForDrag("LeftButton")
    -- Windows with secure children cannot be moved in combat.
    header:SetScript("OnDragStart", function()
        if window:IsLocked() or InCombatLockdown() then return end
        window:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        window:SetUserPlaced(false) -- position lives in the addon's DB, not in WoW's layout cache
        window:SavePosition()
    end)
    window.header = header

    local titleText = header:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
    titleText:SetPoint("LEFT", UI.Spacing.MD, 0)
    UI.BindText(titleText, title)
    window.title = titleText

    local more = CreateFrame("Button", nil, header)
    more:SetSize(UI.Sizes.HeaderHeight, UI.Sizes.HeaderHeight)
    more:SetPoint("RIGHT", -UI.Spacing.XS, 0)
    more.hover = more:CreateTexture(nil, "BACKGROUND")
    more.hover:SetAllPoints()
    more.hover:SetColorTexture(UI.Color("PanelHover"))
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
    window:PaintMenuButton()
    UI.RegisterWindow(window) -- the addon's main window (one per addon)
    return window
end
