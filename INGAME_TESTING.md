# Ingame Testing – PaTiAuras

World of Warcraft: Forever
Interface: 16001

Diese Datei dokumentiert ausschließlich Tests im echten WoW-Client.

Automatisierte Tests, CI und Code Review zählen NICHT als Ingame-Verifikation.
Regeln und Eintragen von Ergebnissen: [PaTiAdmin/docs/TESTING.md](https://github.com/patpaskoch/PaTiAdmin/blob/main/docs/TESTING.md#in-game-test-files).

Zustände im Fenster: ACTIVE (aktiv, mit Restzeit), MISSING (fehlt), EXPIRING (läuft aus), UNKNOWN (unklar).
UNKNOWN darf nie als MISSING erscheinen.

## Legende

- [ ] offen / noch nicht bestätigt
- [x] vom Owner im echten Client bestätigt
- ❌ FAIL = im echten Client fehlgeschlagen
- 🔧 FIX IMPLEMENTED = Codefix vorhanden, Retest noch offen
- ✅ VERIFIED = erfolgreich im echten Client bestätigt
- MANUAL RETEST REQUIRED = erneuter Test notwendig

## Installation / Laden

- [ ] PT-AURAS-001 Fresh Install aus dem Release-ZIP: genau ein Ordner `PaTiAuras/`, Addon lädt allein
- [ ] PT-AURAS-002 PaTiAuras erscheint in der AddOn-Liste mit Beschreibung
- [x] PT-AURAS-003 Icon in der AddOn-Liste korrekt, keine weiße oder fehlende Textur
  - ✅ VERIFIED 2026-10-02
  - Owner: die Icons erscheinen im Spiel in der AddOn-Liste korrekt.
- [ ] PT-AURAS-004 Login ohne Lua-Fehler
- [ ] PT-AURAS-005 `/reload` ohne Lua-Fehler
- [x] PT-AURAS-006 `/pa debug` zeigt die Aura-API: `C_UnitAuras` und `issecretvalue` vorhanden
  - ✅ VERIFIED 2026-09-28
- [ ] PT-AURAS-007 `/pa debug` zeigt je Hand API-Quelle, Waffe/Item, jedes Rohfeld von `GetWeaponEnchantInfo()` mit
  Typ, geparstes hasImbue und Endzustand; `/pa auras` zusätzlich alle Antworten von `C_Item.GetWeaponEnchantInfo`,
  eigene Buffs und die Tooltip-Zeilen der Waffenhand — ohne Lua-Fehler

## Fenster

- [ ] PT-AURAS-010 `/pa` bzw. `/patiauras` blendet das Fenster ein und aus; `/pa show`, `/pa hide`
- [ ] PT-AURAS-011 Fenster am Header verschieben (entsperrt)
- [ ] PT-AURAS-012 Position bleibt nach `/reload`
- [ ] PT-AURAS-013 Lock/Unlock (••• und `/pa lock` / `unlock`): gesperrt nicht verschiebbar
- [ ] PT-AURAS-014 Größe (Scale) in den Einstellungen wirkt
- [ ] PT-AURAS-015 Einstellungen öffnen (`/pa settings` und •••) und speichern
- [ ] PT-AURAS-016 Collapse/Expand über •••, Zustand bleibt nach `/reload`
- [ ] PT-AURAS-017 Test Mode `/pa test` zeigt das eigene Klassenprofil mit Beispieldaten (inkl. Waffe: Waffenhand aktiv,
  Schildhand fehlt); erneut `/pa test` beendet ihn
- [ ] PT-AURAS-018 Panel-Deckkraft 30–100 %: nur der Hintergrund ändert sich
- [ ] PT-AURAS-019 Keine Einrast-Einstellung mehr, Fenster frei verschiebbar
- [ ] PT-AURAS-020 `/pa reset` setzt die Position zurück
- [ ] PT-AURAS-021 `/pa about` und `/pa changelog` zeigen Infos ohne Fehler

## SavedVariables

- [ ] PT-AURAS-030 Einstellungen und Beobachten-Auswahl bleiben nach `/reload`
- [ ] PT-AURAS-031 Einstellungen bleiben nach Relog
- [ ] PT-AURAS-032 Update mit alten Einstellungen: eine vorher abgeschaltete Kategorie (z. B. Procs) bleibt nach dem
  Update abgewählt (Schema-2-Migration), Position/Sprache/Größe bleiben
- [ ] PT-AURAS-033 „Standard wiederherstellen“: alles wieder beobachtet, Position bleibt

## Sprachen

- [ ] PT-AURAS-040 deDE: alle Texte deutsch, Zaubernamen aus dem Client
- [ ] PT-AURAS-041 Sprache enUS in den Einstellungen: nach `/reload` englisch
- [ ] PT-AURAS-042 zhCN/zhTW/koKR: Englisch als Rückfall, keine Schlüsselnamen oder Kästchen
- [ ] PT-AURAS-043 Keine abgeschnittenen wichtigen Texte (deDE), Hinweise brechen um

## Weapon Imbues (Schamane)

Seit 2026-10-02 wird ein konkreter Waffenbuff beobachtet (Felsbeißer, Abschnitt unten), keine „Waffenhand“ mehr.
Die Tests 050–059 beschreiben die frühere Slot-Version; ihre Ergebnisse gelten nicht automatisch für die neue.

- [x] PT-AURAS-050 Mainhand-Waffe wird beim Ausrüsten erkannt (Zeile Waffenhand erscheint)
  - ✅ VERIFIED 2026-09-30
  - Auch mit dem Fix-Build bestätigt: ausrüsten, ablegen, erneut ausrüsten wird jeweils erkannt.
- [x] PT-AURAS-051 Entfernte Mainhand-Waffe verschwindet
  - ✅ VERIFIED 2026-09-30
- [x] PT-AURAS-052 Mainhand ohne Imbue → MISSING (nicht UNKNOWN)
  - ❌ FAIL 2026-09-30
  - Ohne Felsbeißer „Unbekannt“ statt „Fehlt“.
  - 🔧 FIX IMPLEMENTED 2026-09-30
  - Klassisches `GetWeaponEnchantInfo()` zuerst, `C_Item.GetWeaponEnchantInfo(slot)` nur als Rückfall.
  - Retest 2026-09-30: ohne Imbue „Fehlt“, kein UNKNOWN mehr. Nicht aussagekräftig, solange auch ein aktiver Imbue
    „Fehlt“ zeigt (PT-AURAS-053).
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` ist jetzt die erste Quelle (siehe PT-AURAS-053).
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-02
  - Owner: Waffe angelegt, Felsbeißer nicht aktiv → „Waffe des Felsbeißers – Fehlt“.
- [x] PT-AURAS-053 Rockbiter aktivieren → ACTIVE mit Restzeit
  - ❌ FAIL 2026-09-30
  - Waffe selbst wird erkannt, Imbue bleibt UNKNOWN.
  - 🔧 FIX IMPLEMENTED 2026-09-30
  - ❌ FAIL 2026-09-30
  - Retest mit Fix: Waffe vorhanden, Waffe des Felsbeißers aktiv, Anzeige trotzdem „Fehlt“.
  - Diagnose erweitert (PT-AURAS-007), noch kein Fix. Nächster Test: `/pa auras` ohne und mit Felsbeißer, beide
    Ausgaben melden.
  - Owner-Diagnose 2026-10-02 (Felsbeißer aktiv): `GetWeaponEnchantInfo()` meldet `hasMainHand=false`;
    `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` hat einen Eintrag `hasEnchant=true`, `timeLeft=3524825`,
    `enchantType=3` (nicht in `Enum.ItemEnchantType`: None 0, Permanent 1, Temporary 2).
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - Moderne API zuerst pro Hand; `hasEnchant=true` + `timeLeft > 0` = aktiver Imbue, auch bei unbekanntem
    `enchantType`; das klassische Tupel überstimmt eine lesbare moderne Antwort nie.
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-02
  - Owner: Felsbeißer gewirkt → Zeile zeigt die Restzeit statt „Fehlt“.
- [x] PT-AURAS-054 Rockbiter entfernen bzw. auslaufen lassen → MISSING
  - ❌ FAIL 2026-09-30
  - Zeigt „Fehlt“, aber schon vorher mit aktivem Imbue: keine Zustandsänderung erkannt.
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-02
  - Owner: Felsbeißer entfernt → wieder „Fehlt“.
- [x] PT-AURAS-055 Rockbiter erneut aktivieren → ACTIVE
  - ❌ FAIL 2026-09-30
  - Bleibt „Fehlt“.
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-02
  - Owner: Felsbeißer entfernt und erneut gewirkt → wieder Restzeit.
- [ ] PT-AURAS-056 Timer wird aktualisiert; unter 30 s EXPIRING; Erneuern aktualisiert innerhalb von ~1–2 s
- [x] PT-AURAS-057 Mit PaTiAlerts: „Waffenbuff fehlt“ erscheint bei MISSING, verschwindet bei ACTIVE, nie bei UNKNOWN
  - ❌ FAIL 2026-09-30
  - Warnung bleibt bei aktivem Felsbeißer. Ursache upstream: PaTiAuras meldet den aktiven Imbue als MISSING
    (PT-AURAS-053); PaTiAlerts selbst arbeitet richtig.
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - Fix in PaTiAuras (PT-AURAS-053), keine Änderung in PaTiAlerts.
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-02
  - Owner: Felsbeißer fehlt → Warnung „Waffe des Felsbeißers · Fehlt“; gewirkt → Warnung weg.
- ~~PT-AURAS-058 Schildhand: Schild oder leer → keine Zeile; Nebenhand-Waffe → eigene Zeile mit eigenem Zustand~~
  - RETIRED 2026-10-02 – keine generische Schildhand-Beobachtung mehr; noch kein bestätigter Nebenhand-Waffenbuff.
- [ ] PT-AURAS-059 Waffe wechseln: kein alter Zustand, kein Lua-Fehler; Imbue läuft im Kampf aus bzw. wird erneuert

## Konkreter Waffenbuff: Waffe des Felsbeißers

Einstellungen
- [ ] PT-AURAS-140 Beobachten zeigt unter „Waffe“ „Waffe des Felsbeißers“ (Schamane, Zauber gelernt), kein
  „Waffenhand“/„Schildhand“ mehr
- [ ] PT-AURAS-141 `/pa auras`: Zeile `weapon ROCKBITER_WEAPON id=8017` mit dem richtigen Namen und known=true;
  mit aktivem Felsbeißer nennt „Learned spells with icon 136086“ den Felsbeißer (bestätigt die Spell-ID)
- [ ] PT-AURAS-142 Auswahl (an/aus) bleibt nach `/reload`
- [ ] PT-AURAS-143 Update von der Version davor: war die Waffenhand abgewählt, bleibt Felsbeißer aus; sonst fragt
  der Dialog „Neue Auren“ nach Felsbeißer

Anzeige
- [x] PT-AURAS-144 Felsbeißer fehlt: Zeile „Waffe des Felsbeißers – Fehlt“ direkt unter den Gruppenbuffs, keine
  „Waffenhand – Fehlt“-Zeile
  - ✅ VERIFIED 2026-10-04
  - Owner: die Zeile „Waffe des Felsbeißers – Fehlt“ erscheint so. Wunsch: „Fehlt“ rot → PT-AURAS-200
- [x] PT-AURAS-200 „Fehlt“ (Waffe, eigene Buffs, Tracking) steht rot statt grau, in allen drei Themes gut lesbar
  - 🔧 FIX IMPLEMENTED 2026-10-04 (Owner-Wunsch: Fehlt rot)
  - MANUAL RETEST REQUIRED
  - ✅ VERIFIED 2026-10-04
  - Owner: „Fehlt“ in Rot passt.
- [ ] PT-AURAS-201 Schamane: „Blitzschlagschild“ erscheint unter Selbst (Beobachten zeigt ihn); ohne Schild „Fehlt“,
  mit Schild Restzeit und Aufladungen; Klick auf die fehlende Zeile wirkt ihn auf dich; `/pa auras` nennt die ID
  - 🔧 FIX IMPLEMENTED 2026-10-06 (Owner: kein Blitzschlagschild in PaTiAuras)
  - MANUAL RETEST REQUIRED
  - ❌ FAIL 2026-10-06
  - Owner: Blitzschlagschild wird angezeigt, lässt sich aber nicht anklicken (eigene Buffs waren noch nicht klickbar).
  - 🔧 FIX IMPLEMENTED 2026-10-06 (fehlender Schild: Linksklick wirkt ihn auf dich; Profil castable)
  - MANUAL RETEST REQUIRED
- [ ] PT-AURAS-202 Fehlende Zeile (z. B. Blitzschlagschild, Felsbeißer) ist rot hinterlegt mit rotem Strich links; Name
  und „Fehlt“ gut lesbar (alle drei Themes); aktive Zeilen ohne Rot; Klick und Hover funktionieren wie vorher
  - 🔧 FIX IMPLEMENTED 2026-10-06 (Owner-Wunsch: Fehlendes besser sehen, ganze Zeile rot)
  - MANUAL RETEST REQUIRED
- [ ] PT-AURAS-203 Aufspüren (Kräutersuche, Mineraliensuche) steht unter „Selbst“, keine eigene Überschrift „Aufspüren“;
  Klick auf fehlendes Aufspüren wirkt es wie vorher; beide Layouts (vertikal/horizontal) ohne Überlappung
  - 🔧 FIX IMPLEMENTED 2026-10-06 (Owner-Wunsch: kürzere Liste)
  - MANUAL RETEST REQUIRED
- [x] PT-AURAS-145 Felsbeißer aktiv: „Waffe des Felsbeißers“ mit Restzeit, Tooltip „Waffenhand · Waffenbuff“
  - Owner 2026-10-04: Restzeit steht, Icon farbig. Noch offen: Tooltip „Waffenhand · Waffenbuff“.
  - ✅ VERIFIED 2026-10-04
  - Owner: Tooltip „Waffenhand · Waffenbuff“ steht dort.
- [ ] PT-AURAS-146 Ein anderer Waffenbuff (z. B. Flammenzunge) zählt nicht als Felsbeißer: Anzeige „Unbekannt“
  (nicht „Aktiv“); `/pa auras` zeigt dessen enchantID
- [ ] PT-AURAS-147 Höherer Rang von Felsbeißer: bleibt „Aktiv“ oder zeigt „Unbekannt“ — dann enchantID aus
  `/pa auras` melden (bisher nur ID 29 beobachtet)

Klick zum Wirken
- [x] PT-AURAS-150 Felsbeißer fehlt: Hover hellt die Zeile auf, Tooltip „Klicken, um Waffe des Felsbeißers zu wirken.“
  - ✅ VERIFIED 2026-10-04
  - Owner: Hover und Tooltip passen so.
- [x] PT-AURAS-151 Klick auf die fehlende Zeile wirkt Felsbeißer auf die eigene Waffe (ein Klick = ein Cast),
  danach „Aktiv“ mit Restzeit; das Ziel ändert sich nicht
  - ✅ VERIFIED 2026-10-04
  - Owner: Klick wirkt Felsbeißer; danach steht die Restzeit (statt des Worts „Aktiv“), das Icon ist farbig.
- [ ] PT-AURAS-152 Aktiv oder Unbekannt: kein Klick-Hinweis, ein Klick wirkt nichts
- [ ] PT-AURAS-153 Kein Lua-Fehler, kein `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`, `taint.log` ohne
  PaTiAuras-Eintrag
  - Owner 2026-10-04: keine Fehlermeldung, kein `ADDON_ACTION_BLOCKED`. Noch offen: `taint.log` geprüft.
- [ ] PT-AURAS-154 Im Kampf: der Klick bleibt wie bei Kampfbeginn (Tooltip sagt es); Beobachten, „Aktiviert“ und
  „Fehlende anzeigen“ sind im Kampf gesperrt mit Hinweis
- [ ] PT-AURAS-155 Nach `/reload` funktioniert der Klick weiter

PaTiAlerts
- [ ] PT-AURAS-156 Felsbeißer fehlt: Warnung „Waffe des Felsbeißers · Fehlt“ (nicht „Waffenbuff fehlt“)
- [ ] PT-AURAS-157 Felsbeißer aktiv → Warnung verschwindet; Unbekannt → keine Warnung

Abwählen (kein Waffenbuff gewünscht)
- [x] PT-AURAS-158 Ausgewählten Felsbeißer in Beobachten erneut anklicken → abgewählt: keine Felsbeißer-Zeile, kein
  Klick-Button, die PaTiAlerts-Warnung verschwindet (auch wenn er wirklich fehlt), keine „Waffenbuff fehlt“-Warnung
  - ❌ FAIL 2026-10-02
  - Erneuter Klick auf den ausgewählten Felsbeißer in Beobachten wählt ihn nicht ab.
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - Logik nachgestellt (CI, Popup-Klick mit Attrappen): Abwählen speichert `false` und zeichnet neu. Behoben wurde, was
    im Client davon abweichen kann: Mehrfachauswahl zeigt jetzt ein Kästchen statt nur eines Farbpunkts, und ein
    Fehler im Klick verhindert das Neuzeichnen nicht mehr. Beim Retest: `/console scriptErrors 1`, danach
    `/pa debug` (Zeile „Weapon watch“ zeigt `ROCKBITER_WEAPON=false`).
  - MANUAL RETEST REQUIRED
  - Owner 2026-10-02 (Teilbefund): Kästchen wird beim Anklicken leer; ob die Zeile verschwindet, noch offen.
  - ✅ VERIFIED 2026-10-02
  - Owner: Kästchen leer, Felsbeißer-Zeile verschwindet aus dem Fenster.
- [x] PT-AURAS-159 Abgewählt → `/reload` (und Relog): bleibt abgewählt, kein „Neue Auren“-Dialog schaltet ihn wieder ein
  - Owner 2026-10-02 (Teilbefund): nach `/reload` bleibt Felsbeißer abgewählt; Relog noch offen.
  - ✅ VERIFIED 2026-10-02
  - Owner: bleibt nach `/reload` und nach Aus-/Einloggen abgewählt.
- [ ] PT-AURAS-160 Wieder anwählen → Zeile, Zustand, Warnung und Klick zum Wirken sind wieder da

Tooltips (PaTiShared)
- [ ] PT-AURAS-161 Fenster links: Tooltip einer Aura-Zeile steht rechts daneben, Icon und Name bleiben sichtbar;
  Fenster rechts: Tooltip links daneben
- [ ] PT-AURAS-162 Gruppenbuff- und Waffenzeilen (sichere Buttons): Tooltip daneben, Klick funktioniert weiter;
  kein Lua-Fehler

Rechtsklick entfernt einen aktiven Buff
- [ ] PT-AURAS-163 Wasserschild aktiv: Rechtsklick auf die Zeile entfernt ihn von dir; Tooltip „Rechtsklick:
  Wasserschild von dir entfernen.“; danach „Fehlt“
- [ ] PT-AURAS-164 Aktiver Proc (z. B. Flutwellen): Rechtsklick entfernt ihn
- ~~PT-AURAS-165 Felsbeißer aktiv: Rechtsklick entfernt ihn von der Waffe~~
  - ❌ FAIL 2026-10-02 – Lua-Fehler in Blizzards SecureTemplates.lua:478: „attempt to index global
    'CANCELABLE_ITEMS' (a nil value)“ (Zweig target-slot von cancelaura).
  - RETIRED 2026-10-02 – im Forever-Client nicht sauber möglich; Rechtsklick für Waffenbuffs entfernt.
- [ ] PT-AURAS-169 Felsbeißer aktiv: Rechtsklick tut nichts und erzeugt keinen Lua-Fehler; Tooltip ohne
  Rechtsklick-Hinweis
- [ ] PT-AURAS-166 Fehlende oder unklare Zeile: Rechtsklick tut nichts, kein Hinweis im Tooltip; Linksklick auf
  eine aktive Zeile tut nichts
- [ ] PT-AURAS-167 Im Kampf: Rechtsklick auf eine bei Kampfbeginn aktive Zeile entfernt den Buff; ein im Kampf
  auftauchender Proc erscheint unter den anderen Zeilen, nichts verrutscht unter dem Mauszeiger; ein im Kampf
  abgelaufener Buff zeigt „–“
- [ ] PT-AURAS-168 Kein Lua-Fehler, kein `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`, `taint.log` ohne
  PaTiAuras-Eintrag

## Aufspüren (Berufe)

- [ ] PT-AURAS-170 `/pa auras` mit und ohne Kräutersuche: Zeile „Tracking API …“ und die Liste zeigen, was der
  Client meldet (beide Ausgaben melden); Zeile `tracking FIND_HERBS id=2383` mit richtigem Namen
- [ ] PT-AURAS-171 Beobachten zeigt unter „Aufspüren“ nur die gelernten Zauber (z. B. Kräutersuche, Mineraliensuche)
- [ ] PT-AURAS-172 Kräutersuche gewählt, nicht aktiv: Zeile „Kräutersuche – Fehlt“; Linksklick wirkt sie, danach
  „Aktiv“; ein Klick = ein Cast
- [ ] PT-AURAS-173 Mineraliensuche aktiv, Kräutersuche gewählt: „Fehlt“ mit Hinweis „anderes Aufspüren“ (kein
  automatisches Umschalten)
- [ ] PT-AURAS-174 Nur ein Aufspüren wählbar: Mineraliensuche anwählen wählt Kräutersuche ab; erneut anklicken →
  keins; bleibt nach `/reload`
- [ ] PT-AURAS-175 Mit PaTiAlerts: gewähltes Aufspüren fehlt → Warnung; aktiv → weg; Unbekannt → keine
- [ ] PT-AURAS-176 Kein Lua-Fehler, kein `ADDON_ACTION_BLOCKED`; im Kampf wie die anderen Klickzeilen

## Personal (Selbst)

- [ ] PT-AURAS-060 Schamane: Wasserschild ACTIVE mit Restzeit und Aufladungen
- [ ] PT-AURAS-061 Schamane: Wasserschild fehlt → MISSING; läuft aus → EXPIRING
- [ ] PT-AURAS-062 Priester: Inneres Feuer ACTIVE mit Aufladungen, MISSING, EXPIRING
- [ ] PT-AURAS-063 Nicht lesbare Aura-Daten → UNKNOWN, nie MISSING
- [ ] PT-AURAS-064 Mit PaTiAlerts: fehlender/auslaufender beobachteter Selbst-Buff erscheint dort, aktiver verschwindet

## Procs

- [ ] PT-AURAS-070 Flutwellen (Tidal Waves) erscheint nur, solange der Proc aktiv ist
- [ ] PT-AURAS-071 Stapelanzahl wird angezeigt
- [ ] PT-AURAS-072 Procs erscheinen nicht in PaTiAlerts

## Healing (pro Gruppenmitglied) – entfernt

Die Healing-Kategorie wurde am 2026-10-02 entfernt (Owner-Entscheidung): eigene HoTs/Schilde auf Gruppenmitgliedern
zeigt nur noch PaTiHeal (dort getestet). Neue Tests: PT-AURAS-180–182.

- ~~PT-AURAS-075 Schamane: eigenes Erdschild am Mitglied mit Aufladungen~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-076 Schamane: eigene Springflut (Riptide) mit Restzeit~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-077 Priester: eigene Erneuerung (Renew)~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-078 Priester: eigenes Machtwort: Schild~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-079 Priester: eigenes Gebet der Besserung mit Aufladungen~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-080 HoTs/Schilde anderer Heiler erscheinen nicht~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- ~~PT-AURAS-081 `/pa auras` listet die Heil-Auren-IDs als bekannt (Schamane und Priester melden)~~
  - RETIRED 2026-10-02 – Healing-Kategorie aus PaTiAuras entfernt; HoTs/Schilde zeigt PaTiHeal
- [ ] PT-AURAS-180 Kein Abschnitt „Heilung“ mehr im Fenster und keine Heil-Auren im Beobachten-Menü (Schamane und Priester)
- [ ] PT-AURAS-181 Update mit alten Einstellungen (Heil-Auren vorher an oder abgewählt): kein Lua-Fehler, keine leere
  Heilung-Zeile, keine Heil-Auren im Dialog „Neue Auren“; Selbst, Procs, Aufspüren, Gruppe und Felsbeißer unverändert
- [ ] PT-AURAS-182 Mit PaTiHeal: Erdschild/Springflut bzw. Erneuerung/Machtwort: Schild erscheinen nur noch in PaTiHeal;
  beide Addons laufen normal

## Group Buffs (Priester)

- [x] PT-AURAS-085 `/pa auras`: Priester-IDs für Inneres Feuer, Seelenstärke, Göttlicher Willen, Schattenschutz
  (inkl. Gebets-Varianten) sind im Client bekannt
  - ✅ VERIFIED 2026-09-28
  - IDs 588, 1243, 21562, 14752, 27681, 976, 27683 (deDE-Client).
- [ ] PT-AURAS-086 Solo: Gruppenbuff-Zeile erscheint (z. B. „0 / 1“)
- [ ] PT-AURAS-087 Party: Anzahl „x / y“ stimmt, Tooltip nennt, wem der Buff fehlt, und wer offline/tot ist
- [ ] PT-AURAS-088 Gebets-Variante zählt als derselbe Buff
- [ ] PT-AURAS-089 Klick auf die Zeile bufft das im Tooltip genannte Mitglied (höchster bekannter Rang), ein Klick =
  ein Cast
- [ ] PT-AURAS-090 Klick ändert das eigene Ziel nicht
- [ ] PT-AURAS-091 Alle gebufft: Klick tut nichts
- [ ] PT-AURAS-092 Im Kampf bleibt das Klickziel fest (wie bei Kampfbeginn) und der Tooltip zeigt es
- [ ] PT-AURAS-093 Offline, tote oder außer Sicht befindliche Mitglieder werden nicht als Klickziel gewählt
- [x] PT-AURAS-094 Priester: aktiver beobachteter Gruppenbuff wird oben angezeigt und als vorhanden erkannt
  - ✅ VERIFIED 2026-09-30
  - Der Bericht nennt den Buff nicht ausdrücklich (Beispiel darin: Machtwort: Seelenstärke); nur dieser eine Buff.
- [ ] PT-AURAS-095 Priester: beobachtete Machtwort: Seelenstärke fehlt → Zeile zeigt fehlend
- [ ] PT-AURAS-096 Machtwort: Seelenstärke anwenden → Zeile zeigt vorhanden
- [ ] PT-AURAS-097 Machtwort: Seelenstärke entfernen → wieder fehlend

## Beobachten (Einstellungen)

- [ ] PT-AURAS-100 Button „Beobachtete Effekte auswählen (x / y)“ öffnet die Liste mit den Effekten des Charakters,
  gruppiert nach Selbst, Procs, Waffe, Aufspüren, Gruppe (keine Heilung mehr)
- [ ] PT-AURAS-101 Nur die eigene Klasse; unbekannte Zauber fehlen
- [ ] PT-AURAS-102 Häkchen schaltet genau einen Effekt, die Liste bleibt offen, die Anzahl im Button stimmt
- [ ] PT-AURAS-103 Abgewählter Effekt verschwindet aus dem Fenster; Auswahl bleibt nach `/reload`
- [ ] PT-AURAS-104 Kein zweiter Aura-Einstellungsblock und keine Kategorie-Schalter mehr
- [ ] PT-AURAS-105 Neu gelernter Zauber: Dialog „Neue Auren“ erscheint (nicht im Kampf), danach in der Liste
- [ ] PT-AURAS-106 Erster Start: Dialog „Neue Auren“ bietet die Effekte an, Schließen markiert sie als gesehen
- [ ] PT-AURAS-107 Anzeige-Schalter (Timer, Aufladungen, Fehlende, Auslaufende) wirken
- [x] PT-AURAS-108 Priester: ein einzelner Effekt (Machtwort: Seelenstärke) lässt sich im zentralen Beobachten-Menü
  an- und abwählen, PaTiAuras reagiert darauf
  - ✅ VERIFIED 2026-09-30
- [ ] PT-AURAS-109 Abgewählten Effekt wieder anwählen → Eintrag erscheint wieder

## Unabhängigkeit

- [ ] PT-AURAS-110 Ohne PaTiAlerts: unverändert, kein Lua-Fehler
- ~~PT-AURAS-111 Mit PaTiHeal: Heil-Auren lassen sich hier abwählen, beide Addons laufen normal~~
  - RETIRED 2026-10-02 – keine Heil-Auren mehr in PaTiAuras; ersetzt durch PT-AURAS-182

## PaTiAlerts: Gruppenbuffs

- [ ] PT-AURAS-112 Solo: beobachteter Gruppenbuff (z. B. Machtwort: Seelenstärke) fehlt → eine Warnung „Fehlt“
- [ ] PT-AURAS-113 Buff aktiv → Warnung verschwindet; ein aktiver Buff erzeugt nie eine Warnung
- [ ] PT-AURAS-114 Buff im Beobachten-Menü abgewählt → keine Warnung (eine bestehende verschwindet)
- [ ] PT-AURAS-115 Gruppe: Buff fehlt bei N Mitgliedern → genau eine Warnung „Fehlt bei N“, keine Namensliste;
  tote und Offline-Mitglieder zählen nicht
- [ ] PT-AURAS-116 Alle lebenden Mitglieder gebufft → Warnung verschwindet

## Kategorie-Layout (Darstellung)

- [ ] PT-AURAS-190 Ohne Änderung (Bestand und Neuinstallation): Kategorien wie bisher untereinander (Vertikal)
- [ ] PT-AURAS-191 Einstellungen → Darstellung → Kategorie-Layout „Horizontal“: GROUP, WEAPON, SELF, TRACKING als Spalten
  nebeneinander; in jeder Spalte stehen die Einträge untereinander, nie quer gemischt
- [ ] PT-AURAS-192 Horizontal: keine abgeschnittenen Namen (deDE, lange Namen wie „Machtwort: Seelenstärke“), keine
  riesigen Leerflächen; Fensterbreite passt sich an
- [ ] PT-AURAS-193 Horizontal mit großer Größe (Scale 150 %) oder schmalem Bildschirm: Spalten brechen in eine zweite
  Reihe um, nichts liegt außerhalb des Bildschirms
- [ ] PT-AURAS-194 Layout bleibt nach `/reload`; zurück auf „Vertikal“ zeigt wieder das alte Bild
- [ ] PT-AURAS-195 Horizontal: Klick auf eine Gruppenbuff-Zeile bufft genau diesen Buff (Tooltip-Ziel), Klick auf eine
  fehlende Waffen-/Aufspüren-Zeile wirkt genau diesen Zauber — kein Button liegt über einer anderen Zeile (Hover-Rahmen
  deckt genau die Zeile)
- [ ] PT-AURAS-196 Layout im Kampf umstellen: Chat-Hinweis „wird nach dem Kampf angewendet“, im Kampf bleibt das alte
  Layout, nach dem Kampf wechselt es; kein `ADDON_ACTION_BLOCKED`
- [ ] PT-AURAS-197 Horizontal im Kampf: neuer Proc erscheint, ohne dass andere Zeilen/Buttons verrutschen; nach dem
  Kampf ordnet sich alles neu
- [ ] PT-AURAS-198 Horizontal mit nur einer Kategorie (z. B. nur Selbst) und ohne Kategorien („nichts beobachtet“):
  sinnvolle Breite, kein Fehler
- [ ] PT-AURAS-199 Einklappen/Ausklappen und Test Mode im horizontalen Layout ohne Fehler

## Combat / Sicherheit

- [ ] PT-AURAS-120 Kein Lua-Fehler im Kampf
- [ ] PT-AURAS-121 Keine `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` (auch Klick-Buff im Kampf)
- [ ] PT-AURAS-122 `taint.log` (`/console taintLog 1`) ohne PaTiAuras-Eintrag
- [ ] PT-AURAS-123 Im Kampf gesperrt mit Hinweis: Ausblenden, Collapse, Test Mode, Größe, Position zurücksetzen

## Combined

- [ ] PT-AURAS-130 Zusammen mit allen PaTi-Addons geladen: kein Lua-Fehler
- [ ] PT-AURAS-131 Keine Slash-Command-Kollision: `/pa` und `/patiauras` antworten nur PaTiAuras
- [ ] PT-AURAS-132 Eigene Einstellungen speichern nur PaTiAuras-Werte; Fenster erscheint in PaTiSuite
