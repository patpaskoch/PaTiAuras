-- PaTiAuras profile: Restoration Shaman.
-- spellID = base/rank-1 ID. Other ranks are matched by the name the client returns for this ID and by the
-- rank IDs found in the spellbook. An ID the client does not know simply hides its entry.
-- Status: IDs taken from classic/WotLK spell data, NOT yet confirmed in the Interface 16001 client —
-- confirm with /pa auras and record the result in PaTiAdmin/docs/WOW_API_COMPAT.md.
local _, ns = ...
ns.AuraProfiles = ns.AuraProfiles or {}

ns.AuraProfiles.SHAMAN = {
    name = "Restoration Shaman",
    -- On yourself; a click on the icon casts it on yourself.
    personal = {
        { key = "WATER_SHIELD", spellID = 24398, mine = true, expiring = true, showCount = true, clickable = true },
    },
    -- Short-lived effects on yourself, shown only while active; never clickable.
    procs = {
        { key = "TIDAL_WAVES", spellID = 53390, showCount = true },
    },
    -- Your auras on party members, shown as small icons on their frame.
    healing = {
        { key = "EARTH_SHIELD", spellID = 974, mine = true, showCount = true },
        { key = "RIPTIDE", spellID = 61295, mine = true },
    },
    -- Long group buffs cast on players (summary below the frames). Deliberately empty: totem/ground auras only last
    -- inside the totem's radius, so "out of range" would read as "missing" (owner decision 2026-10-02, AGENTS.md).
    group = {},
    -- Concrete weapon imbues (WeaponImbues.lua): spellID = what a click casts, enchantIDs = the temporary enchant
    -- IDs that count as this imbue. Only owner-observed IDs from the Forever client (docs/WOW_API_COMPAT.md):
    -- Rockbiter 29 (2026-10-02, the rank the owner cast). Another rank has another ID: it reads Unknown until added.
    -- One wanted imbue per slot (Watch.SetWatched). Flametongue, Frostbrand, Windfury: no observed IDs yet.
    weapon = {
        { key = "ROCKBITER_WEAPON", spellID = 8017, slot = "MAINHAND", enchantIDs = { 29 }, expiring = true,
            castable = true },
    },
}
