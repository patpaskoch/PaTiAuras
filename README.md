# PaTiAuras

<img src="assets/icon-128.png" width="96" alt="PaTiAuras icon">

A small aura and buff watcher for World of Warcraft: Forever (Interface 16001): your buffs, procs, tracking, group buffs and
weapon imbues — active, missing or expiring. It shows; you decide. (HoTs and shields on party members: PaTiHeal.)

> Status: 0.1.0, in development, not yet released. Not yet fully tested in game (see Known limitations).

## Features
- **Self:** your buffs (e.g. Water Shield, Lightning Shield, Inner Fire) with time and charges; procs (e.g. Tidal Waves) while active.
  Right-click an active buff or proc line to remove it from yourself (one click, never by itself; weapon imbues
  cannot be removed this way in the Forever client)
- **Group:** group buff summary like `Fortitude 4 / 5`; the tooltip lists who is missing it; also shown when solo
- **Weapon (Shaman):** choose the weapon imbue you want under Watch — currently Rockbiter Weapon. The line shows
  that spell (e.g. `Rockbiter Weapon  Missing`, or its remaining time). Another imbue never counts as Rockbiter;
  unreadable data shows "unclear". One wanted imbue per weapon. A missing one can be cast with one click on its
  line (on your own weapon, never by itself). Click the chosen imbue again in Watch to watch none for that weapon
- **Tracking:** pick the profession tracking you want (Find Herbs, Find Minerals; Find Treasure for dwarves — only
  what you learned). The line shows whether it is on; a click on a missing one casts it (never switched by itself).
  Only one tracking can be on, so you choose one or none
- **Click-to-buff:** click a group buff line to cast the buff on the next member who is missing it (named in the
  tooltip). One click, one cast; your target does not change. In combat the member stays fixed until combat ends
- With **PaTiAlerts** installed (optional), missing or expiring buffs and weapon imbues also appear there, and
  watched group buffs someone lacks (one line per buff: "Missing on 2")
- Every aura can be switched on or off; a small window asks on first start which ones to watch
- Profiles: Shaman, Priest. Unknown spells are hidden, never guessed
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Languages: English, Deutsch (others fall back to English)
- Works on its own. Your HoTs and shields on party members (Earth Shield, Riptide, Renew, Power Word: Shield,
  Prayer of Mending) are shown by PaTiHeal on its frames — PaTiAuras no longer has a healing category (2026-10-02)

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
- On first login choose the auras you want to watch (later: `/pa settings` → Auras)
- `/pa test` shows example data
- `/pa` shows or hides the window

## Settings
`/pa settings` or ••• → Settings:
- **General:** on/off, language, scale, window lock
- **Display:** category layout (vertical = stacked, the default; horizontal = one column per category, the
  entries inside a column stay one below the other), timers, charges, missing, expiring
- **Watch:** one button opens the list of everything your character can watch (self, procs, weapon, tracking, group)
  — tick what you want to see
- **Window:** panel opacity (30–100 %)

## Commands
`/pa` or `/patiauras` — alone: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` · `reset` (position) ·
`auras` (which profile spells your client knows) · `debug` · `version` · `about` · `changelog`

Hide, collapse, test mode and reset are blocked in combat (the window has secure buff buttons).

## Known limitations
- Priest group and self buff IDs are confirmed in the Forever client; Shaman IDs are not yet — `/pa auras` shows what your client knows.
- Only your class profile (Shaman, Priest); other classes see no profile yet.
- Weapon imbues: only Rockbiter Weapon so far — its enchant ID (29) was observed by the owner in the Forever client;
  its spell ID (8017, classic data) is used only if your client knows it, and is still to be confirmed with
  `/pa auras`. Another rank may have another enchant ID and then shows "unclear" until it is added. Flametongue,
  Frostbrand and Windfury follow once their IDs are observed. A missing own shield (Water Shield,
  Lightning Shield) is cast on you with a left click; an active one is removed with a right click.
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
