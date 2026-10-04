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
