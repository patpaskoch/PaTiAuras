-- PaTiAuras: small, optional aura and buff watcher. Shows what is active, missing or expiring.
-- It never decides or casts anything; no other PaTi addon is required.
local addonName, ns = ...
local UI, L, Config, Watch, AuraWindow, Spells = ns.UI, ns.UI.L, ns.Config, ns.Watch, ns.AuraWindow, ns.Spells

local DB
local window = AuraWindow.frame

local function say(key, ...)
    print("|cff68caffPaTiAuras:|r " .. L[key]:format(...))
end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(addonName, "Version") or "?"
end

local function update()
    if DB then AuraWindow.Update(DB) end
end

-- Profile, known spells or settings changed.
local function rebuild()
    if not DB then return end
    Spells.Rescan()
    Watch.Rebuild(DB)
    Watch.RefreshAll()
    update()
end

-- Settings ---------------------------------------------------------------------------------------

local modal

local function scaleItems()
    local items = {}
    for _, scale in ipairs(Config.SCALES) do
        items[#items + 1] = { value = scale, text = function() return ("%d %%"):format(scale * 100 + 0.5) end }
    end
    return items
end

local function buildSettings()
    modal = UI.CreateModal("PaTiAurasSettings", function() return "PaTiAuras " .. L.SETTINGS end, 400)
    local function box(label, key)
        return UI.CreateCheckbox(modal, label, {
            get = function() return DB[key] end,
            set = function(value) DB[key] = value; rebuild() end,
        })
    end
    modal:AddSection("GENERAL")
    modal:AddControls(box("ENABLE", "enabled"), box("SHOW_PERSONAL", "showPersonal"))
    modal:AddControls(box("SHOW_GROUP", "showGroup"), box("SHOW_HEALING", "showHealing"))
    modal:AddControls(box("SHOW_PROCS", "showProcs"), UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }))
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 170))
    modal:AddRow("SCALE", UI.CreateDropdown(modal, 170, {
        items = scaleItems,
        get = function() return DB.scale end,
        set = function(scale) DB.scale = scale; window:SetScale(scale) end,
    }))
    modal:AddSection("DISPLAY")
    modal:AddControls(box("SHOW_TIMERS", "showTimers"), box("SHOW_CHARGES", "showCharges"))
    modal:AddControls(box("SHOW_MISSING", "showMissing"), box("SHOW_EXPIRING", "showExpiring"))

    -- Class list: spell names come from the client (already localized).
    local profile, defs = Watch.ClassProfile(), {}
    for _, category in ipairs(Watch.CATEGORIES) do
        for _, def in ipairs(profile and profile[category] or {}) do defs[#defs + 1] = def end
    end
    if #defs > 0 then
        modal:AddSection("AURAS")
        for index = 1, #defs, 2 do
            local pair = {}
            for offset = 0, 1 do
                local def = defs[index + offset]
                if def then
                    pair[offset + 1] = UI.CreateCheckbox(modal, function() return Spells.Name(def.spellID) or def.key end, {
                        get = function() return DB.watch[def.key] ~= false end,
                        set = function(value) DB.watch[def.key] = value; rebuild() end,
                    })
                end
            end
            modal:AddControls(pair[1], pair[2])
        end
    end
    modal:Finish(function()
        Config.RestoreDefaults(DB)
        UI.SetLanguage(DB.language)
        window:SetLocked(DB.locked)
        window:SetScale(DB.scale)
        rebuild()
    end)
end

local function openSettings()
    if not modal then buildSettings() end
    modal:Show()
end

-- Commands -------------------------------------------------------------------------------------

local function toggleTestMode()
    Watch.testMode = not Watch.testMode
    window:SetTestMode(Watch.testMode)
    rebuild()
end

local function setShown(shown)
    window:SetShown(shown)
    if shown then update() else say("HIDDEN_HINT") end
end

local function resetPosition()
    DB.point, DB.relativePoint, DB.x, DB.y = nil, nil, nil, nil
    window:Attach(DB, -330, 120)
end

local function printLines(title, list)
    print("|cff68caffPaTiAuras " .. title .. ":|r")
    for _, line in ipairs(list) do print("  " .. line) end
end

local function groupType()
    if IsInRaid and IsInRaid() then return "raid" end
    return (IsInGroup and IsInGroup()) and "party" or "solo"
end

local function specText()
    if GetSpecialization and GetSpecializationInfo then
        local index = GetSpecialization()
        if index then
            local _, name = GetSpecializationInfo(index)
            if name then return name end
        end
    end
    return "n/a (talents)"
end

-- /pa debug: facts for bug reports. No names, no personal data.
local function printDebug()
    local version, build, _, interface = GetBuildInfo()
    local _, classFile = UnitClass("player")
    local counts = Watch.Count()
    local clickable = 0 -- click-to-buff is not part of v0.1
    printLines("Debug", {
        ("Addon %s %s · PaTiShared UI %s"):format(addonName, addonVersion(), tostring(UI.VERSION)),
        ("WoW %s (build %s, interface %s) · locale %s · UI language %s"):format(tostring(version), tostring(build),
            tostring(interface), GetLocale(), UI.GetLanguage()),
        ("Class %s · spec %s · %s · combat %s · test mode %s"):format(tostring(classFile), specText(), groupType(),
            InCombatLockdown() and "yes" or "no", Watch.testMode and "on" or "off"),
        ("Profile %s · tracked: personal %d, procs %d, group %d, healing %d · clickable %d · pending secure changes: no"):format(
            Watch.profile and Watch.profile.name or "none", counts.personal, counts.procs, counts.group, counts.healing, clickable),
        ("APIs: auras %s · issecretvalue %s · spellbook %s"):format(ns.AuraScan.ApiName(), issecretvalue and "yes" or "no",
            Spells.Rescan() and "ok" or "unreadable"),
    })
end

-- /pa auras: what this client reports for every profile spell ID (to confirm the IDs in game).
local function printAuraCheck()
    local profile = Watch.ClassProfile()
    local list = { ("Aura API %s · issecretvalue %s · last read error: %s"):format(ns.AuraScan.ApiName(),
        issecretvalue and "yes" or "no", ns.AuraScan.lastError or "none") }
    for _, category in ipairs(Watch.CATEGORIES) do
        for _, def in ipairs(profile and profile[category] or {}) do
            local name = Spells.Name(def.spellID)
            list[#list + 1] = ("%s %s id=%d: %s · known=%s · ranks=%d"):format(category, def.key, def.spellID,
                name or "ID NOT FOUND", tostring(name ~= nil and Spells.IsKnown(def.spellID)), #Spells.Ranks(def.spellID))
        end
    end
    if not profile then list[#list + 1] = L.NO_PROFILE end
    printLines("Auras", list)
end

local COMMANDS = {
    [""] = function() setShown(not window:IsShown()) end,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    test = toggleTestMode,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    reset = resetPosition,
    settings = openSettings,
    debug = printDebug,
    auras = printAuraCheck,
    version = function() say("VERSION", addonVersion()) end,
    about = function() say("ABOUT", addonVersion()) end,
    changelog = function() printLines(addonVersion(), { L.CHANGELOG_0_1_0 }) end,
}

SLASH_PATIAURAS1 = "/patiauras"
SLASH_PATIAURAS2 = "/pa"
SlashCmdList.PATIAURAS = function(message)
    local text = (message or ""):match("^%s*(.-)%s*$"):lower()
    local command = COMMANDS[text] or COMMANDS[text:match("^(%S+)")]
    if command and DB then command() else say("HELP") end
end

window:SetMenu(function()
    if not DB then return {} end
    return {
        { text = "SETTINGS", onClick = openSettings },
        { text = window:IsLocked() and "UNLOCK" or "LOCK", onClick = function() window:SetLocked(not window:IsLocked()) end },
        { text = "TEST_MODE", checked = Watch.testMode, onClick = toggleTestMode },
        { text = "HIDE", onClick = function() setShown(false) end },
    }
end)

-- Events ---------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
    "UNIT_CONNECTION", "UNIT_FLAGS", "SPELLS_CHANGED" }) do
    events:RegisterEvent(event)
end
for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event) -- not every client generation has these
end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        PaTiAurasDB = Config.Migrate(PaTiAurasDB)
        DB = PaTiAurasDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, -330, 120)
        window:SetScale(DB.scale)
        rebuild()
        local version = addonVersion()
        if DB.lastChangelog ~= version then
            if DB.lastChangelog then say("UPDATED", version) end
            DB.lastChangelog = version
        end
    elseif not DB then
        return
    elseif event == "UNIT_AURA" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        if Watch.IsWatchedUnit(unit) and not Watch.testMode then
            Watch.RefreshUnit(unit)
            update()
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Watch.RefreshAll()
        update()
    else -- spells, talents or spec changed
        rebuild()
    end
end)
UI.OnLanguageChanged(update)
