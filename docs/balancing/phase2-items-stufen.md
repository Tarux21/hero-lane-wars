# Phase 2 – Schwierigkeitsstufen und Items (Stufe 2)

Gemessen mit Bot-gegen-Bot-Partien in Godot (`--botplay`, 1 gegen 1), Grundlage ist das Wellen-Paket „sanft“ (`wellen_sanft.json`). Stand 16.10.2026. Insgesamt 10 Messreihen, 540 Partien.

## Kurzfassung

Die Stufen lagen mit den neuen langen Partien fast gleichauf (Schwer gegen Normal nur 38 %). Der einzige Hebel, der stark wirkt, ist das **Einkommen** (`goldMul`): Mehr Einkommen heißt mehr Senden, mehr Senden heißt noch mehr Einkommen – das schaukelt sich über 20 Minuten auf. Stärkere Fähigkeiten (`heroMul`), schnellere Reaktion oder früheres Einkaufen bewirken dagegen wenig. Empfehlung ist das Paket **„Gold stark“**: Schwer +60 % Einkommen (statt +30 %), Experte +120 % (statt +50 %), Leicht 25 % weniger Einkommen und schwächere Fähigkeiten. Damit gewinnt Schwer gegen Normal 83–89 %, Normal gegen Leicht 88 %, Experte gegen Schwer 79 %; „Normal“ selbst bleibt unverändert, daher ändert sich die Partiedauer Normal gegen Normal nicht.

## Wichtig zum Lesen der Zahlen

- „Quote“ = Siege der zuerst genannten Stufe. Je Paarung 12 bzw. 24 Partien; Unterschiede unter ~15 Prozentpunkten sind nicht sicher.
- Die Messung verteilt die Klassen ungleich auf die Seiten (die zweite Seite bekommt öfter den Tank, seltener den Magier). Deshalb gewinnt bei **gleicher** Stufe die erste Seite nur 25–35 % (Zeilen „Leicht gegen Leicht“, „Schwer gegen Schwer“). Die echten Stufen-Abstände sind also eher etwas **größer** als in den Tabellen.
- „Normal“ habe ich bewusst nirgends verändert: Die anderen Helfer messen Normal gegen Normal, ihre Zahlen bleiben so gültig.

## Ausgangslage („sanft“, unverändert, 40 Partien)

| Paarung | Quote | Dauer (Median) |
|---|---|---|
| Schwer gegen Normal | 3/8 = 38 % | 25 Min. |
| Normal gegen Leicht | 6/8 = 75 % | 27 Min. |
| Experte gegen Schwer | 4/8 = 50 % | 23 Min. |
| Leicht gegen Leicht / Schwer gegen Schwer | 38 % / 50 % | 25 / 24 Min. |

Warum Schwer nicht besser ist: Schwer und Experte senden viel mehr Monster und haben dadurch mehr Einkommen, kaufen aber **später Items** (bei Welle 20, also Minute 9–10, hat ein Schwer-Bot im Mittel 1,8 Items, ein Leicht-Bot schon 3,5). Der Held ist in der Mitte der Partie schwächer, das frisst den Vorteil auf. `heroMul` stärkt nur den Fähigkeitsschaden, nicht Leben oder Normalangriff, und wirkt deshalb kaum.

## Einzeltests (je 40 Partien)

| Test | Änderung | Schwer–Normal | Normal–Leicht | Experte–Schwer |
|---|---|---|---|---|
| nur Gold | Leicht `goldMul` 0,7 · Schwer 1,6 · Experte 1,9 | **8/8 = 100 %** | 75 % | 75 % |
| nur Held/Verhalten | Leicht `heroMul` 0,6, `miss` 0,45 · Schwer `heroMul` 1,5, `shopGold` 1,0, weniger senden (`strat` 0,45/0,45/0,6) · Experte ähnlich | 50 % | 88 % | 38 % |

Ergebnis: Für die oberen Stufen hilft nur Einkommen. Für „Leicht“ hilft Einkommen kaum (Leicht sendet sowieso fast nichts, sein Einkommen bleibt bei ~25), dort wirken schwächere Fähigkeiten und mehr Fehler.

## Paket 1 „Gold mild“ – `docs/balancing/tunes/stufen_gold.json`

| Wert | alt | neu | Warum |
|---|---|---|---|
| Leicht `goldMul` (Einkommen) | 0,85 | 0,75 | etwas weniger Einkommen |
| Leicht `heroMul` (Fähigkeitsschaden) | 0,75 | 0,6 | schwächere Fähigkeiten |
| Leicht `miss` (Fehlerquote Fähigkeiten) | 0,35 | 0,45 | verfehlt öfter |
| Schwer `goldMul` | 1,3 | 1,45 | mehr Einkommen |
| Experte `goldMul` | 1,5 | 1,7 | mehr Einkommen |

Messung (60 Partien): Schwer–Normal **67 %**, Normal–Leicht **75 %**, Experte–Schwer **67 %**; Dauer Median 24 Min. (Schwer–Normal 25, Normal–Leicht 28, Experte–Schwer 21). Spreizt sichtbar, erreicht das Ziel aber nicht.

## Paket 2 „Mix stark“ – `docs/balancing/tunes/stufen_mix_stark.json`

Gold und stärkerer Held zusammen.

| Wert | alt | neu | Warum |
|---|---|---|---|
| Leicht `goldMul` / `heroMul` / `miss` | 0,85 / 0,75 / 0,35 | 0,75 / 0,6 / 0,45 | wie Paket 1 |
| Leicht `react` (Reaktionszeit, Sek.) | 0,7–1,1 | 0,9–1,4 | reagiert langsamer |
| Schwer `goldMul` / `heroMul` | 1,3 / 1,3 | 1,5 / 1,5 | mehr Einkommen, stärkere Fähigkeiten |
| Schwer `react` | 0,14–0,24 | 0,10–0,18 | reagiert schneller |
| Experte `goldMul` / `heroMul` | 1,5 / 1,5 | 1,8 / 1,8 | |
| Experte `react` | 0,10–0,18 | 0,06–0,12 | |

Messung (60 Partien): Schwer–Normal **75 %**, Normal–Leicht **83 %**, Experte–Schwer **67 %**; Dauer Median 24 Min. (Schwer–Normal 24, Normal–Leicht 27, Experte–Schwer 22). Eine mildere Vorstufe (Schwer Gold 1,4 / Held 1,5, Experte 1,6 / 1,75) ergab 75 % / 92 % / 58 %.

## Paket 3 „Gold stark“ (Empfehlung) – `docs/balancing/tunes/stufen_gold_stark.json`

| Wert | alt | neu | Warum |
|---|---|---|---|
| Leicht `goldMul` | 0,85 | 0,75 | weniger Einkommen |
| Leicht `heroMul` | 0,75 | 0,6 | schwächere Fähigkeiten |
| Leicht `miss` | 0,35 | 0,45 | verfehlt öfter |
| Leicht `react` | 0,7–1,1 s | 0,9–1,4 s | reagiert langsamer |
| Schwer `goldMul` | 1,3 | **1,6** | einziger Hebel, der Schwer deutlich vor Normal bringt |
| Experte `goldMul` | 1,5 | **2,2** | mit 1,9 nur 67 % gegen Schwer, mit 2,2 klar darüber |
| Normal | – | unverändert | Partiedauer Normal gegen Normal bleibt wie bei „sanft“ |

Messung (120 Partien, zwei Durchgänge à 60):

| Paarung | Quote | Dauer (Median) |
|---|---|---|
| Schwer gegen Normal | 20/24 = **83 %** (über alle Messungen mit Schwer-Gold 1,6: 39/44 = **89 %**) | 23 Min. |
| Normal gegen Leicht | 21/24 = **88 %** | 28 Min. |
| Experte gegen Schwer | 19/24 = **79 %** | 19 Min. |
| Leicht gegen Leicht (Vergleich) | 33 % | 31 Min. |
| Schwer gegen Schwer (Vergleich) | 29 % | 22 Min. |

Partiedauer Normal gegen Normal (Klassen-Block, 36 Partien): Median **24,3 Min.**, 10–90 %: 21–30 Min., 36 % der Partien in 25–40 Min., 8 % unter 15 Min. – wie bei „sanft“ (Normal ist unverändert). Das Dauer-Ziel hängt damit weiter an Wellen und Wirtschaft, nicht an diesem Paket.

## Empfehlung

**Paket 3 „Gold stark“.** Es kommt dem Ziel am nächsten (Schwer schlägt Normal in ~85–90 %, Normal schlägt Leicht ~88 %, Experte liegt klar über Schwer), ist leicht zu verstehen (fast nur „wie viel Einkommen bekommt der Bot“) und lässt Normal unangetastet. Nebenwirkung: Partien gegen Schwer/Experte sind etwas kürzer (Experte gegen Schwer 19 Min.), weil der stärkere Bot früher überrollt. Gegen einen menschlichen Spieler dürfte „Schwer“ damit spürbar mehr Druck machen; im Spieltest prüfen, ob es zu hart wird. Feinregler, falls ja: Schwer `goldMul` 1,5 (liegt zwischen Paket 1 und 3).

## Item-Beobachtungen

**Was die Bots kaufen und wann** (Mittel Items im Rucksack; Wellen in Minuten bei Normal gegen Normal: Welle 10 ≈ 4 Min., 20 ≈ 9,5 Min., 30 ≈ 16 Min., 40 ≈ 23 Min.):

| Stufe | Welle 10 | Welle 20 | Welle 30 | Welle 40 | am Ende |
|---|---|---|---|---|---|
| Leicht | 2,0 | 3,5 | 4,2 | 4,1 | 4,1 |
| Normal | 1,6 | 1,8 | 2,6 | 4,1 | 3,9 |
| Schwer | 1,4 | 1,9 | 3,7 | 4,0 | 4,0 |
| Experte | 1,4 | 1,7 | 4,0 | – | 4,3 |

(Paket „Gold stark“; die Zahl bleibt bei ~4, weil Teile zu fertigen Items verschmelzen.)

- **Die Bots sind spät „fertig“ und haben dann nichts mehr zu kaufen.** Fast alle (95–98 %) erreichen das Ende ihres Bauplans (Spezialhut), danach bleiben im Mittel **2 von 6 Plätzen leer**, und das Gold stapelt sich (am Ende Median 1.700 Gold bei Normal, 4.300 bei Schwer, 13.700 bei Experte; Einkommen dann 1.000–6.000 je 10 s). Ein Bauplan kostet nur ~2.500 Gold (ein fertiges Item ~1.000, Hut 600, dazu billige Füllteile). Ein voller Rucksack mit 5 fertigen Items + Hut läge bei ~5.600 Gold.
- **Mitte der Partie kaufen die Bots zu wenig.** Normal hat bei Minute 10 erst ~2 Items, weil fast alles Gold ins Senden geht. Leicht ist dort am besten ausgerüstet, weil es kaum sendet.
- **Preise:** Für die erste Hälfte (bis ~Minute 15) passen die Preise, danach sind sie bedeutungslos, weil das Einkommen explodiert. Das ist vor allem eine Frage der Wirtschaft (Einkommen ab Minute 20) und der fehlenden „späten“ Kaufziele, nicht einzelner Item-Preise.

**Siegquote nach Endausrüstung** (innerhalb derselben Klasse, alle Stufen-Messungen zusammen, ~720 Spieler; Bots wählen den Bauplan zufällig, aber je Startwert oft denselben – daher grob):

| Klasse | Bauweg | Spieler | Siege |
|---|---|---|---|
| Schurke | Mächtige Klinge + Seelentrinker | 118 | 69 % |
| Schurke | Schneide des gefallenen Monarchen | 65 | 78 % |
| Schurke | Sturmbrecher (mit Hut des Wirbelwinds) | 33 | **18 %** |
| Schurke | Splitteraxt (mit Hut des Wirbelwinds) | 35 (inkl. Klassen-Block) | **~11 %** |
| Magier | Seelenreif | 30 | 57 % |
| Magier | Zauberkrone / Quälende Maske | 27 / 26 | 44 % / 50 % |
| Magier | Seelentrinker / Funkenklinge | 54 / 35 | 24 % / 17 % |
| Magier | Zeitzauberstab | 30 | **7 %** |
| Tank | Lebensquell-Harnisch | 52 | **79 %** |
| Tank | Eisernes Bollwerk / Dornenpanzerweste | 48 / 40 | 48 % / 50 % |
| Tank | Gigantenschlag | 80 | 44 % |

Vorschläge (nur wo die Daten deutlich sind; vor Übernahme gezielt nachmessen):

1. **Splitteraxt** und **Sturmbrecher** (Angriffstempo-Wege des Schurken) verlieren klar. Vorschlag: Splitteraxt Rezept 520 → 400 Gold (gesamt 1.000 → 880) oder +60 → +75 Angriffsschaden; Sturmbrecher +48 → +60 Angriffsschaden. Teil der Ursache kann der **Hut des Wirbelwinds** sein (beide Wege enden damit, 11–16 % Siege, gegen 74 % beim Blutroten Hut) – Bots mit Angriffstempo-Bauweg kämpfen evtl. schlechter, das ist nicht sicher ein Item-Problem.
2. **Zeitzauberstab** (Magier) fällt deutlich ab: Vorschlag +90 → +110 Zauberkraft.
3. **Lebensquell-Harnisch** (Tank, +1.000 Leben für 1.100 Gold) ist auffällig stark: Vorschlag +1.000 → +800 Leben. Da der Tank in langen Partien ohnehin vorn liegt (siehe Klassen-Helfer), mit dessen Paket abstimmen.
4. **Nie gekauft** werden Münzbeutel/Händlerkette und Hut des Reisenden (stehen in keinem Bot-Bauplan); Titanenpanzer kam nur 3-mal vor. Darüber sagt die Messung nichts.

## Auffälligkeiten (Bot-Schwächen)

- **Bots füllen den Rucksack nicht** und kaufen nach dem Bauplan nichts mehr (siehe oben). Vorschlag für die Bot-Logik: nach dem Bauplan ein zweites fertiges Item kaufen, bis 6 Plätze voll sind. Das würde vor allem Schwer/Experte (viel ungenutztes Gold) stärker machen und die Stufen zusätzlich spreizen.
- **Bots kaufen nur, wenn kein Monster in der Nähe ist.** Bei großen Sende-Paketen ist die Lane nie leer, dann kommt der Bot lange nicht zum Einkaufen.
- **Senden schadet hohen Stufen in der Mitte der Partie**: Schwer/Experte senden fast alles und sind bis Minute 10 schlechter ausgerüstet als Leicht.
- **`heroMul` wirkt nur auf den Fähigkeitsschaden** (nicht auf Leben, Rüstung, Normalangriff). Für einen Schurken mit Normalangriff-Bauweg bringt „Schwer“ dadurch wenig. Wenn die Stufen sich auch im Kampf (nicht nur im Einkommen) unterscheiden sollen, müsste `heroMul` auch Leben/Normalangriff betreffen – das wäre eine Regeländerung im Prototyp.
- **Sende-Phasen nach fester Uhrzeit** (`strat` gilt ab Minute 4 und 10): passt nicht mehr zu 25-Minuten-Partien (schon im Wellen-Bericht erwähnt).
- **Seitenverteilung der Klassen in der Stufen-Messung** ist ungleich (siehe Lesehilfe). Für genauere Zahlen sollte `run_matrix.sh` jede Stufen-Paarung auch mit vertauschten Seiten spielen.
