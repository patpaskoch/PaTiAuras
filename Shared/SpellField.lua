-- PaTiShared: one spell input (owner 2026-10-07: the same in every addon) — [spell name or ID …… ▾][rank ▾].
-- Three ways in: type a name or ID + Enter (empty + Enter clears), drag a spell from the spellbook onto the field,
-- or pick from ▾ (the addon's list of your spells, e.g. the learned buffs). The rank dropdown is optional (PaTiHeal):
-- "highest" by default, active only when the spell has several known ranks. The addon owns the data.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local PICK, RANK_WIDTH = 22, 84
UI.SPELL_FIELD = { PICK = PICK, RANK = RANK_WIDTH } -- for column titles above spell fields (PaTiHeal)
local CHEVRON = 6

-- parent: the row frame. options:
--   width                 width of the name field
--   get()                 → the spell ID (0 or nil = none)
--   set(id)               set the spell (0 = clear)
--   choices()             → spell IDs offered by ▾ (already filtered/sorted by the addon)
--   name(id), icon(id)    display of a spell
--   resolve(text)         → spell ID, 0 for empty text, nil if nothing matches
--   fromCursor()          → the spell ID on the mouse cursor, or nil
--   notFound(text)        typed text matched nothing
--   tooltip()             → tooltip lines of the name field (optional)
--   ranks(id)             → { { rank, subtext } } known numbered ranks (optional: no rank dropdown without it)
--   getRank(), setRank(r) the chosen rank, 0 = highest (with ranks)
-- Returns the field frame with :Refresh() and .edit; its width is set.
function UI.CreateSpellField(parent, options)
    local field = CreateFrame("Frame", nil, parent)
    local hasRanks = options.ranks ~= nil
    field:SetSize(options.width + PICK + (hasRanks and UI.Spacing.SM + RANK_WIDTH or 0),
        UI.Sizes.ButtonHeight)

    local edit = CreateFrame("EditBox", nil, field, "BackdropTemplate")
    edit:SetSize(options.width + PICK, UI.Sizes.ButtonHeight) -- the pick arrow sits inside, on the right
    edit:SetPoint("LEFT")
    edit:SetAutoFocus(false)
    edit:SetFontObject(UI.Fonts.Text)
    edit:SetTextInsets(UI.Spacing.SM + 2, PICK + UI.Spacing.XS, 0, 0)
    UI.ApplyBackdrop(edit, "Panel", "Border")
    field.edit = edit

    local rank
    function field:Refresh()
        local id = options.get() or 0
        if not edit:HasFocus() then edit:SetText(id ~= 0 and (options.name(id) or tostring(id)) or "") end
        if rank then rank:Refresh() end
    end

    local function set(id)
        options.set(id)
        if options.setRank then options.setRank(0) end -- a new spell starts at its highest rank
        field:Refresh()
    end

    local function receiveDrag()
        local id = options.fromCursor()
        if not id then return end
        if ClearCursor then ClearCursor() end
        set(id)
    end

    edit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local id = options.resolve(text)
        self:ClearFocus()
        if id then set(id) else options.notFound(text); field:Refresh() end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); field:Refresh() end)
    edit:SetScript("OnReceiveDrag", receiveDrag)
    edit:SetScript("OnMouseDown", function()
        if GetCursorInfo and GetCursorInfo() == "spell" then receiveDrag() end
    end)
    if options.tooltip then UI.SetTooltip(edit, options.tooltip) end

    -- The pick arrow lives inside the name field, on its right edge behind a thin divider — it reads like the
    -- arrow of a dropdown, not like the separate up/down buttons of a slot list (owner 2026-10-07).
    local pick = CreateFrame("Button", nil, edit)
    pick:SetPoint("TOPRIGHT", -1, -1)
    pick:SetPoint("BOTTOMRIGHT", -1, 1)
    pick:SetWidth(PICK - 1)
    pick:SetFrameLevel(edit:GetFrameLevel() + 2)
    local divider = pick:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 0, -UI.Spacing.XS)
    divider:SetPoint("BOTTOMLEFT", 0, UI.Spacing.XS)
    divider:SetWidth(1)
    UI.Paint(divider, "SetColorTexture", "Border")
    local hover = pick:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("TOPLEFT", 1, 0)
    hover:SetPoint("BOTTOMRIGHT")
    UI.Paint(hover, "SetColorTexture", "PanelHover")
    hover:Hide()
    local arrow = CreateFrame("Frame", nil, pick)
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER", 1, 0)
    local chevron = { UI.Line(arrow, CHEVRON, -45, -2, 0), UI.Line(arrow, CHEVRON, 45, 2, 0) }
    local function paintArrow(hovered)
        for _, line in ipairs(chevron) do line:SetColorTexture(UI.Color(hovered and "Text" or "TextMuted")) end
        hover:SetShown(hovered)
    end
    pick:SetScript("OnEnter", function() paintArrow(true) end)
    pick:SetScript("OnLeave", function() paintArrow(false) end)
    UI.OnThemeChanged(function() paintArrow(pick:IsMouseOver()) end)
    paintArrow(false)
    UI.SetTooltip(pick, "SPELL_PICK_TIP")
    pick:SetScript("OnClick", function(self)
        local items = { { text = "SPELL_NONE", onClick = function() set(0) end } }
        for _, id in ipairs(options.choices()) do
            local name = options.name(id) or tostring(id)
            items[#items + 1] = { text = function() return name end, icon = options.icon(id),
                onClick = function() set(id) end }
        end
        UI.ShowPopup(self, items, 200, "RIGHT")
    end)

    if hasRanks then
        rank = UI.CreateDropdown(field, RANK_WIDTH, {
            items = function()
                local items = { { value = 0, text = "SPELL_RANK_HIGHEST" } }
                local id = options.get()
                for _, entry in ipairs(id and id ~= 0 and options.ranks(id) or {}) do
                    local subtext = entry.subtext
                    items[#items + 1] = { value = entry.rank, text = function() return subtext end }
                end
                return items
            end,
            get = function() return options.getRank() or 0 end,
            set = function(value) options.setRank(value); field:Refresh() end,
            enabled = function()
                local id = options.get()
                return id ~= nil and id ~= 0 and #options.ranks(id) > 1
            end,
        })
        rank:SetPoint("RIGHT")
    end
    return field
end
