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
