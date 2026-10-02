# Spezifikation: Items (Browser-Prototyp, index.html)

Stand: `index.html` Version aus dem Commit nach `9a9ed9d` (Balancing vom 2026-10-01). Zeilennummern beziehen sich auf diese Datei.
Quelle der Zahlen im Code: `ITEM_LIST` (Zeile 256–335), `CFG` (178–236), `recalcItems` (826), Effekte in `update()` (916–1084), `damageHero` (541), `affect` (610).
Maschinenlesbar stehen alle Items auch in `regelwerk/daten.json` (`items`, Teile mit ausgerechneten Werten).

## 1. Regeln

| Regel | Wert | Code |
|---|---|---|
| Rucksack | 6 Plätze (`CFG.bagSize`), Items mit Gruppe basis/teil/zwischen/fertig/hut | 184, 846 |
| Verbrauchsgegenstände | eigene Slots, höchstens 5 je Sorte (`consMax`), zählen nicht zum Rucksack | 184, 844 |
| Kaufen | **nur in der Basis** (`inBase()`: Held lebt und `H.x < CFG.baseX = 230`), nicht wenn das Spiel vorbei ist | 426, 843 |
| Verkaufen | nur in der Basis; Erlös = `floor(totalCost(item) * 0.7)` (`sellRatio`), `totalCost` = Rezeptgeld + Gesamtpreis aller Teile (rekursiv) | 350, 869 |
| Verbrauchsgegenstände verkaufen | nicht möglich (`sell` arbeitet nur auf dem Rucksack) | 869 |
| Hut-Regel | Es passt nur **ein** Hut (Items mit `slot:'hat'`) in den Rucksack. Ein Spezialhut verbraucht beim Kauf den Lederhut (`parts:['hat']`). Ein zweiter, nicht verbrauchter Hut blockiert den Kauf ("du trägst schon einen Hut") | 848 |
| Rucksack voll | Kauf geht nur, wenn `bag.length - verbrauchteTeile + 1 <= 6` | 846 |
| Gold | Kauf nur, wenn `G.gold >= Preis` | 849 |
| Stats | gelten, solange das Item im Rucksack liegt; werden nach jedem Kauf/Verkauf in `recalcItems()` neu summiert | 826 |
| Einmalig (`unique`) | Der Effekt gilt, sobald mindestens ein Item mit dem Flag im Rucksack liegt (Menge `H.uniq`). Mehrere Items mit demselben Flag stapeln den **Effekt nicht**, ihre **Stats** stapeln aber sehr wohl | 832 |
| Heilung beim Kauf | Steigt das max. Leben durch einen Kauf, steigt `H.hp` um denselben Betrag (höchstens bis max.) | 838 |

### Rezepte und Preise (`resolveBuy`, Zeile 352)

- Jedes Item mit `parts` ist ein Rezept (Gruppen `zwischen`, `fertig`, `hut`). `cost` ist bei solchen Items nur das **Rezeptgeld**.
- Beim Kauf wird für jedes Teil zuerst ein passendes, noch nicht verbrauchtes Item im Rucksack gesucht (der Reihe nach, erstes gleiches Item). Gefundene Teile werden verbraucht (kostenlos). Fehlende Teile werden **mitgekauft** zum Teilepreis, bei Zwischenstufen inklusive deren Rezeptgeld (rekursiv).
- Gesamtpreis eines Rezepts = `cost + Summe(Preis der Teile)`; die Spalte „Gesamt“ unten ist genau `totalCost()`.
- Das gekaufte Item landet am Ende des Rucksacks (`bag.push`), verbrauchte Teile werden entfernt.
- Teile/Basis-Items (ohne `parts`) kosten ihren vollen `cost`.

### Verbrauchsgegenstand: Heiltrank (Zeile 334, 875)

- Preis 120, Heilung `potionHeal = 40 %` des maximalen Lebens, gemeinsame Abklingzeit `potionCd = 15 s` zwischen zwei Tränken.
- Trinken geht nur, wenn der Held lebt, mindestens 1 Trank da ist, `potCd <= 0` und `hp < maxHp`. Taste F.

## 2. Stat-Schlüssel und ihre Wirkung (`recalcItems`, 826–839)

Alle Stats aller Items im Rucksack werden addiert. Danach:

| Schlüssel | Wirkung | Deckel |
|---|---|---|
| `dmg` | `bonusDmg`; wirkt auf Angriffsschaden und auf `k*hDmg()` der Skills mit Faktor `CFG.adEff[Klasse]` (tank 0.8, damage 1, caster 1) | – |
| `armor` | `bonusArmor` (Rüstung: Schadensverringerung = `armor/(armor+150)`) | – |
| `hp` | `bonusHp` (maximales Leben) | – |
| `as` | `bonusAs`; Angriffstempo = `Basis-as * (1 + bonusAs + Buffs)` | – |
| `sp` | `bonusSp` (Zauberkraft); `hSp()` siehe Skills-Spezifikation (spMul, hpAp) | – |
| `spd` | `bonusSpd` (Lauftempo, plus 40 durch Kampfrausch) | – |
| `crit` | `critCh` = Chance auf kritische **Auto-Angriffe** (Skills kritten nicht, außer Kettenblitz mit eigener Chance) | höchstens 1 |
| `cdr` | `H.cdr`; Abklingzeit eines Skills = `cd * (1 - cdr)` | `cdrCap` 0.40 |
| `regen` | `bonusRegen`: Anteil des max. Lebens pro Sekunde | – |
| `ls` | `lifesteal`: Heilung = verursachter Schaden (nach Rüstung) des normalen Angriffs * ls | 0.5 |
| `sv` | `spellVamp`: Heilung = verursachter Skillschaden * sv * 0.4 (`svFactor`), je getroffenem Ziel | 0.5 |
| `dr` | `H.dr`: eingehender Schaden * (1 − dr), **vor** der Rüstung | `drCap` 0.40 |
| `gps` | `goldPS`: Gold pro Sekunde, wird jeden Frame `G.gold += gps*dt` addiert (zählt in `stats.gold`) | – |
| `bpRed` | Backport-Cast = `4.5 * (1 − bpRed)` Sekunden | 0.8 |

Die fünf früheren Starter-Items (Schwert, Rüstung, Herz, Handschuhe, Stab) wurden am 2026-10-02 entfernt (genug Basisteile vorhanden). Die Bot-Builds nutzen stattdessen Harke, Stoffrüstung, Rubinkristall, Dolch und Wälzer.

## 3. Alle 49 Items

Spalten: `Rezeptgeld` = `cost` im Code, `Gesamt` = `totalCost()` (Rezeptgeld + alle Teile), Stats ohne die einmaligen Effekte.
Zeilen sind nach Gruppe sortiert wie im Code (Zeile = Definition in index.html).

| id | Name | Gruppe | Rezeptgeld | Rezept (Teile) | Gesamt | Stats | unique-Flag | Zeile |
|---|---|---|---|---|---|---|---|---|
| sword | Schwert | basis | 80 | – | 80 | Angriffsschaden 8 | – | 258 |
| armor | Rüstung | basis | 80 | – | 80 | Rüstung 6.5 | – | 259 |
| heart | Herz | basis | 100 | – | 100 | Leben 180 | – | 260 |
| gloves | Handschuhe | basis | 90 | – | 90 | Angriffstempo 0.275 | – | 261 |
| staff | Stab | basis | 110 | – | 110 | Zauberkraft 48 | – | 262 |
| bigSword | Großes Schwert | teil | 300 | – | 300 | Angriffsschaden 50 | – | 264 |
| rake | Harke | teil | 200 | – | 200 | Angriffsschaden 30 | – | 265 |
| critCloak | Crit-Mantel | teil | 200 | – | 200 | Krit-Chance 0.25 | – | 266 |
| bigStaff | Großer Stab | teil | 350 | – | 350 | Zauberkraft 64 | – | 267 |
| cloth | Stoffrüstung | teil | 100 | – | 100 | Rüstung 15 | – | 268 |
| thornArmor | Dornenrüstung | teil | 300 | – | 300 | Rüstung 20 | thorns | 269 |
| windCloak | Windumhang | teil | 250 | – | 250 | Angriffstempo 0.25 | – | 270 |
| timeAmulet | Zeitamulett | teil | 300 | – | 300 | Abklingzeit− 0.15 | – | 271 |
| lifeStone | Lebensstein | teil | 350 | – | 350 | Leben 250 | – | 272 |
| regenBand | Regenerationsband | teil | 250 | – | 250 | Regeneration 0.01 (1 % max. Leben/s) | – | 273 |
| ruby | Rubinkristall | teil | 200 | – | 200 | Leben 150 | – | 274 |
| tome | Wälzer | teil | 200 | – | 200 | Zauberkraft 30 | – | 275 |
| wand | Zauberstab | teil | 250 | – | 250 | Zauberkraft 45 | – | 276 |
| bloodGem | Blutkristall | teil | 220 | – | 220 | Lebensraub 0.10 | – | 277 |
| dagger | Dolch | teil | 180 | – | 180 | Angriffstempo 0.20 | – | 278 |
| spellGem | Zauberblut-Kristall | teil | 220 | – | 220 | Zauberraub 0.10 | – | 279 |
| coinPouch | Münzbeutel | teil | 250 | – | 250 | Gold/s 0.4 | – | 280 |
| hat | Lederhut | hut | 150 | – | 150 | Lauftempo 35 | – | 282 |
| hatWind | Hut des Wirbelwinds | hut | 450 | Lederhut | 600 | Lauftempo 50, Angriffstempo 0.35 | – | 283 |
| hatSage | Hut des Weisen | hut | 450 | Lederhut | 600 | Lauftempo 45, Abklingzeit− 0.10, Zauberkraft 25 | – | 284 |
| hatGuard | Wächterhut | hut | 450 | Lederhut | 600 | Lauftempo 45, Rüstung 25, Schaden− 0.08 | – | 285 |
| hatBlood | Blutroter Hut | hut | 450 | Lederhut | 600 | Lauftempo 45, Leben 100, Lebensraub 0.10, Zauberraub 0.15 | – | 286 |
| hatTravel | Hut des Reisenden | hut | 450 | Lederhut | 600 | Lauftempo 70, Backport-Cast− 0.40 | – | 287 |
| mightyBlade | Mächtige Klinge | fertig | 300 | Großes Schwert + Harke + Crit-Mantel | 1000 | Angriffsschaden 80, Krit-Chance 0.25 | critDmg | 289 |
| arcaneCrown | Zauberkrone | fertig | 300 | 2× Großer Stab | 1000 | Zauberkraft 128 | spMul | 291 |
| strongArmor | Starke Rüstung | zwischen | 100 | 2× Stoffrüstung | 300 | Rüstung 40 | – | 293 |
| thornShirt | Dornenhemd | zwischen | 150 | Stoffrüstung + Dornenrüstung | 550 | Rüstung 35 | thorns | 295 |
| thornPlate | Dornenpanzerweste | fertig | 200 | Starke Rüstung + Dornenhemd | 1050 | Rüstung 85 | thorns | 297 |
| stormBreaker | Sturmbrecher | fertig | 350 | Harke + Crit-Mantel + Windumhang | 1000 | Angriffsschaden 48, Krit-Chance 0.22, Angriffstempo 0.30 | stormCrit | 299 |
| timeStaff | Zeitzauberstab | fertig | 350 | Großer Stab + Zeitamulett | 1000 | Zauberkraft 90, Abklingzeit− 0.20 | comboAmp | 301 |
| titanPlate | Titanenpanzer | fertig | 300 | Stoffrüstung + Lebensstein + Regenerationsband | 1000 | Rüstung 30, Leben 420, Regeneration 0.015 | slowAura | 303 |
| guise | Maske der Erscheinung | zwischen | 150 | Rubinkristall + Wälzer | 550 | Leben 150, Zauberkraft 30 | – | 306 |
| tormentMask | Quälende Maske | fertig | 250 | Zauberstab + Maske der Erscheinung | 1050 | Zauberkraft 75, Leben 150 | torment | 308 |
| cutlass | Entersäbel | zwischen | 130 | Harke + Blutkristall | 550 | Angriffsschaden 35, Lebensraub 0.10 | – | 311 |
| ruinBlade | Schneide des gefallenen Monarchen | fertig | 300 | Entersäbel + Windumhang | 1100 | Angriffsschaden 50, Angriffstempo 0.25, Lebensraub 0.12 | ruin | 313 |
| lifeSpring | Lebensquell-Harnisch | fertig | 300 | Lebensstein + Rubinkristall + Regenerationsband | 1100 | Leben 1000, Regeneration 0.02 | lifeflow | 316 |
| cleaver | Splitteraxt | fertig | 520 | Großes Schwert + Dolch | 1000 | Angriffsschaden 60, Angriffstempo 0.25 | cleave | 319 |
| sparkBlade | Funkenklinge | fertig | 320 | Dolch + Zauberstab + Windumhang | 1000 | Angriffstempo 0.45, Zauberkraft 60, Angriffsschaden 15 | onHitMagic | 321 |
| soulDrinker | Seelentrinker | fertig | 360 | Blutkristall + Zauberblut-Kristall + Rubinkristall | 1000 | Lebensraub 0.12, Zauberraub 0.22, Leben 250, Rüstung 20, Angriffsschaden 40, Zauberkraft 45 | vengeance | 323 |
| bulwark | Eisernes Bollwerk | fertig | 450 | Starke Rüstung + Rubinkristall | 950 | Rüstung 90, Leben 400, Schaden− 0.15 | – | 325 |
| giantsMight | Gigantenschlag | fertig | 350 | Lebensstein + Großes Schwert | 1000 | Angriffsschaden 55, Leben 300 | giants | 327 |
| moonstone | Seelenreif | fertig | 250 | Maske der Erscheinung + Regenerationsband | 1050 | Leben 500, Zauberkraft 60, Regeneration 0.01 | hpAp | 329 |
| merchantChain | Händlerkette | fertig | 300 | 2× Münzbeutel | 800 | Gold/s 1.1, Leben 100 | – | 331 |
| potion | Heiltrank | verbrauch | 120 | – | 120 | – (Heilung 40 % max. Leben) | – | 334 |

Zählung nach Gruppe: basis 5, teil 17, hut 6, zwischen 4, fertig 16, verbrauch 1 = **49**.

## 4. Unique-Effekte (exakt)

Alle Zahlen stehen in `CFG` (Zeile 178–236). `hMaxHp()` = Basis-Leben + Leben pro Level*(Level−1) + `bonusHp`. Mit „Schaden“ ist der Schaden vor der Rüstung des Ziels gemeint, wenn nicht anders angegeben; Rüstung des Ziels wirkt über `reduce(dmg, armor) = dmg * (1 − armor/(armor+150))` (Zeile 427, 589).

### Ablauf eines Auto-Angriffs des Helden (Zeile 984–1014)
Der Held greift an, wenn `H.atkT <= 0` und ein Ziel in Reichweite liegt (Reichweite des Helden + Radius des Ziels; Standardziel = nächster Gegner in Reichweite). Danach `atkT = 1/hAs()`.
1. `dmg = hDmg()`; Krit-Wurf: `Math.random() < critCh` → `dmg *= 2.0 (critDmgBase) + 0.25 (nur mit critDmg)`; bei Krit mit `stormCrit` startet/erneuert der Buff `critAs`.
2. Haupttreffer `hitUnit(tgt, dmg)` (Rüstung des Ziels wirkt). `dealt` = tatsächlich abgezogener Schaden.
3. Lebensraub: `hp += dealt * ls * (vengeance und hp < 40 % ? 2 : 1)`.
4. `onHitMagic`, 5. `giants`, 6. `cleave`, 7. `ruin` (Reihenfolge wie hier; jeweils nur, wenn das Ziel noch lebt), 8. Buff Kampfrausch Rang 5 (Umkreis 75 px, 50 % Schaden).

| Flag | Item | Exakte Wirkung | Code |
|---|---|---|---|
| `thorns` | Dornenrüstung, Dornenhemd, Dornenpanzerweste | Wird der Held von einem Gegner getroffen (`damageHero(dmg, src)` mit `src` in `G.units`), erhält `src` den Schaden `(thornFlat 6 + thornArmorPct 0.10 * bonusArmor) * reflectMul (1.0)` über `hitUnit` (Rüstung des Angreifers wirkt). `bonusArmor` = Rüstung aus **allen** Items (nicht Basiswerte, nicht Eiserne Haut). Einmal pro Treffer, stapelt nicht | 201, 554 |
| `critDmg` | Mächtige Klinge | Krit-Faktor 2.0 → 2.25 | 186, 989 |
| `stormCrit` | Sturmbrecher | Jeder kritische Auto-Treffer setzt den Buff `critAs = {t:3 s, as:+0.40}` (erneuert die Zeit, stapelt nicht). Wirkt additiv im Angriffstempo `hAs = baseAs*(1 + bonusAs + rage.as + critAs.as)` | 188, 991, 423 |
| `comboAmp` | Zeitzauberstab | Beim Wirken eines Skills: ist `comboT > 0`, ist `ampNow = true` und **dieser** Skill macht `dmgOf(...) * 1.30` (alle dmgOf-Aufrufe während des Casts, nicht spätere Timer); danach `comboT = 0`. Ist `comboT <= 0`, setzt der Cast `comboT = 5 s`. `comboT` zählt pro Frame herunter (Zeile 943). Der Effekt greift nur bei erfolgreichen Casts (Rückgabe ≠ false) | 189, 804–811 |
| `torment` | Quälende Maske | Bei jedem Skill-Treffer (`affect`, auch Zonen und Elementar-Fähigkeiten), nach dem Schaden und nur wenn das Ziel noch lebt und `tormCd <= 0`: `tormT = 3 s`, `tormTick = 0.5 s`, `tormDmg = 8 + 0.05*hSp() + 0.006*Ziel.max` (zum Zeitpunkt des Treffers festgelegt), `tormCd = 6 s`. Pro Frame: `tormCd -= dt`; solange `tormT > 0`: `tormT -= dt`, `tormTick -= dt`; bei `tormTick <= 0` → `tormTick += 0.5`, `hp -= tormDmg` (**ignoriert Rüstung**, kein Zauberraub, kein Krit). Ein Ziel kann alle 6 s neu belegt werden (die Dauer 3 s wird nicht verlängert, solange sie läuft) | 191–193, 604–609, 1025–1028 |
| `ruin` | Schneide des gefallenen Monarchen | Nach dem Haupttreffer (wenn das Ziel lebt) zusätzlich `hitUnit(tgt, clamp(0.05 * tgt.hp, 12, 120))`; `tgt.hp` ist der Wert **nach** dem Haupttreffer, Rüstung wirkt (`ruinPct 0.05, ruinMin 12, ruinMax 120`) | 194, 1005 |
| `giants` | Gigantenschlag | Nach dem Haupttreffer (wenn das Ziel lebt) `hitUnit(tgt, 0.025 * hMaxHp())`, Rüstung wirkt | 197, 999 |
| `cleave` | Splitteraxt | Zielposition (tx,ty) vor dem Treffer merken. Alle anderen Gegner mit Abstand ≤ **80** px (Mittelpunkt zu Mittelpunkt, Radius zählt nicht) zum Ziel, die 3 nächsten (`cleaveMax`), erhalten `hitUnit(u, dmg * 0.40)`; `dmg` ist der Schaden des Haupttreffers **inkl. Krit-Faktor**, Rüstung der Ziele wirkt | 197, 1000–1004 |
| `lifeflow` | Lebensquell-Harnisch | `H.dmgT` zählt die Sekunden seit dem letzten `damageHero`-Aufruf (wird dort auf 0 gesetzt, auch bei 0 Schaden und Reflexion; Startwert 99). Ist `dmgT >= 5 s`, wird jeden Frame `hp += hMaxHp * 0.08 * dt` addiert (zusätzlich zur normalen Regeneration; Deckel max. Leben) | 200, 546, 951 |
| `slowAura` | Titanenpanzer | Jeder Gegner, der nicht gerade den Helden/Elementar angreift ("engaged"), ist bei Abstand ≤ **150** px zum lebenden Helden mit Faktor `1 − 0.20 = 0.8` langsamer: `step = spd * (slow>0 ? 0.5 : 1) * aura * dt`. Stapelt multiplikativ mit der Verlangsamung durch Skills | 190, 1050–1051 |
| `vengeance` | Seelentrinker | Liegt `H.hp < 0.4 * hMaxHp()`, wirkt Lebensraub (Auto-Angriff) und Zauberraub (`affect`) doppelt. Der Test erfolgt beim jeweiligen Treffer | 613, 994 |
| `onHitMagic` | Funkenklinge | Nach dem Haupttreffer (wenn das Ziel lebt) `tgt.hp -= 12 + 0.35 * hSp()` (**ignoriert Rüstung**, kein Lebensraub), tötet das Ziel bei hp ≤ 0 | 196, 995–998 |
| `spMul` | Zauberkrone | `hSp() = (bonusSp + hpAp-Anteil) * 1.30` | 187, 425 |
| `hpAp` | Seelenreif | `hSp() = (bonusSp + bonusHp * 0.12 + ...)` — `bonusHp` ist das Leben aus **allen** Items (inkl. Hüte), nicht das Basisleben | 199, 425 |

Andere Effekte ohne Flag:

- **Schaden−** (`dr`): `damageHero`: `dmg *= (1 − H.dr)` vor der Rüstung; Reflexion/Dornen rechnen mit dem ungekürzten `raw`-Schaden (Zeile 543).
- **Regeneration** (`regen`): `hp += hMaxHp * bonusRegen * dt`, immer (Zeile 952), zusätzlich zur Grundregeneration (Basis: 12 % max. Leben/s im Lager (`H.x < 230`), sonst `1.5 + 0.3*Level` pro Sekunde) und der Eisernen Haut des Tanks.
- **Gold/s** (`gps`): jeder Frame `G.gold += gps*dt` (Zeile 918).

## 5. Abweichungen und Auffälligkeiten (nicht geändert, nur gemeldet)

Siehe `docs/spec/skills.md`, Abschnitt „Auffälligkeiten“; Item-spezifisch:

1. Die Beschreibung der Zwischenstufen/Fertig-Items nennt Werte in Prozent (z. B. „+25 % Krit-Chance“); im Code sind es Brüche (0.25). Gleiche Bedeutung.
2. `thornArmor` (ein Teil, 300 g) trägt bereits den Dornen-Effekt. Wer es als Teil im Rucksack hat, hat die Dornen schon.
3. Items sind klassenunabhängig (jeder Held kann jedes Item kaufen). `CAT`/`FIT` (Zeile 338–346) sind nur Anzeige im Shop.
4. `merchantChain` und `coinPouch` zählen `goldPS` zu `G.stats.gold`, nicht zu `kills`.
