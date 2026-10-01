# Spezifikation: Helden und Skills (Browser-Prototyp, index.html)

Stand: `index.html` nach Commit `9a9ed9d` (Balancing vom 2026-10-01). Alle Zeilennummern beziehen sich auf diese Datei.
Ziel: Die Skills so genau beschreiben, dass man sie ohne den JS-Code nachbauen kann. Vergleichswerte dazu: `regelwerk/golden-skills.json` (Abschnitt 8).
Alle Zahlen stehen auch maschinenlesbar in `regelwerk/daten.json` (`cfg`, `heroes`, `elem`); die Wirkung der Skills (`cast`) steht dort nicht, nur hier.

## 1. Grundlagen

### 1.1 Helden (HEROES, Zeile 245–249)

| | Tank | Damage | Caster |
|---|---|---|---|
| Leben `hp` / pro Level `hpl` | 416 / +60 | 488 / +65 | 260 / +32 |
| Angriffsschaden `dmg` / pro Level `dpl` | 22 / +3.5 | 26 / +4.5 | 12 / +1.8 |
| Rüstung `armor` / pro Level `armorl` | 6.4 / +0.96 | 5 / +1.0 | 1 / +0.4 |
| Angriffstempo `as` (Angriffe/s) | 1.0 | 1.1 | 0.9 |
| Reichweite `range` (Auto-Angriff) | 38 | 38 | 230 |
| Lauftempo `spd` | 175 | 195 | 180 |

Ableitungen (Zeile 416–426), Level `L` = 1..15 (`maxLevel 15`):
- `hMaxHp = hp + hpl*(L−1) + bonusHp`; beim Levelaufstieg steigt auch `H.hp` um `hpl` (Zeile 567).
- `hDmg = dmg + dpl*(L−1) + bonusDmg * adEff[Klasse]` mit `adEff` = tank 0.8, damage 1, caster 1 (Zeile 220).
- `hArmor = armor + armorl*(L−1) + bonusArmor + ironPassive().armor`.
- `hAs = as * (1 + bonusAs + rage.as + storm.as + critAs.as)` (Buffs nur wenn aktiv, additiv).
- `hSpd = spd + bonusSpd + rage.spd`.
- `hSp = (bonusSp + (hpAp ? bonusHp*0.12 : 0)) * (1 + (spMul ? 0.30 : 0))`. Die Helden haben **keine** Basis-Zauberkraft.
- Rüstung wirkt als `dmg * (1 − armor/(armor+150))` (`reduce`, `armorK 150`).
- Skillpunkte: Start `sp = 1`, +1 je Levelaufstieg (insgesamt 15 bis Level 15). Lernen (`learn`, Zeile 813): nur wenn `sp >= 1`, `rank < max` und `Level >= unlock[i]` mit `unlock = [1, 2, 3, 10]` für Q, W, E, R. Max. Ränge: Q/W/E je 5, R 1.
- Abklingzeit eines Skills nach erfolgreichem Cast: `cd * (1 − H.cdr)` (`cdr` höchstens 0.40). Alle `cds` zählen jeden Frame um `dt` herunter (Zeile 942).

### 1.2 Skillschaden `dmgOf(base, per, r, sc, k)` (Zeile 601)

```
dmgOf = (base + per*(r−1) + sc*hSp() + k*hDmg())
        * CFG.power[Klasse]                         // tank 0.93, damage 1.18, caster 0.95
        * H.mul                                     // 1 beim Spieler; Bot: DIFF.heroMul (leicht 0.75, normal 1.12, schwer 1.3, Experte 1.5)
        * (ampNow ? 1 + comboAmp(0.30) : 1)         // nur während eines Casts mit Zeitzauberstab-Kombo
        * (1 + earlyBoost[Klasse] * max(0, 1 − (L−1)/14))   // earlyBoost: tank 0, damage 0, caster 0.7 (Level 1 → +70 %, Level 15 → +0 %)
```

Wichtig: `dmgOf` liest den Heldenzustand **zum Aufrufzeitpunkt**. Bei Timern (`later`) wird erst beim Auslösen gerechnet (siehe Meteor, Schwertregen, Elementar-Blitz), wo `ampNow` schon false ist und Level/Items sich geändert haben können. Werte, die vor dem Timer in einer Variablen stehen (z. B. Feld-Tickschaden), sind zum Castzeitpunkt festgelegt.

### 1.3 Der Cast (`castSlot`, Zeile 798–812)

1. Abbruch, wenn der Held tot ist, das Spiel vorbei ist, `rank < 1`, `cds[i] > 0` oder der Skill passiv ist.
2. `ampNow = uniq.has('comboAmp') && comboT > 0`.
3. `res = s.cast(r, {dx, dy, dist, ang, wx, wy})`. `dx,dy` = Mauszeiger (Welt) − Heldposition, `dist = hypot(dx,dy) || 1`, `ang = atan2(dy,dx)`, `wx,wy` = Mauszeiger in Weltkoordinaten. Danach `ampNow = false`.
4. Gibt der Skill `false` zurück: **kein** Cooldown, kein Kombo-Verbrauch, kein `lastElem`. (Jeder andere Rückgabewert, auch `undefined`, zählt als erfolgreich.)
5. Erfolg: Sound, bei Caster und Slot 0–2 `lastElem = ['fire','frost','lightning'][slot]`, `cds[slot] = cd*(1−cdr)`, Kombo: `comboT = ampNow ? 0 : 5` (`comboWindow 5`); war es ein verstärkter Cast, erscheint der Text „KOMBO +30%“.

### 1.4 Trefferfunktionen (Zeile 599–662)

- `enemies()` = alle `G.units` mit `lane === 0` (die Lane des Helden).
- `circleHit(cx, cy, radius, dmg, o, fxCol)`: trifft jeden Gegner mit `hypot(u−c) <= radius + u.r`; gibt die Anzahl zurück.
- `coneHit(ox, oy, ang, range, half, dmg, o)`: Gegner mit Abstand `d <= range + u.r` und (`d < 1` oder Winkel zwischen Richtung und Gegnermittelpunkt `<= half`); `half` ist der **halbe** Öffnungswinkel in Bogenmaß.
- `lineHit` wird von keinem Skill benutzt.
- `groundPoint(m, range)`: `k = min(m.dist, range)/m.dist`, Punkt `(H.x + m.dx*k, clampY(H.y + m.dy*k))`; `clampY` begrenzt `y` auf ±80 (`laneHalf 90 − 10`).
- `affect(u, dmg, o)` (Zeile 610) – die zentrale Wirkung auf einen Gegner, in dieser Reihenfolge:
  1. `dealt = hitUnit(u, dmg)` (Rüstung des Ziels: `dmg*(1 − armor/(armor+150))`, Schaden wird sofort abgezogen; stirbt das Ziel, wird es entfernt und es gibt Gold/XP; Rückgabe 0, wenn das Ziel schon weg ist).
  2. **Zauberraub**: wenn `spellVamp > 0` und `dealt > 0`: `hp = min(maxHp, hp + dealt * spellVamp * (vengeance && hp < 0.4*maxHp ? 2 : 1) * 0.4)` (`svFactor 0.4`). Gilt für **jeden** `affect`-Treffer (auch Zonen und Elementar-Fähigkeiten, jeden Tick, jeden getroffenen Gegner).
  3. Lebt das Ziel nicht mehr: Ende.
  4. `torment`: siehe `items.md`.
  5. `o.stun`: `u.stun = max(u.stun, o.stun * (u.boss ? 0.3 : 1))`.
  6. `o.slow`: `u.slow = max(u.slow, o.slow)` (Sekunden; Effekt: Tempo × 0.5).
  7. `o.knock`: `u.x = min(spawnX+80 = 3030, u.x + knock)` (Rückstoß nur in +x, also weg von der Basis, um die Distanz).
  8. `o.bleed`: `u.bleed = max(u.bleed||0, o.bleed)`, `u.bleedPct = max(u.bleedPct||0, o.bleedPct)`.
  9. `o.burn`: `u.burn = max(u.burn||0, o.burn)`, `u.burnDps = max(u.burnDps||0, o.burnDps)`.

### 1.5 Zustände der Gegner pro Frame (Einheitenschleife, Zeile 1020–1069)

Reihenfolge je Einheit: `slow −= dt` (falls > 0) → **Brennen** (`burn −= dt; burnT += dt; wenn burnT >= 1: burnT −= 1; hitUnit(u, burnDps)` – mit Rüstung) → `tormCd −= dt` → **Qual** (ignoriert Rüstung, siehe items.md) → **Blutung** (`bleed −= dt; bleedT += dt; wenn bleedT >= 1: bleedT −= 1; hp −= u.max * bleedPct`, **ignoriert Rüstung**) → **Betäubung** (`stun > 0`: `stun −= dt`, danach `continue`: keine Bewegung, kein Angriff, keine Boss-Logik, kein Leak-Check in diesem Frame). Dann Boss-Logik, Angriff, Bewegung (`step = spd * (slow > 0 ? 0.5 : 1) * aura * dt`).
Brennen/Blutung laufen auch während einer Betäubung weiter. `burnT`/`bleedT` werden nicht zurückgesetzt, wenn der Effekt endet.

### 1.6 Schadensfelder (Zonen, Zeile 928–940)

`G.zones` Einträge `{x, y, r, t, tick:0, every, dmg, o, follow}`. Pro Frame, in Listenreihenfolge: `t −= dt; tick −= dt;` Folgen (`follow === 'enemy'`: zum **nächsten Gegner** (Mittelpunkt) mit `75*dt` Schritt bewegen, wenn Abstand `> 4`; `y = clampY(y)`; `'hero'` wird von keinem Skill mehr benutzt); bei `tick <= 0`: `tick += every` und `affect(u, dmg, o)` für alle Gegner mit `hypot <= r + u.r`. Am Frameende werden Zonen mit `t <= 0` entfernt. Da `tick` bei 0 startet, **tickt jede Zone schon im ersten Frame nach dem Erzeugen**, danach etwa jede Sekunde. Gemessen mit `dt = 0.05` (Golden `caster-q-r1-l15-b0`): Feuerfeld Rang 1 (`t:5`) tickt **6-mal** (Frame 1, dann alle 20 Frames, der letzte Tick im Frame, in dem `t` auf ≤ 0 fällt). Die Zahl der Ticks hängt also vom Zeitschritt und von der Float-Rundung ab (siehe 8.3); eine Zone mit Dauer `T` und `every 1` tickt hier `T+1`-mal.

### 1.7 Reihenfolge von `update(dt)` (Zeile 916–1084)

1. `G.t += dt`, Gold/s-Items, Einkommen-Tick, Wellen-Spawn.
2. **Timer** (`G.timers`, von `later(t, fn)`): `t −= dt`, bei `t <= 0` entfernen und ausführen (Reihenfolge wie in der Liste; Timer, die währenddessen neue Timer anlegen, laufen erst im nächsten Frame).
3. **Zonen** (1.6).
4. Held: Cooldowns/`bpCd`/`potCd`/`comboT` herunterzählen, Buffs `t −= dt` (bei ≤ 0 löschen), Respawn oder (lebend) Lebensfluss, Regeneration, Sprung-Bewegung, Backport, Laufen, **Auto-Angriff**.
5. Elementare (`updateElems`).
6. Gegner (1.5) inkl. Angriffe auf den Helden/Elementar und Leaks.
7. Effekte (Texte etc.), Kamera, Niederlage-Check.

Skills werden von der Eingabe **zwischen** zwei `update`-Aufrufen gewirkt (Tastendruck). Hero-Tod: siehe 1.8.

### 1.8 Tod und Unterbrechung

- `damageHero`: ignoriert Schaden, wenn der Held tot oder `H.god` ist. `dmg *= (1 − H.dr)`; `eff = reduce(dmg, hArmor())`; `hp −= eff`; `dmgT = 0`; **Reflexion/Dornen** mit dem ungekürzten Schaden `raw` (siehe 2.2); Backport wird abgebrochen.
- Bei `hp <= 0`: `hp = 0`, `deaths++`, `H.dead = 5 + 2*Level` Sekunden (Respawn), `target = moveTo = null`, **`H.buffs = {}`** (Kampfrausch endet), `H.leap = null` (Sprung wird abgebrochen, **die Landung findet nicht statt**), Backport abgebrochen.
- Nach dem Respawn: `hp = maxHp`, Position (120, 0).
- Ein toter Held kann keine Skills wirken. **Bereits angelegte Timer, Zonen und Elementare laufen weiter**: z. B. kommt die zweite Schockwelle (Rang 5), der Meteor (Rang 5) und Schwertregen-Einschläge auch nach dem Tod des Helden, an der dann aktuellen `H.x,H.y` (bei der Schockwelle) bzw. an den gemerkten Punkten. Schildwurf: die Heilung bei der Rückkehr entfällt (`if(!H.dead)`).
- Kein Skill unterbricht sich durch Betäubung des Helden (es gibt keine Heldenbetäubung). Nur der Sprung bricht einen laufenden Backport ab (`cancelBackport()`); andere Casts ändern ihn nicht; Schaden bricht ihn ab.
- Während eines laufenden Sprungs (`H.leap`) bewegt sich der Held nicht selbst und greift nicht automatisch an (`else if(!H.leap)` in Zeile 961).

## 2. Tank (`SK.tank`, Zeile 706–741)

### 2.1 Q – Schockwelle (Zeile 707–710)

- Cooldown `CFG.tankQcd = 6.5 s`, max. Rang 5, freigeschaltet ab Level 1. Zielart: **Kegel in Richtung Mauszeiger** (`m.ang`), Ursprung = Heldposition.
- `range = 200 + 15*(r−1)` (200, 215, 230, 245, 260); `half = 0.62` rad (~35.5°).
- `dmg = dmgOf(25, 8, r, 0, 0.5)` = `(25 + 8(r−1) + 0.5*hDmg) * power * mul * amp * early`.
- Wirkung auf alle Gegner im Kegel: Schaden, `stun = 0.8 + 0.12*(r−1)` (0.8, 0.92, 1.04, 1.16, 1.28 s), `knock = 80` ab Rang 3 (sonst 0).
- **Rang 5** zusätzlich: nach `0.6 s` (Timer) eine zweite Welle vom **aktuellen** Heldort, aber gleicher Richtung `m.ang`: `range + 40`, Schaden `dmg*1.25` (der beim Cast berechnete Wert), `stun + 0.4` (das Options-Objekt `o` wird geteilt: Betäubung der zweiten Welle ist `0.8+0.48+0.4 = 1.68 s`), Rückstoß 80 wie vorher.
- Immer erfolgreich (Cooldown auch ohne Treffer).

### 2.2 W – Eiserne Haut (Passiv, Zeile 711–712, 419–421, 541–555)

- Kein Cast (`cast()` gibt false zurück, `passive:true`), wirkt ab Rang 1 ständig. Tabelle `IRON[Rang−1]`: Rüstung `{6, 10, 20, 24, 40}`, Reflexion `{0.20, 0.30, 0.40, 0.50, 0.60}`, Regeneration `{0, 0, 0.01, 0.01, 0.025}` (Anteil des max. Lebens pro Sekunde).
- Ohne Skillpunkt (Rang 0): Rüstung +0, Reflexion `innateReflect = 0.15`, Regeneration 0.
- Rüstung wird zu `hArmor` addiert; Regeneration `+ maxHp * regen * dt` pro Frame.
- **Reflexion**: in `damageHero(dmg, src)`, wenn `src` in `G.units`: `hitUnit(src, raw * reflect * reflectMul(1.0))`, wobei `raw` der Schaden **vor** Schadensverringerung (`dr`) und vor der Rüstung ist; die Rüstung des Angreifers wirkt. Gilt für jeden Treffer eines Gegners (Nahkampf, Fernkampf, Boss-Stampfen).
- Item-Dornen (`thorns`) wirken zusätzlich (siehe `items.md`).

### 2.3 E – Schildwurf (Zeile 713–738)

- Cooldown 10 s, max. Rang 5, ab Level 3. Zielart: **Ziel nahe dem Mauszeiger**: erstes Ziel = der Gegner mit dem kleinsten Abstand zum Mauszeiger (`m.wx,wy`) unter allen Gegnern mit Abstand `<= 450` zum Helden (Mittelpunkt). Kein Ziel → Text „Keine Ziele!“ und Rückgabe **false** (kein Cooldown).
- `dmg = dmgOf(35, 14, r, 0, 0.8)`; Anzahl Ziele `3` (Rang 1–2) oder `5` (ab Rang 3). Ab **Rang 5**: `bleed = 3 s`, `bleedPct = 0.05` (5 % des max. Lebens des Ziels pro Sekunde, Ticks nach 1 s, 2 s, 3 s, ignoriert Rüstung).
- Ablauf `hop(from, u, left)`: ist `u` nicht mehr am Leben, wird der nächste ungetroffene Gegner zu `from` gewählt. Gibt es kein `u` oder `left <= 0` → `comeBack(from)`. Sonst: `hit.add(u)`, `affect(u, dmg, {bleed, bleedPct})`, Position `pos = (u.x,u.y)` merken, nächstes Ziel = nächster ungetroffener Gegner zu `pos` mit Abstand `<= 220`, dann Timer `0.15 s`: wenn es ein nächstes Ziel gibt und `left > 1` → `hop(pos, nächstes, left−1)`, sonst `comeBack(pos)`. Treffer erfolgen also bei t = 0, 0.15, 0.30, … (jede Sekunde nur ein Ziel).
- `comeBack(from)`: Verzögerung `min(0.6, 0.1 + d/900)` mit `d` = Abstand von `from` zum Helden **zum Planungszeitpunkt**; danach (wenn der Held lebt) Heilung `shieldHeal 0.10 * hMaxHp()` (nicht von Power/Items beeinflusst, max. bis maxHp).
- Wechselwirkung: Zauberraub/Qual wirken über `affect` auf jeden Treffer.

### 2.4 R – Titanenstoß (Zeile 739–740)

- Cooldown 50 s, max. Rang 1, ab Level 10. **Kreis um den Helden**: `circleHit(H.x, H.y, 190, dmgOf(200, 0, 1, 0, 1), {stun: 3, knock: 120})`. Schaden `(200 + hDmg) * power * mul * amp * early`; Betäubung 3 s (Boss: 0.9 s), Rückstoß 120. Immer erfolgreich.

## 3. Damage (`SK.damage`, Zeile 742–773)

### 3.1 Q – Wirbel (Zeile 743–748)

- Cooldown 5 s, max. Rang 5, ab Level 1. **Kreis um den Helden**: `radius = 95 + 5*(r−1)` (95…115), `dmg = dmgOf(30, 10, r, 0, 0.7)`.
- Heilung des Helden nach dem Schlag: `n` = Anzahl getroffener Gegner; `heal = min(n, 5) * whirlHeal[r−1] * hMaxHp()` mit `whirlHeal = [0, 0.004, 0.006, 0.008, 0.010]` (Rang 1: keine Heilung); `hp = min(maxHp, hp + heal)`. Zählt alle im Radius, auch wenn der Schaden sie tötet.

### 3.2 W – Kampfrausch (Zeile 749–751)

- Cooldown 20 s, max. Rang 5, ab Level 2. Selbstbuff, kein Ziel: `H.buffs.rage = {t: (r>=3 ? 10 : 6), as: 0.4 + 0.12*(r−1), spd: 40, cleave: r>=5}` (ersetzt einen laufenden Kampfrausch, Dauer wird neu gesetzt).
- Angriffstempo `+as` (0.40, 0.52, 0.64, 0.76, 0.88 additiv zu den anderen Boni), Lauftempo `+40`.
- Rang 5: Jeder Auto-Angriff trifft zusätzlich alle anderen Gegner mit Abstand `<= 75` zum Ziel mit `hitUnit(u, dmg*0.5)` (Schaden des Haupttreffers inkl. Krit, Rüstung wirkt). Endet beim Tod des Helden.
- Das Feld `ls` im Buff existiert im Code nicht (`rg.ls` bleibt ungesetzt, siehe Abschnitt 7).

### 3.3 E – Sprung (Zeile 752–761)

- Cooldown 10 s, max. Rang 5, ab Level 3. Zielart: **Bodenpunkt in Richtung Mauszeiger**, `p = groundPoint(m, 420)` (Weite höchstens 420, `y` begrenzt auf ±80). Ist der Weg `< 30` px → Rückgabe **false** (kein Cooldown).
- Beim Cast: Backport abbrechen, `moveTo = target = null`. `dmg = dmgOf(20, 8, r, 0, 0.4)`, `fdmg = dmgOf(10, 4, r, 0, 0.15)` (beide zum Castzeitpunkt, mit Kombo-Bonus falls aktiv).
- Sprungdauer `0.22 s`: der Held wird linear von Start nach Ziel bewegt (`k = 1 − max(0, L.t)/0.22`); in dieser Zeit keine eigene Bewegung/Auto-Angriffe. Beim Ablauf (`L.t <= 0`, im Update des Helden) springt er genau auf den Zielpunkt und `land()` wird aufgerufen.
- Landung: `circleHit(H.x, H.y, 80 + 4*(r−1), dmg, {stun: r>=5 ? 1.5 : 0})`; ab Rang 3 zusätzlich eine Zone `{r:100, t:4, every:1, dmg:fdmg}` am Landepunkt (tickt sofort im nächsten Update-Teil, dann jede Sekunde).
- Stirbt der Held während des Sprungs, entfällt die Landung (siehe 1.8).

### 3.4 R – Schwertregen (Zeile 762–772)

- Cooldown 50 s, max. Rang 1, ab Level 10. **Zufällige Ziele**: alle Gegner mit Abstand `<= 650` zum Helden werden mit `sort(()=>Math.random()−.5)` gemischt, die ersten 5 genommen. Keine Ziele → „Keine Ziele!“, Rückgabe **false**. (In den Golden Values ist `Math.random` fest 0.5, die Auswahl ist dann die ersten 5 in Listenreihenfolge.)
- `dmg = dmgOf(60, 0, 1, 0, 0.8)`, `fdmg = dmgOf(18, 0, 1, 0, 0.3)`. Für das i-te Ziel (i = 0…4) mit der **beim Cast gemerkten Position (x,y)** nach `0.3 + 0.25*i` s: `circleHit(x, y, 60, dmg)` und Zone `{x, y, r:70, t:8, every:1, dmg:fdmg}`. Die Zone wird im Timer-Schritt erzeugt und tickt im selben Frame (Timer laufen vor den Zonen).

## 4. Caster (`SK.caster`, Zeile 774–796)

### 4.1 Q – Feuerfeld (Zeile 775–781)

- Cooldown 10 s, max. Rang 5, ab Level 1. Zielart: **Bodenpunkt** `p = groundPoint(m, 380)` (Weite höchstens 380).
- `radius = 90 + 6*(r−1)` (90…114), `tick = dmgOf(9, 5, r, 0.2, 0.08)` (Tickschaden je Sekunde, zum Castzeitpunkt berechnet).
- Rang 1–4: eine Zone `{x:p.x, y:p.y, r:radius, t:5, every:1, dmg:tick}`; ab **Rang 3** mit `follow:'enemy'` (jagt den nächsten Gegner mit 75 px/s).
- **Rang 5**: Es entsteht **nur ein Feld**, erst nach dem Meteor: Ring-Vorwarnung, nach `0.9 s` `circleHit(p.x, p.y, 100, dmgOf(120, 0, 1, 0.8, 0.3), {})` (dmgOf zum Auslösezeitpunkt, ohne Kombo-Bonus) und dann die Zone mit `t:6`, `follow:'enemy'`, Tickschaden wie oben (`tick` vom Castzeitpunkt, mit Kombo-Bonus falls aktiv).

### 4.2 W – Frostnova (Zeile 782–783)

- Cooldown 12 s, max. Rang 5, ab Level 2. **Kegel in Richtung Mauszeiger** vom Helden: `range = 200 + 15*(r−1)`, `half = 0.62`, `dmg = dmgOf(20, 10, r, 0.3, 0)`.
- `slow = 3 + 0.5*(r−1)` Sekunden (3, 3.5, 4, 4.5, 5), `stun = 0` (Rang 1–2), `0.8` (Rang 3–4), `1.6` (Rang 5; Boss × 0.3). Immer erfolgreich.

### 4.3 E – Kettenblitz (Zeile 784–789, 647–661)

- Cooldown 8 s, max. Rang 5, ab Level 3. **Start**: Gegner mit Abstand `<= 520` zum Helden, sortiert nach Abstand zum Mauszeiger (`wx,wy`); der nächste ist das erste Ziel. **Keine Ziele → `return` ohne `false`: der Cast gilt als erfolgreich** (Cooldown läuft, `lastElem` wird gesetzt, Kombo wird verbraucht).
- Anzahl Sprünge/Ziele `3 + r` (4…8), `dmg = dmgOf(40, 18, r, 0.6, 0)`, Verlust je Sprung `falloff = 0.9` (Rang 5: 1, also keiner), Sprungweite `170` px.
- `chainLightning(from, first, count, dmg, crit, falloff, jump)`: `cur = first`. Solange `cur` und `count > 0`: `isCrit = Math.random() < crit`; `affect(cur, isCrit ? dmg*2 : dmg, {stun: isCrit ? 0.5 : 0})`; `dmg *= falloff`; nächstes Ziel = nächster **noch nicht getroffener** Gegner mit Abstand `<= jump` zum zuletzt getroffenen (Mittelpunkt). Alle Treffer geschehen im selben Frame.
- Krit-Chance je Rang (`CRIT_BY_RANK`): `[0.10, 0.125, 0.15, 0.225, 0.30]`. Krit: doppelter Schaden **und** 0.5 s Betäubung (Boss × 0.3).

### 4.4 R – Elementar (Zeile 790–795, 664–703)

- Cooldown 90 s, max. Rang 1, ab Level 10. Kein Zielpunkt: erscheint bei `(H.x + 35, H.y)`. Hat der Held seit dem Spielstart keinen der Skills Q/W/E erfolgreich benutzt (`lastElem` leer) → Text „Erst Q, W oder E benutzen!“, Rückgabe **false**.
- Typ = zuletzt benutzter Skill Q/W/E (`fire`, `frost`, `lightning`). `G.elems = [neuer Elementar]` (es gibt **höchstens einen**, ein neuer ersetzt den alten). Wert: `{hp: 700, max: 700 (elemHp), t: 60 (elemTime), atkT: 1, abT: 2, eRank: max(1, Rang von E), sp: hSp() zum Beschwörzeitpunkt}`. `lastElem` wird beim Tod nicht gelöscht.
- Der Elementar bewegt sich nicht. Er wird von Gegnern angegriffen, die den Helden **nicht** in Reichweite haben und ihn in `range + 18` erreichen: Schaden `reduce(u.dmg, 10)` (Rüstung 10). Er verschwindet bei `hp <= 0` oder `t <= 0`; Lebensdauer zählt pro Frame `t −= dt`.
- **Normaler Angriff**: `atkT −= dt`; bei `<= 0`: nächster Gegner im Abstand `< 170` → `hitUnit(t, 8 + 0.15*sp)` (Rüstung wirkt, kein Zauberraub), `atkT = 1.2`; kein Ziel → `atkT = 0.3`.
- **Fähigkeit** (`abT −= dt`; bei `<= 0`: `abT = ability() ? 6 + Math.random()*4 : 1`): Ziel = nächster Gegner im Abstand `< elemRange 320` zum Elementar; kein Ziel → Rückgabe false (nach 1 s erneut).
  - `fire`: `coneHit(e.x, e.y, Winkel zum Ziel, range 260, half 0.6, dmg 45 + 0.5*sp, {burn: 6, burnDps: 16 + 0.3*sp})` (Brennen: Treffer von `burnDps` jede Sekunde, mit Rüstung, 6 s).
  - `frost`: bis zu 3 zufällige Gegner (gemischt wie oben) im Abstand `<= 320` zum Elementar: je eine Zone `{x,y: Position des Gegners, r:75, t:5, every:1, dmg: 7 + 0.2*sp, o:{slow: 1.5}}`, folgt nicht.
  - `lightning`: `chainLightning(e, Ziel, 3 + eRank + 3 Sprünge (7…11), dmg dmgOf(40, 18, eRank, 0.6, 0)*0.8, crit CRIT_BY_RANK[eRank−1], falloff eRank>=5 ? 1 : 0.9, jump 210)`. Hier wird `dmgOf` mit dem **aktuellen** Heldzustand berechnet; `sp` des Elementars ist nur für die anderen beiden Typen gespeichert.
- Alle Elementar-Treffer, die über `affect` laufen (Feuerkegel, Frostzonen, Blitz), lösen Zauberraub und Qual des Helden aus; die normalen Elementar-Angriffe nicht.

## 5. Wechselwirkungen mit Items (Kurzfassung, Details in `items.md`)

| Mechanik | Wirkung auf Skills |
|---|---|
| `cdr` (Items/Hüte, Deckel 0.40) | Abklingzeit `cd*(1−cdr)`, gilt für alle 4 Slots; der Wert wird beim Cast fest gesetzt |
| `comboAmp` (Zeitzauberstab) | Skillschaden ×1.30 für den nächsten Cast innerhalb 5 s; nur dmgOf-Aufrufe während des Casts |
| `spellVamp` (`sv`, Deckel 0.5) | Heilung bei jedem `affect`-Treffer, `*0.4`, ×2 mit `vengeance` unter 40 % Leben |
| `torment` | startet Qual pro Treffer/Ziel (6 s Pause) |
| `spMul` (Zauberkrone), `hpAp` (Seelenreif) | verändern `hSp()` |
| `bonusDmg` | wirkt auf `k*hDmg()` mit `adEff` (Tank 0.8) |
| `bonusSp` | wirkt auf `sc*hSp()` (Caster-Skills 0.2–0.8, Damage/Tank haben `sc = 0`, nur der Meteor/Frost/Chain des Casters und die Elementar-Fähigkeiten nutzen Zauberkraft) |
| `dr`, `armor` | wirken auf eingehenden Schaden/Reflexion des Tanks (siehe 2.2) |
| `lifesteal`, `crit` | nur Auto-Angriffe, keine Skills |

## 6. Cooldown-Übersicht

| Held | Q | W | E | R |
|---|---|---|---|---|
| Tank | Schockwelle 6.5 s | Eiserne Haut (passiv) | Schildwurf 10 s | Titanenstoß 50 s |
| Damage | Wirbel 5 s | Kampfrausch 20 s | Sprung 10 s | Schwertregen 50 s |
| Caster | Feuerfeld 10 s | Frostnova 12 s | Kettenblitz 8 s | Elementar 90 s |

## 7. Auffälligkeiten im Prototyp (nur gemeldet, nicht geändert)

1. **Kettenblitz ohne Ziel verbraucht Abklingzeit** (und setzt `lastElem`), weil `if(!pool.length) return;` statt `return false;` (Zeile 787). Schildwurf und Schwertregen geben dagegen `false` zurück.
2. **Toter Code**: `buff('storm')`/`H.buffs.storm` wird in `update` (Zeile 949, 953) und `draw` ausgewertet, aber nirgends gesetzt (Sturmbrecher arbeitet über `critAs`). `rg.ls` (Kampfrausch-Lebensraub, Zeile 1009) wird nirgends gesetzt. `'iron'`-Buff nur in `draw`. `lineHit` ungenutzt.
3. `dmgOf` für Timer-Effekte (Meteor, Elementar-Blitz) wird zum Auslösezeitpunkt berechnet, Tick-/Landeschaden anderer Skills zum Castzeitpunkt. Deshalb bekommt der Meteor nie den Kombo-Bonus, das Meteorfeld schon.
4. Zauberraub und Qual wirken auch bei Elementar-Fähigkeiten und bei jedem Zonen-Tick (nicht nur beim Cast).
5. Eine Stolperfalle: `o` bei der Schockwelle Rang 5 wird beim zweiten Schlag verändert (`o.stun += .4`), nicht kopiert; der Rückstoß 80 gilt für beide Wellen.
6. Beim Tod des Helden werden Timer und Zonen **nicht** gelöscht (siehe 1.8). Die Schockwelle Rang 5 trifft dann von der Respawn-Position (120, 0) aus, falls der Held schon wiederbelebt wurde, sonst von der Todesposition.
7. Gegnerbewegung durch `knock` ist nur in +x-Richtung und auf `spawnX + 80` begrenzt; Gegner mit `u.stun > 0` überspringen auch den Leak-Check.
8. Skillpunkte reichen nicht für alles: 15 Punkte bis Level 15, aber 5+5+5+1 = 16 Ränge pro Held (der Tank-W-Passiv zählt mit).
9. Die Tooltipp-Texte (`info`) nennen z. B. „Rang 5: Getroffene bluten 3 Sek. (5 % ihres Lebens/Sek.)“; ein Blutungs-Tick fällt nach exakt 1 s Abstand an, die ersten 1 s nach dem Treffer also ohne Schaden (3 Ticks, nicht 4).

## 8. Golden Values (`regelwerk/golden-skills.json`)

### 8.1 Erzeugen

Im Browser (Seite über `serve.ps1` geöffnet, keine laufende Partie nötig):

```js
(0,eval)(await (await fetch('/regelwerk/golden-skills.js')).text());
```

Das Skript simuliert 205 Szenarien mit dem echten Spielcode (`makeState`, `castSlot`, `update`) und speichert per `POST /save-golden` nach `regelwerk/golden-skills.json` (nur diese Datei, siehe `serve.ps1`). Ohne Speichern: vorher `window.GOLDEN_SAVE = false;` setzen, das Ergebnis steht dann in `window.GOLDEN`. Wiederholtes Ausführen liefert byte-identische Ergebnisse (geprüft). Nach Balance-Änderungen in `index.html` neu ausführen und die Datei nach `godot/data/` kopieren.

### 8.2 Aufbau

- Kopf: `version`, `dt` (0.05), `snapshotZeiten` `[0, 0.5, 1, 2, 4, 8, 12]`, `heldPos` `[1000, 0]`, `dummyHp` (100000), `layouts`, `dummyFelder`.
- Je Szenario (`scenarios[]`): `id`, `input`, `result`.
  - `input`: `hero`, `lvl`, `ranks[4]` (direkt gesetzt, Freischaltlevel wird nicht geprüft), `bonus {sp, dmg, hp, armor, as}`, `uniq[]`, `cdr`, `spellVamp`, `lifesteal`, `dr`, `critCh`, `regen`, `hpFrac` (Start-Leben, Standard 0.5), `layout` (`field` = 10 Dummys im Feld, `melee` = 6 Dummys im Nahbereich), `dummyHp`, `dummyArmor` (Standard 0), `dummySpd` (Standard 0), `rand` (Zufallswert, Standard 0.5), `auto` (Held greift automatisch an), `casts [{t, slot, mouse [dx,dy] relativ zum Helden, Standard [200,0]}]`, `hits [{t, dmg, src}]` (direkter `damageHero`-Aufruf, `src` = Dummy-Index).
  - `result.derived`: `maxHp, armor, dmg (hDmg), sp (hSp), as, spd, reflect` vor dem Cast.
  - `result.castInfo`: je Cast `{t, slot, ok, cdAfter}` (`ok` = Cooldown wurde gesetzt, `cdAfter = cd*(1−cdr)`).
  - `result.snaps`: je Schnappschuss `t`, `hero {hp, heal, x, y, dead, comboT, lastElem, cds[4], buffs}`, `dummies [[…9 Zahlen…]]`, `zones`, `elems`.
  - Dummy-Zeile (`dummyFelder`): `[Schaden gesamt, Betäubung Rest s, Verlangsamung Rest s, Brennen Rest s, Brennschaden/s, Blutung Rest s, Qual Rest s, x, y]`. Schaden gesamt = `dummyHp − hp` (inkl. Brennen/Blutung/Qual).
  - `hero.heal` = `hp(mit Casts) − hp(gleiche Lage ohne Casts)` zum gleichen Zeitpunkt (so ist die Heilung unabhängig von der Grundregeneration). Start-Leben 50 %, damit der Deckel `maxHp` nie greift (außer in `hpFrac:1`-Szenarien, wo es nicht um Heilung geht).
- Schnappschuss `t = n*0.05`: nach `n` Aufrufen von `update(0.05)`. Ereignisse mit `t <= aktuelle Zeit` (Casts, Treffer) werden **vor** dem Update des jeweiligen Zeitschritts ausgeführt. Schnappschuss 0 zeigt also nur die sofortigen Wirkungen des Casts (Schaden, Betäubung, Rückstoß), noch ohne Timer/Zonen.

### 8.3 Regeln für den Vergleich

- Dummys: `lane 0`, Radius `r = 9`, Rüstung 0, Tempo 0, Schaden 0, `hp = max = 100000`, `atkT = 1e9`; bewegen sich nur durch Rückstoß. Der Held steht bei (1000, 0) und greift nur im Szenario mit `auto:true` an.
- `Math.random()` liefert konstant `rand`: 0.5 = nie Krit, Auswahl „zufälliger“ Ziele = Listenreihenfolge (Schwertregen: die ersten 5 Dummys; Frost-Elementar: die ersten 3 im Radius); `rand 0` = jeder Zufallswurf `< Chance` trifft (alle Kettenblitz-Sprünge kritisch, Auto-Angriffe kritisch bei `critCh > 0`). Die Elementar-Fähigkeit hat dann `abT = 6 + 0.5*4 = 8`.
- Float-Hinweis: JavaScript rechnet in Double. Zonen-/Blutungs-/Brenn-Ticks hängen davon ab, ob `tick`/`bleedT` nach wiederholtem Subtrahieren von 0.05 genau bei 0 bzw. 1 landen. In Godot (float32) kann ein Tick um einen Frame früher/später fallen; sinnvoll ist, den Vergleich auf Schnappschüsse mit Toleranz ±1 Tick bzw. ±1 % zu legen oder den Zeitzähler in Double zu führen.
- Dummy-Schaden bleibt klein gegenüber 100000, kein Dummy stirbt (außer bewusst gewählten `dummyHp` bei den `monarch`-Szenarien: 1000 und 100).

### 8.4 Szenarien (IDs)

| Muster | Inhalt |
|---|---|
| `{held}-{q,w,e,r}-r{1,max}-l{1,15}-{b0,sp100,dmg60}` | Jeder Skill (Tank-W passiv und Caster-R eigene Szenarien), Rang 1 und max., Level 1 und 15, Bonus: keiner / `bonusSp 100` / `bonusDmg 60`. R nur Rang 1. Mauszeiger Standard (+200, 0), Sprung (+300, 0) |
| `caster-e-r{1,5}-l15-sp100-allcrit` | Kettenblitz mit `rand 0` (jeder Sprung kritisch) |
| `caster-r-{fire,frost,lightning}-e{1,5}-l15-sp{0,100}` | Elementar je Typ (Q/W/E bei t=0, R bei t=0.5), Elementar-Rang (E) 1 und 5 |
| `caster-r-ohne-vorskill` | Elementar ohne vorherigen Skill (`ok:false`, kein Cooldown) |
| `tank-w-passiv-r{0..5}-l{1,15}-arm{0,100}` | Eiserne Haut: ein Treffer 100 Schaden von Dummy 0 (Reflexion, Rüstung, Leben) |
| `tank-dornen-item…`, `tank-schaden-minus-15` | Item-Dornen (mit/ohne Eiserne Haut), `dr 0.15` |
| `caster-kombo-zeitzauberstab`, `caster-qual-maske`, `caster-zauberkrone`, `caster-seelenreif-hpap`, `caster-cdr-40` | Item-Wechselwirkungen |
| `{held}-zauberraub22`, `{held}-rachsucht-doppelt` | Zauberraub 0.22 bei 50 % bzw. Rachsucht bei 30 % Leben |
| `damage-w-r{1,3,5}-auto` | Kampfrausch mit Auto-Angriffen (Rang 5: 75-px-Umkreis) |
| `auto-{held}-{basis,krit-…,sturmbrecher,lebensraub10,rachsucht-lebensraub,funkenklinge,gigantenschlag,splitteraxt,monarch-hoch,monarch-mittel,monarch-niedrig,ruestung-gegner-50}` | Auto-Angriffe und Item-Effekte (Held Level 5, `bonusDmg 20`) |
| `aura-ohne`, `aura-titanenpanzer` | Titanenpanzer-Aura: Dummys laufen mit Tempo 60 auf den Helden zu |

### 8.5 Szenario-Runner in Godot

Pro Szenario: Held mit `lvl`, `ranks`, `bonus`, `uniq` usw. erzeugen, Dummys aus `layouts` an `heldPos + Offset` stellen, dann in 0.05-s-Schritten simulieren (Ereignisse vor dem Update, Schnappschüsse nach dem Update) und die Felder aus `result.snaps` vergleichen. `hero.heal` bekommt man durch einen zweiten Lauf ohne Casts.
