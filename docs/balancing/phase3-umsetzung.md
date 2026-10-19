# Balancing Phase 3: Umsetzung (Stand 19.10.2026)

Entscheidungen: Gesamtpaket v2 übernehmen (1A), Pflichtpunkte plus Bot-Senden nach Welle und alle Sollte-Punkte (2A+C), frühe Wellen härter und Aufholhilfe kleiner, aber nicht zu schwer (3B).

## Was im Prototyp (`index.html`) und in Godot umgesetzt ist

**Regeln (neu, beide Versionen gleich, Golden-Tests decken sie ab):**
- Wellenabstand `waveInterval(n)`: 25 s nach Welle 1, gleichmäßig bis 50 s ab Welle 50 (`waveEveryStart/End/Ramp`), ersetzt `earlyWaves/earlyWaveEvery/waveEvery`.
- Bosswellen `bossWaves [20, 40]`, zweiter Boss ×1,9 (`bossGrow`), je Boss-Kill +50 Gold pro Welle, 35 s Pause nach einer Bosswelle (`bossPause`).
- Endlos-Phase nach Welle 50 (`maxWaves`), Entscheidung des Projektleiters: **Monsterstrom statt Wellen.** Ununterbrochener Strom mit Budget 150 Sende-Kosten pro Sekunde, ×1,35 pro Minute; jedes Monster ×1,10 stärker pro Minute; die Zusammensetzung steigt auf (Pilzling → Pestratte → Dornspinne → Borkengolem → Sumpftroll), ab Minute 6 nur noch Sumpftrolle als „Endboss“. Gesendete Monster laufen sofort los, keine Schübe, keine Bosse. Ziel: schnell einen Sieger finden, nicht überleben. Anzeige „ENDLOS · m:ss“, der Faulbaum leuchtet dauerhaft. (Erste Fassung mit immer kürzeren Wellen ×1,15 ist ersetzt.)
- Startleben 30.

**Zahlen:** alle Werte aus `tunes/gesamt_v2.json`, dazu nach den Phase-3-Messungen:

| Wert | v2 | jetzt | Warum |
|---|---|---|---|
| `hpScalePerMin` | 0,05 | **0,10** | Bots mit vollem Rucksack verloren zwischen Welle 20 und 50 kein Leben mehr |
| `respawnPerLevel` | 2 | **1** | eine einzige Heldentod-Pause ließ oft alle 30 Leben durch (Partien unter 15 Min.) |
| `waveMix` | ab Welle 4 | **ab Welle 2 ein Läufer** | früher Lebensverlust (Ziel „ab Welle 1“) |
| Aufholhilfe | ab 3 Leben, +1 %/Leben, max. 5 % | **ab 4, +1 %, max. 3 %** | Comeback-Ziel 20–30 % |
| `power.tank` | 0,93 | **1,25** | Tank-Ausgleich (siehe offene Punkte) |
| `tankQcd` | 6,5 | **10** | gleich wie die Skill-Liste (Godot nutzt nur die Skill-Liste) |

**Bots (Prototyp und `bot.gd`):**
- Sende-Phasen nach Wellennummer (`botPhaseWaves [8, 22]`), Elites ab Welle 15 (`botEliteWave`) statt nach Uhrzeit.
- Nach dem Bauplan füllt der Bot den Rucksack mit weiteren fertigen Items seiner Klasse (`BOT_FILL`).
- Einkaufen auch mit Monstern in der Nähe, wenn das Gold für das Doppelte reicht.
- Rückzug: Sind Monster nahe der Basis (x < 1500), geht der Bot schon mit 60 % Leben zurück auf die Lane (sonst 90 %).

**Werkzeug:** Stufen-Block in `run_matrix.sh` spielt jede Paarung auf beiden Seiten; `balance_summary.gd` zeigt Lebensverlust bis Welle 5/10/15/20/30, Anteil unter 15 Minuten und frühes Ausscheiden je Klasse. Selbsttest-Fehler behoben: `--selftest` meldete immer „OK“ (Lambda konnte `ok` nicht ändern).

## Bestätigungsmessung (336 Partien, `phase3-messung.json`)

| Ziel | Ergebnis |
|---|---|
| Partiedauer 25–40 Min. | Median 35,3 Min., 7 % unter 15 Min. ✓ |
| Leben verlieren ab Welle 1 | bis Welle 10 im Mittel 2,1 Leben (27 % der Seiten), bis Welle 20 3,8 ✓ |
| Stile ausgewogen | 46–54 % ✓ |
| Schwer schlägt Normal ~90 % | 96 % ✓ (Normal–Leicht 79 %, Experte–Schwer 71 %) |
| Comeback 20–30 % | 37 % (vorher 36–50 %) – näher dran |
| Klassen 45–55 % | Schurke–Magier 50 % ✓, **Tank 21–29 %** ✗ |

## Offene Punkte

- **Tank in der Endlos-Phase zu schwach.** Bis Welle 40 hält der Tank gut mit, entschieden wird aber meist in der Endlos-Phase (Median Welle 60), und dort stirbt der Tank zuerst, weil er Monster am langsamsten tötet. Geprüft ohne Erfolg (je 48 Tank-Duelle): Fähigkeitsschaden 1,1 / 1,25 / 1,6, Schildwurf 10 s, Tank-Bot kauft Gigantenschlag zuerst, Endlos-Stärke nur auf Leben (1,15 und 1,25). Die Werte schwanken bei 48 Partien um ±10 %. Braucht eine Entscheidung (siehe Bericht an den Projektleiter).
- Bot-Partien sind mit gleichem Startwert nicht wiederholbar (bekannt).
- Messungen dauern jetzt länger (Partien ~35 Min. Spielzeit): 336 Partien ≈ 55 Min. bei 12 parallel.

## Nachtrag: Tank-Versuche und Monsterstrom (19.10.2026)

Versuche, die Endlos-Phase früher zu erreichen bzw. den Tank zu stärken (je 48–72 Partien, nur Klassen), haben die Tank-Quote nicht verbessert: Monster-Skalierung 0,12 / 0,14 (mehr frühe Zusammenbrüche, Tank 25–38 %), zweiter Boss ×2,5 / ×3,0 (Tank 13–38 %). Partien enden fast nie zwischen Welle 25 und 50: entweder kippt eine Partie früh durch einen Heldentod, oder beide Bots halten bis zur Endlos-Phase.

Messung mit Monsterstrom (72 Partien, Klassen): Median 37 Min., Entscheidung meist 3–5 Min. nach Welle 50, 11 % unter 15 Min., Comeback 28 %. Klassen: **Schurke dominiert** (gegen Magier 88 %, gegen Tank 69 %), Tank gegen Magier 13 %. Die Endlos-Phase belohnt jetzt Einzelziel-Schaden gegen Golems und Sumpftrolle. Offen: Klassen-Ausgleich für die Elite-Phase (z. B. Prozentschaden für Tank/Magier).

## Nachtrag: Prozentschaden für Tank und Magier (19.10.2026)

Entscheidung A des Projektleiters. Schockwelle (Tank) und Kettenblitz (Magier) treffen ab Rang 4 zusätzlich mit 3 % / 6 % (Rang 4 / 5) der maximalen Lebenspunkte jedes getroffenen Monsters, gegen Bosse halb so viel (`tankQPct`, `casterEPct`, `pctBossMul`).

Messung (je 72 Partien, nur Klassen): Tank gegen Magier vorher 13 %, mit 2/4 % 38 %, **mit 3/6 % 44 %** ✓. Der Schurke gewinnt weiter 75–88 % gegen beide; seinen Fähigkeitsschaden zu senken (1,3 → 1,15 / 1,0) ändert daran nichts (75–81 %), seine Stärke in der Elite-Phase kommt aus dem Normalangriff mit kritischen Treffern. Offen: Schurke im späten Spiel (Normalangriff/Krit) – Entscheidung des Projektleiters nötig.
