# Phase 2 – Wellen und Monster (Stufe 1)

Gemessen mit Bot-gegen-Bot-Partien in Godot (`--botplay`, 1 gegen 1, beide „Normal“), Stand 16.10.2026. Tune-Dateien in `docs/balancing/tunes/`.

## Kurzfassung

Heute endet eine Partie nach gut 3 Minuten um Welle 8–9. Ursache: Die Monster-Lebenspunkte wachsen sehr schnell mit der Zeit (+35 % pro Minute, nach 10 Minuten also das 4,5-fache), die Wellen werden schnell groß (+1,2 Grunts je Welle, Zusatzmonster schon ab Welle 3, ab Welle 15 alle 3 Wellen mehr), und bei Welle 10 kommen zwei Elites auf einmal. Der Held schafft eine Welle dann nicht mehr, bevor die nächste kommt, und verliert 10–20 Leben auf einen Schlag. Die Lösung: Lebenspunkte nur noch langsam mit der Zeit steigen lassen (+5 bis +8 % pro Minute), Wellen langsamer wachsen lassen, Zusatzmonster sanfter staffeln, nur 1 Elite je Elite-Welle, dazu die vereinbarten neuen Regeln (30 Leben, Wellentakt 25 → 50 s, zwei Bosse, Boss-Pause, 50 Wellen + Endlos-Phase). Damit dauern die Partien im Mittel 22–25 Minuten statt 3; ohne Senden (nur Wellen) wären es 35 Minuten. Was die Partien jetzt beendet, ist vor allem das Senden ab etwa Minute 20 (das Einkommen wächst dann sehr stark) – das ist Sache des Wirtschafts-Helfers.

## Gemeinsame Änderungen (in allen drei Paketen)

| Wert | alt | neu | Warum |
|---|---|---|---|
| Startleben `startLives` | 20 | 30 | vereinbart |
| Wellentakt | 16 s (Welle 1–4), dann 30 s | von 25 s (Welle 1) gleichmäßig auf 50 s (Welle 50) | vereinbart; frühe Wellen schnell, späte mit Luft (`waveEveryStart` 25, `waveEveryEnd` 50, `waveEveryRamp` 50) |
| Bosswellen | nur Welle 20 | Welle 20 und 40, der zweite stärker | vereinbart (`bossWaves` [20, 40], `bossGrow`) |
| Pause nach Bosswelle | – | +35 s (also ca. 70 s bis zur nächsten Welle) | vereinbart, Zeit zum Aufräumen und Einkaufen (`bossPause` 35) |
| Wellenanzahl | unbegrenzt gleich | 50 reguläre Wellen, danach jede Welle 15 % schneller, bis höchstens alle 8 s | vereinbart (`maxWaves` 50, `endlessFactor` 0,85, `endlessMin` 8) |
| Grunts je Welle `wavePer` | +1,2 je Welle | +0,5 je Welle (sanft/mittel), +0,6 (knackig) | Welle 50 hätte sonst 63 Grunts; jetzt 28 bzw. 33 |
| Gemischte Wellen `waveMix` | ab 3: 2 Brocken · ab 6: +1 Brocken +2 Schützen · ab 9: +1/+1/+2 Läufer · ab 12: 2/2/2 | ab 4: 1 Brocken · ab 7: 1 Brocken + 1 Schütze · ab 10: 1/1/1 · ab 14: 2/1/1 · ab 18: 2/2/2 | gleiche Idee, aber sanfter Einstieg; der Sprung bei Welle 12 hat früher viele Partien gekippt |
| Wachstum der Zusatzmonster | ab Welle 15 alle 3 Wellen +1 jeder Sorte | ab Welle 22 alle 4 Wellen +1 jeder Sorte | sonst 14 Brocken + 14 Schützen + 14 Läufer in Welle 50 |
| Elites je Elite-Welle `eliteCount` | 2 | 1 | 2 Elites in Welle 10 (je 3 Leben) waren der häufigste frühe Kipp-Punkt; Elite-Welle alle 10 bleibt |

## Paket „sanft“ – `docs/balancing/tunes/wellen_sanft.json`

Zusätzlich:

| Wert | alt | neu | Warum |
|---|---|---|---|
| Monster-Lebenspunkte pro Minute `hpScalePerMin` | +35 % | +5 % | Monster werden langsam stärker; nach 30 Min. 2,5-fach statt 11,5-fach |
| Boss Lebenspunkte | 1200 | 900 | der erste Boss (Welle 20) hat sonst jede 7. Partie beendet |
| Boss kostet Leben | 10 | 5 | ein durchgelaufener Boss ist ein harter Schlag, aber kein sofortiges Aus |
| Zweiter Boss `bossGrow` | – | 1,6-fach | zweiter Boss klar stärker |

## Paket „mittel“ – `docs/balancing/tunes/wellen_mittel.json`

Zusätzlich: `hpScalePerMin` +6 % (statt +35 %), Boss 1000 Lebenspunkte, kostet 6 Leben, zweiter Boss 1,7-fach.

## Paket „knackig“ – `docs/balancing/tunes/wellen_knackig.json`

Zusätzlich: `hpScalePerMin` +8 %, `wavePer` 0,6, Boss unverändert (1200 Lebenspunkte, 10 Leben), zweiter Boss 1,5-fach.

## Messergebnisse

Je Paket 72 Partien (alle Klassen-Paarungen, je 8×, Normal gegen Normal) plus 40 Partien Schwierigkeitsstufen. Zum Vergleich: heute (nur die neuen Regeln, ohne weitere Änderungen; `wellen_v0_basis.json`) und „sanft ohne Senden“ (Bots schicken keine Monster, zeigt die reine Wellenstärke).

| | heute + neue Regeln | sanft | mittel | knackig | sanft ohne Senden |
|---|---|---|---|---|---|
| Partiedauer Median | 3,4 Min. | **25,2 Min.** | 24,3 Min. | 22,1 Min. | 35,5 Min. |
| Spanne (10 %–90 %) | 2,9–6,3 | 19,3–30,2 | 11,4–29,6 | 8,1–27,1 | 30,3–36,2 |
| Partien unter 15 Min. | 100 % | 10 % | 21 % | 31 % | 0 % |
| Partien 25–40 Min. | 0 % | 51 % | 36 % | 26 % | 100 % |
| Welle bei Spielende (Median) | 9 | 42 | 40 | 38 | 62 |
| Welle 50 erreicht | 0 % | 3 % | 3 % | 1 % | 86 % |
| Leben bei Welle 10 / 20 / 30 / 40 | 10,6 / 0,2 / 0 / 0 | 29,0 / 25,5 / 23,0 / 20,6 | 28,9 / 24,9 / 20,1 / 16,0 | 28,3 / 22,4 / 17,1 / 8,1 | 29,9 / 29,4 / 29,4 / 29,4 |
| Leben bei Welle 50 | 0 | 0,8 | 0,7 | 0,4 | 25,4 |
| Größter Verlust in einer Welle (Mittel je Partie) | 13,5 | 26,7 | 24,7 | 23,2 | 22,3 |
| Einbrüche (≥ 7 Leben in einer Welle) bis Welle 35, je Partie | 3,1 | 0,6 | 0,7 | 0,9 | 0 |
| Schwer gegen Normal (Siege Schwer) | 58 % (Iststand) | 4/8 = 50 % | 3/8 = 38 % | 5/8 = 62 % | – |

Lesehilfe: Leben = Mittel beider Seiten; wer schon verloren hat, zählt mit 0 (deshalb ist Welle 50 fast 0 – kaum eine Partie kommt so weit). Der „größte Verlust“ ist fast immer der Schluss-Einbruch, der die Partie beendet; aussagekräftiger für den Spielverlauf ist die Zeile „Einbrüche bis Welle 35“.

Wo die Leben verloren gehen (sanft): fast nichts bis Welle 11, kleine Verluste um Welle 12–13 (Elite-Welle 10 plus stärkeres Senden der Bots ab Minute 4) und um Welle 21 (Boss), dann ruhig bis Welle ~38, ab Welle 40 deutliche Verluste durch die großen Sende-Pakete und den zweiten Boss.

Klassen-Siegquote (Zeile gegen Spalte, Normal gegen Normal, je 8 Partien – mit Seiten-Vertauschung zusammengenommen):

| | sanft | mittel | knackig |
|---|---|---|---|
| Tank gegen Schurke | 69 % | 88 % | 81 % |
| Tank gegen Magier | 81 % | 81 % | 81 % |
| Schurke gegen Magier | 44 % | 44 % | 44 % |

In langen Partien ist der Tank klar vorn, der Schurke am schwächsten (heute ist es in den kurzen Partien umgekehrt). Das ist Sache des Klassen-Helfers, sollte aber mit der neuen Partielänge gemessen werden.

## Empfehlung

**Paket „sanft“** (`docs/balancing/tunes/wellen_sanft.json`). Es erreicht als einziges den Zielbereich (Median 25 Min., die Hälfte der Partien 25–40 Min.), hat die wenigsten frühen Abbrüche (10 % unter 15 Min.) und den gleichmäßigsten Lebensverlauf (30 → 29 → 25 → 23 → 21 bis Welle 40). Die Wellen werden trotzdem stärker (mehr Monster, gemischte Wellen, Lebenspunkte steigen), und der zweite Boss ist deutlich härter als der erste. Ohne Senden endet eine Partie in der Endlos-Phase nach 30–36 Minuten – genau so soll die Endlos-Phase wirken.

Wichtig: Wie lang eine Partie mit Senden dauert, hängt ab Minute 20 vor allem an der Wirtschaft (Einkommen wächst bis auf 1000–4000 Gold je 10 s, die gesendeten Pakete werden riesig). Wenn der Wirtschafts-Helfer das Einkommen bremst, werden die Partien mit „sanft“ länger und enden häufiger erst in der Endlos-Phase (Obergrenze ca. 36 Min., siehe „ohne Senden“). Falls sie dann zu ruhig wirken, ist „mittel“ der nächste Schritt (Monster +6 % pro Minute statt +5 %).

## Nötige Regeländerungen im Prototyp (index.html)

Diese Mechaniken gibt es bisher nur zum Messen in Godot; sie müssen in `index.html` eingebaut und danach exportiert werden:

1. **Wellentakt-Rampe:** Zeit bis zur nächsten Welle wächst gleichmäßig von `waveEveryStart` (25 s) bei Welle 1 bis `waveEveryEnd` (50 s) bei Welle `waveEveryRamp` (50). Ersetzt `earlyWaves`/`earlyWaveEvery`/`waveEvery`.
2. **Mehrere Bosse:** `bossWaves` als Liste (20, 40) statt eines `bossWave`; jeder weitere Boss hat Lebenspunkte und Schaden × `bossGrow` (1,6) gegenüber dem vorigen. Boss-Einkommen nach jedem Sieg wie bisher.
3. **Boss-Pause:** nach einer Bosswelle zusätzlich `bossPause` (35 s) bis zur nächsten Welle (auch die Warnanzeige „Bosswelle in …“ muss für beide Bosse funktionieren).
4. **Endlos-Phase:** nach Welle `maxWaves` (50) wird der Abstand je Welle mit `endlessFactor` (0,85) multipliziert, höchstens bis `endlessMin` (8 s). Wellen wachsen nach den normalen Regeln weiter. Anzeige „Endlos-Phase“ wäre sinnvoll.
5. Startleben 30 sowie die geänderten Zahlen (`hpScalePerMin`, `wavePer`, `waveMix`, `waveMixGrowFrom/Every`, `eliteCount`, Boss-Werte) sind nur Zahlenänderungen in `CFG`/`UNITS`.

## Auffälligkeiten und Risiken

- **Senden entscheidet die Partien, nicht die Wellen.** Ab etwa Minute 20 wächst das Einkommen der Bots sehr stark (bis 1000–4000 je 10 s) und die gesendeten Pakete (30–60 Monster je Welle, viele Elites) überrollen den Helden. Die Wellen allein kosten bis Welle 40 kaum Leben. Das Ziel „ab Welle 1 ein paar Leben verlieren“ wird mit Senden im frühen Spiel nur schwach erreicht; ohne Senden gar nicht. Das sollte nach dem Wirtschafts-Paket nochmal gemeinsam gemessen werden.
- **Bots senden nach fester Uhrzeit:** Sie werden bei Minute 4 und Minute 10 aggressiver, Elites senden sie ab Minute 8. Diese Zeiten stammen aus den alten 3-Minuten-Partien. Mit dem neuen Takt fällt Minute 10 genau auf die erste Bosswelle (Welle 20) – ein Teil der Einbrüche um Welle 21 kommt daher. Die Grenzen sollten mitwachsen (z. B. an der Welle statt an der Uhr).
- **Schwierigkeitsstufen fast ohne Wirkung:** Schwer gewinnt gegen Normal nur 38–62 % (je 8 Partien, also grob), Ziel ~90 %. Das war schon heute so (58 %) und ändert sich mit den Paketen kaum.
- **Tank stark in langen Partien:** siehe Klassen-Tabelle.
- **Bots kaufen wenig Items** (oft 1–2 Items bei 400+ Gold bis Minute 10). Echte Spieler werden früher stärker; die Partien könnten mit Menschen länger dauern.
- **Werkzeug-Fehler:** `tools/balance/run_matrix.sh` übergibt `TUNE` ohne Anführungszeichen. Liegt die Tune-Datei in einem Pfad mit Leerzeichen (z. B. im Projektordner „Projekt hero lane wars“), wird sie stillschweigend ignoriert. Für die Messungen habe ich Kopien in einem Ordner ohne Leerzeichen benutzt.
- Je Klassen-Paarung nur 8 Partien: Unterschiede unter ~20 Prozentpunkten sind nicht sicher.
