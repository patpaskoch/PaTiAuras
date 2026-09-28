# AGENTS.md — PaTiAuras

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full.
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: show which auras/buffs/HoTs are active, missing or expiring. Never recommend or cast by itself. Not a WeakAuras clone:
  no trigger editor, no scripting, no import strings, no boss auras, no raid matrix.
- Files: `Config.lua` (SavedVariables defaults/migration, pure) · `SpellBook.lua` (spell adapter, deliberate copy of
  PaTiHeal's) · `Auras.lua` (state logic, pure) · `AuraScan.lua` (aura adapter + test data) · `Profiles/<Class>.lua` (data) ·
  `Watch.lua` (state per unit) · `AuraWindow.lua` (UI) · `PaTiAuras.lua` (init, settings, slash, events).
- SavedVariables: `PaTiAurasDB` (per character), schema 1 — see `Config.DEFAULTS`; `watch[key] = false` hides one aura.
- Profiles: only classes whose spell IDs are confirmed in this client. A new profile = one data file + TOC line, no code.
  Several spells giving the same buff (e.g. Prayer versions) = one entry with `variants = { id, … }`, never two entries.
- Secure: none in 0.1. Click-to-buff (planned) must use SecureActionButtonTemplate with unit+spell fixed out of combat,
  always-visible buttons (state shown visually), no auto target, no sequences.
- Independence: no dependency on PaTiHeal/PaTiTank. A later integration = a small versioned global API, checked with `if PaTiAurasAPI then`.
- Slash: `/pa`, `/patiauras`.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.
