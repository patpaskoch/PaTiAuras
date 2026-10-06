-- PaTiAuras: the one own list (owner 2026-10-06): everything you keep up on yourself — buffs, procs, weapon imbues
-- and tracking — in your order. Pure logic, no WoW API calls (tests/ownlist_spec.lua):
--   * what kind each listed spell is (Classify),
--   * weapon imbues learn their enchant ID when you cast them (NoteCast → Learn → ApplyLearned): WoW names an imbue
--     only by a number, which differs per imbue and rank, so PaTiAuras watches what your cast put on the weapon.
local _, ns = ...
local OwnList = {}
ns.OwnList = OwnList

-- A cast is linked to a weapon change only within this many seconds (the client may report the enchant late).
OwnList.LEARN_SECONDS = 5
-- A refreshed imbue (same enchant ID) counts when its end time moved at least this far.
local REFRESH_MIN = 1
local SLOTS = { "MAINHAND", "OFFHAND" }

-- Profile entries by spell ID: { def, category } for personal, procs, weapon and tracking.
local function profileIndex(profile)
    local index = {}
    for _, category in ipairs({ "personal", "procs", "weapon", "tracking" }) do
        for _, def in ipairs(profile and profile[category] or {}) do
            if def.spellID and not index[def.spellID] then index[def.spellID] = { def = def, category = category } end
        end
    end
    return index
end

local function generic(id)
    return { key = "OWN:" .. id, spellID = id, expiring = true, showCount = true, castable = true }
end

-- What a listed spell is:
--   weapon   — a profile imbue (e.g. Rockbiter) or a spell whose imbue was learned (db.imbues[id]); its enchant IDs
--              are the profile's plus the learned ones, its hand the learned one (else the profile's).
--   tracking — a profile tracking spell (Find Herbs …).
--   procs    — marked "only while active" (db.ownProcs[id] = true), or a profile proc not marked false.
--   personal — everything else: a buff on you. A not yet learned imbue also starts here (missing until cast).
function OwnList.Classify(ids, db, profile)
    local index, list = profileIndex(profile), {}
    local imbues, procs = db.imbues or {}, db.ownProcs or {}
    for _, id in ipairs(ids) do
        if id ~= 0 then
            local known, learned = index[id], imbues[id]
            local def, category = known and known.def or generic(id), known and known.category or "personal"
            if category == "weapon" or learned then
                local enchantIDs = {}
                for _, enchantID in ipairs(category == "weapon" and def.enchantIDs or {}) do
                    enchantIDs[#enchantIDs + 1] = enchantID
                end
                for _, enchantID in ipairs(learned and learned.enchantIDs or {}) do
                    enchantIDs[#enchantIDs + 1] = enchantID
                end
                local slot = learned and learned.slot or def.slot or "MAINHAND"
                def = setmetatable({ enchantIDs = enchantIDs, slot = slot, castable = true },
                    { __index = def })
                category = "weapon"
            elseif category ~= "tracking" then
                local proc = procs[id]
                if proc == nil then proc = category == "procs" end
                category = proc and "procs" or "personal"
            end
            list[#list + 1] = { def = def, category = category }
        end
    end
    return list
end

-- Enchant ID and end time per hand, for comparing before/after a cast. weapons: Watch.weapons (WeaponImbues.Read).
function OwnList.Snapshot(weapons)
    local snapshot = {}
    for _, slot in ipairs(SLOTS) do
        local raw = weapons and weapons[slot]
        snapshot[slot] = raw and { enchantID = raw.enchantID, expiresAt = raw.expiresAt } or {}
    end
    return snapshot
end

-- A successful cast of `castID`. listed: the own list's IDs; sameSpell(listedID, castID) → true for the same spell
-- (another rank); kinds: [id] = category (OwnList.Classify). Only a listed buff or imbue (not a proc or tracking) is a
-- learning candidate. Returns a pending note { id, before, at } or nil.
function OwnList.NoteCast(castID, listed, kinds, sameSpell, weapons, now)
    for _, id in ipairs(listed) do
        if id ~= 0 and (id == castID or sameSpell(id, castID)) then
            local kind = kinds[id]
            if kind ~= "personal" and kind ~= "weapon" then return nil end
            return { id = id, before = OwnList.Snapshot(weapons), at = now }
        end
    end
    return nil
end

-- After the cast: which hand got the imbue? A readable enchant ID that is new on that hand, or the same one with a
-- clearly later end time (refreshed). Exactly one such hand → slot, enchantID. Returns nil while nothing changed,
-- and nil, true once the note is too old (then it is dropped).
function OwnList.Learn(pending, weapons, now)
    if now - pending.at > OwnList.LEARN_SECONDS then return nil, true end
    local found, foundID, count = nil, nil, 0
    for _, slot in ipairs(SLOTS) do
        local raw, before = weapons and weapons[slot], pending.before[slot] or {}
        if raw and type(raw.enchantID) == "number" then
            local refreshed = type(raw.expiresAt) == "number"
                and (type(before.expiresAt) ~= "number" or raw.expiresAt > before.expiresAt + REFRESH_MIN)
            if raw.enchantID ~= before.enchantID or refreshed then
                found, foundID, count = slot, raw.enchantID, count + 1
            end
        end
    end
    if count == 1 then return found, foundID end
    return nil
end

-- Saves what was learned: db.imbues[id] = { slot, enchantIDs }. Returns true if anything new was saved.
function OwnList.ApplyLearned(db, id, slot, enchantID)
    if type(db.imbues) ~= "table" then db.imbues = {} end
    local record = db.imbues[id]
    if not record then
        record = { slot = slot, enchantIDs = {} }
        db.imbues[id] = record
    end
    local changed = record.slot ~= slot
    record.slot = slot
    for _, known in ipairs(record.enchantIDs) do
        if known == enchantID then return changed end
    end
    record.enchantIDs[#record.enchantIDs + 1] = enchantID
    return true
end
