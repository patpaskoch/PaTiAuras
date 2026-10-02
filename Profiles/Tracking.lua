-- PaTiAuras: profession tracking, added to every class profile (owner wish 2026-10-02). Classic spell IDs, NOT
-- confirmed in the Interface 16001 client: an ID the client does not know, or a spell you did not learn, stays
-- hidden — /pa auras shows what your client knows. slot = "TRACKING": only one tracking can be on at a time, so at
-- most one is the wanted one (Watch.SetWatched). castable: a click on a missing line casts it (one click, one cast).
local _, ns = ...
ns.AuraProfiles = ns.AuraProfiles or {}

ns.AuraTracking = {
    { key = "FIND_HERBS", spellID = 2383, slot = "TRACKING", castable = true },    -- Herbalism
    { key = "FIND_MINERALS", spellID = 2580, slot = "TRACKING", castable = true }, -- Mining
    { key = "FIND_TREASURE", spellID = 2481, slot = "TRACKING", castable = true }, -- Dwarf racial
}

for _, profile in pairs(ns.AuraProfiles) do profile.tracking = ns.AuraTracking end
