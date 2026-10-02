# Hero Lane Wars – Godot-Version (3D)

Ziel: Das Spiel als 3D-Spiel mit Kamera von schräg oben (wie LoL/Warcraft). Der Browser-Prototyp (`../index.html`) bleibt die Referenz für Regeln und Balance.

## Starten
- Spiel direkt: `Godot-Spiel-starten.bat` im Projektordner (Doppelklick). Der Pfad zu Godot steht oben in der Datei.
- Editor: `Godot-Editor-oeffnen.bat`.
- Steuerung: **Rechtsklick** auf den Boden = laufen, auf ein Monster = angreifen. Der Held greift automatisch an.

## Stand (Meilenstein 1)
Enthalten: 3D-Szene, Kamera, Held (alle 3 Klassen mit Originalwerten), Auto-Angriffe, Monsterwellen (Elite ab Welle 10, Boss Welle 20 nur als starker Gegner), Level/XP, Gold und Einkommen, Lebensverlust, Tod und Wiederbelebung, Anzeige.
Noch nicht: Skills, Shop und Items, Gegner-Bot mit eigener Lane, Monster senden, Boss-Fähigkeiten, Aufholhilfe, Sounds und Effekte, echte 3D-Figuren.

## Startmenü und Kartenaufbau je Spielerzahl
Beim Start wählst du im Menü Spielmodus (1 gegen 1, 2 gegen 2, 4 gegen 4) und Held. Für Tests überspringt `--team=1|2|4` das Menü (Starter `...-2v2.bat`, `...-4v4.bat`). Der Aufbau:
- **1 gegen 1:** je eine Lane pro Spieler, Fluss dazwischen.
- **2 gegen 2:** je eine breite Lane pro Team (2 Helden nebeneinander, Lane-Breite ×1,95 gegenüber dem Prototyp).
- **4 gegen 4:** pro Team eine Doppel-Lane (2 Lanes, je 2 Helden). Die gemeinsame Wand ist durchgehend, nur die Basis (x < 300) ist offen: zur anderen Lane kommt man nur über die Basis (Backport nutzen oder zurücklaufen), das Team muss sich absprechen. Beide Lanes bekommen die Wellen. Fluss zwischen den Teams.
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

## Backport und Minimap
- **Backport (B):** wie im Prototyp 4,5 s Zauberzeit, 75 s Abklingzeit, Schaden unterbricht, nicht in der Basis. Stopp: S.
- **Minimap** (unten links): alle Lanes von oben, Monster rot (Elite/Boss größer), dein Held in Heldenfarbe, über jeder Lane deines Teams die Zahl der Monster.
- **Selbsttest** (Lane-Wechsel und Backport): `Godot_console.exe --headless --path godot -- --selftest --team=4`

## Skills, Items, Tests (Stand Meilenstein 2 und 3)
- **Skills Q W E R** aller drei Helden (`scripts/skills.gd`), Skillpunkte (1 pro Level, Shift+Taste oder „+“), Rang-Werte, Abklingzeiten, Zonen, Elementare, Statuseffekte – 1:1 aus dem Prototyp.
- **Items und Shop** (`scripts/items.gd`): 49 Items, Rucksack mit 6 Plätzen, Rezepte, Hut-Regel, Verkauf 70 %, Heiltrank (F). Shop mit **Tab** oder Knopf; Kaufen nur in der Basis. Alle Item-Effekte (Krit, Lebensraub, Dornen, Qual, Aura, Gold pro Sekunde ...) sind umgesetzt.
- **Tests:**
  - `-- --golden` : Szenario-Runner, vergleicht 205 Szenarien (`data/golden-skills.json`, erzeugt aus dem Prototyp) Zahl für Zahl. Stand: 205 von 205 identisch.
  - `-- --selftest-items` : Shop-Regeln (20 Prüfungen). `-- --selftest --team=4` : Lane-Wechsel, Backport, Minimap, Kristall.
  - Neue Vergleichswerte erzeugen: im Browser `regelwerk/golden-skills.js` ausführen, Datei nach `godot/data/` kopieren.

## Senden, Bot, Wirtschaft (Stand Meilenstein 4)
- **Zwei Seiten** (dein Team, Gegner-Team): je eigene Monster, Wellen, Team-Leben, Spieler. Jeder Spieler hat eigenes Gold, Einkommen, Rucksack, Skills.
- **Monster senden** (Z X C V N oder Knöpfe links): kostet Gold, erhöht das Einkommen; das Monster erscheint auf **allen** Lanes des Gegner-Teams.
- **Bots** (`scripts/bot.gd`): Gegner und Mitspieler, 1:1 aus dem Prototyp (Kaufplan, Skills, Backport-Einkaufsreisen, Senden nach Schwierigkeit und Stil).
- **Menü:** Spielmodus, Held, Schwierigkeit (Leicht..Experte), Gegner-Stil. P/Esc = Pause, 1/2/3 = Tempo. Aufholhilfe, Boss (Phasen, Stampfen, Verstärkung, Boss-Einkommen) umgesetzt.
- **Prüfung:** `-- --golden-eco` vergleicht 4339 Fälle aus `data/golden-economy.json` (Einkommen, Senden, Level, Respawn, Wellen, Items, Item-Effekte, Bot-Kaufpläne/Lernen/Senden/Modus). Stand: 4339 von 4339 identisch zum Prototyp.

## 3D-Figuren (Platzhalter)
Helden (Krieger, Schurke, Magier) und Monster (GreenDemon, Cyclops, Skull, Bat, Demon, YellowDragon) stammen von **Quaternius** (CC0, Pakete „RPG Characters" und „Cute Animated Monsters"), Ordner `godot/assets/quaternius/`. Sie werden zur Laufzeit aus den glTF-Dateien geladen (`_make_figure` in `game.gd`) und laufen, stehen oder greifen an. Zuordnung: `HERO_MODEL` und `UNIT_MODEL` oben bei `_spawn_unit`. Tausch gegen andere Modelle: Datei ablegen, Zuordnung ändern.
