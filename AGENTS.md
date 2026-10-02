# AGENTS.md — PaTiAuras

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full.
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: show which auras/buffs/HoTs are active, missing or expiring. Never recommend or cast by itself. Not a WeakAuras clone:
  no trigger editor, no scripting, no import strings, no boss auras, no raid matrix.
- Files: `Config.lua` (SavedVariables defaults/migration, pure) · `SpellBook.lua` (spell adapter, deliberate copy of
  PaTiHeal's) · `Auras.lua` (state logic, pure) · `AuraScan.lua` (aura adapter + test data) ·
  `WeaponImbues.lua` (temporary weapon enchants: own adapter, not UNIT_AURA; pure Evaluate) · `Profiles/<Class>.lua` (data) ·
  `Watch.lua` (state per unit) · `AuraWindow.lua` (UI) · `PaTiAuras.lua` (init, settings, slash, events).
- SavedVariables: `PaTiAurasDB` (per character), schema 1 — see `Config.DEFAULTS`; `watch[key] = false` hides one aura;
  `seen[key] = true` = already offered in the "new auras" dialog (`promptNewAuras`, `Config.NewDefs`).
- Profiles: only classes whose spell IDs are confirmed in this client. A new profile = one data file + TOC line, no code.
  Several spells giving the same buff (e.g. Prayer versions) = one entry with `variants = { id, … }`, never two entries.
- Secure: `PaTiAurasBuff1..4` (SecureActionButtonTemplate) over the group buff lines; `unit`/`type1`/`spell1` set only out of
  combat in `AuraWindow.applySecure` (target = `Auras.NextTarget`, tested). The window is therefore protected: no
  resize/show/hide/scale/move in combat (pending until PLAYER_REGEN_ENABLED); the group section stays first.
  Owner decision 2026-09-28: pre-selecting the next missing member is allowed; never cast, target or loop by itself.
- No totem or ground auras (owner decision 2026-10-02): effects that only last while a player stands in the radius of
  a placed totem or ground source (e.g. Shaman totem group buffs) are never watched — not in profiles, Watch, group
  counts, missing logic or PaTiAlerts reports, and no logic that infers from members' auras that a totem should be
  recast. Reason: leaving the radius is not "the buff is missing"; it would only make false alerts. Group buffs cast
  directly on players (e.g. Priest Fortitude, Divine Spirit, Shadow Protection) stay. A totem feature, if ever, tracks
  the totem itself, not the group's auras (PaTiAdmin/docs/FOLLOW_UPS.md F27).
- Independence: no dependency on PaTiHeal/PaTiTank and no runtime API between them (owner decision 2026-09-28).
  PaTiHeal shows healer auras on its own frames with its own small profile data; duplicated spell data is accepted.
- Slash: `/pa`, `/patiauras`.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.

## PaTiAlerts (optional)
Reports its current alerts with `PaTiAlertsAPI.Sync("PaTiAuras", list)` after every normal refresh — only if the API
exists with version 1, always inside `pcall` (PaTiAdmin/AGENTS.md §3). The list is built by a pure, tested function.
Without PaTiAlerts nothing may change. Never make PaTiAlerts a dependency.
