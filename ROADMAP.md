# Roadmap Hero Lane Wars

Rolle: Projektmanager (Planung, Abnahme) – Claude setzt um und stellt nach jedem Schritt Feedbackfragen.

## Phase 1 – Browser-Prototyp verbessern (jetzt)
- [x] Testfenster standardmäßig zu (F2 öffnet es), Spielfeld skaliert auf kleine Fenster
- [x] Einstieg: Kasten „So gewinnst du“ im Startmenü + 5 Einsteiger-Tipps im Spiel (je einmal; Einstellungen → „Tipps erneut zeigen“)
- [x] Aufholhilfe: ab 3 Leben Rückstand +4 % Einkommen je Leben, max. +20 % (HUD zeigt „Aufholhilfe“). Messung `snowball.js`: Bot-Partien snowballen kaum (Führender nach 3 Min gewinnt ~52 %); Balance und Spieldauer unverändert (~15 Min). Die Hilfe ist ein Netz für menschliche Fehler – bitte im Spiel prüfen.
- [ ] Offen aus der Messung: Damage liegt bei 38–42 % Siegquote (Ziel 50 %), vom Balancing-Stand 2161de5 unabhängig von der Aufholhilfe
- [ ] Spielgefühl: Treffer-Feedback, Schadenszahlen, Sounds prüfen
- [ ] Bot-Verhalten und Schwierigkeitsstufen mit der Simulation gegenprüfen

## Phase 2 – Umzug in eine Engine
- Empfehlung: Godot (kostenlos, leicht, gutes 2D, Web-Export). Unity nur, wenn C# und viele Plattformen wichtig sind.
- Regeln und Zahlen (CFG, UNITS, HEROES, ITEM_LIST) bleiben als Datenbasis erhalten.

## Phase 3 – Online 1 gegen 1 (Abschluss)
- Erst nach stabilem Solo-Spiel gegen die KI.

## Quellen der Recherche
- Snowballing und Einkommen in Tower-Wars-Spielen: Hive Workshop, "Tower War, how to do it right"
- Flow und Schwierigkeitskurve im Tower Defense: Diva-Portal "Flow in Tower Defense", Defender's Quest
- Godot vs Unity für Web: cinevva.com Vergleich 2026
