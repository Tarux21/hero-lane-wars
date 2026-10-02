# Roadmap Hero Lane Wars

Rolle: Projektmanager (Planung, Abnahme) – Claude setzt um und stellt nach jedem Schritt Feedbackfragen.

## Phase 1 – Browser-Prototyp verbessern (jetzt)
- [x] Testfenster standardmäßig zu (F2 öffnet es), Spielfeld skaliert auf kleine Fenster
- [x] Einstieg: Kasten „So gewinnst du“ im Startmenü + 5 Einsteiger-Tipps im Spiel (je einmal; Einstellungen → „Tipps erneut zeigen“)
- [x] Aufholhilfe: ab 3 Leben Rückstand +4 % Einkommen je Leben, max. +20 % (HUD zeigt „Aufholhilfe“). Messung `snowball.js`: Bot-Partien snowballen kaum (Führender nach 3 Min gewinnt ~52 %); Balance und Spieldauer unverändert (~15 Min). Die Hilfe ist ein Netz für menschliche Fehler – bitte im Spiel prüfen.
- [ ] Offen aus der Messung: Damage liegt bei 38–42 % Siegquote (Ziel 50 %), vom Balancing-Stand 2161de5 unabhängig von der Aufholhilfe
- [x] Spielgefühl (Stand 1, wartet auf Abnahme): 14 synthetische Sounds (kein Download nötig), Schadenszahlen nach Stärke skaliert (Krit gelb/größer), Trefferblitz, Sterbe-Partikel, Bildschirmwackeln, roter Rand bei wenig Leben/Lebensverlust. Regler in den Einstellungen: Lautstärke, Wackeln an/aus. Nur für den Spieler, nicht in der Simulation.
- [x] Bot (Stand 1, wartet auf Abnahme): Stufen gemessen (Bot gegen Bot, je Klasse gespiegelt): Normal schlägt Leicht ~77 %, Schwer schlägt Normal ~83 %, Experte schlägt Schwer ~58–85 % (Damage am schwächsten, ~58 %; frühere Werte um 43 % waren Messrauschen). Neu: 3 Gegner-Spielstile (Ausgewogen, Aggressiv, Wirtschaft; im Menü wählbar oder Zufall, im HUD sichtbar), gegeneinander fair (je ~42–58 %).
- [ ] Offen: Wie sich die Stufen für einen Menschen anfühlen, kann nur im Spiel getestet werden (Abnahme durch den Projektmanager)

- [x] Testversion v0.3.0-test: Versionsnummer, Feedback-Fenster, Build-Skript `build-testversion.ps1` (ZIP in `dist\`)
- [ ] Optik: schönere Figuren, Hintergründe, Oberfläche (als Nächstes)

> **Richtungsentscheid:** Endziel ist ein 3D-Spiel mit animierten Figuren aus der Vogelperspektive (Look wie LoL/Warcraft). Der Browser-Prototyp wird deshalb nicht mehr optisch ausgebaut, sondern bleibt Referenz für Regeln und Balance. Engine: Godot 4.7 (3D).

## Phase 2 – Umzug nach Godot (läuft)
- [x] Regelwerk exportiert (`regelwerk/daten.json`, Skript `export-regelwerk.js`)
- [x] Meilenstein 1: 3D-Szene, Kamera, Held, Wellen, Level, Gold, Leben (siehe `godot/README.md`)
- [x] Karte: Warcraft-artige Kamera, senkrechte Lanes, Fluss, Platz; Layout je Spielerzahl (1v1/2v2: eine Lane pro Team, ab 4v4 Doppel-Lane pro Team, breitere Lanes, größerer Teamabstand)
- [x] 4v4: Wand zwischen den Lanes eines Teams durchgehend (keine Durchgänge), Wechsel nur über die offene Basis, Backport (B), Minimap mit Monsterzahl je Lane
> **Grundsatz:** Der Browser-Prototyp ist die Spielbasis. Die Godot-Version übernimmt Regeln, Zahlen und Abläufe 1:1 aus `index.html`; Abweichungen nur nach Absprache.
- [x] Meilenstein 2: Skills (Q W E R) und Heiltrank, Backport – 1:1 zum Prototyp, geprüft mit 205 Vergleichsszenarien (205 von 205 identisch)
- [x] Meilenstein 3: Shop und Items (49 Items, Rucksack, Rezepte, alle Effekte), geprüft mit Selbsttest und Vergleichsszenarien
- [x] Meilenstein 4: Gegner-Bot (1:1 Prototyp), Monster senden (alle Lanes des Gegner-Teams), Aufholhilfe, Schwierigkeiten und Stile, Boss, Menü, Pause/Tempo, Endbildschirm – geprüft mit 4339 Vergleichsfällen
- [ ] Meilenstein 5: Boss, Elite, Sounds und Effekte
- [ ] Meilenstein 6: echte 3D-Figuren, Animationen, Umgebung, Oberfläche

## Ältere Notiz zu Phase 2
- Empfehlung: Godot (kostenlos, leicht, gutes 2D, Web-Export). Unity nur, wenn C# und viele Plattformen wichtig sind.
- Regeln und Zahlen (CFG, UNITS, HEROES, ITEM_LIST) bleiben als Datenbasis erhalten.

## Phase 3 – Online 1 gegen 1 (Abschluss)
- Erst nach stabilem Solo-Spiel gegen die KI.

## Quellen der Recherche
- Snowballing und Einkommen in Tower-Wars-Spielen: Hive Workshop, "Tower War, how to do it right"
- Flow und Schwierigkeitskurve im Tower Defense: Diva-Portal "Flow in Tower Defense", Defender's Quest
- Godot vs Unity für Web: cinevva.com Vergleich 2026
