# Neue Helden: Plan (19.10.2026)

Status: **Waldläufer und Druide freigegeben** („passt so fürs Erste“). **Nekromant freigegeben mit Variante N2** (Diener steigen immer aus dem Boden, Kills machen sie nur stärker). Einbau nach der Grafik-Grundlage, vor dem großen Balancing.

Drei neue Helden: **Waldläufer**, **Druide**, **Nekromant**. Alle Zahlen sind Startwerte; im großen Balancing (nach der Grafik-Grundlage) werden sie fein eingestellt. Formeln wie bei den bisherigen Helden: Fähigkeitsschaden = `dmgOf(Grund, je Rang, Rang, Anteil Zauberkraft, Anteil Angriffsschaden)`, Ultimate ab Level 6, Fähigkeiten auf Level 1 mit 50 % Schaden (wie alle Helden).

## Grundwerte im Vergleich

| | Leben (+je Level) | Angriff (+je Level) | Rüstung (+je Level) | Angriffe/s | Reichweite | Tempo | Schaden kommt von |
|---|---|---|---|---|---|---|---|
| Tank | 416 (+60) | 22 (+3,5) | 6,4 (+0,96) | 1,0 | 38 | 175 | Fähigkeiten, Dornen |
| Schurke | 488 (+65) | 26 (+4,5) | 5 (+1,0) | 1,1 | 38 | 195 | Normalangriff, Fähigkeiten |
| Magier | 320 (+45) | 12 (+1,8) | 1 (+0,4) | 0,9 | 230 | 180 | Zauberkraft |
| **Waldläufer** | 340 (+48) | 20 (+3,8) | 2 (+0,6) | 1,15 | 260 | 190 | **Normalangriff** (Fernkampf) |
| **Druide** | 380 (+55) | 16 (+2,4) | 4 (+0,8) | 0,95 | 180 | 180 | Zauberkraft, Team-Hilfe |
| **Nekromant** | 300 (+42) | 14 (+2,0) | 1,5 (+0,5) | 0,9 | 220 | 180 | Zauberkraft, Diener |

## Waldläufer – Fernkämpfer, stark gegen einzelne starke Ziele

Rolle: schießt aus sicherer Entfernung, hält Gegner mit Fallen auf, ist der Spezialist gegen Elites und Bosse. Schwach gegen große Massen (wenig Flächenschaden). Profitiert von Angriffs-Items (Krit, Angriffstempo).

| Taste | Fähigkeit | Wirkung | Abklingzeit |
|---|---|---|---|
| Q | **Durchschuss** | Pfeil in Mausrichtung (Reichweite 500), durchbohrt alle Gegner in der Linie: `dmgOf(30, 14, r, 0, 1.0)`. Rang 3: Getroffene 2 s um 40 % verlangsamt. Rang 5: zwei Pfeile kurz nacheinander. | 7 s |
| W | **Dornenfalle** | Legt eine Falle an die Mausposition (bis 400 entfernt). Das erste Monster löst sie aus: alle im Umkreis 90 sind 1,5 s festgehalten (+0,25 s je Rang) und nehmen `dmgOf(20, 10, r, 0, 0.4)`. Bis zu 2 Fallen gleichzeitig (Rang 3: 3). Rang 5: zusätzlich Gift 4 s. | 12 s |
| E | **Rückwärtssalto** | Springt 180 vom Mauszeiger weg; die nächsten 3 Angriffe +40 % Angriffstempo. Rang 3: lässt Krähenfüße zurück (Verlangsamung im Umkreis 80, 3 s). Rang 5: setzt die Abklingzeit von Durchschuss zurück. | 10 s |
| R | **Jagdbeute** | Markiert das stärkste Monster bis 600 entfernt (Boss > Elite > Rest) für 8 s: es nimmt von allem +50 % Schaden; dazu 3 schwere Schüsse `dmgOf(120, 0, 1, 0, 1.5)` je Schuss auf das Ziel. | 60 s |

Bot: steht hinten, schießt, legt Fallen vor sich, springt weg wenn Monster nah sind, Jagdbeute auf Elite/Boss.

## Druide – Unterstützer, stark im Team

Rolle: hält Monster fest, heilt sich und Mitspieler, stärkt das Team. Allein solide (Wurzeln + eigener Beschützer), im 2v2/4v4 am wertvollsten.

| Taste | Fähigkeit | Wirkung | Abklingzeit |
|---|---|---|---|
| Q | **Rankenheilung** | Ranken um den Druiden (Umkreis 220) für 4 s: heilt ihn und Mitspieler darin um insgesamt 6 % (+2 % je Rang) ihres max. Lebens + 40 % Zauberkraft; Monster darin nehmen `dmgOf(8, 4, r, 0.15, 0)` pro Sekunde. | 12 s |
| W | **Wurzelgriff** | Kreis an der Mausposition (Umkreis 120): nach 0,6 s Vorwarnung werden alle Monster darin 1,2 s festgehalten (+0,2 s je Rang) und nehmen `dmgOf(25, 12, r, 0.5, 0)`. Rang 5: zieht sie zur Mitte. | 11 s |
| E | **Totem des Hains** | Setzt ein Totem für 15 s (Umkreis 300): Mitspieler darin +15 % Angriffstempo (+5 % je Rang) und 1 % Leben/s Regeneration; das Totem schießt Dornen auf Monster: `dmgOf(6, 3, r, 0.1, 0)` pro Sekunde. | 20 s |
| R | **Baumhüter** | Beschwört einen Baumhüter für 45 s (900 Leben): Monster in der Nähe greifen ihn statt dich an; alle 3 s Stampfer im Umkreis 140: `dmgOf(60, 0, 1, 0.6, 0)`. | 90 s |

Bot: bleibt bei Mitspielern, Wurzelgriff auf Gruppen, Rankenheilung bei wenig Leben (eigen oder Mitspieler), Totem vor dem Kampf, Baumhüter bei großen Wellen.

## Nekromant – Beschwörer mit Skelett-Dienern

Rolle: ruft Skelett-Diener aus dem Boden, die für ihn kämpfen; frisch gestorbene Monster in der Nähe machen die Diener stärker. Funktioniert auch ohne Kills (Entscheidung N2). Selbst zerbrechlich.

| Taste | Fähigkeit | Wirkung | Abklingzeit |
|---|---|---|---|
| Q | **Knochensplitter** | Geschoss in Mausrichtung: `dmgOf(28, 12, r, 0.55, 0)` am ersten Ziel. Rang 3: durchbohrt. Rang 5: drei Splitter im Fächer. | 5 s |
| W | **Totenruf** | Immer 2 / 3 / 3 / 4 / 5 Skelettkrieger (je Rang) steigen an der Mausposition aus dem Boden, halten 30 s (Skelettkrieger: Leben 120 + 20 je Level, Schaden 10 + 2 je Level). **Bonus:** Ist in den letzten 4 s im Umkreis 300 ein Borkengolem, Sumpftroll oder Boss gestorben, wird je solcher Leiche ein Krieger zum **Skelett-Hünen** (doppeltes Leben und Schaden, größer). Höchstens 8 Diener gleichzeitig; die ältesten zerfallen zuerst. | 10 s |
| E | **Seelenentzug** | Strahl auf ein Ziel für 2 s: alle 0,25 s `dmgOf(12, 6, r, 0.3, 0)`, heilt den Nekromanten um 50 % des Schadens. Rang 5: springt beim Tod des Ziels auf das nächste über. | 9 s |
| R | **Seelenernte** | Sofort steigen 4 Skelettkrieger auf; danach 10 s lang steht jedes Monster, das im Umkreis 500 stirbt, als Diener auf (insgesamt höchstens 12 Diener); alle Diener +50 % Schaden. Nie wirkungslos, auch ohne Kills. | 70 s |

Bot: hält Abstand, Totenruf vor anrollenden Wellen (bevorzugt nach großen Kills), Seelenentzug bei wenig Leben, Seelenernte bei großen Wellen.

## Was dafür neu gebaut werden muss

- **Verbündete Einheiten** (Diener, Baumhüter, Totem): eine gemeinsame Mechanik, aufgebaut auf dem heutigen Elementar des Magiers. Monster greifen sie an, sie greifen Monster an, sie zählen nicht als Leben.
- **Wirkung auf Mitspieler** (Heilung, Totem): neu, nur im 2v2/4v4 sichtbar.
- **Fallen** (Waldläufer): wie Schadensfelder, aber mit Auslöser.
- Alles im Prototyp (Regeln, Golden-Tests) und 1:1 in Godot, plus Bot-Verhalten für jeden Helden.
- Grafik zunächst Platzhalter (Modelle, Effekte, Symbole kommen mit der neuen Grafik).

## Offene Punkte für die Freigabe

1. Passen Rollen und Fähigkeiten so, oder etwas tauschen?
2. Namen: „Waldläufer“, „Druide“, „Nekromant“ – oder eigene Namen (wie bei den Monstern, z. B. „Dornenläufer“, „Hainhüterin“, „Totenrufer“)?
3. Geschlecht/Aussehen ist Sache der Grafikphase.
