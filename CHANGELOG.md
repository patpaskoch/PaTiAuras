# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.

## [Unreleased] — 0.1.0
### Added
- Window with Self, Group and Healing sections; Restoration Shaman profile (Water Shield, Tidal Waves, Earth Shield, Riptide).
- Active / Missing / Expiring / Unknown states, remaining time, charges; offline/dead members before missing buffs.
- Settings, test mode (fake party incl. an offline member and a group buff), `/pa debug`, `/pa auras` (incl. aura API
  and last read error), changelog notice.
- English texts, German translation; spell names from the client.
- Priest profile: Inner Fire; Fortitude, Divine Spirit and Shadow Protection as group buffs — the Prayer version
  counts as the same buff (profile entries may list `variants`). `/pa auras` also lists the variants.
- Click-to-buff: each group buff line is a secure button. A click casts the single-target buff (e.g. Power Word:
  Fortitude, highest known rank) on the next member who is missing it — alive, online and in sight — without changing
  your target. One click = one cast; when everyone has the buff, the line does nothing. Out of combat the target
  follows every aura/group change; in combat it stays as it was when combat started (WoW does not allow changing
  secure attributes in combat) and the tooltip shows whom the click buffs.
- "New auras" dialog: on the first start and whenever a watchable aura becomes available that was never offered
  (newly learned spell, profile update), a small window lists just those, pre-checked; closing it marks them as seen.
  Later changes in /pa settings. Waits until combat ends. Saved in PaTiAurasDB.seen.
- Group buffs are also shown solo (you are the only member, e.g. "0 / 1").
- Group buff tooltip: "Buffed: x / y", who is missing it, who is offline/dead, and whom a click buffs.
- `/pa test` shows your class profile with test data (generic test profile only for classes without one).
### Changed
- The group section is shown first (its rows must not move in combat). Hide, test mode, scale and position
  reset are blocked in combat, because the window now holds secure buttons.
### Fixed
- Hint texts such as "no aura profile for your class" wrap onto up to three lines instead of being cut off.
- If reading auras fails (e.g. restricted values), the state is Unknown instead of wrongly Missing.
### Known Issues
- Spell IDs and aura APIs are not yet confirmed in the Interface 16001 client (`/pa auras`, `/pa debug`).
- Click-to-buff not tested in game yet. In combat the click target cannot move on to the next member (WoW limit).
- `## IconTexture` support of this client is unknown. Shaman spell IDs still unconfirmed.
