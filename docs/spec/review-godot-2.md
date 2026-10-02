# Review 2: Godot-Bot, Items, Wirtschaft und Boss gegen Prototyp und Spezifikation

Geprüft (Stand Commit b9f4e30, Arbeitskopie): `godot/scripts/bot.gd`, `items.gd` komplett, `golden_economy_runner.gd` (Kopf: Vergleichslogik und `_setup`), in `game.gd`: `send`, `_make_player`, `_spawn_unit`, `_spawn_wave`, `_kill_unit`, `_gain_xp`, `hit_unit`, `_damage_hero`, `step`, `_boss_think`, `comeback_bonus`, `_step_zones`, `_step_hero`, `_start_backport`, `_step_units`.
Vergleich: `index.html` (Zeilen in Klammern), `docs/spec/economy.md`, `docs/spec/skills.md`. Nur gelesen.

## Ergebnis in Kürze
Items, Kauf-/Verkaufsregeln, Wirtschaft, Boss-Phasen/Stampfen/Verstärkung, Boss-Betäubung ×0,3, Elite-Welle, Aufholhilfe und die Bot-Entscheidungen sind 1:1 aus dem Prototyp übernommen (Reihenfolgen und Schwellen verglichen). Es gibt einen echten Logikfehler im Mehr-Lane-Fall (Boss), einige Unterschiede, die die Golden Values nicht abdecken, und Hinweise zum Prüfer.

## A. Logikfehler / Abweichungen

| # | Stelle | Befund | Erwartet |
|---|---|---|---|
| A1 | `game.gd:1292–1294` (`_spawn_wave`) | `side["boss_spawned"] = true` wird **innerhalb** der Lane-Schleife gesetzt. Bei `lanes_per_team = 2` bekommt nur die **erste** Lane den Boss (die zweite sieht `boss_spawned == true`). Damit ist die Welle 20 auf einer Lane ohne Boss | Entweder bewusst „ein Boss je Seite“ (dann dokumentieren, und der Boss erscheint auf Lane 0), oder „ein Boss je Lane“: `boss_spawned` erst **nach** der Lane-Schleife setzen. Prototyp: ein Boss (`index.html:460–461`) |
| A2 | `game.gd:602–612` (`send`) | Das gesendete Monster erscheint auf **allen** Lanes des Gegner-Teams, die Kosten und das Einkommen fallen aber nur einmal an. Bei 2 Lanes bekommt der Gegner doppelt so viele Monster für denselben Preis | Balance-Entscheidung des Nutzers (im Prototyp gibt es nur 1 Lane). Entweder je Lane bezahlen oder ein Monster auf eine gewählte Lane |
| A3 | `game.gd:1792–1797` (Aura) | Aura wirkt, sobald **irgendein** lebender Held der Seite die Aura hat und Abstand ≤ 150 – passt zum Prototyp für 1 Held; bei mehreren Helden bewusst neu, kein Fehler | – |
| A4 | `golden_economy_runner.gd:61–62` `_num_ok` | Toleranz `0.0012 + 0.0005*|b|` ist relativ 0,05 %. Bei großen Werten (z. B. Blutung 15137 Schaden, Gesamtschaden 4000+) sind das mehrere Einheiten Schaden, die einen echten Unterschied verdecken könnten. Die meisten Szenarien liegen unter 1000 | Für Vergleiche mit Gold/Schaden besser absolut `0.01` plus relativ `1e-6`. (Der Prototyp rechnet in Double, Godot ebenfalls) |
| A5 | `golden_economy_runner.gd:139` | `_unit_row` setzt `"lane": 0` fest, vergleicht also die Lane nicht | Nur relevant mit mehreren Lanes |

## B. Geprüft und gleich zum Prototyp (Auszug)

- **Boss (`_boss_think`, `game.gd:1447–1473`)**: Phase `f > 0.66 → 1`, `> 0.33 → 2`, sonst 3 (`index.html:886`); Phasenwechsel setzt `summon_t = min(summon_t, 2)`; `spd = base * bossSpeedMul[ph−1]` (0.8/1.0/1.3); Stampfen: `stomp_t −= dt`, bei ≤ 0 neu auf `bossStompEvery[ph−1]` (6/5/4 s), Schaden `dmg * 1.5` an Helden mit Abstand ≤ `150 + 14`; Verstärkung: `summon_t −= dt`, Neustart `bossSummonEvery[ph−1]` (20/14/10 s), `2 + ph` Grunts bei `x = u.x + 30 + i*14`, y zufällig. Start `stomp_t 5`, `summon_t 12` (`index.html:437`).
- **Reihenfolge**: `_boss_think` kommt wie im Prototyp **nach** dem Betäubungs-Check (betäubter Boss: keine Timer, kein Stampfen, keine Verstärkung, keine Bewegung) und **vor** `atk_t −= dt` (`game.gd:1752–1757` gegen `index.html:1032–1034`). Boss-Betäubung ×0.3 in `skills.gd:88`.
- **Elite-Welle**: `n % eliteEvery == 0`, `eliteCount 2` bei `base_off + count*4 + 30 + k*40`, Welle 20 hat Elites **und** Boss (`index.html:457–461`).
- **Boss-Einkommen**: Boss-Kill `+50` auf `boss_income`; bei jedem Wellen-Spawn `gold += boss_income` (nach dem Spawn, gleiche Wirkung wie `index.html:459`).
- **Kill-Gold/XP/Level/Respawn**, `hit_unit` (Rüstung), Rückgabe `dealt`, `last_p` für Brennen/Blutung/Qual: gleich (Prototyp: Töter ist immer der Lane-Besitzer).
- **Einkommen**: ein gemeinsamer `income_t` für alle Spieler, `income * gold_mul * (1 + comeback_bonus)`, `gps*dt` pro Frame; Aufholhilfe-Formel identisch (`index.html:908`, 4 % je Leben ab Diff 3, Deckel 20 %; Gegner unendlich → 0).
- **Wellen-Timer**: je Seite eigener `wave_t`, 16 s bis Welle 4, danach 30 s (`index.html:924`).
- **`_damage_hero`**: Reihenfolge `dr` → Rüstung → `bp = 0` → `hp −= eff` → `dmg_t = 0` → Reflexion (`raw`) → Dornen-Item → Tod (Buffs gelöscht, Sprung abgebrochen) wie `index.html:541–561`.
- **`_step_hero`**: Regeneration (12 % in der Basis sonst `1.5 + 0.3*lvl`), Lebensfluss (`dmg_t >= 5`), Sprung, Backport (mit `bp_red`), Auto-Angriff mit allen Item-Effekten in der Prototyp-Reihenfolge (Krit → Haupttreffer → Lebensraub mit Rachsucht → onHitMagic → giants → cleave (Radius 80, 3 nächste, Schaden inkl. Krit) → ruin → Kampfrausch-Cleave) wie `index.html:984–1013`.
- **Items (`items.gd`)**: `resolve_buy` (erstes freies gleiches Teil, rekursiv), `buy_reason` (Reihenfolge der Prüfungen wie `index.html:841–850`: Basis, Verbrauch, Rucksack, Hut, Gold), Verkauf `floor(total * 0.7)` (Double), `recalc` mit Deckeln (crit 1, cdr 0.4, ls/sv 0.5, dr 0.4, bpRed 0.8) und Heilung bei höherem Max-Leben.
- **Bot (`bot.gd`)**: Lern-Bias, Pool-Pläne (inkl. `FD/FC/FT`), `shop` (Schritt überspringen nur bei Rucksack voll/Vorrat voll), Sende-Entscheidung (`t < 35`, `sendEvery * every`, `ph`, `f`-Formel, Gegner-Held tot ×1.6 Deckel 0.9, eigene Lane > 22 ×0.4, Reserve, Gewichte `< 480` / `≥ 480`, bis zu 10 Sendungen), Modus (`retreat`/`shop`/`fight`, Schwellen `retreat`, `shopGold`, `0.6`, Backport nur bei `bp_cd <= 0` und keinem Gegner in 260), Zielwahl (x, Archer −250, Elite −120, Läufer −150, Abstand > 800 +500) und Skill-Bedingungen (`nearCount`-Radien je Klasse) stimmen mit `botSend/botThink/botSkills` überein.

## C. Kleinigkeiten und Hinweise (kein Fehler)

- C1 `bot.gd:128,134`: `cast_skills` nutzt `randf()` statt `g.rand()`. Im Spiel gewollt wie `Math.random`; Tests mit fester Zufallszahl erreichen diesen Pfad nicht (Skill-Würfe des Bots sind also nicht deterministisch). Ein Botplay-Vergleich mit festem Seed sollte `seed()` setzen.
- C2 `bot.gd:171–172`: `last_send` startet bei `0.0` (wie `lastSend:0`); gemeinsam mit `t < 35` heißt das, dass die erste Sendung frühestens bei `t = 35` fällt (nicht erst nach `sendEvery`).
- C3 `bot.gd:116–121` `near_count` zählt Monster **beider** Lanes der Seite (Prototyp: nur die eine Lane); wegen des y-Abstands der Lanes selten relevant, aber ein Bot kann auf der anderen Lane „Gegner nah“ sehen. Absicht laut Auftrag (Mehr-Helden-Lagen).
- C4 `game.gd:1763–1767` Monster greifen den **nächsten** lebenden Helden in Reichweite an (Prototyp: einziger Held). Gleich für 1 Held.
- C5 `game.gd:1314` (`_kill_unit`): `kills` wird nur für Seite 0 gezählt – nur Statistik.
- C6 Prototyp-Eigenheit, die bewusst unverändert bleibt: ein betäubtes Monster überspringt auch den Leak-Check (`game.gd:1752–1754` `continue` vor Zeile 1823), wie `index.html:1032`.
