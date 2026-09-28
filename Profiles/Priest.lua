-- PaTiAuras profile: Priest.
-- spellID = base/rank-1 ID of the single-target spell; `variants` = other spells that give the same buff (the
-- group "Prayer" versions). A member with either one counts as buffed; they are never two separate buffs.
-- Status: all IDs confirmed by the owner in the Interface 16001 client (deDE, 2026-09-28) with C_Spell.GetSpellInfo.
local _, ns = ...
ns.AuraProfiles = ns.AuraProfiles or {}

ns.AuraProfiles.PRIEST = {
    name = "Priest",
    -- On yourself.
    personal = {
        { key = "INNER_FIRE", spellID = 588, mine = true, expiring = true, showCount = true },
    },
    procs = {},
    healing = {},
    -- Group buffs (summary "have / total", tooltip lists who is missing it). Anyone's cast counts, not only yours.
    group = {
        { key = "FORTITUDE", spellID = 1243, variants = { 21562 }, expiring = true },          -- Machtwort: Seelenstärke / Gebet der Seelenstärke
        { key = "DIVINE_SPIRIT", spellID = 14752, variants = { 27681 }, expiring = true },     -- Göttlicher Willen / Gebet der Willenskraft
        { key = "SHADOW_PROTECTION", spellID = 976, variants = { 27683 }, expiring = true },   -- Schattenschutz / Gebet des Schattenschutzes
    },
}
