# Phase 2 – Gegenprüfung des Gesamtpakets

Gemessen mit Bot-gegen-Bot-Partien in Godot (`--botplay`, 1 gegen 1), Stand 16.10.2026. Geprüft wird `docs/balancing/tunes/gesamt_v1.json` (= Wellen „sanft“ + Wirtschaft A + Klassen „Tank langsamer plus“ + Stufen „Gold stark“), also alle vier Helfer-Pakete **zusammen**. Insgesamt 8 Messläufe, 1.936 Partien.

## Kurzfassung

**Urteil: mit Korrektur v2 übernehmen** (`docs/balancing/tunes/gesamt_v2.json`).

Das Gesamtpaket funktioniert im Großen: Partien dauern im Mittel 27 Minuten, das Einkommen bleibt bis Minute 30 im Rahmen, die Klassen sind fair, keine Partie hängt fest. Beim Zusammenspiel der Pakete sind aber drei Nebenwirkungen aufgetaucht, die einzeln niemand sehen konnte:

1. **Der aggressive Bot-Stil verliert fast immer** (33 % statt 40–60 %). Grund: Mit dem gebremsten Einkommen (Wirtschaft A) lohnt sich frühes „alles senden“ nicht mehr.
2. **Der Magier fällt oft direkt nach dem ersten Boss** (13 % aller Magier-Partien enden bei Welle 21–23, nach 11 Minuten). Boss und die verstärkten Bot-Sendungen ab Minute 10 kommen gleichzeitig.
3. **Der Tank bricht früh öfter ein** (12 % der Tank-Partien sind bei Welle 14–18 vorbei, nach 7–9 Minuten; mit den Einzelpaketen waren es 4 %). Weniger Einkommen plus langsamere Tank-Fähigkeiten lassen ihn am Anfang zu langsam aufleveln.

Korrektur v2 behebt 1 und 2 vollständig und hebt nebenbei die Schwierigkeitsstufen etwas an (sechs Zahlen, alle leicht erklärbar). Für Punkt 3 habe ich zwei Tank-Korrekturen gemessen; beide machen den Tank später zu stark, deshalb sind sie **nicht** in v2. Der frühe Tank-Einbruch ist mit v2 etwas seltener (9 %), bleibt aber ein offener Punkt für Phase 3.

Zwei Ziele erreicht auch v2 nicht, weil sie keine Frage einzelner Zahlen sind: **Comeback** (wer zur Halbzeit hinten liegt, gewinnt noch ~45 %, Ziel 20–30 %) und **„ab Welle 1 ein paar Leben verlieren“** (die Bots verlieren im Mittel erst ab Welle 44 Leben).

## Ziel gegen Ist

Normal gegen Normal, wenn nicht anders angegeben. v1: großer Lauf (448 Partien) plus Stufen mit beiden Seitenbelegungen (160). v2: Klassen-Block mit 32 Wiederholungen (288 Partien); Stile und Stufen aus den beiden Korrektur-Läufen v2a/v2b, die sich von v2 nur bei einem Tank-Wert unterscheiden (je 144 + 160 Partien).

| Bereich | Ziel | gesamt_v1 | **gesamt_v2** |
|---|---|---|---|
| Partiedauer Median | 25–40 Min. | 26,8 Min. | **27,5 Min.** |
| Partien 25–40 Min. | möglichst viele | 61 % | **69 %** |
| Partien unter 15 Min. (frühe Einbrüche) | wenige | 17 % | **9 %** |
| Spanne 10 %–90 % | | 11,0–34,5 Min. | 18,9–34,7 Min. |
| Längste Partie / Partien über 40 Min. | | 37,8 Min. / 0 % | 37,6 Min. / 0 % |
| Welle 50 erreicht (Endlos-Phase) | | 30 % | 35 % |
| Leben bei Welle 10 / 20 / 30 / 40 / 50 | ab Welle 1 ein paar weg | 29,0 / 24,9 / 23,3 / 21,1 / 15,9 | 29,1 / 26,2 / 25,5 / 23,6 / 17,3 |
| Erste verlorene Leben (Median) | früh | Welle 41 | Welle 44 |
| Einbrüche (≥ 7 Leben in einer Welle) bis Welle 35, je Partie | selten | 1,0 | **0,6** |
| Boss Welle 20: verlorene Leben (Mittel) / Seiten ausgeschieden | | 1,0 / 9 von 554 | **0,4 / 1 von 559** |
| Boss Welle 40: verlorene Leben (Mittel) / Seiten ausgeschieden | | 1,5 / 24 von 487 | 1,8 / 33 von 519 |
| Einkommen je Tick Minute 10 / 20 / 30 (Median) | kein Durchgehen | 75 / 285 / 888 | 74 / 287 / 890 |
| Sende-Pool je Welle, Welle 41–50 (Median / 90 %) | | 25 / 34 | 25 / 34 |
| **Stile** ausgewogen / sparsam / aggressiv (gleiche Klasse beidseitig, je 64) | je 40–60 % | 61 / 56 / **33 %** | **52 / 45 / 53 %** (v2a) · 47 / 52 / 52 % (v2b) |
| **Klassen** Magier–Schurke / Magier–Tank / Schurke–Tank (Siege der Erstgenannten) | je 45–55 % | 50 / 47 / 44 % (je 32) | **50 / 45 / 47 %** (je 64) |
| Schwer gegen Normal (beide Seitenbelegungen) | ~90 % | 91 % (29/32) | **95 %** (61/64) |
| Normal gegen Leicht | ähnlich deutlich | 75 % (24/32) | **81 %** (52/64) |
| Experte gegen Schwer | deutlich | 91 % (29/32) | 91 % (58/64) |
| Comeback (≥ 4 Leben hinten zur Halbzeit, gewinnt) | 20–30 % | 46 % (Spiegel) / 48 % (alle) | 36–43 % (Spiegel) / 50 % (Klassen) |
| Partien ohne Sieger (Hänger) | 0 | 0 | 0 |

Lesehilfe: Quoten mit 32 Partien schwanken um etwa ±9 Prozentpunkte, mit 64 um etwa ±6. Die Bot-Partien sind bei gleichem Startwert weitgehend gleich – Partien ohne Tank lieferten in v2a und v2b exakt dieselben Ergebnisse. Mehr Partien heißt deshalb: mehr verschiedene Startwerte.

Dauer je Klassen-Paarung (v2, je 32–64 Partien): Magier–Magier 26,7 Min., Magier–Schurke 26,8, Magier–Tank 30,7, Schurke–Schurke 26,7, Schurke–Tank 27,5, Tank–Tank 33,7. Keine Paarung bleibt vor der Endlos-Phase stecken: Welle 50 erreichen 17–22 % der Partien ohne Tank, 31–41 % mit einem Tank und 94 % der Tank-Spiegelduelle.

## Gefundene Nebenwirkungen (mit Belegen)

### 1. Aggressiver Stil chancenlos (Wirtschaft × Bot-Stil)
- v1, Stil-Block mit gleicher Klasse auf beiden Seiten: aggressiv gewinnt 21 von 64 (33 %). Das gilt für jede Klasse: Magier 7/20, Schurke 9/24, Tank 5/20.
- Ursache: Der Stil „aggressiv“ legt nur 30 % des Item-Golds zurück und sendet früh 25 % mehr. Mit `incMul` 0,7 bringt Senden nur noch 70 % des alten Einkommens; frühes „alles senden“ zahlt sich erst nach 11 statt 8 Minuten aus. Der Bot hat dann weder Items noch einen Einkommensvorsprung. Der Wirtschafts-Helfer hat nur mit gemischten Klassen gemessen, dort fiel es nicht auf.

### 2. Magier fällt nach dem ersten Boss (Wellen × Bot-Uhr × Klassen)
- v1: 24 von 186 Magier-Seiten (13 %) verlieren bei Welle 20–24, nach etwa 11 Minuten. In 10 davon ist der Boss durchgelaufen. Typischer Verlauf: Bis Welle 20 kein Leben verloren, bei Welle 21 stehen 16 Monster auf der Lane, der Held stirbt, alle 30 Leben gehen in einer Welle verloren (Boss 5 + 25 Monster).
- Ursache: Die Bots senden ab Minute 10 (600 s) deutlich mehr (feste Uhrzeit im Bot). Mit Takt und Boss-Pause fällt Minute 10 genau auf die Bosswelle 20. Der Magier ist dann Level 13 mit 2–3 Items und schafft den Boss (900 × 1,5 Lebenspunkte durch die Zeit-Skalierung) plus die erste große Sendung nicht.
- Mit Korrektur v2 (Boss 1 schwächer): 4 % (8 von 192), Boss läuft nur noch einmal durch.

### 3. Früher Tank-Einbruch (Wirtschaft × Klassen)
- Anteil der Tank-Seiten, die vor Welle 20 verlieren: nur „sanft“ 4 %, „sanft“ + Wirtschaft A 4 %, „sanft“ + Tank-Paket 6–12 %, **Gesamtpaket v1 12 %** (22 von 186). Das sind fast alle Partien unter 10 Minuten.
- Verlauf: Der Tank ist bei Welle 8 erst Level 3,8 (Magier/Schurke 4,7), räumt die Wellen zu langsam, verliert ab Welle 6 laufend Leben (Mittel 24 Leben bei Welle 12), der Gegner nutzt das zum Senden, ein Tod und alles läuft durch (Welle 14–18).
- Ursache: Weniger Einkommen (Wirtschaft A) und seltenere Schockwelle (10 statt 6,5 s, Klassen-Paket) treffen beide den frühen Tank.
- Gemessene Korrekturen (je ca. 290 Partien):

| | v1 | v2a: Tank Grundschaden 22 → 28 | v2b: Schockwelle 10 → 8 s | v2 (ohne Tank-Änderung) |
|---|---|---|---|---|
| Tank vor Welle 20 raus | 12 % | 7,5 % | 8,6 % (3,1 % in zweitem Lauf) | 8,9 % |
| Tank gewinnt gegen Magier / Schurke | 53 / 56 % | 56 / 62 % | 64 / 59 % (je 64) | **55 / 53 %** (je 64) |

  Beide Tank-Hilfen machen den Tank im späten Spiel wieder zu stark (genau das Problem, das der Klassen-Helfer gelöst hatte). v2 lässt den Tank deshalb unverändert.

### 4. Messwerkzeug: Stufen-Block hängt an der Seitenverteilung
- Gleiche Einstellung (v1), gemessen mit dem Block „stufen“ aus `run_matrix.sh`: Schwer gegen Normal 69 %, Normal gegen Leicht 62 %. Mit meinem Skript, das jede Paarung auch mit vertauschten Klassen spielt: 91 % und 75 %. Die Stufen-Zahlen aus dem Werkzeug sind deshalb nur grob; im Werkzeug sollten beide Seitenbelegungen gespielt werden.

### 5. Weitere Beobachtungen
- **Endlos-Phase:** 23 % aller Partien erreichen sie. Sie endet schnell und sicher: im Mittel bei Welle 55, 2–3 Minuten nach Welle 50; längste Partie 37,8 Minuten (Schurke-Spiegel bis Welle 79). Keine Hänger, keine Partie ohne Sieger. Folge: **Partien über 38 Minuten gibt es nicht**, die obere Hälfte des Zielbereichs (35–40 Min.) wird praktisch nie erreicht.
- **Tank-Spiegelduelle enden fast immer in der Endlos-Phase** (94 %, Median 33,7 Min.) – die Partie entscheidet dann nur, wer zuerst in den immer schnelleren Wellen umfällt.
- **Bosse sind milde:** Boss 1 kostet im Mittel 0,4 Leben (v2), Boss 2 1,8 Leben; 6 % der Seiten scheiden bei Boss 2 aus. Kein Boss ist ein „Partie-Ende-Knopf“.
- **Leicht ist nicht zu schwach:** Leicht-Bots, die verlieren, schaffen im Mittel Welle 41; nur 4 von 58 scheitern vor Welle 20. Leicht gegen Leicht endet in 28–31 % unter 15 Minuten (schon in v1 so).
- **Experte gegen Schwer** ist mit 21 Minuten die kürzeste Paarung (90 % unter 25 Minuten) – gewollt, der stärkere Bot überrollt.
- **Einkommen:** Die Klassen- und Stufen-Pakete ändern das Einkommen von Normal nicht; die Werte entsprechen dem Wirtschafts-Bericht (96 / 315 / 920 dort mit Bonus gerechnet, hier ohne den Normal-Bonus ×1,12).

### 6. Ziele, die Zahlen allein nicht erreichen
- **Comeback 36–50 % statt 20–30 %.** Auch mit 8 oder 12 Leben Rückstand zur Halbzeit gewinnt der Zurückliegende noch 35–46 % (Spiegelpartien). Grund: Entschieden wird fast immer durch **einen** Zusammenbruch (Held stirbt, 20–30 Leben auf einmal), Leben-Vorsprung schützt davor kaum. Die Aufhol-Hilfe ist mit höchstens +5 % schon klein; der Wirtschafts-Helfer hatte mit nur 10 Partien 20 % gemessen.
- **Lebensverlust ab Welle 1:** Bis Welle 5 verliert kein Bot ein Leben, die ersten Leben gehen im Mittel bei Welle 44 verloren. Dazwischen kleine Verluste um Welle 6–15 (fast nur der Tank). Die Wellen sind für die Bots am Anfang zu leicht; ob das für Menschen auch gilt, zeigt erst der Spieltest.

## Korrekturvorschlag v2 – `docs/balancing/tunes/gesamt_v2.json`

Wie gesamt_v1, dazu:

| Wert | v1 | **v2** | Warum |
|---|---|---|---|
| Boss Lebenspunkte `units.boss.hp` | 900 | **750** | erster Boss plus Bot-Sendewelle kippte 13 % der Magier-Partien |
| Zweiter Boss `bossGrow` | 1,6 | **1,9** | hält Boss 2 gleich stark (750 × 1,9 ≈ 900 × 1,6) |
| Bot-Stil aggressiv: Rücklage für Items `reserve` | 0,3 | **0,6** | spart wieder etwas für Items |
| Bot-Stil aggressiv: Senden früh `strat[0]` | 1,25 | **1,1** | frühes „alles senden“ lohnt mit `incMul` 0,7 nicht mehr |
| Schwer `goldMul` | 1,6 | **1,8** | gleicht das gebremste Einkommen aus (Abstand zu Normal) |
| Experte `goldMul` | 2,2 | **2,5** | Abstand zu Schwer halten |
| Leicht `heroMul` / `miss` | 0,6 / 0,45 | **0,5 / 0,55** | Normal schlägt Leicht deutlicher |

Ergebnis siehe Tabelle oben: unter 15 Minuten 17 → 9 %, Stile alle 45–53 %, Klassen 45–50 %, Schwer gegen Normal 95 %, Normal gegen Leicht 81 %, Boss 1 fast ohne Ausfälle. Partiedauer, Einkommen und Boss 2 bleiben praktisch gleich.

Hinweis: v2 ist im Klassen-Block direkt gemessen (288 Partien). Stile und Stufen stammen aus den Läufen v2a/v2b, die v2 plus je eine Tank-Änderung enthalten; Partien ohne Tank sind dort mit v2 identisch. Ein kurzer Bestätigungslauf (`BLOCKS="stile stufen"`) nach der Umsetzung im Prototyp ist sinnvoll.

Verworfen: `gesamt_v2a.json` (Tank Grundschaden 28) und `gesamt_v2b.json` (Schockwelle 8 s) – siehe Nebenwirkung 3.

## Was in Phase 3 im Prototyp umgesetzt werden muss

Gesammelt aus allen vier Helfer-Berichten und dieser Prüfung, nach Wichtigkeit.

**Muss (sonst lässt sich das Paket gar nicht übernehmen):**
1. **Wellentakt-Rampe** `waveEveryStart` 25 s → `waveEveryEnd` 50 s bis Welle `waveEveryRamp` 50; ersetzt `earlyWaves`/`earlyWaveEvery`/`waveEvery` (Wellen-Bericht).
2. **Mehrere Bosse** `bossWaves` [20, 40] mit `bossGrow`, Boss-Einkommen nach jedem Sieg (Wellen-Bericht).
3. **Boss-Pause** `bossPause` 35 s nach jeder Bosswelle, Warnanzeige für beide Bosse (Wellen-Bericht).
4. **Endlos-Phase** nach Welle `maxWaves` 50: Abstand × `endlessFactor` 0,85 je Welle bis `endlessMin` 8 s; Anzeige „Endlos-Phase“ (Wellen-Bericht).
5. **Zahlen aus gesamt_v2** in `CFG`, `UNITS`, `HEROES`, Skill-Liste, `DIFF`, Bot-Stile übernehmen. Dabei `CFG.tankQcd` (6,5) und die Abklingzeit der Schockwelle in der Skill-Liste (10) gleich halten – Godot nutzt nur die Skill-Liste (Klassen-Bericht).
6. Danach `daten.json` und Golden-Dateien neu erzeugen, Godot abgleichen, Stile/Stufen bestätigen.

**Sollte (Bots, betrifft die Messung und das Spielgefühl gegen Bots):**
7. **Bot-Sende-Phasen an der Welle statt an der Uhr** (`bot.gd` `send_decision`, Prototyp ebenso): heute Minute 4 / 10, Elites ab Minute 8. Vorschlag: ab Welle 8 / ab Welle 22 (nach Boss 1), Elites ab Welle 15. Ursache von Nebenwirkung 2 (Wirtschafts-, Wellen-, Stufen-Bericht und diese Prüfung).
8. **Früher Tank-Einbruch:** Ursache prüfen (Tank-Bot levelt langsamer, räumt früh zu langsam). Erst nach Punkt 7 neu messen; falls er bleibt, eine Hilfe nur für das frühe Spiel suchen (z. B. Schockwelle mit kürzerer Abklingzeit auf Rang 1–2, längerer auf Rang 5 – braucht Abklingzeit je Rang als Regel).
9. **Bots füllen den Rucksack** nach dem Bauplan und kaufen auch, wenn Monster in der Nähe sind (Stufen-/Item-Bericht). Macht Schwer/Experte stärker, also danach Stufen neu messen.
10. **Bot zieht sich bei wenig Leben zurück und lässt die Lane leer** – häufigster Weg zur Niederlage von Magier/Schurke (Klassen-Bericht); im Spieltest beobachten.

**Kann (Regeln für später, jeweils eigene Messung nötig):**
11. **Abnehmender Ertrag beim Senden** (`incSoft`, K ≈ 250) statt `incMul` 0,7 – stoppt das Zinseszins-Wachstum dauerhaft und erhält das frühe Einkommen (Wirtschafts-Bericht). Könnte auch den frühen Tank-Einbruch mildern.
12. **Aufhol-Hilfe als fester Betrag** auf das Grundeinkommen statt Prozent auf alles (Wirtschafts-Bericht). Für das Comeback-Ziel reicht das allein aber vermutlich nicht (siehe Nebenwirkung 6).
13. **Eiserne Haut ins Regelwerk** (Rüstung/Dornen/Regeneration je Rang, heute fest im Code) – nächster Hebel, falls der Tank zu stark wird (Klassen-Bericht).
14. **`heroMul` auch auf Leben/Normalangriff**, damit sich Stufen auch im Kampf unterscheiden (Stufen-Bericht).
15. **Items** (vor Übernahme gezielt messen): Splitteraxt und Sturmbrecher stärker, Zeitzauberstab +90 → +110 Zauberkraft, Lebensquell-Harnisch +1.000 → +800 Leben (Item-Bericht).

**Werkzeug:**
16. `run_matrix.sh` Block „stufen“: jede Paarung auch mit vertauschten Seiten spielen (Nebenwirkung 4).

## Offene Risiken
- **Comeback-Ziel** bleibt verfehlt (~45 %). Ob das stört, zeigt der Spieltest; Menschen sterben seltener „auf einen Schlag“ als die Bots. Falls nötig: Regeländerung, damit ein Heldentod nicht die ganze Welle durchlässt (z. B. kürzere Wiederbelebung im frühen Spiel).
- **Früher Tank-Einbruch** (9 % der Tank-Partien in v2) – siehe Punkt 8.
- **Kaum Lebensverlust vor Welle 40** bei den Bots; das Ziel „ab Welle 1 ein paar Leben verlieren“ ist eher für Menschen gedacht und im Spieltest zu prüfen.
- **Keine Partie über 38 Minuten**: Die Endlos-Phase beendet alles bei 34–38 Minuten. Wer längere Partien will, müsste `endlessFactor` milder setzen (z. B. 0,9) – nicht gemessen.
- **Bots sind keine Menschen** (kein Kiten, wenig Items); alle Zahlen sind Trends, keine Garantie.
- Die Tank-Klasse reagiert empfindlich: kleine Tank-Hilfen kippen die Duelle schnell auf 60 %+. Jede Tank-Änderung immer mit mindestens 64 Partien je Duell messen.

## Messläufe (Arbeitsordner, nicht im Projekt)
1. v1, alle Blöcke, 16 Wiederholungen (448) – Zusammenfassung in `docs/balancing/gesamt-messung.json`
2. v1, Stufen mit beiden Seiten (160)
3. v2a, Klassen + Stile (288) · 4. v2a, Stufen beide Seiten (160)
5. v2b, Klassen + Stile (288) · 6. v2b, Stufen beide Seiten (160) · 7. v2b, Klassen Startwerte 17–32 (144)
8. v2, Klassen Startwerte 1–32 (288)
