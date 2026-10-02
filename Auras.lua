-- PaTiAuras: aura state logic without WoW API calls (unit-tested in tests/auras_spec.lua).
-- It only describes states (active / missing / expiring / unknown). It never decides what to cast.
local _, ns = ...
local Auras = {}
ns.Auras = Auras

-- Below this many seconds a personal or group buff counts as "expiring". Healing auras (HoTs) are short
-- by nature and never get this state. One central value on purpose: no aggressive warnings.
Auras.EXPIRING_SECONDS = 30

-- settings = PaTiAurasDB (Config.lua); watch[key] = false switches one entry off.
function Auras.IsWatched(settings, entry)
    return settings.enabled and settings.watch[entry.key] ~= false
end

-- entry: { key, ids = { [spellID] = true }, names = { [name] = true }, mine?, expiring? }
-- aura (normalized by the adapter): { name, spellId, icon, count, expiration, fromPlayer, secret, timerSecret }
function Auras.Matches(entry, aura)
    if aura.secret then return false end
    if entry.mine and aura.fromPlayer == false then return false end
    return (aura.spellId ~= nil and entry.ids[aura.spellId] == true)
        or (aura.name ~= nil and entry.names[aura.name] == true)
end

-- Result for one entry on one unit: { state, remaining?, count?, icon? }.
-- Unreadable (secret) auras make a missing result "UNKNOWN" instead of claiming "MISSING".
function Auras.Evaluate(entry, auras, now, settings)
    local unreadable = false
    for _, aura in ipairs(auras) do
        if aura.secret then
            unreadable = true
        elseif Auras.Matches(entry, aura) then
            local remaining
            if not aura.timerSecret and aura.expiration and aura.expiration > 0 then remaining = aura.expiration - now end
            local state = "ACTIVE"
            if remaining and entry.expiring and settings.showExpiring and remaining < Auras.EXPIRING_SECONDS then
                state = "EXPIRING"
            end
            return { state = state, remaining = remaining, count = aura.count, icon = aura.icon }
        end
    end
    return { state = unreadable and "UNKNOWN" or "MISSING" }
end

-- Short text shown on an icon: charges first (when the entry counts them), then remaining time.
function Auras.IconText(entry, result, settings, formatRemaining)
    if result.state == "MISSING" or result.state == "UNKNOWN" then return nil end
    if entry.showCount and settings.showCharges and result.count and result.count > 0 then return tostring(result.count) end
    if settings.showTimers and result.remaining then return formatRemaining(result.remaining) end
    return nil
end

-- Click-to-buff target: the first member (in unit order: you, party1..4) whose buff is MISSING and who is alive,
-- online and reachable. EXPIRING counts as buffed, UNKNOWN is never guessed. Returns the member or nil.
-- The player still clicks for every single cast; this only decides which unit the button points at.
function Auras.NextTarget(members)
    for _, member in ipairs(members) do
        if not member.unitState and member.reachable ~= false and member.result.state == "MISSING" then
            return member
        end
    end
    return nil
end

-- Alerts for PaTiAlerts (optional). items: { { entry, result } } of your watched personal buffs and weapon slots.
-- MISSING (only if showMissing) and EXPIRING are sent as WARNING; ACTIVE sends nothing (so the alert disappears) and
-- UNKNOWN never becomes a "missing" alert. Procs are left out (they only exist while active). texts = { missing,
-- expiring, imbueMissing, imbueExpiring }: plain strings. A name that is not a plain string is not sent.
function Auras.Alerts(items, texts, showMissing, isSecret)
    local list = {}
    for _, item in ipairs(items) do
        local entry, state = item.entry, item.result.state
        local weapon = entry.category == "weapon"
        local name = entry.name
        local plainName = not isSecret(name) and type(name) == "string" and name ~= ""
        if plainName and entry.category ~= "procs" and ((state == "MISSING" and showMissing) or state == "EXPIRING") then
            local missing = state == "MISSING"
            -- A concrete imbue (spellID) is named by its spell like any buff ("Rockbiter Weapon · Missing"); only a
            -- generic weapon slot ("Main Hand") needs the "weapon imbue missing" wording.
            local slotOnly = weapon and not entry.spellID
            list[#list + 1] = {
                id = (weapon and "weapon:" or "aura:") .. entry.key,
                priority = "WARNING",
                kind = weapon and (missing and "WEAPON_IMBUE_MISSING" or "WEAPON_IMBUE_EXPIRING")
                    or (missing and "AURA_MISSING" or "AURA_EXPIRING"),
                text = name,
                detail = slotOnly and (missing and texts.imbueMissing or texts.imbueExpiring)
                    or (missing and texts.missing or texts.expiring),
            }
        end
    end
    return list
end

-- Group buff summary. members: { { name, unitState = nil | "OFFLINE" | "DEAD", result } }.
-- Offline/dead members are left out: they need no buff reminder (spec: offline/dead before missing).
function Auras.Summarize(members)
    local summary = { have = 0, total = 0, missing = {}, unknown = 0, away = {} }
    for _, member in ipairs(members) do
        if member.unitState then
            summary.away[#summary.away + 1] = member.name
        else
            summary.total = summary.total + 1
            local state = member.result.state
            if state == "ACTIVE" or state == "EXPIRING" then
                summary.have = summary.have + 1
            elseif state == "UNKNOWN" then
                summary.unknown = summary.unknown + 1
            else
                summary.missing[#summary.missing + 1] = member.name
            end
        end
    end
    return summary
end

-- Alerts for PaTiAlerts from your watched group buffs. groups: Watch.Group result { { entry, summary } }.
-- One WARNING per buff while at least one living, online member surely lacks it (Summarize leaves offline/dead out
-- and counts UNKNOWN apart, so neither ever makes an alert); no list of names (those stay in the tooltip).
-- Solo: "Missing"; in a group: "Missing on N". texts = { missing, missingOn (format with %d) }.
function Auras.GroupAlerts(groups, texts, showMissing, isSecret)
    local list = {}
    if not showMissing then return list end
    for _, group in ipairs(groups) do
        local entry, summary = group.entry, group.summary
        local name = entry.name
        local plainName = not isSecret(name) and type(name) == "string" and name ~= ""
        local missing = #summary.missing
        if plainName and missing > 0 then
            list[#list + 1] = {
                id = "group:" .. entry.key,
                priority = "WARNING",
                kind = "GROUP_AURA_MISSING",
                text = name,
                detail = summary.total > 1 and texts.missingOn:format(missing) or texts.missing,
            }
        end
    end
    return list
end

-- Clicks on WEAPON and SELF lines ------------------------------------------------------------------
-- Owner wishes 2026-10-02: left-click casts a missing castable weapon imbue; right-click removes an active own buff,
-- proc or weapon imbue from your character. Always one click = one action, never by itself.

Auras.SLOT_IDS = { MAINHAND = 16, OFFHAND = 17 } -- inventory slots ("target-slot" of the cancelaura action)
-- Every secure attribute a line button may carry: re-arming sets all of them, so no old action survives.
Auras.CLICK_ATTRIBUTES = { "unit", "type1", "spell1", "type2", "spell2", "target-slot2" }

-- Pure: what a click on this line may do. item = { entry, result }; castName = the client's cast name of the
-- entry's spell, nil if it cannot be cast (unknown spell, test mode). Unknown state or a name that is not a plain
-- string: nothing. Returns { cast?, cancelSpell?, cancelSlot? }.
function Auras.LineActions(item, castName, isSecret)
    local entry, state = item.entry, item.result.state
    local actions = {}
    local active = state == "ACTIVE" or state == "EXPIRING"
    if entry.category == "weapon" then
        if state == "MISSING" and entry.castable then actions.cast = castName end
        if active then actions.cancelSlot = Auras.SLOT_IDS[entry.slot] end
    elseif active and not isSecret(entry.name) and type(entry.name) == "string" and entry.name ~= "" then
        actions.cancelSpell = entry.name
    end
    return actions
end

-- Pure: the SecureActionButtonTemplate attributes for those actions (nil = cleared). Left button: cast on yourself.
-- Right button: "cancelaura" by spell name, or for a weapon slot by "target-slot".
function Auras.ClickAttributes(actions)
    local cancel = actions.cancelSpell ~= nil or actions.cancelSlot ~= nil
    return {
        unit = (actions.cast or cancel) and "player" or nil,
        type1 = actions.cast and "spell" or nil,
        spell1 = actions.cast,
        type2 = cancel and "cancelaura" or nil,
        spell2 = actions.cancelSpell,
        ["target-slot2"] = actions.cancelSlot,
    }
end

-- Pure: the WEAPON/SELF line list while in combat. Their secure buttons cannot move in combat, so the lines of
-- combat start (frozen) keep their order: a line whose buff is gone stays as { gone = true } with its entry; new
-- lines (e.g. a proc) come after them, with their section header if it was not there. Rows: { header = key } or
-- { key, item }.
function Auras.MergeRows(frozen, current)
    local fresh, used, headers, out = {}, {}, {}, {}
    for _, row in ipairs(current) do if row.key then fresh[row.key] = row end end
    for _, row in ipairs(frozen) do
        if row.header then
            headers[row.header] = true
            out[#out + 1] = row
        else
            used[row.key] = true
            out[#out + 1] = fresh[row.key] or { key = row.key, gone = true,
                item = { entry = row.item.entry, result = { state = "MISSING", icon = row.item.result.icon } } }
        end
    end
    for _, row in ipairs(current) do
        if row.key and not used[row.key] then
            local section = row.section
            if section and not headers[section] then
                headers[section] = true
                out[#out + 1] = { header = section }
            end
            out[#out + 1] = row
        end
    end
    return out
end
