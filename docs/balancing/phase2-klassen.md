# Phase 2 – Klassen und Fähigkeiten (Stufe 2)

Gemessen mit Bot-gegen-Bot-Partien in Godot (`--botplay`, 1 gegen 1, beide „Normal“, zufällige Bot-Stile), Stand 16.10.2026. Grundlage ist überall das Wellen-Paket „sanft“ (`docs/balancing/tunes/wellen_sanft.json`); jede Tune-Datei unten enthält „sanft“ vollständig plus die Klassen-Änderungen.

## Kurzfassung

Mit den langen Partien (ca. 25 Min.) gewinnt der Tank zu oft: 72 % gegen den Schurken, 78 % gegen den Magier (144 Partien). Entschieden wird eine Partie fast immer im späten Spiel, wenn ab Welle 40 riesige Sende-Pakete kommen: Wer dabei stirbt, verliert die ganze Welle und damit die Partie. Der Tank überlebt diese Fluten, weil er die Monster mit Schockwelle und Schildwurf ständig betäubt, zurückstößt und bluten lässt. Magier und Schurke sterben darin. Mein Vorschlag: Tank-Fähigkeiten etwas seltener (Schockwelle 6,5 → 10 s, Schildwurf 10 → 14 s), Magier zäher und etwas stärker, Schurke etwas stärker (Paket „Tank langsamer plus“). Damit liegen alle drei Duelle bei 44–56 %, die Partiedauer bleibt bei 25 Minuten.

## Warum welche Klasse stark oder schwach ist (Iststand mit „sanft“)

Daten: 144 Partien (72 aus Stufe 1, 72 neu), Siegquote Zeile gegen Spalte, Seiten zusammengenommen.

| | Siegquote |
|---|---|
| Tank gegen Schurke | **72 %** (23/32) |
| Tank gegen Magier | **78 %** (25/32) |
| Schurke gegen Magier | 44 % (14/32) |

| | Kills je Partie | Tode je Partie | Level am Ende | Leben bei Welle 10 / 20 / 30 / 40 |
|---|---|---|---|---|
| Tank | 1515 | 0,7 | 14,7 | 27,5 / 20,6 / 20,4 / 19,0 |
| Schurke | 1244 | 0,6 | 14,8 | 30,0 / 29,1 / 27,7 / 23,1 |
| Magier | 1205 | 1,0 | 14,7 | 29,6 / 25,8 / 19,9 / 19,7 |

(Leben: wer schon verloren hat, zählt mit 0.)

- **Wer stirbt, verliert.** In jeder verlorenen Partie von Magier und Schurke ist der Held mindestens einmal gestorben (100 %). Gewinnende Schurken sterben fast nie (6 %). Nach einem Tod laufen 10–30 Monster auf einmal durch.
- **Tank: früh schwach, spät kaum zu knacken.** Der Tank verliert seine Leben früh (Welle 8–16, Level 3–9; er levelt langsamer, ist bei Welle 8 oft erst Level 3–4, die anderen Level 5). Im späten Spiel hält er dagegen 40–90 Monster gleichzeitig auf seiner Lane aus, ohne zu sterben, während Magier und Schurke bei so vielen Monstern zusammenbrechen. Grund sind seine Fähigkeiten gegen Massen: Schockwelle betäubt und stößt alle im Kegel zurück (alle 6,5 s, ab Rang 5 doppelt), Schildwurf lässt 5 Gegner bluten (Schaden in % ihres Lebens, wird also mit den stärkeren Monstern nicht schwächer), dazu Eiserne Haut (+40 Rüstung, 2,5 % Leben/s Regeneration auf Rang 5).
- **Magier: zu zerbrechlich.** Auf Level 15 hat der Magier 708 Leben und 7 Rüstung (Tank 1256 Leben + 60 Rüstung, Schurke 1398 Leben + 19 Rüstung). Er stirbt am häufigsten (1,0 Tode je Partie). Sein Früh-Bonus auf Fähigkeiten (+70 %) ist auf Level 15 ganz weg, also genau dann, wenn die großen Wellen kommen.
- **Schurke: zu wenig Flächenschaden im späten Spiel.** Er überlebt lange (kaum Lebensverlust bis Welle 30), hat aber die wenigsten Kills gegen den Tank und bricht in den großen Fluten zusammen.
- Was **nicht** viel gebracht hat (je 36–48 Partien): Tank-Dornen schwächer (`reflectMul` 0,6), Tank weniger Leben/Rüstung pro Level, mehr Wirbel-Heilung beim Schurken, Magier nur mehr Leben pro Level. Der Tank blieb damit bei 75–92 % gegen mindestens eine Klasse. Was gewirkt hat: **Abklingzeiten der Tank-Fähigkeiten** (gegen den Schurken) und **Magier mehr Leben plus mehr Fähigkeitsschaden zusammen** (gegen den Tank).

## Pakete

Alle Werte: Prototyp `index.html` → `HEROES` (Leben `hp`, Leben pro Level `hpl`), `CFG.power` (Fähigkeitsschaden je Klasse), Skill-Abklingzeiten `cd`. In den Tune-Dateien steht bei den Tank-Skills die ganze Skill-Liste (weil Listen nur komplett ersetzt werden können); geändert ist darin nur `cd`.

### Paket 1 „Tank langsamer plus“ – `docs/balancing/tunes/klassen_tank_langsamer_plus.json` (Empfehlung)

| Wert | alt | neu | Warum |
|---|---|---|---|
| Tank Schockwelle (Q) Abklingzeit | 6,5 s | 10 s | weniger Dauer-Betäubung der Monsterfluten |
| Tank Schildwurf (E) Abklingzeit | 10 s | 14 s | weniger Blutung (Prozent-Schaden) |
| Magier Leben Start | 260 | 320 | stirbt sonst in jeder großen Welle |
| Magier Leben pro Level | 32 | 45 | Level 15: 950 statt 708 Leben |
| Magier Fähigkeitsschaden `power.caster` | 0,95 | 1,10 | gleicht den wegfallenden Früh-Bonus etwas aus |
| Schurke Fähigkeitsschaden `power.damage` | 1,18 | 1,30 | mehr Flächenschaden gegen späte Fluten |

### Paket 2 „Tank langsamer“ – `docs/balancing/tunes/klassen_tank_langsamer.json`

Wie Paket 1, aber **ohne** Schurken-Änderung (`power.damage` bleibt 1,18). Weniger Änderungen, Schurke bleibt etwas schwächer.

### Paket 3 „gemischt“ – `docs/balancing/tunes/klassen_gemischt.json`

| Wert | alt | neu |
|---|---|---|
| Tank Schockwelle / Schildwurf Abklingzeit | 6,5 / 10 s | 10 / 14 s |
| Magier Leben pro Level | 32 | 42 |
| `power.caster` | 0,95 | 1,15 |
| `power.damage` | 1,18 | 1,35 |

### Paket 4 „nur Stärken“ (Tank-Fähigkeiten unverändert) – `docs/balancing/tunes/klassen_staerken.json`

| Wert | alt | neu |
|---|---|---|
| Tank Dornen `reflectMul` | 1,0 | 0,7 |
| Magier Leben / pro Level | 260 / 32 | 320 / 45 |
| `power.caster` | 0,95 | 1,20 |
| `power.damage` | 1,18 | 1,45 |

## Messwerte

Je Paket mindestens `BLOCKS="klassen"` mit 8 Wiederholungen (72 Partien, davon 48 ohne Spiegelduell, also 16 Partien je Duell). Paket 2 und 3 zusätzlich mit 48 weiteren Partien (andere Startwerte) zusammengefasst.

| | Basis „sanft“ | **1 Tank langsamer plus** | 2 Tank langsamer | 3 gemischt | 4 nur Stärken |
|---|---|---|---|---|---|
| Partien je Duell | 32 | 16 | 32 | 32 | 16 |
| Tank gegen Schurke | 72 % | **56 %** | 56 % | 69 % | 62 % |
| Tank gegen Magier | 78 % | **56 %** | 62 % | 44 % | 69 % |
| Schurke gegen Magier | 44 % | **44 %** | 44 % | 34 % | 38 % |
| Partiedauer Median | 25,2 Min. | 25,2 Min. | 25,5 Min. | 25,2 Min. | 25,3 Min. |
| Spanne 10–90 % | 12,0–30,3 | 13,7–29,7 | 20,6–29,9 | 13,3–29,6 | 10,9–30,3 |
| Partien 25–40 Min. | 51 % | 56 % | 60 % | 50 % | 61 % |
| Tode Magier je Partie | 1,0 | 0,7 | 0,6 | 0,7 | 0,6 |

Lesehilfe: Bei 16 Partien je Duell schwankt eine Quote zufällig um etwa ±12 Prozentpunkte, bei 32 um etwa ±9. Ein Ergebnis von 56 % ist also vom Ziel 45–55 % nicht unterscheidbar; 72–78 % (Basis) dagegen klar zu hoch. Dieselbe Einstellung kann zweimal gemessen deutlich anders aussehen (Paket 3: erst 62/50/44, dann 75/38/25).

## Empfehlung

**Paket 1 „Tank langsamer plus“** (`docs/balancing/tunes/klassen_tank_langsamer_plus.json`). Es hat als einziges alle drei Duelle im Bereich 44–56 % und ändert nur sechs gut verständliche Zahlen. Die Klassen bleiben erkennbar: Der Tank ist weiter der zäheste und kontrolliert Massen, nur nicht mehr im Dauertakt; der Schurke macht mehr Schaden; der Magier ist weiter der zerbrechlichste, stirbt aber nicht mehr in jeder großen Welle. Die Partiedauer ändert sich nicht.

Falls weniger Änderungen gewünscht: Paket 2 (ohne Schurken-Stärkung), dort liegt der Tank noch etwas vorn (56–62 %).

Wichtig: Wenn der Wirtschafts-Helfer das späte Einkommen bremst, werden die späten Monsterfluten kleiner. Genau dort war der Tank stark; der Vorteil des Tanks dürfte dann von selbst etwas sinken. Deshalb nach dem Gesamtpaket noch einmal messen, möglichst mit 200+ Partien (z. B. `BLOCKS="klassen"`, Wiederholungen 24).

## Auffälligkeiten

- **Die Bot-Partien sind nicht wiederholbar:** Gleicher Startwert und gleiche Einstellung ergeben nicht dieselbe Partie (Sieger und Dauer weichen ab). Darum sind viele Partien nötig; die Golden-Tests sind davon nicht betroffen (andere Modi).
- **Bots ziehen sich bei wenig Leben zurück** und laufen zur Basis. Die Lane ist dann leer und alles läuft durch. Für Magier und Schurke ist das der häufigste Weg zur Niederlage; ein Mensch würde eher kiten oder einen Trank nehmen.
- **Bots kiten nicht:** Der Magier-Bot greift aus seiner Reichweite an, weicht aber vor heranlaufenden Monstern nicht zurück. Echte Spieler werden mit dem Magier vermutlich besser abschneiden als der Bot.
- **Tank-Bot kauft billig** (Stoff, Rubin), kommt trotzdem gut zurecht – seine Stärke kommt fast ganz aus den Fähigkeiten.
- **Eiserne Haut ist nicht über das Regelwerk einstellbar:** Rüstung, Dornen und Regeneration je Rang stehen fest im Code (`IRON` in `godot/scripts/skills.gd`, im Prototyp ebenso). Falls der Tank nach dem Gesamtpaket noch zu stark ist, wäre Rang 5 (40 Rüstung, 2,5 %/s Regeneration) der nächste Hebel; dazu müssten diese Werte ins Regelwerk.
- `CFG.tankQcd` (6,5) wird in Godot nicht benutzt; die Abklingzeit der Schockwelle steht in der Skill-Liste. Beim Umsetzen im Prototyp prüfen, welcher Wert dort gilt, und beide gleich halten.
- `reflectMul` (Paket 4) wirkt auch auf Dornen-Items aller Klassen.
- Bei der ersten Messung lief ein abgebrochener Durchlauf im Hintergrund weiter; seine 72 Partien (Basis „sanft“) sind gültig und in der Basis-Spalte mitgezählt.
