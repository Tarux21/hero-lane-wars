# Balancing-Ziele (Phase 0, festgelegt am 16.10.2026)

Diese Sollwerte sind der Maßstab für alle Balancing-Änderungen. Gemessen wird mit Bot-gegen-Bot-Simulationen (Godot, `--botplay`), geprüft am Ende durch eigene Spieltests.

## Zielwerte

| Bereich | Ziel | Messung |
|---|---|---|
| Partiedauer | 1 gegen 1, Normal: **25–40 Minuten** | Spielzeit bis zum Sieg |
| Lebensverlust | **Ab Welle 1 normal**: ein paar durchgekommene Monster gehören dazu, gefährlich wird es erst, wenn eine Welle richtig durchbricht | Leben pro Welle, Verlauf über die Partie |
| Startleben | **30** (heute 20) | Regel |
| Senden | **Ausgewogen**: Einkommen und Druck zugleich; wer nie sendet, fällt wirtschaftlich zurück, wer zu viel sendet, hat zu wenig für Items | Siegquote der Bot-Stile (sparsam / ausgewogen / aggressiv) liegt je zwischen 40 und 60 % |
| Klassen | **Fair: jedes Duell 45–55 %** (Tank, Schurke, Magier) | Siegquote je Paarung, Spiegelduelle ausgenommen |
| Comeback | **Mäßig**: wer klar vorn liegt, gewinnt meist, Drehen ist mit gutem Spiel möglich | Team mit deutlichem Lebensrückstand zur Halbzeit gewinnt noch etwa 20–30 % |
| Schwierigkeit | **Deutliche Stufen**: Bot „Schwer“ schlägt „Normal“ in **~90 %**, „Normal“ schlägt „Leicht“ ähnlich deutlich | Siegquote Stufe gegen Stufe |

## Neue Regeln, die dafür nötig sind (noch nicht umgesetzt)

- **Wellen:** 50 reguläre Wellen. Danach **Endlos-Phase**: Die Wellen kommen immer schneller, bis ein Team fällt (Sudden Death).
- **Wellentakt:** Frühe Wellen schnell (ca. 20–25 s), späte Wellen mit mehr Luft (ca. 45–50 s), weil sie größer sind. **Zusätzlich nach jeder Bosswelle eine längere Pause** (ca. 60 s).
- **Bosse:** Mehrere Bosswellen statt einer (z. B. Welle 20 und 40), jede stärker als die vorige.
- **Startleben:** 30.

Die genauen Zahlen (Takt je Welle, Boss-Wellen, Stärke-Zuwachs) werden in Phase 2 per Simulation bestimmt und als Änderungspakete zur Wahl gestellt.

## Ablauf

1. Phase 0: Ziele festlegen (dieses Dokument)
2. Phase 1: Messwerkzeug (viele Bot-Partien parallel) und Ist-Stand als Übersicht mit Diagrammen
3. Phase 2: vier Helfer untersuchen parallel Wellen/Monster, Wirtschaft/Senden, Klassen/Fähigkeiten, Items; ein Gegenprüfer sucht Nebenwirkungen im Gesamtpaket
4. Phase 3: Paket auswählen, im Prototyp umsetzen, Godot neu abgleichen, Spieltest mit kurzem Fragebogen; wiederholen

Hinweis: Bots spielen anders als Menschen (z. B. kein gezieltes Kiten). Die Simulation findet Ausreißer und Trends, das Feingefühl kommt aus den Spieltests.

## Messwerkzeug (Phase 1)

- Viele Partien: `bash tools/balance/run_matrix.sh <Ausgabeordner> [Wiederholungen=12] [parallel=10]` (336 Partien in ca. 5 Min.).
- Auswertung: `<Godot-Konsole> --headless --path godot -s res://tools/balance_summary.gd -- <Ordner> <Ausgabe.json>`.
- Godot-Flags dafür: `--botplay --sim=5400 --hero= --enemy= --diff= --ediff= --style= --estyle= --seed= --result=pfad.json`.
- Iststand: `docs/balancing/iststand.html` (Übersicht), Zahlen in `docs/balancing/iststand-messung.json`.
