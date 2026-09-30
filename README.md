# PaTiAuras

<img src="assets/icon-128.png" width="96" alt="PaTiAuras icon">

A small aura and buff watcher for World of Warcraft: Forever (Interface 16001): your buffs, procs, group buffs and
healing auras — active, missing or expiring. It shows; you decide.

> Status: 0.1.0, in development, not yet released. Not yet fully tested in game (see Known limitations).

## Features
- **Self:** your buffs (e.g. Water Shield, Inner Fire) with time and charges; procs (e.g. Tidal Waves) while active
- **Group:** group buff summary like `Fortitude 4 / 5`; the tooltip lists who is missing it; also shown when solo
- **Weapon (Shaman):** Main Hand and Off Hand each show whether a weapon imbue is on (with its remaining time),
  missing, expiring or unclear. Slots without a weapon (e.g. a shield) are not shown. Which imbue it is (Flametongue,
  Windfury …) is not shown yet
- **Healing:** your HoTs and shields per party member (Shaman: Earth Shield, Riptide;
  Priest: Renew, Power Word: Shield, Prayer of Mending)
- **Click-to-buff:** click a group buff line to cast the buff on the next member who is missing it (named in the
  tooltip). One click, one cast; your target does not change. In combat the member stays fixed until combat ends
- With **PaTiAlerts** installed (optional), missing or expiring buffs and weapon imbues also appear there, and
  watched group buffs someone lacks (one line per buff: "Missing on 2")
- Every aura can be switched on or off; a small window asks on first start which ones to watch
- Profiles: Shaman, Priest. Unknown spells are hidden, never guessed
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Languages: English, Deutsch (others fall back to English)
- Works on its own. With PaTiHeal installed as well, you can switch off the healing auras here to avoid seeing them twice

## Installation
1. Download the release zip (`PaTiAuras-<version>.zip`).
2. Unpack it and copy the folder `PaTiAuras` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Start WoW and enable PaTiAuras in the AddOns list.

## First steps
- On first login choose the auras you want to watch (later: `/pa settings` → Auras)
- `/pa test` shows example data
- `/pa` shows or hides the window

## Settings
`/pa settings` or ••• → Settings:
- **General:** on/off, language, scale, window lock
- **Display:** timers, charges, missing, expiring
- **Watch:** one button opens the list of everything your character can watch (self, procs, healing, weapon, group)
  — tick what you want to see
- **Window:** panel opacity (30–100 %)

## Commands
`/pa` or `/patiauras` — alone: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` · `reset` (position) ·
`auras` (which profile spells your client knows) · `debug` · `version` · `about` · `changelog`

Hide, collapse, test mode and reset are blocked in combat (the window has secure buff buttons).

## Known limitations
- Priest group and self buff IDs are confirmed in the Forever client; Shaman IDs and the Priest healing auras are not
  yet — `/pa auras` shows what your client knows.
- Only your class profile (Shaman, Priest); other classes see no profile yet.
- Weapon imbues: V1 only tells whether an imbue is on each weapon, not which one. **Known bug:** an active imbue
  (e.g. Rockbiter) still shows "Missing" in the Forever client; the weapon itself is detected. `/pa auras` prints
  everything the client returns — please report it once without and once with the imbue.
- In-game test status: [`INGAME_TESTING.md`](INGAME_TESTING.md).
- Party only (no raid).

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
