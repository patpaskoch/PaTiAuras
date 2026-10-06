# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.

## [Unreleased] — 0.1.0
### Added
- Shaman: a missing Water Shield or Lightning Shield line is cast on you with a left click (owner 2026-10-06; same
  secure line button as weapon imbues, one click = one cast, attributes only out of combat).
- Shaman: Lightning Shield in the Self section (owner 2026-10-06: a low-level shaman saw no shield). Rank 1 = ID 324
  from classic data, other ranks by name; not yet confirmed in the Forever client.
- Themes (owner wish 2026-10-03): Settings → Window → Theme — Default (the PaTi look as before), WoForever (warm brown, gold/bronze) or Dracula (dark, purple/pink/cyan accents). Colours only; layout, secure buttons and behaviour are unchanged. Saved per character in this addon (`theme`, unknown values → Default); Restore Defaults returns to Default. PaTiSuite can switch all PaTi windows at once.
- Settings → Display → **Category layout**: Vertical (stacked, default — unchanged for existing installs) or
  Horizontal (GROUP, WEAPON, SELF, TRACKING as columns side by side; the entries inside a column stay vertical).
  Columns share one width, wide enough for long names (up to 320 px, then "…"), and wrap into a second row when the
  screen is too narrow. Saved as `PaTiAurasDB.categoryLayout` (new key with default, no schema step).
  The secure buttons follow their lines in both layouts. In combat the layout of combat start stays (the buttons
  cannot move): a change is saved at once and applied after combat (chat note).
- Profession tracking (owner wish 2026-10-02): Watch offers the tracking spells you learned (Find Herbs, Find
  Minerals, Find Treasure — classic IDs, hidden if the client does not know them), 0 or 1 wanted (slot TRACKING, like
  weapon imbues). New TRACKING section: Active / Missing ("another tracking is on") / Unknown; a left-click on a
  missing one casts it. Own adapter `Tracking.lua`: C_Minimap.GetTrackingInfo, GetTrackingInfo or GetTrackingTexture,
  or shown as a buff; MINIMAP_UPDATE_TRACKING plus the 1 s fallback check. PaTiAlerts reports a missing one.
  `/pa auras` prints the tracking API and every listed type. Classes without a profile do not get it yet.
- Right-click on an active line in the window removes that buff from you (owner wish 2026-10-02): own buffs and
  procs by name (secure `cancelaura`, unit player). Weapon imbues are left out: the Forever client's secure
  target-slot cancel fails in Blizzard's SecureTemplates.lua:478 (`CANCELABLE_ITEMS` is nil, owner's error).
  Left-click on a missing
  weapon imbue still casts it. One button pool `PaTiAurasLine1..8` over the WEAPON and SELF lines, armed only out of
  combat; in combat the lines keep the order of combat start (a buff that ended shows "–", new ones come below), so
  a button never sits over another line.
- Concrete weapon imbue watches (owner wish 2026-10-02): under Watch you pick the imbue you want — currently
  Rockbiter Weapon (spell 8017, offered only if your client knows it and you learned it). It counts as active only
  with its own temporary enchant ID: 29, observed by the owner in the Forever client. Another known imbue reads
  Missing ("another imbue"), an unmapped or unreadable ID reads Unknown. One wanted imbue per weapon slot:
  switching one on switches the others of that slot off.
- Click-to-buff for a missing watched weapon imbue: a secure button over its line casts the spell on yourself
  (one click = one cast, unit player). Armed only out of combat and only while Missing; in combat it keeps what it
  had when combat started. Watch list, "enabled" and "show missing" are blocked in combat (lines must not move
  under an armed button).
- `/pa debug`, `/pa auras`: per watched imbue the wanted spell, its spell ID and expected enchant IDs against the
  detected enchant ID, time and icon; `/pa auras` also lists learned spells with the active enchant's icon.
- Window settings (PaTiShared): panel opacity 30–100 % (default 75 %, the header stays opaque). The window registers
  itself for the optional PaTiSuite control panel, which shows/hides it with this addon's own rules. (Snapping to
  other PaTi windows was tried and removed again: it did not work in the client.)
- Optional PaTiAlerts report: your watched personal buffs and weapon imbues that are missing or expiring (warning);
  active ones disappear, unclear data is never reported as missing, procs are not reported. Nothing changes without
  PaTiAlerts.
- New icon from the PaTiSuite icon set (`Media/icon.tga`, AddOns list); platform images in `assets/`.
- MIT license (`LICENSE`, not part of the release zip).
- Shaman weapon imbues: new WEAPON section with Main Hand and Off Hand (own data source `WeaponImbues.lua`, not
  UNIT_AURA): Active with remaining time, Missing, Expiring, Unclear. MISSING only when the enchant API answered
  readably; API missing, error, empty answer or a secret flag → Unclear. Slots without a weapon (shield) are hidden.
  Updates on UNIT_INVENTORY_CHANGED / PLAYER_EQUIPMENT_CHANGED plus a 2 s check that repaints only on changes.
  Setting "Weapon imbues" (on) and one switch per slot; test mode shows an imbued main hand and a missing off hand.
  `/pa debug` names the enchant APIs, `/pa auras` the readable raw values per slot. V1 does not tell which imbue.
- Window with Self, Group and Healing sections; Restoration Shaman profile (Water Shield, Tidal Waves, Earth Shield, Riptide).
- Active / Missing / Expiring / Unknown states, remaining time, charges; offline/dead members before missing buffs.
- Settings, test mode (fake party incl. an offline member and a group buff), `/pa debug`, `/pa auras` (incl. aura API
  and last read error), changelog notice.
- English texts, German translation; spell names from the client.
- Priest profile: Inner Fire; Fortitude, Divine Spirit and Shadow Protection as group buffs — the Prayer version
  counts as the same buff (profile entries may list `variants`). `/pa auras` also lists the variants.
- Priest healing auras: your Renew, Power Word: Shield and Prayer of Mending per party member (IDs not yet
  confirmed in this client; unknown IDs stay hidden). Each can be switched off like every other aura.
- Click-to-buff: each group buff line is a secure button. A click casts the single-target buff (e.g. Power Word:
  Fortitude, highest known rank) on the next member who is missing it — alive, online and in sight — without changing
  your target. One click = one cast; when everyone has the buff, the line does nothing. Out of combat the target
  follows every aura/group change; in combat it stays as it was when combat started (WoW does not allow changing
  secure attributes in combat) and the tooltip shows whom the click buffs.
- "New auras" dialog: on the first start and whenever a watchable aura becomes available that was never offered
  (newly learned spell, profile update), a small window lists just those, pre-checked; closing it marks them as seen.
  Later changes in /pa settings. Waits until combat ends. Saved in PaTiAurasDB.seen.
- Collapse/Expand in the ••• menu: only the header stays; saved in PaTiAurasDB.collapsed (old saves: expanded).
  Disabled in combat (the window holds secure buff buttons). Restore Defaults expands the window.
- Group buffs are also shown solo (you are the only member, e.g. "0 / 1").
- Group buff tooltip: "Buffed: x / y", who is missing it, who is offline/dead, and whom a click buffs.
- `/pa test` shows your class profile with test data (generic test profile only for classes without one).
- Optional PaTiAlerts report for group buffs: a watched group buff that a living, online member surely lacks is one
  warning per buff (kind GROUP_AURA_MISSING): "Missing" solo, "Missing on N" in a group — no names (those stay in the
  tooltip). Active buffs, unwatched or unknown spells, offline/dead members and unreadable (Unknown) data never alert;
  the warning disappears once everyone has the buff. Follows "show missing" like the personal buffs.
### Changed
- "Missing" (weapon imbue, own buffs, tracking lines) is now shown in red instead of grey (owner wish 2026-10-04).
- Tracking (Find Herbs, Find Minerals …) is listed under Self instead of its own "Tracking" header — a shorter
  window (owner wish 2026-10-06). Settings → Watch still lists it separately.
- A missing line (weapon imbue, own buff, tracking) is tinted red with a red bar on the left, so it stands out at a
  glance (owner wish 2026-10-06). Display only; the click buttons over the lines are unchanged.
- Diagnostics (hardening 2026-10-02): errors that are caught so the addon keeps running are no longer silent — the debug command shows the last caught error per source (no chat spam, nothing saved).
- Weapon imbue watch: 0 or 1 wanted imbue per slot (owner 2026-10-02). Clicking the chosen imbue again deselects
  it: no line, no click button, no PaTiAlerts warning (and no generic one) for that slot. Deselecting also turns
  the slot's still undecided imbues off, so none moves up by itself; an explicit choice wins over the default.
  `watch = false` stays over `/reload`, login and rebuilds; only Restore Defaults watches everything again.
- Tooltips sit beside the hovered line (PaTiShared).
- The weapon line is named by the watched spell ("Rockbiter Weapon  Missing" / its remaining time) instead of
  "Main Hand"; the WEAPON section now comes right after GROUP. PaTiAlerts gets the concrete spell
  ("Rockbiter Weapon · Missing") instead of "weapon imbue missing".
- SavedVariables schema 3: the slot watches MAIN_HAND_IMBUE / OFF_HAND_IMBUE are gone. A switched-off main hand
  keeps Rockbiter off (and offered, no dialog); a watched main hand picks nothing by itself — the "new auras"
  dialog asks. There is no generic off-hand watch any more (no off-hand imbue observed yet).
- Weapon imbue diagnostics (owner test 2026-09-30: with Rockbiter active Main Hand still reads "Missing"): `/pa debug`
  prints every `GetWeaponEnchantInfo()` field by name with its type, and per hand the API source, item, weapon,
  parsed values and final state; `/pa auras` also prints every `C_Item.GetWeaponEnchantInfo` answer (no slot,
  `Enum.WeaponSlot`, slot ID 16/17), your buffs and the main-hand tooltip lines. Secret values are printed as
  "secret", never formatted.
- Settings: one "Watch" list instead of category switches plus a second aura list — a button opens a multi-select
  list of your character's entries (self, procs, healing, weapon, group). SavedVariables schema 2: a switched-off
  category of schema 1 becomes watch = false for each of its entries (once); the category switches are gone.
- AddOns list description in English with a German translation (`## Notes-deDE`); README rewritten for players
  (features, installation, first steps, commands, known limitations).
- The group section is shown first (its rows must not move in combat). Hide, test mode, scale and position
  reset are blocked in combat, because the window now holds secure buttons.
### Fixed
- Hardening: a broken SavedVariables save (not a table, a broken schema or scale) no longer breaks the login; only the broken value is replaced, every valid setting (also `false`) stays, and the migration is idempotent (tests/robustness_spec.lua).
- Watch: re-clicking the chosen Rockbiter did not deselect it in the owner's test (2026-10-02). The toggle logic was
  correct (reproduced in CI with the real popup code: false is saved, the list repaints); fixed what could differ in
  the client — the list now shows check boxes instead of a 4 px dot, and an error during the rebuild no longer stops
  the repaint (PaTiShared). `/pa debug` shows the saved weapon watch values (`ROCKBITER_WEAPON=false`).
- Weapon imbues: an active imbue (Rockbiter) read "Missing" (owner test 2026-09-30, `/pa auras` 2026-10-02).
  In the Forever client `GetWeaponEnchantInfo()` says `hasMainHand=false` while
  `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` reports the imbue with `hasEnchant=true`, a positive
  `timeLeft` and `enchantType=3`, a value missing from the client's `Enum.ItemEnchantType` — so the old code
  trusted the wrong tuple and also dropped the entry by its type. Now per hand the modern API comes first;
  `hasEnchant` + positive `timeLeft` counts as an imbue whatever the type; a permanent enchant (no time left) never
  does; the tuple only fills a hand the modern API cannot read, and then only to confirm an imbue (its "no imbue"
  stays Unknown). No enchant IDs are hard-coded.
- Weapon imbues showed "Unknown" with and without Rockbiter (owner test 2026-09-30): the adapter called
  `C_Item.GetWeaponEnchantInfo()` without a slot and read it like the classic tuple. Now one priority chain with
  separate parsers: `GetWeaponEnchantInfo()` (classic tuple, both hands) first, `C_Item.GetWeaponEnchantInfo(slot)`
  only as fallback and only with `Enum.WeaponSlot` (no guessed slot numbers; a permanent enchant never counts as an
  imbue). Any item in the main hand counts as a weapon. Also reacts to WEAPON_ENCHANT_CHANGED / WEAPON_SLOT_CHANGED if
  the client has them; the fallback check runs every 1 s. `/pa debug` and `/pa auras` print both APIs' raw answers.
- Secret values: a secret member name is replaced by "You" / "Party member N" (names are joined into tooltips);
  secret offline/dead flags no longer count as offline or dead.
- Hint texts such as "no aura profile for your class" wrap onto up to three lines instead of being cut off.
- If reading auras fails (e.g. restricted values), the state is Unknown instead of wrongly Missing.
### Removed
- **Healing category** (owner decision 2026-10-02): your HoTs and shields on party members (Shaman: Earth Shield,
  Riptide; Priest: Renew, Power Word: Shield, Prayer of Mending) are now shown only by PaTiHeal, which has all of
  them in its own profiles. PaTiAuras keeps Self, Procs, Tracking, Group buffs and Weapon imbues. Old saved watch
  choices of the removed entries stay in `PaTiAurasDB` and are simply ignored (no error, no empty section; no
  schema change). Weapon imbues, Rockbiter and click-to-buff are unchanged.
### Known Issues
- Shaman with both Water Shield and Lightning Shield learned: both are watched and one always reads Missing — unwatch
  the one you do not use (Settings → Watch).
- Tracking (2026-10-02) is not tested in game: which tracking API the Forever client offers and the spell IDs are
  unconfirmed (`/pa auras`).
- Right-click remove (2026-10-02) is not tested in game; whether the Forever client's secure `cancelaura` action works
  for buffs and weapon imbues is not confirmed.
- Concrete weapon imbues and click-to-buff (2026-10-02) are not tested in game yet (PT-AURAS-140–157); the
  Rockbiter spell ID 8017 is still to be confirmed with `/pa auras`.
- The weapon imbue fix of 2026-10-02 is not tested in game yet (PT-AURAS-052–057 in `INGAME_TESTING.md`).
- Spell IDs and aura APIs are not yet confirmed in the Interface 16001 client (`/pa auras`, `/pa debug`).
- Click-to-buff not tested in game yet. In combat the click target cannot move on to the next member (WoW limit).
- `## IconTexture` support of this client is unknown. Shaman spell IDs still unconfirmed.
