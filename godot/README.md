# Hero Lane Wars – Godot-Version (3D)

Ziel: Das Spiel als 3D-Spiel mit Kamera von schräg oben (wie LoL/Warcraft). Der Browser-Prototyp (`../index.html`) bleibt die Referenz für Regeln und Balance.

## Starten
- Spiel direkt: `Godot-Spiel-starten.bat` im Projektordner (Doppelklick). Der Pfad zu Godot steht oben in der Datei.
- Editor: `Godot-Editor-oeffnen.bat`.
- Steuerung: **Rechtsklick** auf den Boden = laufen, auf ein Monster = angreifen. Der Held greift automatisch an.

## Stand (Meilenstein 1)
Enthalten: 3D-Szene, Kamera, Held (alle 3 Klassen mit Originalwerten), Auto-Angriffe, Monsterwellen (Elite ab Welle 10, Boss Welle 20 nur als starker Gegner), Level/XP, Gold und Einkommen, Lebensverlust, Tod und Wiederbelebung, Anzeige.
Noch nicht: Skills, Shop und Items, Gegner-Bot mit eigener Lane, Monster senden, Boss-Fähigkeiten, Aufholhilfe, Sounds und Effekte, echte 3D-Figuren.

## Kartenaufbau je Spielerzahl
Der Aufbau hängt von den Spielern pro Team ab (`--team=1|2|4`; Starter: `Godot-Spiel-starten.bat` = 1 gegen 1, `...-2v2.bat`, `...-4v4.bat`):
- **1 gegen 1:** je eine Lane pro Spieler, Fluss dazwischen.
- **2 gegen 2:** je eine breite Lane pro Team (2 Helden nebeneinander, Lane-Breite ×1,7 gegenüber dem Prototyp).
- **4 gegen 4:** pro Team eine Doppel-Lane (2 Lanes, durch eine gemeinsame Felswand getrennt, je 2 Helden), Fluss zwischen den Teams.
Die Breiten und Abstände stehen oben in `game.gd` (`WALL`, `TEAM_SPACE`, Faktoren in `_setup_layout`). Aktuell spielt nur 1 Held (du) in Lane 1; weitere Spieler und Bots kommen mit Meilenstein 4.

## Regeln und Zahlen
`data/daten.json` kommt aus dem Browser-Prototyp (`export-regelwerk.js`, schreibt nach `../regelwerk/daten.json`; danach nach `data/` kopieren). Nicht von Hand ändern, sondern im Prototyp ändern und neu exportieren.

## Test ohne Fenster (für Entwicklung)
```
Godot_console.exe --headless --path godot -- --autoplay --sim=300 --hero=damage
Godot_console.exe --path godot --resolution 1280x720 -- --autoplay --sim=60 --shot=bild.png
```
`--sim` rechnet N Spielsekunden sofort, `--autoplay` lässt einen einfachen Test-Helden spielen, `--shot` speichert ein Bild.

## Aufbau
- `scripts/data.gd` – lädt die Regeln (Autoload `Data`).
- `scripts/game.gd` – Spiellogik, Szene, Eingabe (Spielwerte × `S` = Meter).
- `scenes/main.tscn` – Hauptszene.
