# Hero Lane Wars (Prototyp)

Ein Lane-Spiel im Browser: Dein Held ist der „Turm“, der die Lane gegen Monsterwellen verteidigt.
Du entwickelst ihn (Level, Skills, Items) und schickst Monster zum Gegner, um dein Einkommen zu erhöhen.
Der Gegner ist ein Bot mit eigenem Helden und eigener Lane.

## Starten
- **Einfach:** `index.html` per Doppelklick im Browser öffnen (Chrome, Edge oder Firefox am PC). Es ist nichts zu installieren.
- **Mit lokalem Server (optional):** `serve.ps1` ausführen und `http://localhost:8123/` öffnen
  (`powershell -ExecutionPolicy Bypass -File serve.ps1`).

## Steuerung (Standard, in den Einstellungen änderbar)
| Aktion | Taste |
|---|---|
| Laufen / angreifen | Rechtsklick |
| Skills | Q W E R (Mauszeiger = Ziel) |
| Skillpunkt vergeben | Shift + Taste oder „+“ in der Skill-Leiste |
| Backport zur Basis | B |
| Stopp | S |
| Heiltrank | F |
| Monster senden | Z X C V N |
| Pause | P oder Esc |
| Gegner zuschauen | Tab |
| Testfenster | F2 |

Einkaufen geht nur in der Basis (Shop, Rucksack mit 6 Plätzen, Rezepte mit Hover-Fenster).

## Wichtige Dateien
| Datei | Inhalt |
|---|---|
| `index.html` | Das komplette Spiel (Logik, Oberfläche, Bot). Alle Balance-Zahlen stehen oben im Block `CFG`, dazu `UNITS`, `HEROES`, `ITEM_LIST`, `DIFF`. |
| `sim2.js` | Simulation: zwei Bots spielen ohne Grafik gegeneinander (für das Balancing). |
| `bal.js` | Hilfen für Balance-Messungen (Rahmenbaupläne, Messfunktionen). |
| `snowball.js` | Messung: Wie oft gewinnt, wer nach 3/6 Minuten führt? (`snowball(30)`; Aufholhilfe aus: `CFG.comebackCap=0`) |
| `ROADMAP.md` | Plan und Stand der Phasen |
| `serve.ps1` | Kleiner lokaler Webserver (Port 8123). |

## Balancing mit der Simulation
Im Browser (Seite über den lokalen Server geöffnet) in der Konsole:

```js
(0,eval)(await (await fetch('/sim2.js')).text());
(0,eval)(await (await fetch('/bal.js')).text());
crossAgg(3, 12);                       // Klassenbalance: Siegquoten Tank/Damage/Caster
measure('damage', ['dStorm'], 'dStd'); // Item-Variante gegen den Standardbuild
```

Hinweis: Die Messungen streuen um etwa ±10 Prozentpunkte; für aussagekräftige Werte mehrere Messreihen mitteln.

## Gegner-Stile
`BOT_STYLE` in `index.html` (Ausgewogen, Aggressiv, Wirtschaft). Für Simulationen: `duel('tank','tank',{style:['rush','balanced']})`. Messwerte (je Klasse gespiegelt, Normal): Aggressiv ~49 % gegen Ausgewogen, Wirtschaft ~55 % gegen Ausgewogen, Aggressiv ~42 % gegen Wirtschaft.

## Spielgefühl (Sound und Effekte)
Im Block „SPIELGEFÜHL“ in `index.html`: `SFX` (Sounds, per WebAudio erzeugt), `sfx()`, `shake()`, `burst()`. Alles läuft nur über `feelOn()` (nur Spieler, nicht Bot, nicht in der Simulation – `sim2.js` setzt `simMode`).

## Stand
- 3 Helden (Tank, Damage, Caster) mit je 4 Skills, Rucksack-Item-System mit Teilen/Rezepten/Hüten
- Bot-Gegner mit Schwierigkeitsstufen (Leicht bis Experte) und wechselnden Builds
- Elite-Wellen alle 10 Wellen, Bosswelle auf Welle 20, Wellenvorschau
- Pause, Tempo ×1–×3, Endbildschirm mit Statistik, Skill-Leiste mit Tooltips, Einstellungen mit Speichern
- Balancing (Simulation, Stand 2026-10-01): Klassen ca. 50 % Siegquote (Tank/Damage/Caster), Spieldauer ca. 14 Min., Boss wird in ca. 83 % der Partien erreicht, Schwierigkeiten Leicht < Normal < Schwer < Experte, Items und Hüte meist im Bereich 35–65 % gegen den Standardbuild. Schwachpunkt: reine Item-Strategie ohne Monster schicken verliert klar (Tank ca. 10 %).
