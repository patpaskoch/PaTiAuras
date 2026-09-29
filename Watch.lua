-- PaTiAuras: which auras are watched and their current state per unit (no UI code here).
-- v1 covers the 5-player party: player + party1..4.
local _, ns = ...
local L, Auras, Spells, AuraScan, WeaponImbues = ns.UI.L, ns.Auras, ns.Spells, ns.AuraScan, ns.WeaponImbues

local Watch = {
    UNITS = { "player", "party1", "party2", "party3", "party4" },
    CATEGORIES = { "personal", "procs", "group", "healing", "weapon" },
    entries = { personal = {}, procs = {}, group = {}, healing = {}, weapon = {} },
    info = {},
    testMode = false,
}
ns.Watch = Watch

local CATEGORY_SETTING = { personal = "showPersonal", procs = "showProcs", group = "showGroup", healing = "showHealing",
    weapon = "showWeapon" }
local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

local WATCHED_UNIT = {}
for _, unit in ipairs(Watch.UNITS) do WATCHED_UNIT[unit] = true end

function Watch.IsWatchedUnit(unit) return WATCHED_UNIT[unit] == true end

function Watch.ClassProfile()
    local _, classFile = UnitClass("player")
    return ns.AuraProfiles and ns.AuraProfiles[classFile]
end

-- One watched buff. `variants` (e.g. the Prayer version of a group buff) join the same entry: their names and
-- rank IDs are added to ids/names, so either spell counts as "has the buff".
local function makeEntry(def, category, test)
    if def.slot then -- weapon imbue slot: no spell behind it (see WeaponImbues.lua)
        return setmetatable({ category = category, name = L[def.nameKey], ids = {}, names = {} }, { __index = def })
    end
    local name = Spells.Name(def.spellID) or (test and def.nameKey and L[def.nameKey]) or (test and def.key)
    if not name then return nil end -- ID unknown to this client: the entry stays hidden
    local ids, names = Spells.FamilyIDs(def.spellID), { [name] = true }
    for _, variant in ipairs(def.variants or {}) do
        local variantName = Spells.Name(variant)
        if variantName then names[variantName] = true end
        for id in pairs(Spells.FamilyIDs(variant)) do ids[id] = true end
    end
    return setmetatable({ category = category, name = name, icon = Spells.Icon(def.spellID), ids = ids, names = names },
        { __index = def })
end

-- A buff is offered if you know the spell or one of its variants (e.g. only the Prayer rank is learned).
local function isKnown(def)
    if Spells.IsKnown(def.spellID) then return true end
    for _, variant in ipairs(def.variants or {}) do
        if Spells.IsKnown(variant) then return true end
    end
    return false
end

-- Is this profile entry available to you? Procs always (they only show while active), everything else when you
-- know the spell or one of its variants. Used for the watch list and the "new auras" dialog.
function Watch.IsOffered(def, category)
    return category == "procs" or category == "weapon" or isKnown(def)
end

-- Label of a profile entry in settings and dialogs: the client's spell name, or the slot name for weapon imbues.
function Watch.DefName(def)
    if def.slot then return L[def.nameKey] end
    return Spells.Name(def.spellID) or def.key
end

-- Recomputes the watched entries (login, spells learned, settings or test mode changed).
function Watch.Rebuild(db)
    local test = Watch.testMode
    -- Test mode shows your class profile with fake auras; classes without a profile get the generic test profile.
    local profile = Watch.ClassProfile()
    if test and not profile then profile = AuraScan.TEST_PROFILE end
    Watch.profile = profile
    for _, category in ipairs(Watch.CATEGORIES) do
        local list = {}
        local shown = test or (db.enabled and db[CATEGORY_SETTING[category]])
        for _, def in ipairs(shown and profile and profile[category] or {}) do
            local known = test or Watch.IsOffered(def, category)
            if known and (test or Auras.IsWatched(db, def)) then
                list[#list + 1] = makeEntry(def, category, test)
            end
        end
        Watch.entries[category] = list
    end
end

-- Name and offline/dead state of a unit, or nil if the unit does not exist.
local function unitBasics(unit)
    if Watch.testMode then
        local fake = AuraScan.TEST_UNITS[unit]
        return fake and { name = L[fake.nameKey], state = fake.state }
    end
    if not UnitExists(unit) then return nil end
    -- Names end up in table.concat/format (tooltips), so a secret name is replaced, never passed on.
    local name = UnitName(unit)
    if isSecret(name) or name == nil then
        name = unit == "player" and L.YOU or L.PARTY_MEMBER:format(tonumber(unit:match("%d")) or 0)
    end
    local basics = { name = name }
    -- Flags: secrecy first; an unreadable flag gives no state (the aura data decides, UNKNOWN if unreadable).
    local connected, dead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
    if not isSecret(connected) and not connected then basics.state = "OFFLINE"
    elseif not isSecret(dead) and dead then basics.state = "DEAD" end
    -- Reachable = within the client's visibility range (far-away members are no click target).
    -- Unreadable or missing API → nil, treated as reachable; the cast itself reports "out of range".
    if UnitIsVisible then
        local visible = UnitIsVisible(unit)
        if not isSecret(visible) then basics.reachable = visible == true or visible == 1 end
    end
    return basics
end

-- Re-reads one unit (UNIT_AURA etc.). Offline/dead units keep no aura list: their state wins.
function Watch.RefreshUnit(unit)
    local info = unitBasics(unit)
    if info then
        if Watch.testMode then
            info.helpful = AuraScan.TestAuras(unit, Watch.entries, GetTime())
        else
            info.helpful = info.state and {} or AuraScan.Read(unit, "HELPFUL")
        end
    end
    Watch.info[unit] = info
end

-- Weapon imbues (not UNIT_AURA): re-read on inventory/equipment events and by the slow fallback check.
-- Returns true if anything changed since the last read.
function Watch.RefreshWeapons()
    local now = GetTime()
    Watch.weapons = Watch.testMode and WeaponImbues.TestRead(now) or WeaponImbues.Read(now)
    local signature = WeaponImbues.Signature(Watch.weapons)
    local changed = signature ~= Watch.weaponSignature
    Watch.weaponSignature = signature
    return changed
end

function Watch.RefreshAll()
    for _, unit in ipairs(Watch.UNITS) do Watch.RefreshUnit(unit) end
    Watch.RefreshWeapons()
end

-- View data for the window ---------------------------------------------------------------------

-- { { entry, result } } for personal buffs (always listed) and procs (only while active).
function Watch.Self(db)
    local list, player, now = {}, Watch.info.player, GetTime()
    local helpful = player and player.helpful or {}
    for _, entry in ipairs(Watch.entries.personal) do
        list[#list + 1] = { entry = entry, result = Auras.Evaluate(entry, helpful, now, db) }
    end
    for _, entry in ipairs(Watch.entries.procs) do
        local result = Auras.Evaluate(entry, helpful, now, db)
        if result.state == "ACTIVE" or result.state == "EXPIRING" then list[#list + 1] = { entry = entry, result = result } end
    end
    return list
end

-- { { entry, summary } } — only when in a group.
-- { { entry, summary, target } } — also solo (then you are the only member). `target` is the member a click
-- would buff next (Auras.NextTarget), or nil when everyone reachable has it.
function Watch.Group(db)
    local list, now = {}, GetTime()
    for _, entry in ipairs(Watch.entries.group) do
        local members = {}
        for _, unit in ipairs(Watch.UNITS) do
            local info = Watch.info[unit]
            if info then
                members[#members + 1] = { unit = unit, name = info.name, unitState = info.state,
                    reachable = info.reachable, result = Auras.Evaluate(entry, info.helpful, now, db) }
            end
        end
        list[#list + 1] = { entry = entry, summary = Auras.Summarize(members), target = Auras.NextTarget(members) }
    end
    return list
end

-- { { name, auras = { { entry, result } } } } — units with at least one of your healing auras active.
-- Offline/dead units have no aura list (see RefreshUnit), so they never show up here.
function Watch.Healing(db)
    local list, now = {}, GetTime()
    if #Watch.entries.healing == 0 then return list end
    for _, unit in ipairs(Watch.UNITS) do
        local info = Watch.info[unit]
        if info then
            local auras = {}
            for _, entry in ipairs(Watch.entries.healing) do
                local result = Auras.Evaluate(entry, info.helpful, now, db)
                if result.state == "ACTIVE" or result.state == "EXPIRING" then auras[#auras + 1] = { entry = entry, result = result } end
            end
            if #auras > 0 then list[#list + 1] = { name = info.name, auras = auras } end
        end
    end
    return list
end

-- { { entry, result } } for the watched weapon slots that hold a weapon (MISSING only when surely readable).
function Watch.Weapon(db)
    local list, now = {}, GetTime()
    for _, entry in ipairs(Watch.entries.weapon) do
        local result = WeaponImbues.Evaluate(Watch.weapons and Watch.weapons[entry.slot], now, db)
        if result then list[#list + 1] = { entry = entry, result = result } end
    end
    return list
end

function Watch.Count()
    local counts = {}
    for _, category in ipairs(Watch.CATEGORIES) do counts[category] = #Watch.entries[category] end
    return counts
end
