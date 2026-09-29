# PaTiAuras

PaTiAuras is a lightweight aura and buff watcher for World of Warcraft: Forever (Interface 16001).
Part of the PaTiSuite, but completely standalone: no other PaTi addon is needed, and no other PaTi addon needs it.

**No automatic gameplay decisions.** PaTiAuras shows what is active, missing or expiring — you decide what to do.

**Status:** 0.1.0 is not yet verified in the game client — the spell IDs are unconfirmed (check with `/pa auras`).

## Features (0.1.0)
- **Self:** personal buffs (Active / Missing / Expiring, remaining time, charges) and procs while they are active
- **Group:** group buff summary like `Fortitude 4 / 5`; tooltip lists who is missing it and who is offline/dead
- **Healing:** your healing auras (HoTs, shields) per party member, with timer or charges
- Profiles: Restoration Shaman — Water Shield, Tidal Waves, Earth Shield, Riptide (IDs not yet confirmed in game);
  Priest — Inner Fire (personal) and the group buffs Fortitude, Divine Spirit, Shadow Protection, where the
  Prayer version counts as the same buff (IDs confirmed in game), plus the healing auras Renew, Power Word: Shield,
  Prayer of Mending (IDs not yet confirmed). Group buffs are also shown when you play alone.
- Works without PaTiHeal. If you use both, PaTiHeal already shows your HoTs/shields on its frames: switch them off
  here if you do not want them twice (each aura has its own switch).
- Settings modal (language, scale, lock, sections, display options, per-aura switches), test mode, diagnostics
- On the first start, and when you learn a new watchable buff, a small window asks which auras to watch
- **Click-to-buff:** click a group buff line to cast the single-target buff on the next member who is missing it
  (shown in the tooltip). Each cast needs your click; your target does not change. In combat the click target stays
  as it was when combat began — WoW allows changing it only out of combat.
- Planned: optional PaTiHeal integration

## Commands
`/pa` or `/patiauras` — `show`, `hide`, `test`, `lock`, `unlock`, `reset` (position), `settings`, `auras` (spell ID check),
`debug`, `version`, `about`, `changelog`. `/pa` alone toggles the window.

Spell names come from the game client, already localized. Shared look: PaTiShared UI (embedded in `Shared/`).
