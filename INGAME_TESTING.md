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
- [ ] PT-AURAS-003 Icon in der AddOn-Liste korrekt, keine weiße oder fehlende Textur
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
- [ ] PT-AURAS-032 Update mit alten Einstellungen: eine vorher abgeschaltete Kategorie (z. B. Heilung) bleibt nach dem
  Update abgewählt (Schema-2-Migration), Position/Sprache/Größe bleiben
- [ ] PT-AURAS-033 „Standard wiederherstellen“: alles wieder beobachtet, Position bleibt

## Sprachen

- [ ] PT-AURAS-040 deDE: alle Texte deutsch, Zaubernamen aus dem Client
- [ ] PT-AURAS-041 Sprache enUS in den Einstellungen: nach `/reload` englisch
- [ ] PT-AURAS-042 zhCN/zhTW/koKR: Englisch als Rückfall, keine Schlüsselnamen oder Kästchen
- [ ] PT-AURAS-043 Keine abgeschnittenen wichtigen Texte (deDE), Hinweise brechen um

## Weapon Imbues (Schamane)

- [x] PT-AURAS-050 Mainhand-Waffe wird beim Ausrüsten erkannt (Zeile Waffenhand erscheint)
  - ✅ VERIFIED 2026-09-30
  - Auch mit dem Fix-Build bestätigt: ausrüsten, ablegen, erneut ausrüsten wird jeweils erkannt.
- [x] PT-AURAS-051 Entfernte Mainhand-Waffe verschwindet
  - ✅ VERIFIED 2026-09-30
- [ ] PT-AURAS-052 Mainhand ohne Imbue → MISSING (nicht UNKNOWN)
  - ❌ FAIL 2026-09-30
  - Ohne Felsbeißer „Unbekannt“ statt „Fehlt“.
  - 🔧 FIX IMPLEMENTED 2026-09-30
  - Klassisches `GetWeaponEnchantInfo()` zuerst, `C_Item.GetWeaponEnchantInfo(slot)` nur als Rückfall.
  - Retest 2026-09-30: ohne Imbue „Fehlt“, kein UNKNOWN mehr. Nicht aussagekräftig, solange auch ein aktiver Imbue
    „Fehlt“ zeigt (PT-AURAS-053).
  - MANUAL RETEST REQUIRED
- [ ] PT-AURAS-053 Rockbiter aktivieren → ACTIVE mit Restzeit
  - ❌ FAIL 2026-09-30
  - Waffe selbst wird erkannt, Imbue bleibt UNKNOWN.
  - 🔧 FIX IMPLEMENTED 2026-09-30
  - ❌ FAIL 2026-09-30
  - Retest mit Fix: Waffe vorhanden, Waffe des Felsbeißers aktiv, Anzeige trotzdem „Fehlt“.
  - Diagnose erweitert (PT-AURAS-007), noch kein Fix. Nächster Test: `/pa auras` ohne und mit Felsbeißer, beide
    Ausgaben melden.
- [ ] PT-AURAS-054 Rockbiter entfernen bzw. auslaufen lassen → MISSING
  - ❌ FAIL 2026-09-30
  - Zeigt „Fehlt“, aber schon vorher mit aktivem Imbue: keine Zustandsänderung erkannt.
- [ ] PT-AURAS-055 Rockbiter erneut aktivieren → ACTIVE
  - ❌ FAIL 2026-09-30
  - Bleibt „Fehlt“.
- [ ] PT-AURAS-056 Timer wird aktualisiert; unter 30 s EXPIRING; Erneuern aktualisiert innerhalb von ~1–2 s
- [ ] PT-AURAS-057 Mit PaTiAlerts: „Waffenbuff fehlt“ erscheint bei MISSING, verschwindet bei ACTIVE, nie bei UNKNOWN
  - ❌ FAIL 2026-09-30
  - Warnung bleibt bei aktivem Felsbeißer. Ursache upstream: PaTiAuras meldet den aktiven Imbue als MISSING
    (PT-AURAS-053); PaTiAlerts selbst arbeitet richtig.
- [ ] PT-AURAS-058 Schildhand: Schild oder leer → keine Zeile; Nebenhand-Waffe → eigene Zeile mit eigenem Zustand
- [ ] PT-AURAS-059 Waffe wechseln: kein alter Zustand, kein Lua-Fehler; Imbue läuft im Kampf aus bzw. wird erneuert

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

## Healing (pro Gruppenmitglied)

- [ ] PT-AURAS-075 Schamane: eigenes Erdschild am Mitglied mit Aufladungen
- [ ] PT-AURAS-076 Schamane: eigene Springflut (Riptide) mit Restzeit
- [ ] PT-AURAS-077 Priester: eigene Erneuerung (Renew)
- [ ] PT-AURAS-078 Priester: eigenes Machtwort: Schild
- [ ] PT-AURAS-079 Priester: eigenes Gebet der Besserung mit Aufladungen
- [ ] PT-AURAS-080 HoTs/Schilde anderer Heiler erscheinen nicht
- [ ] PT-AURAS-081 `/pa auras` listet die Heil-Auren-IDs als bekannt (Schamane und Priester melden)

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
  gruppiert nach Selbst, Procs, Heilung, Waffe, Gruppe
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
- [ ] PT-AURAS-111 Mit PaTiHeal: Heil-Auren lassen sich hier abwählen, beide Addons laufen normal

## PaTiAlerts: Gruppenbuffs

- [ ] PT-AURAS-112 Solo: beobachteter Gruppenbuff (z. B. Machtwort: Seelenstärke) fehlt → eine Warnung „Fehlt“
- [ ] PT-AURAS-113 Buff aktiv → Warnung verschwindet; ein aktiver Buff erzeugt nie eine Warnung
- [ ] PT-AURAS-114 Buff im Beobachten-Menü abgewählt → keine Warnung (eine bestehende verschwindet)
- [ ] PT-AURAS-115 Gruppe: Buff fehlt bei N Mitgliedern → genau eine Warnung „Fehlt bei N“, keine Namensliste;
  tote und Offline-Mitglieder zählen nicht
- [ ] PT-AURAS-116 Alle lebenden Mitglieder gebufft → Warnung verschwindet

## Combat / Sicherheit

- [ ] PT-AURAS-120 Kein Lua-Fehler im Kampf
- [ ] PT-AURAS-121 Keine `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` (auch Klick-Buff im Kampf)
- [ ] PT-AURAS-122 `taint.log` (`/console taintLog 1`) ohne PaTiAuras-Eintrag
- [ ] PT-AURAS-123 Im Kampf gesperrt mit Hinweis: Ausblenden, Collapse, Test Mode, Größe, Position zurücksetzen

## Combined

- [ ] PT-AURAS-130 Zusammen mit allen PaTi-Addons geladen: kein Lua-Fehler
- [ ] PT-AURAS-131 Keine Slash-Command-Kollision: `/pa` und `/patiauras` antworten nur PaTiAuras
- [ ] PT-AURAS-132 Eigene Einstellungen speichern nur PaTiAuras-Werte; Fenster erscheint in PaTiSuite
