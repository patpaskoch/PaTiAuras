# PaTiAuras

<img src="assets/icon-128.png" width="96" alt="PaTiAuras icon">

A small aura and buff watcher for World of Warcraft: Forever (Interface 16001): your buffs, procs, tracking, group buffs and
weapon imbues — active, missing or expiring. It shows; you decide. (HoTs and shields on party members: PaTiHeal.)

> Status: 0.1.0, in development, not yet released. Not yet fully tested in game (see Known limitations).

## Features
- **My auras — one list for everything on you** (Settings → Watch → "My auras (n) …"): buffs, procs, weapon
  imbues and tracking, up to 12, in your order. Type a spell name or ID or drag spells from your spellbook; sort with
  the arrows or the ≡ grip. Procs of your class (e.g. Tidal Waves) show only while active. Until you edit the list it
  holds what your class profile offered (e.g. Lightning Shield, Rockbiter Weapon, Tidal Waves, Find Herbs)
- **Weapon imbues learn themselves:** WoW names an imbue only by a number that differs per imbue and rank. Put the
  imbue (e.g. Flametongue Weapon) on the list and cast it once: PaTiAuras remembers the number your cast put on
  the weapon and recognises it from then on (also a new rank after one cast). Until then it reads Missing
- Missing = red line; a **left click** casts it on you (or your weapon), one click = one cast. A right click on an
  active buff or proc removes it. In combat a line keeps what it did when combat started
- **Group:** group buff summary like `Fortitude 4 / 5` above your list; the tooltip lists who is missing it; also
  shown when solo. Click it to cast the buff on the next member who is missing it (named in the tooltip); your
  target does not change. Choose them under Watch → "Group buffs"
- **Grid:** 1, 2 or 3 columns, no headers. **Show:** all, only missing (and expiring; active procs too), or only active
- With **PaTiAlerts** installed (optional), missing or expiring auras also appear there, and watched group buffs
  someone lacks (one line per buff: "Missing on 2")
- Profiles (seed and group buffs): Shaman, Priest. Unknown spells are hidden, never guessed
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Languages: English, Deutsch (others fall back to English)

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – healing: party frames, heal target, click casting, HoTs, dispels
- **PaTiAuras** – buffs, procs, tracking, group buffs and weapon imbues *(this addon)*
- [PaTiTank](https://github.com/patpaskoch/PaTiTank) – tank HUD and aggro monitor
- [PaTiRota](https://github.com/patpaskoch/PaTiRota) – your own skill priority with cooldowns and fixed cast buttons
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – party awareness: tank, healer, roles and the tank's target
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – lead the group: raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiSocial](https://github.com/patpaskoch/PaTiSocial) – "Party Social": quick emote and message buttons
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – shows your HoTs and shields on its party frames (that is its job, not PaTiAuras')
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – receives your watched buffs, weapon imbues and group buffs that are missing or expiring
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – shows and hides this window together with the other PaTi windows

## Installation
1. Download the release zip (`PaTiAuras-<version>.zip`).
2. Unpack it and copy the folder `PaTiAuras` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Start WoW and enable PaTiAuras in the AddOns list.

## First steps
- `/pa settings` → Watch → "My auras (n) …": check the list, add what you keep up (buffs, procs, imbues, tracking)
- `/pa test` shows example data
- `/pa` shows or hides the window

## Settings
`/pa settings` or ••• → Settings:
- **General:** on/off, language, scale, window lock
- **Display:** Show (all / only missing / only active), Columns (1–3), timers, charges, expiring
- **Watch:** "My auras (n) …" opens your list; "Group buffs (n / m)" picks the group buffs
- **Window:** panel opacity (30–100 %)

## Commands
`/pa` or `/patiauras` — alone: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` · `reset` (position) ·
`auras` (which profile spells your client knows) · `debug` · `version` · `about` · `changelog`

Hide, collapse, test mode and reset are blocked in combat (the window has secure buff buttons).

## Known limitations
- Priest group and self buff IDs are confirmed in the Forever client; Shaman IDs are not yet — `/pa auras` shows what your client knows.
- Class profiles (seed and group buffs) only for Shaman and Priest; other classes start with an empty list.
- Weapon imbues are recognised by the number your own cast put on the weapon (learned once per imbue and rank).
  An imbue that was already on before you listed it reads Missing until you cast it once. Only readable numbers
  are learned (in combat WoW may keep them secret). Rockbiter Weapon (29) is known from the start. A dual-wield
  imbue on both hands is learned for the hand of the last cast.
- In combat a click on a weapon line does what it did when combat started (WoW does not let the button change).
- In-game test status: [`INGAME_TESTING.md`](INGAME_TESTING.md).
- Party only (no raid).
- Totem and other ground auras (e.g. Shaman totem buffs) are not watched on purpose: they only last while a player
  stands in range, so PaTiAuras would report buffs as "missing" that are just out of reach. Group buffs cast directly
  on players (e.g. Power Word: Fortitude) are watched as before.

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
