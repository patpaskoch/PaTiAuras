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
    if def.slot and not def.spellID then -- generic weapon slot (test profile): no spell behind it
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

-- Is this profile entry available to you? Procs always (they only show while active), a generic weapon slot
-- always, everything else (also a concrete weapon imbue) when you know the spell or one of its variants. Used for
-- the watch list and the "new auras" dialog.
function Watch.IsOffered(def, category)
    if category == "procs" or (category == "weapon" and not def.spellID) then return true end
    return isKnown(def)
end

-- The settings "Watch" list: per category the entries your character can use and the client knows, in the order
-- self, procs, healing, weapon, group. Returns { { category, defs = { def, … } } } (empty categories left out).
Watch.CHOICE_ORDER = { "personal", "procs", "healing", "weapon", "group" }
function Watch.Choices(profile)
    local list = {}
    for _, category in ipairs(Watch.CHOICE_ORDER) do
        local defs = {}
        for _, def in ipairs(profile and profile[category] or {}) do
            local named = (def.slot and not def.spellID) or Spells.Name(def.spellID)
            if Watch.IsOffered(def, category) and named then defs[#defs + 1] = def end
        end
        if #defs > 0 then list[#list + 1] = { category = category, defs = defs } end
    end
    return list
end

-- Label of a profile entry in settings and dialogs: the client's spell name, or the slot name of a generic slot.
function Watch.DefName(def)
    if def.slot and not def.spellID then return L[def.nameKey] end
    return Spells.Name(def.spellID) or def.key
end

-- Switches one watch entry on or off (settings list, "new auras" dialog). 0 or 1 wanted imbue per weapon slot
-- (owner 2026-10-02): switching a concrete imbue on switches the other imbues of that slot off (one weapon cannot
-- carry two); switching it off also turns the slot's still undecided imbues off — "no imbue" stays a real choice
-- instead of the next one moving up.
function Watch.SetWatched(db, def, watched, profile)
    db.watch[def.key] = watched == true
    if not (def.slot and def.spellID) then return end
    for _, other in ipairs(profile and profile.weapon or {}) do
        if other.key ~= def.key and other.slot == def.slot and other.spellID
            and (watched or db.watch[other.key] == nil) then
            db.watch[other.key] = false
        end
    end
end

-- Weapon defs in the order Rebuild picks the wanted one per slot: explicitly chosen (watch = true) first, then the
-- undecided ones (nil = default on), each in profile order.
local function weaponPickOrder(defs, db)
    local chosen, others = {}, {}
    for _, def in ipairs(defs) do
        local list = db.watch[def.key] == true and chosen or others
        list[#list + 1] = def
    end
    for _, def in ipairs(others) do chosen[#chosen + 1] = def end
    return chosen
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
        local shown = test or db.enabled -- what to watch is the watch list alone (settings "Watch")
        local slotTaken = {} -- weapon: the first watched imbue per slot is the wanted one (SetWatched keeps one)
        local defs = shown and profile and profile[category] or {}
        if category == "weapon" then defs = weaponPickOrder(defs, db) end
        for _, def in ipairs(defs) do
            local known = test or Watch.IsOffered(def, category)
            if known and (test or Auras.IsWatched(db, def)) and not (def.slot and slotTaken[def.slot]) then
                local entry = makeEntry(def, category, test)
                if entry then
                    list[#list + 1] = entry
                    if def.slot then slotTaken[def.slot] = true end
                end
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
    Watch.weapons = Watch.testMode and WeaponImbues.TestRead(now, Watch.entries.weapon) or WeaponImbues.Read(now)
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

-- Enchant IDs of the profile's other weapon imbues: tells "another imbue is on" from "an unknown enchant".
local function otherEnchantIDs(entry)
    local ids = {}
    for _, def in ipairs(Watch.profile and Watch.profile.weapon or {}) do
        if def.key ~= entry.key then
            for _, id in ipairs(def.enchantIDs or {}) do ids[#ids + 1] = id end
        end
    end
    return ids
end

-- { { entry, result, raw } } for the watched weapon imbues whose slot holds a weapon (MISSING only when surely
-- readable; a concrete imbue only counts with its own enchant ID, see WeaponImbues.Evaluate).
function Watch.Weapon(db)
    local list, now = {}, GetTime()
    for _, entry in ipairs(Watch.entries.weapon) do
        local raw = Watch.weapons and Watch.weapons[entry.slot]
        local result = WeaponImbues.Evaluate(raw, now, db, entry, otherEnchantIDs(entry))
        if result then list[#list + 1] = { entry = entry, result = result, raw = raw } end
    end
    return list
end

function Watch.Count()
    local counts = {}
    for _, category in ipairs(Watch.CATEGORIES) do counts[category] = #Watch.entries[category] end
    return counts
end
