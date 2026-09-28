-- PaTiShared: dropdown = button with current value (+ optional icon) and a ▾ arrow, opening a popup list.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local ICON = UI.Sizes.IconMedium

-- options.items() -> { { value, text, icon? }, ... }  (called on every open/refresh)
-- options.get() -> current value; options.set(value); options.placeholder: text when nothing matches;
-- options.enabled() -> boolean (optional, re-checked on every refresh).
function UI.CreateDropdown(parent, width, options)
    local dropdown = UI.CreateButton(parent, nil, width or 180)
    dropdown.options = options

    dropdown.icon = dropdown:CreateTexture(nil, "ARTWORK")
    dropdown.icon:SetSize(ICON, ICON)
    dropdown.arrow = CreateFrame("Frame", nil, dropdown)
    dropdown.arrow:SetSize(12, 12)
    dropdown.arrow:SetPoint("RIGHT", -UI.Spacing.MD, 0)
    local arrowLines = { UI.Line(dropdown.arrow, 6, -45, -2, 0), UI.Line(dropdown.arrow, 6, 45, 2, 0) }
    for _, line in ipairs(arrowLines) do line:SetColorTexture(UI.Color("TextMuted")) end

    function dropdown:LayoutLabel(dx, dy)
        local left = UI.Spacing.MD
        self.icon:ClearAllPoints()
        self.icon:SetPoint("LEFT", left + dx, dy)
        if self.icon:IsShown() then left = left + ICON + UI.Spacing.SM end
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", left + dx, dy)
        self.label:SetPoint("RIGHT", self.arrow, "LEFT", -UI.Spacing.SM + dx, dy)
        self.label:SetJustifyH("LEFT")
    end

    function dropdown:Refresh()
        if self.options.enabled then self:SetEnabled(self.options.enabled()) end
        local current = self.options.get()
        local selected
        for _, item in ipairs(self.options.items()) do
            if item.value == current then selected = item; break end
        end
        self.icon:SetTexture(selected and selected.icon)
        self.icon:SetShown(selected ~= nil and selected.icon ~= nil)
        self.label:SetText(UI.Text(selected and selected.text or self.options.placeholder or "SELECT") or "")
        self.label:SetTextColor(UI.Color(selected and self:IsEnabled() and "Text" or "TextMuted"))
        self:LayoutLabel(0, 0)
    end

    dropdown:SetScript("OnClick", function(self)
        local current = self.options.get()
        local items = {}
        for index, item in ipairs(self.options.items()) do
            items[index] = {
                text = item.text, icon = item.icon, checked = item.value == current,
                onClick = function() self.options.set(item.value); self:Refresh() end,
            }
        end
        UI.ShowPopup(self, items, self:GetWidth(), "LEFT")
    end)
    UI.OnLanguageChanged(function() dropdown:Refresh() end)
    dropdown:Refresh()
    return dropdown
end

-- Language choice for every addon's settings. db.language: "auto" (default) or a language code.
function UI.CreateLanguageDropdown(parent, db, width)
    return UI.CreateDropdown(parent, width, {
        items = function()
            local items = {}
            for index, language in ipairs(UI.LANGUAGES) do
                local code = language.code
                items[index] = { value = code, text = function() return UI.LanguageName(code) end }
            end
            return items
        end,
        get = function() return db.language or "auto" end,
        set = function(code)
            db.language = code
            UI.SetLanguage(code)
        end,
    })
end
