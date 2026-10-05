# Mein Fortschritt

## Ausgangslage (Schritt 0, 2026-10-04)

- **Spiel:** Hero Lane Wars, zwei Versionen. Browser-Prototyp `index.html` (Regeln und Balance, die Referenz) und 3D-Version in `godot/` (Godot 4.7, GDScript). Rund 120 Commits.
- **CLAUDE.md:** keine, weder im Projekt noch global (`~/.claude/CLAUDE.md`). Dafür ausführliche `README.md`, `godot/README.md`, `ROADMAP.md`, `docs/`.
- **Tests:** ja, umfangreich. `Alle-Tests.bat` startet 6 Prüfungen ohne Fenster (Golden-Vergleiche mit dem Prototyp: Skills 205, Wirtschaft 4339, Boss 32; Selbsttests Shop und Karte; Bot-gegen-Bot-Partie). Stand in `docs/Teststand.md`, Vergleichswerte in `regelwerk/`.
- **Start-Skripte:** `Godot-Spiel-starten*.bat` (1v1, 2v2, 4v4), `Godot-Editor-oeffnen.bat`, `serve.ps1` (Browser-Version auf Port 8123, auch in `.claude/launch.json`), `build-testversion.ps1`.
- **Skills im Projekt:** keine (außer diesem Coach). **Global** in `~/.claude/skills/`: Matt Pococks Sammlung, u. a. `teach`, `tdd`, `grilling`, `codebase-design`, `git-guardrails-claude-code`.
- **Hooks:** keine. **Rechte-Regeln:** keine (globale settings.json hat nur `enableWorkflows`).
- **Gedächtnis-Notizen** von Claude: „erst 2–3 Vorschläge zeigen, dann umsetzen“, „Item-Icons als Code-Prototyp“.
- **Kandidaten „gibt es schon“:** Tests (Level 2) und Start-/Prüfskripte (Level 4, Schritt A) erklären und verbessern statt neu bauen.

## Verlauf

- 2026-10-04 · Schritt 0 · Bestandsaufnahme gemacht. Offen: Output-Style Explanatory einstellen, /teach (ist schon installiert).
- 2026-10-04 · Schritt 0 · Output-Style Explanatory in `.claude/settings.local.json` eingetragen (gilt ab neuer Sitzung). /teach ist da, Lernordner z. B. `C:\Users\kipps\Lernen`. Nächster Schritt: Level 1, erstes Video.
- 2026-10-04 · Level 1 · Video 1 (Claude Code 101) gesehen. Gelernt: Agent = Modell in einer Schleife (Werkzeug nutzen, Ergebnis lesen, weiter); CLAUDE.md = kurzer Spickzettel, nicht das ganze Projekt, wächst aus Korrekturen; Commit = Speicherpunkt, geprüft wird davor; /clear bei neuer Aufgabe; Hook = wird sicher ausgeführt, Regel = Bitte. Arbeitsweise mit Urteil → CLAUDE.md, mechanische Prüfung → Hook. Nächster Schritt: Video 2.
- 2026-10-05 · Level 1 · Video 2 (Every Claude Code Concept) gesehen. Gelernt: Skill = Anleitung für bestimmte Aufgaben (z. B. /coach), Subagent = Helfer mit leerem Kopf, liefert nur Zusammenfassung zurück (spart Kontext, frischer Blick), MCP = Anschluss an externe Programme, Hook = steht in settings.json und wird sicher ausgeführt (nicht in CLAUDE.md). Verwechselt und geklärt: Gedächtnis-Notizen (von Claude) ≠ CLAUDE.md (von mir). Nächster Schritt: Quest.
- 2026-10-05 · Level 1 · Quest Teil 1: Modell (Opus 5.5) und Aufwand (mittel) nachgesehen. Gelernt: Modell = wer denkt, Effort = wie lange; high bei Aufgaben über viele Teile; lange Sitzungen kosten Kontingent und Qualität. Offen: /usage einmal anschauen. Nächster Schritt: CLAUDE.md mit /init.
- 2026-10-05 · Level 1 · Quest Teil 2: CLAUDE.md mit /init angelegt und durchgegangen (Projekt/Referenz, Starten, Testen einzeln vs. alle, Stolperfallen). Gelernt: Referenz-Satz schützt vor Änderung an der falschen Version; einzelne Tests beim Bauen, alle vor dem Commit; deterministischer Zufall (Kartenstapel) – Optik braucht eigenen RNG. Meine 3 Regeln eingetragen: Varianten zeigen, selbst prüfen, Fragen gesammelt am Anfang. Nächster Schritt: potetos Prompt, dann Feature mit Plan-Modus.
- 2026-10-05 · Level 1 · Quest Teil 3: potetos Prompt benutzt, Feature „Level-Aufstieg sichtbar“ im Plan-Modus mit Erfolgskriterium geplant (Explore-Subagent), 3 Varianten als Testbilder, ich habe C (Runenkreis) gewählt; Plus-Knopf pulsiert golden. Gegner-Effekt bleibt im Nebel → Prüfung mit Mitspieler im 2v2. Alle 6 Tests ok. Aufgefallen: Bot-Partien enden schon nach ~5 Min (auch ohne die Änderung), Teststand.md sagt ~15 Min – offen. Nächster Schritt: Commit, dann Level-Abschluss.
- 2026-10-05 · **Level 1 geschafft.** Commit 8b2a6ff (CLAUDE.md + Level-Aufstieg). Sechs Begriffe in eigenen Worten erklärt; ergänzt: CLAUDE.md wird automatisch geladen, Hook führt Claude Code aus (nicht Claude), Plan-Modus ist feste Sperre. `lernen/mein-setup.md` angelegt. Offen (eigenes Thema): Bot-Partien ~5 statt ~15 Min. Nächster Schritt: /clear, dann /coach → Level 2, erstes Video.
