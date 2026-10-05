# Mein Setup

Was ich eingebaut oder eingestellt habe, wo es liegt, wozu es da ist und wie ich es benutze.

## Level 1 · Commis

### Output-Style „Explanatory“
- **Wo:** `.claude/settings.local.json` (nur für mich, nicht im Git).
- **Wozu:** Claude erklärt bei jeder Änderung in kurzen „Insight“-Kästen, warum es so gemacht wird.
- **Benutzen:** läuft von selbst in jeder Sitzung dieses Projekts.

### CLAUDE.md
- **Wo:** `CLAUDE.md` im Projektordner (im Git).
- **Wozu:** Spickzettel, den Claude in jeder Sitzung automatisch liest: was das Spiel ist, wie man startet und testet, Stolperfallen, meine 3 Regeln.
- **Meine 3 Regeln:** 1. erst 2–3 Varianten zeigen, dann umsetzen · 2. vor „fertig“ selbst prüfen (Tests grün, Bild angeschaut) · 3. Fragen gesammelt am Anfang stellen, nicht selbst entscheiden.
- **Benutzen:** wächst aus Korrekturen. Sage ich Claude zweimal dasselbe, kommt es rein. Kurz halten.

### Modi
- **Manual:** Claude fragt vor jeder Dateiänderung. So arbeite ich beim Lernen.
- **Plan:** Claude darf nur lesen und zeigt einen Plan mit Erfolgskriterium. Freigeben mit „Yes, manually approve edits“.
- **Auto:** Claude arbeitet allein. Erst später.
- **Wo:** Modus-Auswahl neben dem Senden-Knopf.

### Modell und Aufwand
- Opus 5.5, Aufwand „mittel“. „Hoch“ nur bei Aufgaben über viele Teile. Verbrauch mit `/usage`.

### Arbeitsweise
- **Explore → Plan → Code → Commit.** Geprüft wird vor dem Commit, der Commit ist nur der Speicherpunkt.
- **potetos Prompt** vor größeren Sachen: „restate in your own words what you think my goals are and what the problem I'm trying to solve is“.
- **/clear** am Ende jeder Aufgabe oder jedes Levels: Der Speicher wird geleert, und der Stand bleibt in Dateien.

### Begriffe in einem Satz
- **Kontext:** der Speicher der Sitzung; wird er voll, vergisst Claude Früheres.
- **Skill:** Anleitung für eine bestimmte Aufgabe (z. B. `/coach`).
- **Subagent:** Helfer mit leerem Kopf, der eine Teilaufgabe erledigt und nur eine Zusammenfassung zurückgibt.
- **Hook:** kleines Programm, das Claude Code (nicht Claude) automatisch ausführt, z. B. vor jedem Commit.
- **MCP:** Anschluss an externe Programme (GitHub, OneDrive …).
