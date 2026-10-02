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

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- PaTiAlerts is optional (AGENTS.md §3): report only if it is installed with API version 1, never depend on it.
-- Sent: your watched personal buffs and weapon imbues that are missing or expiring (Auras.Alerts) and your watched
-- group buffs that a living, online member lacks (Auras.GroupAlerts, one line per buff); pcall so a problem
-- in PaTiAlerts never breaks PaTiAuras. Test mode and "disabled" send an empty list (their alerts disappear).
local function reportAlerts()
    local api = _G.PaTiAlertsAPI
    if type(api) ~= "table" or api.version ~= 1 or type(api.Sync) ~= "function" then return end
    local list = {}
    if DB.enabled and not Watch.testMode then
        local items = {}
        for _, item in ipairs(Watch.Self(DB)) do items[#items + 1] = item end
        for _, item in ipairs(Watch.Weapon(DB)) do items[#items + 1] = item end
        list = ns.Auras.Alerts(items, { missing = L.STATUS_MISSING, expiring = L.STATUS_EXPIRING,
            imbueMissing = L.ALERT_IMBUE_MISSING, imbueExpiring = L.ALERT_IMBUE_EXPIRING }, DB.showMissing, isSecret)
        local groupAlerts = ns.Auras.GroupAlerts(Watch.Group(DB), { missing = L.STATUS_MISSING,
            missingOn = L.ALERT_GROUP_MISSING }, DB.showMissing, isSecret)
        for _, alert in ipairs(groupAlerts) do list[#list + 1] = alert end
    end
    pcall(api.Sync, "PaTiAuras", list)
end

-- After every redraw (events and the 0.5 s timer redraw), so "expiring" reaches PaTiAlerts in time.
AuraWindow.afterUpdate = function() if DB then reportAlerts() end end

local function update()
    if DB then AuraWindow.Update(DB) end
end

-- Profile, known spells or settings changed.
local updateWeaponCheck -- defined with the events below

local function rebuild()
    if not DB then return end
    Spells.Rescan()
    Watch.Rebuild(DB)
    Watch.RefreshAll()
    update()
    if updateWeaponCheck then updateWeaponCheck() end
end

-- The window holds secure click-to-buff buttons, so showing, hiding, moving, scaling and anything that changes
-- their targets (test mode) is only possible out of combat.
local function combatBlocked()
    if InCombatLockdown() then say("COMBAT_LOCKED"); return true end
    return false
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
    -- "On" and "show missing" change which lines exist; in combat the secure click buttons could not follow.
    local LINE_KEYS = { enabled = true, showMissing = true }
    local function box(label, key)
        return UI.CreateCheckbox(modal, label, {
            get = function() return DB[key] end,
            set = function(value)
                if LINE_KEYS[key] and combatBlocked() then return end
                DB[key] = value
                rebuild()
            end,
        })
    end
    modal:AddSection("GENERAL")
    modal:AddControls(box("ENABLE", "enabled"), UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }))
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 170))
    modal:AddRow("SCALE", UI.CreateDropdown(modal, 170, {
        items = scaleItems,
        get = function() return DB.scale end,
        set = function(scale)
            DB.scale = scale
            if not combatBlocked() then window:SetScale(scale) end -- else applied after combat
        end,
    }))
    UI.AddWindowSettings(modal, window) -- panel opacity (PaTiShared)

    -- WATCH: the one list of what to watch (DB.watch), as a multi-select popup of your character's entries.
    modal:AddSection("WATCH")
    local watchButton
    local function watchLabel()
        local on, total = 0, 0
        for _, group in ipairs(Watch.Choices(Watch.ClassProfile())) do
            for _, def in ipairs(group.defs) do
                total = total + 1
                if DB.watch[def.key] ~= false then on = on + 1 end
            end
        end
        return total > 0 and L.WATCH_SELECT:format(on, total) or L.WATCH_NONE
    end
    local function watchItems()
        local items = {}
        for _, group in ipairs(Watch.Choices(Watch.ClassProfile())) do
            items[#items + 1] = { header = true, text = string.upper(L["WATCH_" .. group.category:upper()]) }
            for _, def in ipairs(group.defs) do
                items[#items + 1] = { text = Watch.DefName(def), checked = DB.watch[def.key] ~= false, keepOpen = true,
                    onClick = function()
                        if combatBlocked() then return end -- lines (and their click buttons) change
                        -- Toggles this entry; a concrete weapon imbue switches the others of its slot off.
                        Watch.SetWatched(DB, def, DB.watch[def.key] == false, Watch.ClassProfile())
                        rebuild()
                        watchButton.label:SetText(watchLabel())
                    end }
            end
        end
        return items
    end
    watchButton = UI.CreateButton(modal, watchLabel, 240, function(self)
        UI.ShowPopup(self, watchItems, 240, "LEFT")
    end)
    modal:AddControl(watchButton)
    modal:HookScript("OnShow", function() watchButton.label:SetText(watchLabel()) end)

    modal:AddSection("DISPLAY")
    modal:AddControls(box("SHOW_TIMERS", "showTimers"), box("SHOW_CHARGES", "showCharges"))
    modal:AddControls(box("SHOW_MISSING", "showMissing"), box("SHOW_EXPIRING", "showExpiring"))
    modal:Finish(function()
        Config.RestoreDefaults(DB)
        window:ApplyOpacity()
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

-- New auras ------------------------------------------------------------------------------------
-- On the first start and whenever an aura becomes available that was never offered (newly learned spell,
-- profile update), a small dialog lists just those — pre-checked, changes apply at once. Closing it (also ESC)
-- marks them as seen; later changes happen in the settings. Never shown in combat (waits for the end of combat).

local newAurasDialog, newAurasWaiting, dialogCount = nil, false, 0

local function promptNewAuras()
    if not DB or Watch.testMode or (newAurasDialog and newAurasDialog:IsShown()) then return end
    if InCombatLockdown() then newAurasWaiting = true; return end
    newAurasWaiting = false
    local profile, offered = Watch.ClassProfile(), {}
    for _, category in ipairs(Watch.CATEGORIES) do
        for _, def in ipairs(profile and profile[category] or {}) do
            if Watch.IsOffered(def, category) then offered[#offered + 1] = def end
        end
    end
    local new = Config.NewDefs(offered, DB.seen)
    if #new == 0 then return end
    -- The list differs each time, so every prompt gets its own small modal (rare: first start, new spells).
    dialogCount = dialogCount + 1
    local dialog = UI.CreateModal("PaTiAurasNewAuras" .. dialogCount, "NEW_AURAS_TITLE", 320)
    dialog:AddLabel("NEW_AURAS_QUESTION")
    for _, def in ipairs(new) do
        dialog:AddControls(UI.CreateCheckbox(dialog, function() return Watch.DefName(def) end, {
            get = function() return DB.watch[def.key] ~= false end,
            set = function(value)
                if combatBlocked() then return end
                Watch.SetWatched(DB, def, value, Watch.ClassProfile())
                rebuild()
            end,
        }))
    end
    dialog:AddLabel("NEW_AURAS_LATER")
    dialog:Finish()
    dialog:HookScript("OnHide", function()
        for _, def in ipairs(new) do DB.seen[def.key] = true end
    end)
    newAurasDialog = dialog
    dialog:Show()
end

-- Commands -------------------------------------------------------------------------------------

local function toggleTestMode()
    if combatBlocked() then return end
    Watch.testMode = not Watch.testMode
    window:SetTestMode(Watch.testMode)
    rebuild()
end

local function setShown(shown, quiet)
    if InCombatLockdown() then -- secure buff buttons: the window cannot be shown/hidden in combat
        if not quiet then say("COMBAT_LOCKED") end
        return false
    end
    window:SetShown(shown)
    if shown then update() elseif not quiet then say("HIDDEN_HINT") end
    return true
end

-- Optional PaTiSuite control panel: the same rules as the commands, without chat lines (false = not possible now).
window.suiteSetShown = function(shown) return setShown(shown, true) end

local function toggleCollapsed()
    if combatBlocked() then return end -- secure buff buttons: no hide/resize in combat
    DB.collapsed = not DB.collapsed
    update()
end

local function resetPosition()
    if combatBlocked() then return end
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
-- Saved watch value per weapon imbue of your profile (to see a deselected one in /pa debug).
local function weaponWatchText()
    local parts = {}
    for _, def in ipairs(Watch.profile and Watch.profile.weapon or {}) do
        parts[#parts + 1] = def.key .. "=" .. tostring(DB.watch[def.key])
    end
    return #parts > 0 and table.concat(parts, ", ") or "none"
end

local function printDebug()
    local version, build, _, interface = GetBuildInfo()
    local _, classFile = UnitClass("player")
    local counts = Watch.Count()
    local clickable = 0
    for _, entry in ipairs(Watch.entries.group) do
        if Spells.IsKnown(entry.spellID) then clickable = clickable + 1 end
    end
    printLines("Debug", {
        ("Addon %s %s · PaTiShared UI %s"):format(addonName, addonVersion(), tostring(UI.VERSION)),
        ("WoW %s (build %s, interface %s) · locale %s · UI language %s"):format(tostring(version), tostring(build),
            tostring(interface), GetLocale(), UI.GetLanguage()),
        ("Class %s · spec %s · %s · combat %s · test mode %s"):format(tostring(classFile), specText(), groupType(),
            InCombatLockdown() and "yes" or "no", Watch.testMode and "on" or "off"),
        ("Profile %s · tracked: personal %d, procs %d, group %d, healing %d, weapon %d · clickable %d · pending secure: %s"):format(
            Watch.profile and Watch.profile.name or "none", counts.personal, counts.procs, counts.group, counts.healing,
            counts.weapon, clickable, AuraWindow.HasPendingSecure() and "yes" or "no"),
        ("APIs: auras %s · issecretvalue %s · spellbook %s"):format(ns.AuraScan.ApiName(), issecretvalue and "yes" or "no",
            Spells.Rescan() and "ok" or "unreadable"),
        ("Weapon watch (nil = default on, false = off): %s"):format(weaponWatchText()),
        unpack(ns.WeaponImbues.Describe(GetTime(), DB, false, Watch.Weapon(DB))),
    })
end

-- /pa auras: what this client reports for every profile spell ID (to confirm the IDs in game).
local function printAuraCheck()
    local profile = Watch.ClassProfile()
    local list = { ("Aura API %s · issecretvalue %s · last read error: %s"):format(ns.AuraScan.ApiName(),
        issecretvalue and "yes" or "no", ns.AuraScan.lastError or "none") }
    local function describe(label, id)
        local name = Spells.Name(id)
        return ("%s id=%d: %s · known=%s · ranks=%d"):format(label, id, name or "ID NOT FOUND",
            tostring(name ~= nil and Spells.IsKnown(id)), #Spells.Ranks(id))
    end
    if profile then list[#list + 1] = "Profile " .. profile.name end
    local weapons = false
    for _, category in ipairs(Watch.CATEGORIES) do
        for _, def in ipairs(profile and profile[category] or {}) do
            if def.slot then weapons = true end -- what the enchant APIs report: once, after the spell list
            if def.spellID then
                list[#list + 1] = describe(category .. " " .. def.key, def.spellID)
                for _, variant in ipairs(def.variants or {}) do
                    list[#list + 1] = describe("    + same buff", variant)
                end
            end
        end
    end
    if weapons then
        for _, line in ipairs(ns.WeaponImbues.Describe(GetTime(), DB, true, Watch.Weapon(DB))) do
            list[#list + 1] = line
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
    local combat = InCombatLockdown()
    local combatTip = combat and "COMBAT_LOCKED" or nil
    return {
        { text = "SETTINGS", onClick = openSettings },
        { text = window:IsLocked() and "UNLOCK" or "LOCK", onClick = function() window:SetLocked(not window:IsLocked()) end },
        { text = DB.collapsed and "EXPAND" or "COLLAPSE", disabled = combat, tooltip = combatTip, onClick = toggleCollapsed },
        { text = "TEST_MODE", checked = Watch.testMode, disabled = combat, tooltip = combatTip, onClick = toggleTestMode },
        { text = "HIDE", disabled = combat, tooltip = combatTip, onClick = function() setShown(false) end },
    }
end)

-- Events ---------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
    "UNIT_CONNECTION", "UNIT_FLAGS", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    events:RegisterEvent(event)
end
for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED",
    "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED" }) do
    pcall(events.RegisterEvent, events, event) -- not every client generation has these
end

-- Weapon imbues: no UNIT_AURA. Inventory/equipment events are the main signal; whether this client fires them for
-- imbues is unconfirmed, so a slow check (every 1 s, only while weapon slots are watched) repaints on changes only.
local WEAPON_CHECK_SECONDS = 1
local weaponCheck = CreateFrame("Frame")
weaponCheck:Hide()
local sinceWeaponCheck = 0
weaponCheck:SetScript("OnUpdate", function(_, elapsed)
    sinceWeaponCheck = sinceWeaponCheck + elapsed
    if sinceWeaponCheck < WEAPON_CHECK_SECONDS then return end
    sinceWeaponCheck = 0
    if Watch.RefreshWeapons() then update() end
end)
updateWeaponCheck = function() -- assigns the local declared above rebuild()
    weaponCheck:SetShown(DB ~= nil and DB.enabled and not Watch.testMode and #Watch.entries.weapon > 0)
end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        PaTiAurasDB = Config.Migrate(PaTiAurasDB, Watch.ClassProfile()) -- the profile: once, for schema 1 → 2
        DB = PaTiAurasDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, -330, 120)
        if not InCombatLockdown() then window:SetScale(DB.scale) end -- /reload in combat: after combat
        rebuild()
        promptNewAuras()
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
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "WEAPON_ENCHANT_CHANGED" or event == "WEAPON_SLOT_CHANGED" then
        if (event ~= "UNIT_INVENTORY_CHANGED" or unit == "player") and Watch.RefreshWeapons() then update() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat over: buff buttons point at the next missing member again, window gets its real size/scale.
        window:SetScale(DB.scale)
        update()
        if newAurasWaiting then promptNewAuras() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        update() -- tooltips switch to "target fixed until combat ends"
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Watch.RefreshAll()
        update()
    else -- spells, talents or spec changed
        rebuild()
        promptNewAuras() -- a newly learned buff may be new to the watch list
    end
end)
UI.OnLanguageChanged(update)
