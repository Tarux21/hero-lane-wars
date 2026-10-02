# Teststand (Godot-Version)

Alle Prüfungen laufen ohne Fenster: Doppelklick auf `Alle-Tests.bat` (Ergebnis in `Alle-Tests-Ergebnis.txt`).

| Prüfung | Aufruf (nach `--` an Godot) | Was wird verglichen | Stand |
|---|---|---|---|
| Skills | `--golden` | 205 Szenarien aus dem Browser-Prototyp: Schaden, Heilung, Betäubung, Zonen, Elementare, Item-Effekte, Tod/Respawn, Backport | 205 von 205 identisch |
| Wirtschaft, Items, Bot | `--golden-eco` | Einkommen, Aufholhilfe, Senden, Level, Respawn, Wellen, Boss-Einkommen, Kaufen/Verkaufen/Rezepte, 58 Item-Effekt-Läufe, Bot-Kaufpläne, Skill-Lernen, 2592 Sende-Entscheidungen, Modus, Preistabelle | 4339 von 4339 identisch |
| Boss und Elite | `--golden-boss` | Boss-Phasen, Stampfen, Verstärkung, Betäubung, Aggro, Boss-Einkommen, Elite-Welle | 32 von 32 identisch |
| Shop-Regeln | `--selftest-items --team=1` | 20 Prüfungen (Hut-Regel, Rucksack voll, Verkauf 70 %, Heiltrank ...) | OK |
| Karte/Team | `--selftest --team=4` | Lane-Wechsel nur über die Basis, Backport, Minimap-Klick, Kristall | OK |
| Ganze Partien | `--botplay --sim=2400 --team=1` | Bot gegen Bot: Dauer ca. 15 Min., Seiten ausgeglichen (10 Läufe: 5 zu 5) | OK |

Quellen der Vergleichswerte: `regelwerk/golden-*.json` (aus dem Prototyp erzeugt von `regelwerk/golden-*.js`). Neu erzeugen und nach `godot/data/` kopieren, wenn sich Regeln im Prototyp ändern.

## Bekannte, bewusste Unterschiede zum Prototyp
- **Mehrere Spieler/Lanes:** Monster jagen den nächsten Helden, Aura/Bots/Boss arbeiten pro Seite (im Prototyp gibt es nur einen Helden und eine Lane).
- **Senden bei Doppel-Lane:** Ein gesendetes Monster erscheint auf beiden Gegner-Lanes, kostet aber nur einmal (Entscheidung des Projektmanagers).
- **Rechengenauigkeit:** Godot rechnet Vektor-Längen in 32 Bit, JavaScript in 64 Bit. Die Angriffs-Reichweite der Monster ist deshalb auf 64 Bit umgestellt; an anderen Grenzfällen kann es theoretisch Abweichungen von 1 Frame geben.
- **Kettenblitz ohne Ziel** startet im Prototyp trotzdem die Abklingzeit (vermutlich ein Versehen). Godot macht es 1:1 nach. Entscheidung offen.
- **Titanenstoß (Tank R) im echten Spiel ein Kegel statt Kreis** (Wunsch des Projektmanagers, Test): Reichweite 380, Halbwinkel 0,8 rad (Prototyp: Kreis, Radius 190). Schaden, Betäubung (3 s) und Rückstoß sind unverändert. Schalter: `TANK_R_CONE` in `godot/scripts/skills.gd`. Die Vergleichstests (`test_mode`) laufen weiter mit dem Kreis, deshalb bleiben 205/205 grün. Entscheidung offen, ob der Prototyp nachzieht.
