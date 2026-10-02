# Hero Lane Wars – Godot-Version (3D)

Ziel: Das Spiel als 3D-Spiel mit Kamera von schräg oben (wie LoL/Warcraft). Der Browser-Prototyp (`../index.html`) bleibt die Referenz für Regeln und Balance.

## Starten
- Spiel direkt: `Godot-Spiel-starten.bat` im Projektordner (Doppelklick). Der Pfad zu Godot steht oben in der Datei.
- Editor: `Godot-Editor-oeffnen.bat`.
- Steuerung: **Rechtsklick** auf den Boden = laufen, auf ein Monster = angreifen. Der Held greift automatisch an.
- **Testfenster (F2):** Level, Skillpunkte, Ränge Q W E R, Alles max, Cooldowns 0, +1000 Gold, Welle jetzt, Monster löschen, Übungspuppen (stehende Monster zum Ausprobieren), Unsterblich, Gegner-Leben ∞, Held heilen. Zum schnellen Testen von Fähigkeiten und Sounds.

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

## Fähigkeiten-Effekte (Caster, Stand Meilenstein 6)
- `scripts/fx.gd`: Partikel, Licht, Blitze, Kristalle, Zauberkreise, alles im Code erzeugt (reine Optik, ändert keine Spielwerte, nutzt nicht den Spiel-Zufall). Aufgerufen aus `skills.gd` über `g.vfx`.
- `scripts/sfx_caster.gd`: selbst berechnete Klänge (Feuer, Frost, Blitz, Elementare). Zum Anhören: Ordner `Caster-Sounds/` (WAV-Dateien, mit `godot --headless --path godot --script res://tools/sfxtest.gd -- --wav` neu erzeugbar).
- Bildertest: `-- --hero=caster --team=1 --fxtest=q|w|e|rfire|rfrost|rlightning --rank=1..5 --shot=Prefix` (Skript `tools/fxrun.sh`), speichert Bilder in Zeitabständen.
- Tank und Damage haben noch die alten einfachen Effekte.

## Tank (Stand Meilenstein 6)
- Modell: Quaternius-Krieger, etwas breiter, mit Turmschild (hoch, dunkles Eisen, violette Einfassung, Spikes vorne) am linken Unterarm. Läuft mit `Run_Weapon`, steht mit `Idle_Weapon`.
- Effekte: Schockwelle (Q, Bodenschlag, Staub, Risse, Druckbogen), Schildwurf (E, das Schild verlässt die Hand, springt von Ziel zu Ziel und kehrt zurück), Eiserne Haut (W, Funken bei Treffern), Titanenstoß (R, Erdbeben-Welle: gerade Linie nach vorn mit Felsplatten, Magma-Rissen, Erdfontänen und Beben; Wirkung bleibt der Kreis wie im Prototyp).
- Eigene Sounds ablegen als `godot/assets/sounds/<Name>.wav`: `tank_q`, `tank_e` (Wurf), `tank_e_hit` (je Treffer), `tank_e_back` (Rückkehr), `tank_r`. Ohne diese Dateien spielen noch die einfachen alten Klänge.
- Bildertest: `godot/tools/fxrun.sh q|e|r|look|lookside 3 tank`.

## Damage / Schurke (Stand Meilenstein 6)
- Modell: Quaternius-Schurke mit **zwei Dolchen** (der zweite an der linken Hand, `attach_offhand_dagger`). Auto-Angriff mit kleinem Schnitt am Ziel.
- **Q Wirbel = Dolchfächer:** Schurke dreht sich, ein Kranz Dolche fächert nach allen Seiten bis zum Rand des Kreises (je Rang mehr Dolche).
- **W Kampfrausch:** roter Schein mit Flammen um den Schurken, solange der Rausch anhält. **Flächenschaden (Rang 5, auch Splitteraxt)** ist sichtbar: Druckring am Hauptziel und gekreuzte Schnitte an jedem mitgetroffenen Gegner.
- **E Sprung:** Absprung mit Staub und dunkler Spur, die Figur fliegt im Bogen (Rolle), Landung mit Druckwelle, Rissen, Dolchen im Boden; ab Rang 3 brennt die Landestelle, Rang 5: Betäubungssterne.
- **R (Schwertregen) als Dolchhagel:** violette Warnkreise, Dolche fallen in engen Kreis und bleiben kurz stecken, danach Giftnebel (grün) statt gelbem Feld. Wirkung unverändert (5 Ziele, Kreis 60, Feld 8 s).
- Eigene Sounds ablegen als `godot/assets/sounds/<Name>.wav`: `damage_shot` (Auto-Angriff), `damage_q`, `damage_w`, `damage_e` (Absprung), `damage_e_land` (Landung), `damage_r` (Wurf), `damage_r_hit` (je Dolchsalve). Ohne diese Dateien spielen noch die alten einfachen Klänge.
- Bildertest: `godot/tools/fxrun.sh q|w|wauto|e|r|look|lookside 3 damage`.
