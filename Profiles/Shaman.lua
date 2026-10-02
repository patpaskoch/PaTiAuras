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
    -- Weapon imbues per slot (WeaponImbues.lua): V1 checks "an imbue is on this weapon", not which one — the client's
    -- way to name an imbue is not confirmed yet. Slots without a weapon (e.g. a shield) are not shown.
    weapon = {
        { key = "MAIN_HAND_IMBUE", slot = "MAINHAND", nameKey = "MAIN_HAND", expiring = true },
        { key = "OFF_HAND_IMBUE", slot = "OFFHAND", nameKey = "OFF_HAND", expiring = true },
    },
}
