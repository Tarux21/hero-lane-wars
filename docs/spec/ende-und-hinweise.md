# Spezifikation: Spielende, Endstatistik, Pause und Einsteiger-Hinweise (Browser-Prototyp, index.html)

Stand: wie `economy.md`. Reine Beschreibung (keine Golden Values, da diese Teile fast nur Oberfläche sind).

## 1. Siegbedingung (Zeile 1865–1870, 1082)

- **Niederlage**: `G.lives <= 0` in `update(dt)` der eigenen Lane → `G.over = true` und Meldung „NIEDERLAGE“. Ein Leck zieht `UNITS[type].lives` ab (Grunt/Brocken/Schütze/Läufer 1, Elite 3, Boss 10), die Zählung erfolgt im selben Frame (Zeile 1063).
- **Sieg**: in `stepWorld` nach beiden Updates: `E.G.lives <= 0 && !P.G.over` → `P.G.over = true`, Meldung „SIEG!“. Es gibt nur **ein** `over`-Flag (das des Spielers); die Lane des Gegners bekommt keinen Endzustand.
- Reihenfolge je Schritt: `update(P)`; wenn `P.G.over` nicht gesetzt: `botStep(E)` und `update(E)`; danach Sieg-Check. Verliert der Spieler in diesem Schritt (Leben ≤ 0), wird die Lane des Gegners in diesem Schritt nicht mehr aktualisiert und der Sieg-Check ist wegen `P.G.over` falsch → **bei gleichzeitigem Nullwerden verliert der Spieler**.
- `CFG.infiniteEnemyLives` (Testmodus) setzt `E.G.lives = 1e9`; `comebackBonus` und Endstatistik behandeln `> 1e8` als „unendlich“.
- Nach `over`: `update` kehrt sofort zurück (keine Wellen, kein Einkommen); Rechtsklick, Skills (außer `learn`), Senden und Backport sind gesperrt (Zeile 1346, 1363 `if(P.G.over) return`).

## 2. Endstatistik (`showEnd`, Zeile 1669–1696)

Der Endbildschirm erscheint 1.1 s nach `over` (`setTimeout(showEnd, 1100)`) und nur, wenn `running` und `P.G.over`. Titel „SIEG!“ wenn `P.G.lives > 0`, sonst „NIEDERLAGE“. Untertitel: Spielzeit `m:ss` (`P.G.t`), Gegner-Heldenname und Schwierigkeit.
Tabelle (Spalten Du / Gegner), je Seite `S`:

| Zeile | Wert |
|---|---|
| Held | `Name (Level N)` |
| Leben übrig | `max(0, lives)` oder `∞` (> 1e8), `von startLives (20)` |
| Monster getötet | `G.stats.kills` (nur Kills auf der eigenen Lane, `killUnit` zählt bei `lane === 0`) |
| Tode des Helden | `H.deaths` |
| Gold verdient | `round(G.stats.gold)` = Kill-Gold + Einkommen-Ticks + Gold/s + Boss-Einkommen (nicht das Startgold, nicht Verkaufserlös) |
| Monster gesendet | Summe von `G.stats.sent`, dazu je Typ „Name Anzahl“ |
| Einkommen | `income * goldMul` auf eine Nachkommastelle, „pro 10 s“ |
| Boss | `bossSpawned ? (bossIncome > 0 ? 'besiegt (+50 Gold pro Welle)' : 'nicht besiegt') : 'nicht erschienen'` |
| Skill-Ränge | `ranks.join(' / ')` |
| Items | Namen der Rucksack-Items, kommagetrennt, ggf. `, N× Heiltrank` |

Felder von `G.stats` (Zeile 386, 474, 585, 1065): `kills`, `gold`, `sent{type: n}`, `leak{type: lives}` (Leak wird gezählt, aber im Endbildschirm nicht angezeigt). `G.bossIncome` und `G.bossSpawned` liegen direkt in `G`.
Hinweis zu `stats.gold`: Zählt Einkommen mit `goldMul` und Aufholhilfe (`inc` im Tick), Gold/s, Kill-Gold (`killUnit`), Boss-Einkommen (`spawnWave`). Beim Senden/Kaufen sinkt es nicht.

## 3. Pause, Tempo, Menü (Zeile 1586–1612, 1871–1880)

- `paused` stoppt `stepWorld` (kein Update, keine Wellen, keine Cooldowns). In der Pause bleiben Shop und Skillpunkte bedienbar (`learn` ist ohne Pausenprüfung; `castSlot`, `startBackport`, `drinkPotion`, `send` und Stopp sind gesperrt: `if(paused) return;`, Zeile 1365–1366). Kaufen/Verkaufen über die Shop-Oberfläche geht in der Pause (nur Basis-Regel).
- `togglePause` ist bei `P.G.over` oder ohne Partie wirkungslos. Esc schließt zuerst die Einstellungen, sonst Pause. Einstellungen und Feedback-Fenster pausieren automatisch (`settingsPaused`, `fbPaused`) und setzen danach fort.
- Tempo ×1/×2/×3: `loop` rechnet `dt = min(0.1, Frame-Zeit)`, zerlegt `dt*Tempo` in Schritte von höchstens 0.05 s.
- „Zurück zum Menü“ und „Neu starten“ fragen per `confirm`, solange die Partie läuft und nicht vorbei ist.

## 4. Hinweise (`uiTick`, `coachTick`, Zeile 1622–1666)

Alle 2 s (`uiT.coach`) wird ein Einsteiger-Tipp geprüft (nur wenn nicht pausiert und nicht vorbei). Jeder Tipp erscheint höchstens einmal je Spieler (gemerkt in `settings.tipsSeen`), höchstens ein Tipp pro Prüfung, Anzeige 8 s:

| id | Bedingung |
|---|---|
| move | `G.t > 2` |
| skill | `G.t > 12` |
| shop | `G.t > 30 && G.gold >= 80 && H.bag.length === 0` |
| send | `G.t > 50 && G.gold >= 90 && noch nichts gesendet` |
| lives | `G.lives < startLives` |

Warnungen (immer aktiv): Verlust von Leben („−N Leben! Noch X“), „⚠ N Monster nahe deiner Basis!“ (Monster mit `x < baseX + 320`, höchstens alle 6 s), Vorschau besondere Welle in ≤ 10 s (`waveKind`), „Skillpunkt frei“ alle 30 s, solange ein Skillpunkt vergebbar ist. Höchstens 4 Hinweise gleichzeitig sichtbar.
