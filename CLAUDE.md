# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Das Projekt

Hero Lane Wars: Lane-Spiel, dein Held verteidigt die Lane gegen Monsterwellen, du schickst Monster zum Gegner. Zwei Versionen:

- **Browser-Prototyp** `index.html` (ein File, Balance-Zahlen oben in `CFG`, `UNITS`, `HEROES`, `ITEM_LIST`, `DIFF`). **Referenz für Regeln und Zahlen.**
- **3D-Version** in `godot/` (Godot 4.7, GDScript). Übernimmt Regeln 1:1 vom Prototyp; Abweichungen nur nach Absprache (bekannte stehen in `docs/Teststand.md`).

Details: `README.md` (Prototyp), `godot/README.md` (Godot, Testflags), `ROADMAP.md` (Stand der Phasen).

## Starten

- Prototyp: `index.html` öffnen oder `powershell -ExecutionPolicy Bypass -File serve.ps1` → http://localhost:8123/
- Godot: `Godot-Spiel-starten.bat` (1v1), `...-2v2.bat`, `...-4v4.bat`; Editor: `Godot-Editor-oeffnen.bat`

## Testen

- Alle Prüfungen: `Alle-Tests.bat` (ca. 1 Min., ohne Fenster, Ergebnis in `Alle-Tests-Ergebnis.txt`). Jede Zeile muss „identisch“ bzw. „OK“ zeigen.
- Einzeln: `<Godot-Konsole> --headless --path godot -- --golden` (bzw. `--golden-eco`, `--golden-boss`, `--selftest-items --team=1`, `--selftest --team=4`, `--botplay --sim=2400 --team=1 --diff=normal`). Pfad zur Godot-Konsole steht oben in `Alle-Tests.bat`.
- Bilder prüfen: `--sim=N --shot=bild.png` (siehe `godot/README.md`).

## Stolperfallen

- `godot/data/daten.json` und `godot/data/golden-*.json` nie von Hand ändern: Regeln in `index.html` ändern, mit `export-regelwerk.js` bzw. `regelwerk/golden-*.js` (im Browser über `serve.ps1`) neu erzeugen und nach `godot/data/` kopieren.
- Optik (`fx.gd`, `sfx*.gd`, Anzeige) darf keine Spielwerte ändern und nicht den Spiel-Zufall benutzen, sonst weichen die Golden-Vergleiche ab.

## Regeln für Claude

1. Vor jeder neuen Funktion oder sichtbaren Änderung 2–3 Varianten zum Anschauen zeigen (Mockup, Testbild oder kurze Szene); erst nach meiner Wahl umsetzen.
2. Bevor du etwas als fertig meldest, selbst prüfen: passende Tests grün, Ergebnis im Bild angeschaut.
3. Keine Entscheidungen selbst treffen, wenn etwas unklar ist: alle offenen Fragen gesammelt am Anfang stellen, dann ohne Unterbrechung arbeiten.
