-- PaTiAuras: profession tracking (Find Herbs, Find Minerals …) — is the watched tracking on? Owner wish 2026-10-02.
-- Own adapter: depending on the client the active tracking comes from C_Minimap.GetTrackingInfo, the classic
-- GetTrackingInfo or only GetTrackingTexture; some clients also show it as a buff (Watch passes that in). None of
-- this is confirmed in the Forever client yet (docs/WOW_API_COMPAT.md) — /pa auras prints the raw values.
-- Display and one click to cast only: PaTiAuras never switches tracking by itself.
local _, ns = ...
local Tracking = {}
ns.Tracking = Tracking

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function plain(value) if isSecret(value) then return nil end return value end
local function pack(...) return { n = select("#", ...), ... } end

-- Pure: one tracking type as the client returns it — an info table (name, texture, active, spellID) or the classic
-- values (name, texture, active, type, subType, spellID). Secret values become nil; activeUnreadable marks a secret
-- or missing "active" flag.
function Tracking.ParseInfo(first, ...)
    local info
    if type(first) == "table" and not isSecret(first) then
        info = { name = plain(first.name), texture = plain(first.texture), active = first.active,
            spellID = plain(first.spellID) }
    else
        local texture, active, _, _, spellID = ...
        info = { name = plain(first), texture = plain(texture), active = active, spellID = plain(spellID) }
    end
    if isSecret(info.active) or info.active == nil then
        info.active, info.activeUnreadable = nil, true
    else
        info.active = info.active == true or info.active == 1
    end
    return info
end

local function listApi()
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        return C_Minimap.GetNumTrackingTypes, C_Minimap.GetTrackingInfo, "C_Minimap.GetTrackingInfo"
    end
    if GetNumTrackingTypes and GetTrackingInfo then return GetNumTrackingTypes, GetTrackingInfo, "GetTrackingInfo" end
    return nil, nil, nil
end

-- { listRead, list = { info, … }, textureRead, texture } — fresh every time, never errors.
function Tracking.Read()
    local result = { list = {} }
    local count, info = listApi()
    if count then
        local ok, n = pcall(count)
        if ok and type(n) == "number" and not isSecret(n) then
            result.listRead = true
            for index = 1, n do
                local values = pack(pcall(info, index))
                if values[1] then
                    result.list[#result.list + 1] = Tracking.ParseInfo(unpack(values, 2, values.n))
                else
                    result.listRead = false
                end
            end
        end
    end
    if GetTrackingTexture then
        local ok, texture = pcall(GetTrackingTexture)
        if ok and not isSecret(texture) then result.textureRead, result.texture = true, texture end
    end
    return result
end

-- Pure: the state of one watched tracking. entry = { name, icon, ids = { [spellID] = true } }; read = Tracking.Read();
-- shownAsBuff = the player's buffs show it. ACTIVE when it is on; MISSING when surely not (wrong = another one is
-- on); UNKNOWN when the client does not tell — never a guess.
function Tracking.Evaluate(entry, read, shownAsBuff)
    local icon = entry.icon
    if shownAsBuff then return { state = "ACTIVE", icon = icon } end
    local listed, other = false, false
    for _, info in ipairs(read.list or {}) do
        local isThis = (info.spellID ~= nil and entry.ids and entry.ids[info.spellID])
            or (info.name ~= nil and info.name == entry.name)
        if isThis then
            listed = true
            if info.activeUnreadable then return { state = "UNKNOWN", icon = icon } end
            if info.active then return { state = "ACTIVE", icon = icon } end
        elseif info.active then
            other = true
        end
    end
    if read.listRead and listed then return { state = "MISSING", wrong = other or nil, icon = icon } end
    if read.textureRead then
        if read.texture == nil then return { state = "MISSING", icon = icon } end -- nothing is tracked
        if icon ~= nil and type(icon) == type(read.texture) then
            if icon == read.texture then return { state = "ACTIVE", icon = icon } end
            return { state = "MISSING", wrong = true, icon = icon }
        end
    end
    return { state = "UNKNOWN", icon = icon }
end

-- Pure: a short fingerprint, so the slow fallback check repaints only on a change.
function Tracking.Signature(read)
    local parts = { tostring(read.listRead), tostring(read.textureRead), tostring(read.texture) }
    for _, info in ipairs(read.list or {}) do
        parts[#parts + 1] = tostring(info.spellID or info.name) .. "=" .. tostring(info.active)
    end
    return table.concat(parts, "|")
end

-- Test mode: the first watched tracking is on.
function Tracking.TestRead(entries)
    local first = entries and entries[1]
    return { listRead = true, list = first and { { name = first.name, active = true } } or {} }
end

-- Plain facts for /pa auras: which API answered and every tracking type it listed (secret values as "secret").
function Tracking.Describe()
    local _, _, apiName = listApi()
    local read = Tracking.Read()
    local lines = { ("Tracking API: list=%s (read=%s) · GetTrackingTexture %s → %s"):format(tostring(apiName),
        tostring(read.listRead), GetTrackingTexture and "yes" or "no",
        read.textureRead and tostring(read.texture) or "unreadable") }
    for index, info in ipairs(read.list) do
        lines[#lines + 1] = ("  #%d %s spellID=%s texture=%s active=%s"):format(index, tostring(info.name),
            tostring(info.spellID), tostring(info.texture),
            info.activeUnreadable and "unreadable" or tostring(info.active))
    end
    return lines
end
