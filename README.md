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

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – healer party frames and click casting
- **PaTiAuras** – buff, aura and proc watcher *(this addon)*
- [PaTiTank](https://github.com/patpaskoch/PaTiTank) – tank HUD and aggro monitor
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – shows your HoTs and shields on its party frames too — untick them under Watch here to avoid seeing them twice
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – receives your watched buffs, weapon imbues and group buffs that are missing or expiring
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – shows and hides this window together with the other PaTi windows

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
- Totem and other ground auras (e.g. Shaman totem buffs) are not watched on purpose: they only last while a player
  stands in range, so PaTiAuras would report buffs as "missing" that are just out of reach. Group buffs cast directly
  on players (e.g. Power Word: Fortitude) are watched as before.

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
