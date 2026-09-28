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
- `/pa test` shows your class profile with test data (generic test profile only for classes without one).
### Fixed
- Hint texts such as "no aura profile for your class" wrap onto up to three lines instead of being cut off.
- If reading auras fails (e.g. restricted values), the state is Unknown instead of wrongly Missing.
### Known Issues
- Spell IDs and aura APIs are not yet confirmed in the Interface 16001 client (`/pa auras`, `/pa debug`).
- No click-to-buff yet. `## IconTexture` support of this client is unknown. Shaman spell IDs still unconfirmed.
