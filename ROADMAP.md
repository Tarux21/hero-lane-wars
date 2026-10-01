# Roadmap Hero Lane Wars

Rolle: Projektmanager (Planung, Abnahme) – Claude setzt um und stellt nach jedem Schritt Feedbackfragen.

## Phase 1 – Browser-Prototyp verbessern (jetzt)
- [x] Testfenster standardmäßig zu (F2 öffnet es), Spielfeld skaliert auf kleine Fenster
- [ ] Einstieg: kurze Einführung für neue Spieler (Ziel, Steuerung, erste Schritte)
- [ ] Snowball-Bremse: Wer weit zurückliegt, bekommt etwas Hilfe (Recherche: Rubber-Banding)
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
