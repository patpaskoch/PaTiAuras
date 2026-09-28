# PaTiAuras

PaTiAuras is a lightweight aura and buff watcher for World of Warcraft: Forever (Interface 16001).
Part of the PaTiSuite, but completely standalone: no other PaTi addon is needed, and no other PaTi addon needs it.

**No automatic gameplay decisions.** PaTiAuras shows what is active, missing or expiring — you decide what to do.

## Features (0.1.0)
- **Self:** personal buffs (Active / Missing / Expiring, remaining time, charges) and procs while they are active
- **Group:** group buff summary like `Fortitude 4 / 5`; tooltip lists who is missing it and who is offline/dead
- **Healing:** your healing auras (HoTs, shields) per party member, with timer or charges
- Profile: Restoration Shaman — Water Shield, Tidal Waves, Earth Shield, Riptide
- Settings modal (language, scale, lock, sections, display options, per-aura switches), test mode, diagnostics
- Planned: Priest group buffs (after the spell IDs are confirmed in this client), click-to-buff, optional PaTiHeal integration

## Commands
`/pa` or `/patiauras` — `show`, `hide`, `test`, `lock`, `unlock`, `reset` (position), `settings`, `auras` (spell ID check),
`debug`, `version`, `about`, `changelog`. `/pa` alone toggles the window.

Spell names come from the game client, already localized. Shared look: PaTiShared UI (embedded in `Shared/`).
