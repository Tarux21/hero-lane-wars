# Spezifikation: Wirtschaft, Wellen, Level und Bot (Browser-Prototyp, index.html)

Stand: `index.html` nach Commit `9a9ed9d` plus Aufholhilfe und Bot-Stile (Commit `080e65f`ff.). Zeilennummern beziehen sich auf diese Datei.
Vergleichswerte: `regelwerk/golden-economy.json` (erzeugt von `regelwerk/golden-economy.js`, Abschnitte `economy`, `items`, `itemEffects`, `bot`, `priceTable`).
Items selbst: `items.md`, Skills: `skills.md`.

## 1. Spielschleife (Zeile 1865–1880)

- `loop` rechnet `dt = min(0.1, Frame-Zeit)` und teilt `dt*Tempo` in Schritte von höchstens **0.05 s** (`stepWorld`).
- `stepWorld(dt)`: `update(dt)` für deine Lane (Spieler `P`); danach, wenn deine Partie nicht vorbei ist, `botStep` (Bot entscheidet) und `update(dt)` für die Lane des Bots (`E`).
- Sieg: `E.G.lives <= 0` (und `P.G.over` noch nicht gesetzt) → `P.G.over = true`. Niederlage: `G.lives <= 0` in `update` (Zeile 1082).
- Jeder Spieler hat **eigene Lane** (`G`: Einheiten, Gold, Einkommen, Leben, Zeit) und **eigenen Helden** (`H`); gesendete Monster sammeln sich im Pool des anderen und kommen mit dessen nächster Welle.

## 2. Einkommen (`update`, Zeile 916–921)

- Start: `startGold 300`, `baseIncome 24`, `incomeTick 10 s`, `startLives 20`.
- Pro Frame: `G.t += dt`, `G.gold += goldPS*dt` (Gold-Items).
- Pro Frame `incomeT += dt`; bei `incomeT >= 10`: `incomeT -= 10`, `inc = G.income * G.goldMul * (1 + comebackBonus(G))`, `G.gold += inc` (auch `stats.gold`).
  Golden: der erste Tick fällt exakt im 200. Schritt (t = 10.0), keine Float-Drift.
- `goldMul`: 1 für den Spieler, beim Bot `DIFF.goldMul` (leicht 0.85, normal 1.12, schwer 1.3, Experte 1.5).
- **Aufholhilfe** `comebackBonus(g)` (Zeile 908): `o` = Gegner-Lane; 0, wenn `o.lives > 1e8` (unendlich) oder `g.lives >= o.lives`; `behind = o.lives − g.lives`; `0` wenn `behind < 3` (`comebackDiff`), sonst `min(0.20, 0.04 * (behind − 3 + 1))` (`comebackPerLife 0.04`, `comebackCap 0.20`). Rückstand 3 → +4 %, 6 → +16 %, ab 7 → +20 %.
- Einkommen wächst nur durch **Senden von Monstern** (und Item-Gold/s), nicht durch Kills.

## 3. Monster senden (Zeile 471–477)

- `send(type)`: nur wenn `G.gold >= cost`, Spiel nicht vorbei und Gegner vorhanden. Dann `gold −= cost`, `income += inc * incMul (1)`, `stats.sent[type]++`; das Monster kommt in den **Pool** des Gegners (`E.G.sendPool`, `sendTo`). Mit der nächsten Welle des Gegners (`spawnWave`) laufen alle Pool-Monster gesammelt los: nach Grunts, Elite und Boss je `spawn(t, 0, (from − spawnX) + Wellengröße*4 + 60 + i*6, t = fast ? 1 : waveSpeedMul)`; danach ist der Pool leer. Bei 2 Lanes pro Team kommt jedes Pool-Monster auf beiden Lanes.
- Boss kann nicht gesendet werden (`noSend`, die Tastenbelegung enthält ihn nicht; `send('boss')` selbst prüft das nicht).
- Gesendete Monster laufen mit der Welle im Wellentempo (`waveSpeedMul 0.85`), nur der Läufer (`fast`) mit voller Geschwindigkeit (`spdMul 1`).
- Helden laufen höchstens bis `maxX 2950` (= `spawnX`, Öffnung des Spawns), nicht hinter den Spawn.

| Typ | Kosten | Einkommen `inc` | HP | Schaden | Tempo | Reichweite | Rüstung | Radius | XP | Kill-Gold | Leben bei Leak |
|---|---|---|---|---|---|---|---|---|---|---|---|
| grunt | 90 | 1.9 | 60 | 6 | 70 | 26 | 0 | 9 | 8 | 6 | 1 |
| tank (Brocken) | 225 | 4.7 | 220 | 8 | 50 | 28 | 6 | 13 | 20 | 6 | 1 |
| archer | 180 | 3.8 | 45 | 10 | 65 | 130 | 0 | 8 | 14 | 6 | 1 |
| fast (Läufer) | 150 | 2.8 | 35 | 5 | 135 | 24 | 0 | 7 | 12 | 6 | 1 |
| elite | 720 | 15 | 600 | 25 | 55 | 30 | 15 | 16 | 60 | 40 | 3 |
| boss | – | – | 1200 | 28 | 45 | 46 | 20 | 26 | 400 | 300 | 10 |

(`UNITS`, Zeile 237–244.) Alle Monster (außer `fast`) jagen den Helden (`aggroRange 350` wenn er vor ihnen steht, `aggroBehind 110` wenn er hinter ihnen steht).

### Zeitliche Skalierung (`spawn`, Zeile 433–438)
`m = hpMult() = 1 + (G.t/60) * hpScalePerMin (0.35)` mit der Zeit **der Lane, auf der das Monster entsteht**. `hp = max = u.hp*m`, `dmg = u.dmg * (1 + unitDmgScale (0.5) * (m−1))`. Position beim Spawn: `x = spawnX (2950) + offX + Math.random()*30`, `y = (Math.random()*2 − 1) * (laneHalf 90 − 16)`.

## 4. Kill-Belohnung, XP, Level, Respawn

- `killUnit(u)` (Zeile 580): nur für `u.lane === 0`. Boss: `G.bossIncome += 50`. Gold = `UNITS[type].gold ?? killGold (6)`, `stats.kills++`, `gainXp(UNITS[type].xp)`. Der Töter ist immer der Besitzer der Lane (Held `H`, auch bei Zonen, Brennen und Blutung).
- `xpNeed(l) = xpBase (30) + xpPer (30) * l` (XP von Level l auf l+1; Level 1→2: 60, 2→3: 90, …, 14→15: 450; Summe bis Level 15: 3570). `gainXp`: `xp += n`; solange `lvl < 15` und `xp >= xpNeed(lvl)`: `xp −= xpNeed`, `lvl++`, `sp++`, `hp += hpl`. Überschüssige XP auf Level 15 bleiben stehen.
- Respawn: `dead = respawnBase (5) + respawnPerLevel (2) * lvl` Sekunden; danach `hp = maxHp`, Position (120, 0).
- Boss-Einkommen: nach dem Boss-Kill bekommt der Töter bei **jedem** Wellen-Spawn `+bossIncome` Gold (`spawnWave`, Zeile 459), der Wert `G.bossIncome` steigt pro Boss-Kill um 50 (es gibt nur einen Boss, also 50 pro Welle).

## 5. Wellen (`spawnWave`, Zeile 449–467; `update`, Zeile 923–924)

- Erste Welle bei `t = firstWave = 1`. `waveT` danach: `earlyWaveEvery 16 s` solange `wave <= earlyWaves (4)` (nach Welle 1–4 je 16 s), sonst `waveEvery 30 s`. Golden: Wellen bei t = 1, 17, 33, 49, 65, 95, 125, …
- Wellengröße: `round(waveBase 3 + wavePer 1.2 * n)` Grunts; Position `from = min(spawnX, rampStart 2950 + rampStep 250*(n−1))` (rampStart = spawnX: jede Welle startet am Lane-Ende), `x = spawnX + (from − spawnX) + i*4 + Math.random()*30`.
- Elite-Welle (`n % 10 == 0`): zusätzlich 2 Elites (`eliteCount`) bei `from + count*4 + 30 + k*40`.
- Boss (Welle 20, einmalig): 1 Boss bei `from + count*4 + 160`. Die Welle 20 hat auch die 2 Elites.
- Boss-Logik: Phasen bei 66 % / 33 % Leben (Tempo ×0.8 / 1.0 / 1.3), Stampfen im Radius 150 mit `dmg*1.5` alle 6/5/4 s, Verstärkung (`2+Phase` Grunts) alle 20/14/10 s (`bossThink`, Zeile 885).
- Gold-Bonus pro Welle durch `bossIncome` siehe oben.

## 6. Bot (Zeile 1406–1570)

### 6.1 Schwierigkeit und Stile
`DIFF` (Zeile 375–380): `react` (Reaktionszeit zufällig im Bereich), `miss` (Fehlerquote beim Skill), `strat[früh,mitte,spät]` (Sende-Anteil), `heroMul`, `goldMul`, `sendEvery`, `retreat` (Rückzug-Lebensanteil), `shopGold` (Einkaufsfaktor). Stile `BOT_STYLE` (Zeile 1515): `strat`-Faktoren, `every`, `reserve`.

### 6.2 Kaufplan (`BOT_BUILD`, `BOT_POOL`, `botShop`)
Der Bot besitzt je Klasse einen Plan (Liste von Item-IDs in Kaufreihenfolge); beim Spielstart wird ein Pool-Plan zufällig gewählt (`pickBotBuild`). `botShop` kauft in der Basis der Reihe nach, solange `buy(id)` gelingt (echte Kauflogik inklusive Rezepten). Ein Schritt wird übersprungen, wenn er **nie** möglich ist (Rucksack voll durch den Kauf oder Trankvorrat voll), sonst wartet der Bot auf Gold. Golden `bot.plans`: je Plan Schritt für Schritt Kosten, Rucksack und Endwerte.
`BOT_CLASS.items` (Zeile 1409–1411) wird **nicht benutzt** und enthält ein nicht existierendes Item `'boots'`; nur `BOT_CLASS.bias` wird gelesen.

### 6.3 Skills lernen (`botLearn`, Zeile 1485)
Solange `H.sp > 0`: wähle unter den freigeschalteten, nicht vollen Skills den mit dem kleinsten `Rang + bias[i]` (`bias` Tank/Damage `[0,1,1,−10]`, Caster `[0,1,.5,−10]`; der Ultimate hat −10, wird also sofort ab Level 6 gewählt). Ergebnis je Level in `bot.learn`.

### 6.4 Senden (`botSend`, Zeile 1520)
1. Abbruch, wenn `G.t < 35` oder `G.t − lastSend < diff.sendEvery * style.every`.
2. `ph = t < 240 ? 0 : t < 600 ? 1 : 2`; `f = min(0.95, diff.strat[ph] * style.strat[ph])`; ist der Held des Gegners tot: `f = min(0.9, f*1.6)`; hat die **eigene** Lane > 22 Monster: `f *= 0.4`.
3. `reserve = (inBase() || mode == 'shop') ? 0 : botNextCost(I) * 0.7 * style.reserve`; `budget = max(0, gold − reserve) * f`.
4. Bis zu 10-mal: Gewichte `w = t < 480 ? {grunt 3, tank 3, archer 2, fast 1, elite 0} : {grunt 1, tank 3, archer 2, fast 1, elite 3}`; Auswahl unter den Typen mit `w > 0` und `cost <= budget`; Ziehung `r = Math.random()*Summe`, der erste Typ mit kumuliertem Gewicht ≥ r; `gold −= cost`, `income += inc`, `sent++`, `sendTo(Gegner)`, `budget −= cost`, `lastSend = G.t`.
Golden `bot.send`: `grid` (diff × Stil × Zeit × Gold × Gegner tot × Lane voll × in Basis, `rand 0.5`), `gating` (Pausenzeit), `randomPicks` (rand 0.01/0.5/0.99), `weights`, `diff`, `style`.

### 6.5 Modus (`botThink`, Zeile 1538; Golden `bot.mode`)
Reaktionszeit: `clock −= dt`; bei `<= 0` neu aus `react` würfeln und entscheiden. Reihenfolge: `botLearn`; Trank bei `hp < 40 %` und Trank vorhanden; in der Basis `botShop` (und Modus `fight` bei `hp > 90 %`); `botSend`; dann Modus:
- `fight` → `retreat`, wenn `hp < diff.retreat * maxHp`; sonst → `shop`, wenn Plan nicht fertig (`nx > 0`), nicht in der Basis, `bpCd <= 0`, keine Gegner im Umkreis 300 und (`gold >= diff.shopGold * nx` oder (`gold >= nx` und (keine Gegner auf der Lane oder `hp < 60 %`))).
- `retreat`/`shop`: in der Basis: bei `shop` `trips++` und zurück zu `fight`; sonst (kein Backport aktiv): `target = null`; Backport starten, wenn `bpCd <= 0` und keine Gegner im Umkreis 260, sonst nach (100, 0) laufen.
- `fight`: ohne Gegner nach (700, 0); sonst Ziel = Gegner mit kleinstem Wert `x` (Archer −250, Elite −120, Läufer −150, Abstand > 800 +500), Skills nach `botSkills`.

## 7. Auffälligkeiten (nur gemeldet)

1. `send('boss')` prüft `noSend` nicht (nur die Tastenbelegung schließt den Boss aus). Für Godot: Boss nie sendbar machen.
2. `BOT_CLASS.items` ist toter Code mit nicht existierenden Items (`boots`).
3. Verkaufspreis `floor(total*0.7)` in Double: Handschuhe 62, Großer Stab 244, Lebensstein 244, Dolch 125 (siehe `priceTable`).
4. Monster-Spawn und Bot nutzen `Math.random` (Positionen, Reaktionszeiten, Sendeauswahl, Zielunschärfe); die Golden Values fixieren das.
