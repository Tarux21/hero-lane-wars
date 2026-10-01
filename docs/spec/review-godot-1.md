# Review 1: Godot-Skills und Heldenlogik gegen Prototyp und Spezifikation

Geprüft: `godot/scripts/skills.gd` (komplett) und in `godot/scripts/game.gd` `step`, `_step_zones`, `_step_hero`, `_step_units`, `_damage_hero`, `hit_unit`, `_kill_unit`, `_gain_xp`, `_spawn_wave`, `_unhandled_input`, `_start_backport` (Stand Commit 75bde44 plus lokale Änderungen, Zeilennummern der Arbeitskopie vom Review-Zeitpunkt).
Vergleich gegen `index.html` (Zeilen in Klammern) und `docs/spec/skills.md`. Nur gelesen, nichts geändert.

## Ergebnis in Kürze
Skills, Zonen, Timer, Elementare, Statuseffekte, Tod/Respawn und Level/XP stimmen mit dem Prototyp überein (auch Randfälle: Kettenblitz ohne Ziel, Schildwurf-Kette bei toten Zielen, Schockwelle-Rang-5-Betäubung 1,68 s, Boss-Betäubung ×0,3, Elementar als Monsterziel mit Rüstung 10). Die unten gelistete Abweichungen betreffen Eingabe und Dinge, die die Golden Values nicht abdecken.

## A. Echte Abweichungen (verhalten sich anders als der Prototyp)

| # | Stelle | Ist (Godot) | Erwartet (Prototyp) |
|---|---|---|---|
| A1 | `game.gd:1464–1480` (Rechtsklick) | Ein Rechtsklick während des Backports ändert nichts: der Held steht still, `_step_hero` kehrt bei `bp > 0` früh zurück, Laufbefehle werden zwar gesetzt, wirken aber erst nach dem Backport | Rechtsklick **bricht den Backport ab** (`index.html:1347 if(H.bp>0) cancelBackport();`), danach läuft/greift der Held sofort. Das ist die einzige Möglichkeit, einen Backport abzubrechen, außer Schaden oder Sprung |
| A2 | `game.gd:1472` | Ziel per Rechtsklick: `dd <= u["r"] + 14.0` | `d < u.r + 8` (`index.html:1349`) – die Klickfläche ist 6 px kleiner |
| A3 | `game.gd:1447` | `_unhandled_input` kehrt bei totem Held zurück, damit auch `Shift+Q/W/E/R` (Skillpunkte) | Skillpunkte lassen sich auch **als toter Held** und in der Pause vergeben (`index.html:1364–1365`: `learn` hat keine Tod-Prüfung) |
| A4 | `game.gd:1035` (Einkommen) | `hero["gold"] += hero["income"]` | `income * G.goldMul * (1 + comebackBonus(G))` (`index.html:921`) und `stats.gold += inc`. Aufholhilfe (`comebackBonus`, `index.html:908–913`) und Schwierigkeits-`goldMul` fehlen; wird mit der Wirtschaft kommen |
| A5 | `game.gd:1188 _start_backport` | Cast-Zeit `cfg.backportCast` fest | `backportCast * (1 − bpRed)` (Hut des Reisenden, `index.html:822`); kommt mit den Items |
| A6 | `game.gd:1000 _damage_hero` | Kein `dmg_t = 0` (Lebensfluss), keine Item-Dornen, `god` fehlt | `index.html:541–555`; kommt mit den Items (Dornen: `6 + 0.10*bonusArmor`, siehe `items.md`) |
| A7 | `game.gd:1247 _step_units`, `_spawn_unit` | Keine Boss-Logik: kein `bossThink` (Phasen 66/33 %, Stampfen alle 6/5/4 s mit `dmg*1.5` im Radius 150, Verstärkung alle 20/14/10 s mit `2+Phase` Grunts, Tempo ×0,8/1,0/1,3), Boss hat keine Felder `boss/phase/base/stompT/summonT` | `index.html:885–905, 437`. Die Boss-Betäubung ×0,3 greift bereits über `u["type"] == "boss"` |
| A8 | `game.gd:954 _kill_unit`, `_spawn_wave` | Kein Boss-Einkommen: Boss-Tod gibt `+50` Gold **pro Welle** dauerhaft (`G.bossIncome += 50`), jede Welle `G.gold += G.bossIncome` (`index.html:459, 584`); auch kein `bossSpawned`-Merker | wie links |
| A9 | `game.gd:1247 _step_units` | Keine Titanenpanzer-Aura, keine Qual (`tormCd/tormT`), `apply_torment` ist ein Stub | `index.html:1025–1028, 1050` (Items) |
| A10 | `game.gd:1087 _step_hero` | Auto-Angriff ohne Krit, Lebensraub, Item-Effekte (`onHitMagic, giants, cleave, ruin`), kein `critAs`-Buff, kein Lebensfluss, kein `goldPS` | `index.html:984–1013, 951, 918`; kommt mit den Items. Reihenfolge der Effekte siehe `items.md` Abschnitt 4 |
| A11 | `game.gd:1247 _step_units` Leak | Leak zieht von `team_lives[0]` ab, ohne Statistik `leak[type]` | Prototyp zählt `G.stats.leak` nach Typ (`index.html:1065`) – nur Statistik |

## B. Kleinigkeiten / bewusste Unterschiede (kein Fehler)

- B1 `skills.gd:157 ground_point` und `game.gd:1385 _mouse_info`: `dist = maxf(1.0, len)` statt Prototyp `hypot || 1` (nur bei Länge exakt 0 → 1). Bei Länge 0 < d < 1 weicht Godot minimal ab (Skills mit Mauszeiger genau auf dem Helden). Folgenlos.
- B2 `chain_lightning`, `circle_hit`, `cone_hit`, `nearest_enemy` laufen über `g.units` (alle Lanes deines Teams, Prototyp: `enemies()` = Lane 0). In 1v1 identisch; bei 2 Lanes bewusst eine Gruppe.
- B3 `skills.gd:385 _cas_e`: Kettenblitz ohne Ziel gibt `true` zurück (Cooldown läuft, Kombo verbraucht, `last_elem` gesetzt), wie im Prototyp (`index.html:787`, dort ein Versehen). Entscheidung offen, ob das bleibt; wäre in Godot mit `return false` leicht korrigierbar. Dann auch im Prototyp ändern, damit die Golden Values übereinstimmen.
- B4 game.gd:700 rand(): im deterministischen Modus 0.999 (Golden-Läufe setzen and_fixed). Für die vorhandenen Golden Values ohne Folge, weil jedes Szenario sein and explizit vorgibt (0.5 oder 0); der Default weicht nur für Zufallsentscheidungen mit Schwelle ≥ 0.5 ab, die es im Spiel nicht gibt.
- B5 Konkrete Reihenfolge von `step()` stimmt mit `update()` überein (Einkommen → Wellen → Timer → Zonen → Held → Elementare → Einheiten). Tick-Reihenfolge und Statuseffekte der Einheiten (Slow → Brennen → Qual → Blutung → Betäubung) stimmt, Qual fehlt noch (A9).

## C. Geprüft und gleich (Auszug der Fragen)

- **Zielauswahl/Mausinput**: `_mouse_info` entspricht `m.{dx,dy,dist,ang,wx,wy}`; Schildwurf wählt das erste Ziel nach Abstand zum Mauszeiger unter `<= 450` zum Helden, Kettenblitz `<= 520`, Sprung `groundPoint(420)`, Feuerfeld `groundPoint(380)`.
- **Cooldown-Zeitpunkt**: nur bei erfolgreichem Cast (`res != false`), `cd * (1 − cdr)`; kein Cast bei Tod/Spielende; keine Zauberzeit im Prototyp (Godot ebenfalls keine).
- **Tod/Respawn**: `dead = 5 + 2*lvl`, Buffs gelöscht, Sprung abgebrochen (Landung entfällt), Timer/Zonen/Elementare bleiben, Heilung des Schildwurfs entfällt bei totem Held; Respawn `hp = max`, Position (120, y).
- **Backport-Unterbrechung**: Schaden (`bp = 0` in `_damage_hero`, auch bei Tod) und Sprung (`cancel_backport`) brechen ab; während `bp > 0` kein Laufen/Angreifen (gleich). Nur A1 fehlt.
- **XP/Level/Skillpunkte**: `xpBase + xpPer*lvl`, `sp += 1`, `hp += hpl`, Maximum Level 15, Freischaltlevel `[1,2,3,10]`, Rang-Maxima gleich.
- **Eiserne Haut**: `IRON`-Tabelle, Reflexion vom ungekürzten Schaden mit Rüstung des Angreifers, Regeneration, Grund-Reflexion 0,15 bei Rang 0, Rüstung ersetzt nicht addiert zur Grund-Rüstung (gleich).
- **Schildwurf bei toten Zielen**: `_hop` sucht das nächste ungetroffene Ziel unbegrenzt weit; Rückkehr/Heilung wie im Prototyp.
- **Elementar als Ziel**: Monster greifen den Elementar an, wenn der Held nicht in Reichweite ist (`range + 18`, Schaden `reduce(dmg, 10)`); Elementar verschwindet bei `hp <= 0` oder `t <= 0`; ein Elementar gleichzeitig.
- **Boss-Betäubung 0,3**: `skills.gd:88` gleich.
- Die Dictionary-Vergleiche `units.has(u)`/`erase(u)` sind in Godot 4 Referenzvergleiche (kein Value-Vergleich), damit korrekt auch bei zwei gleich aussehenden Monstern.
