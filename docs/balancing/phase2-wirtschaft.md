# Phase 2 – Wirtschaft und Senden (Stufe 2)

Gemessen mit Bot-gegen-Bot-Partien in Godot (`--botplay`, 1 gegen 1, beide „Normal“), Stand 16.10.2026. Grundlage ist das Wellen-Paket „sanft“ (`tunes/wellen_sanft.json`); jede Tune-Datei unten enthält „sanft“ vollständig plus die Änderungen.

## Kurzfassung

Das Einkommen wächst heute exponentiell: Jedes gesendete Monster bringt dauerhaft etwa 2 % seines Preises pro Einkommens-Tick (10 s) zurück, und die Bots stecken fast ihr ganzes Gold wieder ins Senden. Damit verdoppelt sich das Einkommen etwa alle 5 Minuten (150 → 700 → 2500 Gold je Tick bei Minute 10/20/30). Zweiter Befund: Die Aufhol-Hilfe (bis +20 % Einkommen bei Lebensrückstand) wirkt in dieser Zinseszins-Wirtschaft viel zu stark – wer zur Halbzeit hinten liegt, gewinnt in Spiegelpartien 80 % (Ziel 20–30 %). Empfehlung: **Paket A** – Einkommen aus Senden auf 70 % (`incMul` 0,7) und Aufhol-Hilfe auf höchstens +5 %. Das senkt das Einkommen bei Minute 30 auf etwa ein Drittel (≈ 920), halbiert die Sende-Pakete in Welle 41–50, bringt die Aufhol-Quote in Spiegelpartien auf 20 % und bestraft sowohl „nie senden“ als auch „alles senden“. Dauerhaft zähmt das Wachstum aber erst eine Regeländerung (abnehmender Ertrag beim Senden, siehe unten).

## Die drei Pakete

### Paket A „Bremse 70 %“ – `docs/balancing/tunes/wirtschaft_a.json` (Empfehlung)

| Wert | alt | neu | Warum |
|---|---|---|---|
| Einkommen aus Senden `incMul` | 1,0 | **0,7** | Jedes Monster bringt 70 % des bisherigen Einkommens-Zuwachses; ein Grunt zahlt sich nach ca. 11 statt 8 Minuten aus. Senden lohnt weiter, das Wachstum ist aber deutlich langsamer. |
| Aufhol-Hilfe je Leben Rückstand `comebackPerLife` | 4 % | **1 %** | Die Hilfe wirkt auf das ganze Einkommen und verzinst sich über das Senden – ein kleiner Bonus reicht. |
| Aufhol-Hilfe höchstens `comebackCap` | 20 % | **5 %** | wie oben; +20 % entschied heute fast jede Partie zugunsten des Zurückliegenden. |

### Paket B „Bremse 80 %“ – `docs/balancing/tunes/wirtschaft_b.json`

Wie A, aber `incMul` **0,8** (statt 0,7). Etwas mehr Druck und Einkommen, Aufhol-Hilfe gleich (1 % je Leben, höchstens 5 %).

### Paket C „Teure Monster = Druck“ – `docs/balancing/tunes/wirtschaft_c.json`

Wie B (`incMul` 0,8, Aufhol-Hilfe 1 %/5 %), zusätzlich:

| Wert | alt | neu | Warum |
|---|---|---|---|
| Brocken Einkommen `units.tank.inc` | 4,7 | **3,8** | teure Monster sind eher Druck als Geldanlage |
| Elite Einkommen `units.elite.inc` | 15 | **9** | Elites (ab Minute 8 gesendet) trieben das späte Einkommen am stärksten |

Grunts, Schützen und Läufer bleiben die „Geldanlage“; späte, teure Monster bringen weniger Einkommen.

## Messwerte

Je Paket 108 Partien (Bot-Stile 9 Paarungen × 6, Klassen 9 Paarungen × 6). Vergleich „heute (sanft)“: Klassen aus Stufe 1 (72 Partien), Stile 36 Partien. Zusätzlich je Paket 30 **Spiegelpartien** (beide Helden gleiche Klasse, Seiten getauscht, mit den Test-Stilen „nie senden“ und „alles senden“) – siehe Auffälligkeiten, warum das nötig war.

| | heute (sanft) | **A (0,7)** | B (0,8) | C (0,8 + Druck-Monster) |
|---|---|---|---|---|
| **Einkommen je Tick** (Median, Minute 10 / 20 / 30) | 147 / 680 / 2500 | **96 / 315 / 920** | 109 / 406 / 1370 | 108 / 386 / 1120 |
| Höchstwert bei Minute 30 | 4565 | 1110 | 1610 | 1360 |
| **Sende-Pool je Welle** (Median / 90 %), Welle 21–30 | 9 / 14 | 7 / 10 | 7 / 11 | 7 / 11 |
| Welle 31–40 | 19 / 28 | 12 / 16 | 14 / 19 | 14 / 18 |
| Welle 41–50 | 44 / 61 | 24 / 34 | 31 / 43 | 28 / 40 |
| **Partiedauer** Klassen-Block: Median (10 %–90 %) | 25,2 (19,3–30,2) | 26,7 (11,3–35,0) | 26,3 (11,0–34,1) | 26,7 (11,0–35,0) |
| Partien 25–40 Min. (Klassen / Stile) | 51 % / 38 % | 57 % / 70 % | 66 % / 72 % | 62 % / 75 % |
| Partien unter 15 Min. (Klassen) | 10 % | 20 % | 14 % | 14 % |
| Alle Partien: Median, Welle bei Ende | 25,2 Min., Welle 42 | 27,5 Min., Welle 45 | 26,3 Min., Welle 43 | 26,7 Min., Welle 44 |
| **Stil-Siegquote** ausgewogen / aggressiv / sparsam (je 24 Partien gegen die anderen) | 62 / 44 / 44 % (je 16) | 62 / 42 / 46 % | 58 / 42 / 50 % | 62 / 42 / 46 % |
| Spiegelpartien: ausgewogen gegen „nie senden“ | 6 : 0 | **6 : 0** | 3 : 3 | 4 : 2 |
| Spiegelpartien: ausgewogen gegen „alles senden“ | 3 : 3 | **5 : 1** | 6 : 0 | 5 : 1 |
| Spiegelpartien ausgewogen/aggressiv/sparsam untereinander | 1:5, 3:3, 3:3 | 3:3, 3:3, 3:3 | 3:3, 2:4, 3:3 | 4:2, 5:1, 3:3 |
| **Comeback** (≥ 4 Leben hinten zur Halbzeit, gewinnt trotzdem) – Spiegelpartien | 12/15 = 80 % | **2/10 = 20 %** | 4/9 = 44 % | 4/9 = 44 % |
| Comeback – alle Partien (Auswertungs-Werkzeug) | 63 % | 52 % | 58 % | 55 % |

Lesehilfe: Einkommen ist der Grundwert ohne den Schwierigkeits-Bonus (Normal-Bots bekommen ×1,12). Die Stil-Quoten mit 24 Partien schwanken um etwa ±10 Prozentpunkte; die Spiegelpaarungen (je 6 Partien) zeigen nur Richtungen. Die Comeback-Zahl „alle Partien“ ist stark von den Klassen verzerrt (siehe unten), aussagekräftig ist die Spiegel-Zeile.

## Empfehlung

**Paket A** (`docs/balancing/tunes/wirtschaft_a.json`): nur drei Zahlen, und es erfüllt am meisten Ziele zugleich:
- Kein Einkommens-Durchgehen mehr bis Minute 30 (920 statt 2500, Ausreißer 1100 statt 4500), Sende-Pakete in Welle 41–50 etwa halb so groß.
- Senden ist „ausgewogen“: Wer nie sendet, verliert (6:0); wer alles sendet und keine Items kauft, verliert meist (1:5); die drei normalen Stile liegen in Spiegelpartien gleichauf, im großen Block bei 42–62 % (ausgewogen knapp über dem Ziel, im Rahmen der Messunsicherheit).
- Comeback in Spiegelpartien 20 % (Ziel 20–30 %).
- Dauer: Median 27,5 Min.; 63 % der Partien im Zielbereich (heute 51 %/38 %).

B ist die Alternative mit mehr Tempo und etwas besser verteilten Stil-Quoten, aber „nie senden“ ist dort nicht mehr klar im Nachteil (3:3) und das Comeback liegt höher (44 %). C liegt zwischen A und B, ist aber schwerer zu erklären und bringt gegenüber A keinen Vorteil.

## Nötige Regel- und Bot-Änderungen (Vorschläge)

Zahlen allein bremsen das Wachstum nur, sie stoppen es nicht: Auch mit Paket A verdreifacht sich das Einkommen noch alle 10 Minuten (Zinseszins, weil jedes Senden dauerhaft Einkommen bringt). Dafür schlage ich vor:

1. **Abnehmender Ertrag beim Senden** (Regel, `send` in `index.html`/`game.gd`): Der Einkommens-Zuwachs eines gesendeten Monsters wird mit `K / (K + Sende-Einkommen)` multipliziert, wobei „Sende-Einkommen“ = aktuelles Einkommen minus `baseIncome` ist (neuer Wert `incSoft`, Vorschlag K = 250). Früh (wenig Einkommen) wirkt Senden fast wie heute, spät bringt es vor allem Druck. Grobe Hochrechnung mit den Messwerten (ohne `incMul`-Kürzung): Einkommen bei Minute 10/20/30 ≈ 105 / 290 / 550 statt 147 / 680 / 2500 – also früh fast unverändert, spät deutlich flacher als Paket A. Mit dieser Regel könnte `incMul` wieder 1,0 sein. Anzeige: Der Sende-Knopf sollte den tatsächlichen Zuwachs zeigen (z. B. „+1,2“ statt „+1,9“).
2. **Aufhol-Hilfe nicht als Prozent des ganzen Einkommens** (Regel, `comeback_bonus`): Heute multipliziert sie auch das Sende-Einkommen und verzinst sich. Besser: fester Betrag nur auf das Grund-Einkommen (z. B. +2 Gold je Tick je Leben Rückstand ab 3 Leben, höchstens +20). Paket A nähert das mit 1 %/höchstens 5 % an.
3. **Bot-Sende-Phasen an der Welle statt an der Uhr** (Bot, `bot.gd` `send_decision`/`send_weights`): Phasen heute bei 240 s und 600 s, Elites ab 480 s. Vorschlag: Phase 1 ab Welle 8, Phase 2 ab Welle 22 (nach dem ersten Boss), Elites ab Welle 15. Heute fällt der Wechsel auf Phase 2 genau auf die Bosswelle 20. Das lässt sich mit Tune-Werten nicht nachbilden, deshalb nicht gemessen.
4. **Bot-Stil „sparsam“ ist kein Wirtschafts-Stil**: In diesem Spiel *ist* Senden die Wirtschaft; „sparsam“ sendet früh weniger und kauft trotzdem kaum Items. Damit die Stile sich wirklich unterscheiden, müssten die Bots ihr gespartes Gold in Items stecken (Sache des Item-Helfers).

## Auffälligkeiten

- **Die Klasse entscheidet die Stil-Messung, nicht der Stil.** Im Block „stile“ hat jede Wiederholung feste Klassen (z. B. Wiederholung 1: Schurke gegen Tank). In allen 4 Messungen gewann bei Klassen-Ungleichheit fast immer der Tank – egal welcher Stil (z. B. Wiederholung 1–3: 27 von 27 Partien an dieselbe Seite). Die 40–60 %-Quoten im Block „stile“ sind deshalb zum Teil Zufall der Klassen-Verteilung. Für saubere Stil-Messungen habe ich Spiegelpartien (gleiche Klasse, Seiten getauscht) mit einem eigenen Skript im Arbeitsordner gefahren; das sollte ins Messwerkzeug übernommen werden (Block „stile“ mit `--enemy=<gleiche Klasse>`).
- **Die Comeback-Quote im Werkzeug ist ebenfalls klassen-verzerrt:** Der Tank verliert früh Leben und gewinnt spät. Heute (sanft) 63 % – auch in Spiegelpartien 80 %, dort wegen der +20 %-Aufhol-Hilfe.
- **Frühe Einbrüche (7–13 Min.)**: In 14–20 % der Klassen-Partien bricht ein Held um Welle 15–25 plötzlich von 30 auf 0 Leben ein (Held stirbt, alles läuft durch). Mit weniger Einkommen ist das etwas häufiger als in Stufe 1 (11 % bei denselben Wiederholungen); vermutlich weil die Bots früher etwas weniger Gold haben. Die Regel „abnehmender Ertrag“ (Punkt 1) würde das frühe Einkommen erhalten.
- **Der Tank ist in langen Partien klar vorn** (gegen Magier 83–100 %, gegen Schurke 67–75 %) – unverändert durch die Wirtschafts-Pakete; Sache des Klassen-Helfers.
- **Bots kaufen kaum Items** (am Ende meist 4–5 Gegenstände, oft mit 300–2000 Gold auf dem Konto). Deshalb ist der Item-Nachteil von „alles senden“ in der Simulation kleiner als bei echten Spielern.
- Mit den Paketen enden mehr Partien erst in der Endlos-Phase (A: 11 % über 35 Min.); die Obergrenze bleibt durch die Endlos-Phase bei etwa 36 Minuten.
- Messaufwand: 11 Messläufe (u. a. `incMul` 0,5 als Gegenprobe: Einkommen 70/185/430, aber Senden zahlt sich erst nach ca. 14 Min. aus – zu schwach, verworfen; nur Druck-Monster ohne `incMul`: kaum Wirkung, weil die Bots meist billige Monster senden).
