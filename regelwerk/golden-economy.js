// Golden Values fuer Wirtschaft, Items (Kaufen/Verkaufen/Rezepte), Item-Effekte und Bot-Plaene -> regelwerk/golden-economy.json
// Fuer den Godot-Szenario-Runner: gleiche Eingaben, Zahl fuer Zahl vergleichen. Alles laeuft mit dem echten Spielcode aus index.html.
//
// Benutzung (Seite ueber den lokalen Server geoeffnet, serve.ps1 laeuft, KEINE laufende Partie noetig), in der Konsole:
//   (0,eval)(await (await fetch('/regelwerk/golden-economy.js')).text());
// Standard: speichert per POST /save-golden-economy nach regelwerk/golden-economy.json. Ohne Speichern: window.GOLDEN_SAVE = false; vorher setzen
// (das Ergebnis steht dann in window.GOLDEN_ECO).
//
// Abschnitte im JSON:  economy (a), items (b), itemEffects (c), bot (d). Beschreibung: docs/spec/economy.md
// Regeln: dt = 0.05 s, Math.random() fest (rand, Standard 0.5), Held steht bei (1000, 0) (ausserhalb der Basis) bzw. bei (120, 0) (in der Basis),
// kein Gegner, keine Welle, ausser ein Szenario sagt etwas anderes.
(async function(){
  const SAVE = (typeof window.GOLDEN_SAVE === 'undefined') ? true : window.GOLDEN_SAVE;
  const DT = 0.05;
  const r3 = x => Math.round(x*1000)/1000;
  const r4 = x => Math.round(x*10000)/10000;

  // ---------- Hilfen: isolierte Spielzustaende ----------
  // Stellt P (Spieler) und E (Gegner) bereit, setzt G/H auf P, ersetzt Oberflaeche/Zufall und stellt danach alles wieder her.
  function sim(opts, fn){
    const o = opts || {};
    const saved = {G, H, cam, mouse, P, E, rnd: Math.random, uh: updateHud, bs: buildShop, bn: buildSend, bk: buildSkills, sm: simMode, tt: toast, ua: uiAlert, run: running};
    const stub = ()=>{};
    try{
      updateHud = buildShop = buildSend = buildSkills = toast = uiAlert = stub; simMode = true; running = false;
      P = makeState(o.hero || 'damage'); E = makeState(o.enemy || 'damage');
      useInst(P); mouse = {x:0, y:0, wx:0, wy:0};
      Math.random = ()=> o.rand === undefined ? 0.5 : o.rand;
      P.G.waveT = 1e9; E.G.waveT = 1e9;                       // keine Wellen, ausser das Szenario will welche
      H.x = o.inBase ? 120 : 1000; H.y = 0; H.atkT = 1e9;     // Held steht still und greift nicht an
      return fn(P, E);
    } finally {
      G = saved.G; H = saved.H; cam = saved.cam; mouse = saved.mouse; P = saved.P; E = saved.E; Math.random = saved.rnd;
      updateHud = saved.uh; buildShop = saved.bs; buildSend = saved.bn; buildSkills = saved.bk; simMode = saved.sm; toast = saved.tt; uiAlert = saved.ua; running = saved.run;
    }
  }
  const derived = () => ({
    maxHp:r3(hMaxHp()), armor:r3(hArmor()), dmg:r3(hDmg()), sp:r3(hSp()), as:r3(hAs()), spd:r3(hSpd()),
    cdr:r3(H.cdr), crit:r3(H.critCh), lifesteal:r3(H.lifesteal), spellVamp:r3(H.spellVamp), dr:r3(H.dr), regen:r3(H.bonusRegen), goldPS:r3(H.goldPS), bpRed:r3(H.bpRed),
    bonus:{dmg:r3(H.bonusDmg), armor:r3(H.bonusArmor), hp:r3(H.bonusHp), as:r3(H.bonusAs), sp:r3(H.bonusSp), spd:r3(H.bonusSpd)},
    uniq:[...H.uniq].sort(),
  });
  const unitRow = u => ({type:u.type, lane:u.lane, x:r3(u.x), y:r3(u.y), hp:r3(u.hp), max:r3(u.max), dmg:r3(u.dmg), spd:r3(u.spd), range:u.range, armor:u.armor, r:u.r});

  // =====================================================================================================
  // (a) WIRTSCHAFT
  // =====================================================================================================
  const economy = {};

  // a1: Einkommen-Tick. Der Held steht still; je Schritt update(0.05). Schnappschuesse nach den angegebenen Schritten.
  economy.incomeTick = (()=>{
    const cases = [
      {id:'basis-24', income:24, goldMul:1, gold:0, lives:[20,20]},
      {id:'income-50', income:50, goldMul:1, gold:100, lives:[20,20]},
      {id:'goldMul-1.12', income:24, goldMul:1.12, gold:0, lives:[20,20]},
      {id:'goldMul-1.5', income:40, goldMul:1.5, gold:0, lives:[20,20]},
      {id:'aufholhilfe-2-leben-zurueck', income:24, goldMul:1, gold:0, lives:[18,20]},      // behind 2 < comebackDiff 3 -> 0 %
      {id:'aufholhilfe-3-leben-zurueck', income:24, goldMul:1, gold:0, lives:[17,20]},      // 3 -> +4 %
      {id:'aufholhilfe-6-leben-zurueck', income:24, goldMul:1, gold:0, lives:[14,20]},      // 6 -> +16 %
      {id:'aufholhilfe-10-leben-zurueck', income:24, goldMul:1, gold:0, lives:[10,20]},     // gedeckelt bei +20 %
      {id:'aufholhilfe-vorne', income:24, goldMul:1, gold:0, lives:[20,10]},                // vorne: 0 %
      {id:'aufholhilfe-gegner-unendlich', income:24, goldMul:1, gold:0, lives:[5,1e9]},     // Gegner unendlich: 0 %
      {id:'aufholhilfe-mit-goldMul', income:30, goldMul:1.3, gold:0, lives:[14,20]},
    ];
    const steps = [100, 199, 200, 201, 202, 400, 401, 402, 600, 601, 602];       // 5 s, 9.95, 10, 10.05, 10.1, 20 s, ..., 30 s
    return cases.map(c=>sim({}, (P,E)=>{
      G.income = c.income; G.goldMul = c.goldMul; G.gold = c.gold; P.G.lives = c.lives[0]; E.G.lives = c.lives[1];
      const snaps = []; let n = 0;
      for(const s of steps){ while(n < s){ update(DT); n++; } snaps.push({step:s, t:r3(s*DT), gold:r4(G.gold), statsGold:r4(G.stats.gold), incomeT:r4(G.incomeT)}); }
      return {id:c.id, input:c, comebackBonus:r4(comebackBonus(P.G)), snaps};
    }));
  })();

  // a2: Monster senden. G ist der Sender (P), das Monster erscheint auf der Lane des Gegners (E.G). hpMult nutzt die Zeit des EMPFAENGERS.
  economy.send = (()=>{
    const out = [];
    const types = ['grunt','tank','archer','fast','elite'];
    for(const t of types) for(const [label, gold] of [['genau', UNITS[t].cost], ['ein-gold-zu-wenig', UNITS[t].cost-1], ['viel', 5000]]) for(const time of [0, 300]){
      out.push(sim({}, (P,E)=>{
        P.G.gold = gold; E.G.t = time; P.G.t = time;
        const before = {gold:P.G.gold, income:P.G.income, units:E.G.units.length};
        send(t);
        return {id:`send-${t}-${label}-t${time}`, input:{type:t, gold, t:time}, result:{
          sent: E.G.units.length > before.units, goldAfter:r3(P.G.gold), incomeAfter:r3(P.G.income), incomeDelta:r3(P.G.income-before.income),
          stats:{sent:{...P.G.stats.sent}}, enemyUnits:E.G.units.map(unitRow), ownUnits:P.G.units.length}};
      }));
    }
    out.push(sim({}, (P,E)=>{      // Folge: mehrere Sendungen, Einkommen summiert sich, Gold sinkt
      P.G.gold = 1000; const log = [];
      for(const t of ['grunt','grunt','tank','archer','fast','elite','elite','grunt']){ send(t); log.push({type:t, gold:r3(P.G.gold), income:r3(P.G.income)}); }
      return {id:'send-folge', input:{gold:1000, folge:['grunt','grunt','tank','archer','fast','elite','elite','grunt']}, result:{log, stats:{sent:{...P.G.stats.sent}}, enemyCount:E.G.units.length}};
    }));
    out.push(sim({}, (P,E)=>{      // incMul 2 (Balance-Regler)
      const old = CFG.incMul; CFG.incMul = 2; try{ P.G.gold = 1000; send('tank'); } finally { CFG.incMul = old; }
      return {id:'send-incMul-2', input:{type:'tank', incMul:2}, result:{goldAfter:r3(P.G.gold), incomeAfter:r3(P.G.income)}};
    }));
    out.push(sim({}, (P,E)=>{      // Spiel vorbei: kein Senden
      P.G.gold = 1000; P.G.over = true; send('grunt');
      return {id:'send-spiel-vorbei', input:{over:true}, result:{goldAfter:P.G.gold, enemyCount:E.G.units.length}};
    }));
    return out;
  })();

  // a3: Skalierung der Monster mit der Zeit (hpMult = 1 + t/60*hpScalePerMin, Schaden 1 + unitDmgScale*(m-1))
  economy.unitScaling = (()=>{
    const times = [0, 60, 300, 600, 900, 1200];
    return times.map(t=>sim({}, (P,E)=>{
      P.G.t = t; const row = {t, hpMult:r4(hpMult()), units:{}};
      for(const type of Object.keys(UNITS)){ P.G.units.length = 0; spawn(type, 0, 0, 1); row.units[type] = unitRow(P.G.units[0]); }
      return row;
    }));
  })();

  // a4: Kill-Gold und XP je Monstertyp (Held Level 1, 0 XP, 0 Gold; Monster mit 1 Leben, ein Schlag toetet es)
  economy.kill = (()=>{
    const out = [];
    for(const hero of ['tank','damage','caster']) for(const type of Object.keys(UNITS)) out.push(sim({hero}, (P,E)=>{
      G.gold = 0; H.xp = 0; H.lvl = 1; H.sp = 1; spawn(type, 0, 0, 1);
      const u = G.units[0]; u.hp = 1; const hp0 = H.hp;
      hitUnit(u, 1e6);
      return {id:`kill-${hero}-${type}`, input:{hero, type}, result:{gold:r3(G.gold), statsGold:r3(G.stats.gold), kills:G.stats.kills, xp:r3(H.xp), lvl:H.lvl, sp:H.sp, hpDelta:r3(H.hp-hp0), bossIncome:G.bossIncome, unitsLeft:G.units.length}};
    }));
    out.push(sim({}, (P,E)=>{      // Monster auf der Gegner-Lane (lane 1) gibt nichts
      spawn('grunt', 1, 0, 1); const u = G.units[0]; u.hp = 1; G.gold = 0; hitUnit(u, 1e6);
      return {id:'kill-lane1', input:{lane:1}, result:{gold:G.gold, xp:H.xp, kills:G.stats.kills}};
    }));
    out.push(sim({}, (P,E)=>{      // Ruestung des Ziels: Schaden = dmg*(1-armor/(armor+150))
      spawn('elite', 0, 0, 1); const u = G.units[0]; const hp0 = u.hp; const d = hitUnit(u, 100);
      return {id:'hit-ruestung-elite', input:{dmg:100, armor:u.armor}, result:{dealt:r4(d), hpAfter:r3(u.hp), hp0:r3(hp0)}};
    }));
    return out;
  })();

  // a5: Level-Kurve und Skillpunkte: gainXp(n) vom Level 1
  economy.levelCurve = (()=>{
    const table = []; let cum = 0;
    for(let l = 1; l < CFG.maxLevel; l++){ cum += xpNeed(l); table.push({lvl:l, xpToNext:xpNeed(l), cumulative:cum}); }
    const gains = [0, 59, 60, 61, 90, 150, 500, 2000, 5000, 100000];
    const runs = [];
    for(const hero of ['tank','damage','caster']) for(const n of gains) runs.push(sim({hero}, (P,E)=>{
      const hp0 = H.hp, max0 = hMaxHp(); gainXp(n);
      return {id:`gainXp-${hero}-${n}`, input:{hero, xp:n}, result:{lvl:H.lvl, xp:r3(H.xp), sp:H.sp, hp:r3(H.hp), hpDelta:r3(H.hp-hp0), maxHp:r3(hMaxHp()), maxHpDelta:r3(hMaxHp()-max0)}};
    }));
    return {xpFormel:'xpNeed(l) = xpBase + xpPer*l', xpBase:CFG.xpBase, xpPer:CFG.xpPer, maxLevel:CFG.maxLevel, table, runs};
  })();

  // a6: Tod und Respawn: letaler Treffer, Respawnzeit je Level
  economy.respawn = (()=>{
    const out = [];
    for(const hero of ['tank','damage','caster']) for(let lvl = 1; lvl <= CFG.maxLevel; lvl++) out.push(sim({hero}, (P,E)=>{
      H.lvl = lvl; H.hp = hMaxHp(); H.buffs = {rage:{t:5, as:.4, spd:40, cleave:false}}; damageHero(1e9, null);
      const dead = H.dead, deaths = H.deaths, buffs = Object.keys(H.buffs).length;
      return {id:`respawn-${hero}-l${lvl}`, input:{hero, lvl}, result:{dead:r3(dead), deaths, buffsAfter:buffs, formel:'respawnBase + respawnPerLevel*lvl = '+(CFG.respawnBase+CFG.respawnPerLevel*lvl)}};
    }));
    out.push(sim({hero:'damage'}, (P,E)=>{      // Wiederbelebung: nach der Zeit hp = max, Position (120, 0)
      H.lvl = 5; H.hp = hMaxHp(); damageHero(1e9, null); const wait = H.dead; const rows = [];
      for(let s = 0; s <= Math.round(wait/DT)+2; s++){ if(s === Math.round(wait/DT)-1 || s === Math.round(wait/DT) || s === Math.round(wait/DT)+1) rows.push({step:s, dead:r4(H.dead), hp:r3(H.hp), x:r3(H.x), y:r3(H.y)}); update(DT); }
      return {id:'respawn-ablauf-damage-l5', input:{lvl:5}, result:{wait:r3(wait), rows}};
    }));
    return out;
  })();

  // a7: Wellen: update() mit leerer Lane (nach jedem Schritt werden die Monster entfernt), Aufzeichnung jedes Wellen-Spawns
  economy.waves = (()=>{
    return sim({}, (P,E)=>{
      P.G.waveT = CFG.firstWave; P.G.lives = 1e9; E.G.lives = 1e9;
      const rows = []; let lastWave = 0; let steps = 0; const maxSteps = Math.round(1000/DT);
      while(P.G.wave < 30 && steps < maxSteps){
        const before = P.G.gold;
        update(DT); steps++;
        if(P.G.wave !== lastWave){
          lastWave = P.G.wave;
          const byType = {}; for(const u of P.G.units) byType[u.type] = (byType[u.type]||0) + 1;
          const xs = P.G.units.map(u=>u.x);
          rows.push({wave:P.G.wave, step:steps, t:r3(P.G.t), kind:waveKind(P.G.wave+0) , counts:byType, firstGruntX:r3(P.G.units.find(u=>u.type==='grunt').x), lastX:r3(Math.max(...xs)), minX:r3(Math.min(...xs)),
            gruntHp:r3(P.G.units.find(u=>u.type==='grunt').hp), gruntSpd:r3(P.G.units.find(u=>u.type==='grunt').spd), gruntDmg:r3(P.G.units.find(u=>u.type==='grunt').dmg),
            bossSpawned:P.G.bossSpawned, nextWaveIn:r3(P.G.waveT)});
        }
        P.G.units.length = 0;
      }
      return {note:'kind = waveKind(wave) NACH dem Spawn: fuer Welle 20 ist bossSpawned dann schon true; die tatsaechlichen Typen stehen in counts', waves:rows, totalSteps:steps};
    });
  })();
  // a7b: Boss-Einkommen: nach dem Boss-Kill +bossIncome Gold pro Welle
  economy.bossIncome = sim({}, (P,E)=>{
    P.G.lives = 1e9; spawn('boss', 0, 0, 1); const u = G.units[0]; u.hp = 1; G.gold = 0; hitUnit(u, 1e6);
    const afterKill = {gold:r3(G.gold), bossIncome:G.bossIncome, xp:r3(H.xp), lvl:H.lvl};
    G.gold = 0; G.waveT = 0; update(DT);   // naechste Welle: +bossIncome Gold
    return {afterKill, goldAfterNextWave:r3(G.gold), wave:G.wave, bossIncome:G.bossIncome};
  });

  // =====================================================================================================
  // (b) ITEMS: Kaufen, Verkaufen, Rezepte, Hut-Regel, Rucksack, Heiltrank als Folge von Aktionen
  // =====================================================================================================
  // Aktionen: {a:'buy', id} | {a:'sell', i} | {a:'potion'} | {a:'wait', s} (Sekunden, in 0.05-Schritten) | {a:'gold', v} | {a:'pos', base:true|false}
  //           | {a:'hp', frac} (Leben = Anteil von maxHp) | {a:'lvl', v} | {a:'over'} (Spiel vorbei)
  // Nach jeder Aktion: ok, reason (buyReason vor dem Kauf), gold, bag, cons, potCd, hp, derived.
  const items = [];
  const ITEM_CASES = [];
  const IC = (id, note, hero, gold, actions, o) => ITEM_CASES.push({id, note, hero, gold, actions, ...(o||{})});
  const B = id => ({a:'buy', id});
  IC('basis-items', 'Basis-Items kaufen (Preise 80/80/100/90/110), Werte aus CFG.itemPower', 'damage', 1000, ['sword','armor','heart','gloves','staff'].map(B));
  IC('ausserhalb-basis', 'Kaufen und Verkaufen nur in der Basis', 'damage', 1000, [{a:'pos', base:false}, B('sword'), {a:'sell', i:0}, {a:'pos', base:true}, B('sword'), {a:'pos', base:false}, {a:'sell', i:0}, {a:'pos', base:true}, {a:'sell', i:0}]);
  IC('mightyBlade-ohne-teile', 'Rezept ohne Teile im Rucksack: Rezeptgeld 300 + Teile 300+200+200 = 1000; mit 999 Gold geht es nicht', 'damage', 999, [B('mightyBlade'), {a:'gold', v:1000}, B('mightyBlade')]);
  IC('mightyBlade-mit-teilen', 'Teile einzeln kaufen, dann kombinieren: nur Rezeptgeld 300', 'damage', 1000, [B('bigSword'), B('rake'), B('critCloak'), B('mightyBlade')]);
  IC('mightyBlade-teilweise', 'Nur die Harke im Rucksack: Preis 300 + 300 + 200 = 800', 'damage', 1000, [B('rake'), B('mightyBlade')]);
  IC('arcaneCrown-ein-stab', 'Ein Grosser Stab vorhanden: Kronen-Rezept 300 + zweiter Stab 350', 'caster', 1000, [B('bigStaff'), B('arcaneCrown')]);
  IC('thornPlate-ketten', 'Verschachtelt: Dornenpanzerweste = 200 + strongArmor(100+2*100) + thornShirt(150+100+300) = 1050; danach mit Zwischenstufen im Rucksack', 'tank', 5000,
     [B('thornPlate'), {a:'sell', i:0}, B('cloth'), B('thornArmor'), B('thornShirt'), B('strongArmor'), B('thornPlate')]);
  IC('zwischenstufe-reihenfolge', 'strongArmor aus 2 Stoffruestungen: Rezeptgeld 100; bag-Reihenfolge nach Kauf', 'tank', 1000, [B('cloth'), B('heart'), B('cloth'), B('strongArmor')]);
  IC('hut-aufwerten', 'Lederhut 150, dann Spezialhut 450 (verbraucht den Lederhut); ein zweiter Hut wird abgelehnt', 'damage', 3000, [B('hat'), B('hatWind'), B('hatSage'), B('hat')]);
  IC('hut-direkt', 'Spezialhut ohne Lederhut: 450 + 150 = 600', 'caster', 1000, [B('hatSage')]);
  IC('hut-blockiert-spezialhut', 'Mit Spezialhut im Rucksack kein weiterer Hut, auch kein Lederhut', 'tank', 3000, [B('hatGuard'), B('hat'), B('hatBlood')]);
  IC('rucksack-voll', '6 Plaetze: der 7. Gegenstand wird abgelehnt; ein Rezept, das 2 Teile verbraucht, geht bei vollem Rucksack (6-2+1=5)', 'tank', 5000,
     [B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('strongArmor'), B('heart'), B('heart'), B('heart')]);
  IC('rucksack-voll-trank', 'Heiltraenke zaehlen nicht zum Rucksack (eigene Slots, max. 5 je Sorte)', 'tank', 5000,
     [B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('cloth'), B('potion'), B('potion'), B('potion'), B('potion'), B('potion'), B('potion')]);
  IC('trank-trinken', 'F: 40 % maxHp, 15 s Abklingzeit; nicht bei vollem Leben; nicht ohne Trank', 'damage', 1000,
     [{a:'potion'}, B('potion'), B('potion'), {a:'pos', base:false}, {a:'hp', frac:1}, {a:'potion'}, {a:'hp', frac:.5}, {a:'potion'}, {a:'potion'}, {a:'hp', frac:.5}, {a:'wait', s:14.9}, {a:'potion'}, {a:'wait', s:0.1}, {a:'potion'}]);
  IC('trank-hp-obergrenze', 'Heilung hoechstens bis maxHp', 'tank', 1000, [B('potion'), {a:'pos', base:false}, {a:'hp', frac:.8}, {a:'potion'}]);
  IC('verkaufen-70-prozent', 'Verkaufspreis = floor(0.7 * totalCost): Teil 70 %, fertiges Item (Gesamtpreis inkl. Rezept und Teile), Hut', 'damage', 3000,
     [B('cloth'), B('mightyBlade'), B('hat'), B('hatWind'), {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:5}]);
  IC('verkaufen-ungerade', 'floor(0.7*Gesamtpreis) in Double: Entersaebel 550 -> 385, Dolch 180 -> 125 (nicht 126: 0.7*180 = 125.99999999999999), Blutkristall 220 -> 154', 'damage', 3000, [B('cutlass'), B('dagger'), {a:'sell', i:1}, {a:'sell', i:0}]);
  IC('unique-stapelt-nicht', 'Zwei Dornen-Items: Ruestung stapelt (20+35), Effekt `thorns` nur einmal', 'tank', 3000, [B('thornArmor'), B('thornShirt')]);
  IC('obergrenzen', 'Deckel: cdr 0.40, Lebensraub 0.5, Zauberraub 0.5, Schaden- 0.40, Krit 1.0', 'damage', 40000,
     [B('timeAmulet'), B('timeAmulet'), B('timeAmulet'), {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0},
      B('bloodGem'), B('bloodGem'), B('bloodGem'), B('bloodGem'), B('bloodGem'), B('bloodGem'), {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0},
      B('spellGem'), B('spellGem'), B('spellGem'), B('spellGem'), B('spellGem'), B('spellGem'), {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0},
      B('bulwark'), B('bulwark'), B('bulwark'), B('hatGuard'), {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0}, {a:'sell', i:0},
      B('critCloak'), B('critCloak'), B('critCloak'), B('critCloak'), B('critCloak')]);
  IC('leben-heilt-beim-kauf', 'Steigt maxHp durch einen Kauf, steigt hp um denselben Betrag (hoechstens bis max)', 'tank', 3000,
     [{a:'hp', frac:.5}, B('lifeStone'), B('heart'), {a:'hp', frac:1}, B('ruby')]);
  IC('verkauf-senkt-max-leben', 'Verkauf senkt maxHp; hp wird nicht automatisch gesenkt (nur durch Obergrenze im naechsten Frame)', 'tank', 3000,
     [B('lifeStone'), {a:'hp', frac:1}, {a:'sell', i:0}, {a:'wait', s:0.05}]);
  IC('spiel-vorbei', 'Nach Spielende kein Kauf', 'damage', 1000, [{a:'over'}, B('sword')]);
  IC('level-skaliert-werte', 'Abgeleitete Werte je Level mit Items (Level 15, Damage mit mightyBlade + hatWind)', 'damage', 5000,
     [{a:'lvl', v:15}, B('mightyBlade'), B('hatWind'), B('heart')]);
  IC('verbrauch-obergrenze-kauf', 'Trank-Vorrat: beim 6. Kauf Fehlermeldung, Gold bleibt', 'caster', 2000, [B('potion'), B('potion'), B('potion'), B('potion'), B('potion'), B('potion')]);
  for(const c of ITEM_CASES) items.push(sim({hero:c.hero, inBase:true}, (P,E)=>{
    G.gold = c.gold; H.hp = hMaxHp();
    const log = []; const stepRow = (act, ok, reason) => ({...act, ok, reason, gold:r3(G.gold), bag:H.bag.slice(), cons:{...H.cons}, potCd:r3(H.potCd), hp:r3(H.hp), maxHp:r3(hMaxHp()), derived:derived()});
    for(const act of c.actions){
      let ok = null, reason = '';
      if(act.a === 'buy'){ reason = buyReason(act.id); ok = buy(act.id); }
      else if(act.a === 'sell'){ const g0 = G.gold, n0 = H.bag.length; sell(act.i); ok = H.bag.length < n0; reason = ok ? 'erloes '+r3(G.gold-g0) : (H.bag[act.i] ? 'nur in der Basis' : 'kein Item'); }
      else if(act.a === 'potion'){ ok = drinkPotion(); }
      else if(act.a === 'wait'){ const n = Math.round(act.s/DT); for(let k = 0; k < n; k++) update(DT); ok = true; }
      else if(act.a === 'gold'){ G.gold = act.v; ok = true; }
      else if(act.a === 'pos'){ H.x = act.base ? 120 : 1000; ok = true; reason = inBase() ? 'in der Basis' : 'ausserhalb'; }
      else if(act.a === 'hp'){ H.hp = hMaxHp()*act.frac; ok = true; }
      else if(act.a === 'lvl'){ H.lvl = act.v; ok = true; }
      else if(act.a === 'over'){ G.over = true; ok = true; }
      log.push(stepRow(act, ok, reason));
    }
    return {id:c.id, input:{note:c.note, hero:c.hero, gold:c.gold, actions:c.actions}, steps:log};
  }));

  // =====================================================================================================
  // (c) ITEM-EFFEKTE mit echtem Rucksack (recalcItems): Auto-Angriffe, Skills und Treffer, 12 s in 0.05-Schritten
  // =====================================================================================================
  // Eingaben je Szenario: hero, lvl, ranks, bag (Item-IDs, danach recalcItems), layout (melee|field), dummyHp/dummySpd/dummyArmor, rand, hpFrac,
  // auto (Held greift an), casts [{t, slot, mouse}], hits [{t, dmg, src}]. Dummys wie in golden-skills (Radius 9, Rüstung 0, Tempo 0, Schaden 0).
  const LAYOUTS = {
    field: [[60,0],[100,20],[140,-20],[200,0],[260,30],[300,10],[330,-30],[420,0],[-60,0],[60,60]],
    melee: [[30,0],[50,25],[70,-20],[90,10],[30,-85],[60,40]],
  };
  const SNAP = [0, 10, 20, 40, 80, 160, 240];
  function runItemScenario(sc){
    return sim({hero:sc.hero, rand:sc.rand}, (P,E)=>{
      H.lvl = sc.lvl; H.ranks = sc.ranks.slice(); H.sp = 0; H.x = 1000; H.y = 0;
      H.bag = sc.bag.slice(); recalcItems();
      H.hp = hMaxHp() * (sc.hpFrac === undefined ? 0.5 : sc.hpFrac); H.atkT = sc.auto ? 0 : 1e9;
      const dhp = sc.dummyHp || 100000;
      LAYOUTS[sc.layout || 'melee'].forEach(([dx, dy], gid) =>
        G.units.push({gid, type:'grunt', lane:0, x:1000+dx, y:dy, hp:dhp, max:dhp, dmg:0, spd:sc.dummySpd||0, range:0, armor:sc.dummyArmor||0, r:9, atkT:1e9, stun:0, slow:0}));
      const start = derived();
      const ev = [];
      (sc.casts||[]).forEach(c=>ev.push({t:c.t, k:'cast', slot:c.slot, m:c.mouse||[200,0]}));
      (sc.hits||[]).forEach(h=>ev.push({t:h.t, k:'hit', dmg:h.dmg, src:h.src}));
      ev.sort((a,b)=>a.t-b.t);
      const castInfo = [], snaps = [];
      const snap = t => ({
        t:r3(t),
        hero:{hp:r3(H.hp), lvl:H.lvl, xp:r3(H.xp), gold:r3(G.gold), kills:G.stats.kills, x:r3(H.x), y:r3(H.y), dmgT:r3(H.dmgT), comboT:r3(H.comboT), cds:H.cds.map(r3), as:r3(hAs()),
              buffs:Object.fromEntries(Object.entries(H.buffs).map(([n,v])=>[n, Object.fromEntries(Object.entries(v).map(([k,x])=>[k, typeof x==='number' ? r3(x) : x]))]))},
        dummyIds:G.units.map(u=>u.gid),
        dummies:G.units.map(u=>[r3(dhp-u.hp), r3(u.stun), r3(u.slow), r3(u.burn||0), r3(u.burnDps||0), r3(u.bleed||0), r3(u.tormT||0), r3(u.x), r3(u.y)]),
        zones:G.zones.length, elems:G.elems.map(e=>({type:e.type, hp:r3(e.hp), t:r3(e.t)})),
      });
      let ei = 0; const last = SNAP[SNAP.length-1];
      for(let step = 0; step <= last; step++){
        const now = step*DT;
        while(ei < ev.length && ev[ei].t <= now + 1e-9){
          const e = ev[ei++];
          if(e.k === 'cast'){ mouse = {x:0, y:0, wx:1000+e.m[0], wy:e.m[1]}; const b0 = H.cds[e.slot]; castSlot(e.slot); castInfo.push({t:e.t, slot:e.slot, ok:b0 <= 0 && H.cds[e.slot] > 0, cdAfter:r3(H.cds[e.slot])}); }
          else damageHero(e.dmg, e.src === undefined ? null : G.units[e.src]);
        }
        if(SNAP.includes(step)) snaps.push(snap(now));
        if(step < last) update(DT);
      }
      return {id:sc.id, input:sc, result:{derived:start, castInfo, snaps}};
    });
  }
  const itemEffects = [];
  const ITEM_HERO = {mightyBlade:'damage', stormBreaker:'damage', ruinBlade:'damage', cleaver:'damage', cutlass:'damage', sparkBlade:'damage', soulDrinker:'damage', merchantChain:'damage',
    arcaneCrown:'caster', timeStaff:'caster', tormentMask:'caster', moonstone:'caster', guise:'caster',
    thornPlate:'tank', thornShirt:'tank', titanPlate:'tank', lifeSpring:'tank', bulwark:'tank', strongArmor:'tank', giantsMight:'tank',
    hatWind:'damage', hatSage:'caster', hatGuard:'tank', hatBlood:'damage', hatTravel:'damage'};
  const baseRun = (id, hero, bag, o) => ({id, hero, lvl:8, ranks:[3,3,3,0], bag, layout:'melee', auto:true,
    casts:[{t:0, slot:0}, {t:1, slot:2}, {t:3, slot:1}], hits:[{t:0, dmg:100, src:0}, {t:7, dmg:100, src:1}], ...(o||{})});
  for(const [id, hero] of Object.entries(ITEM_HERO)) itemEffects.push(runItemScenario(baseRun('item-'+id, hero, [id])));
  // Zusatzvarianten fuer Zufall/Dummy-Eigenschaften
  for(const id of ['mightyBlade','stormBreaker']) itemEffects.push(runItemScenario(baseRun('item-'+id+'-allcrit', 'damage', [id], {rand:0, casts:[], hits:[]})));
  itemEffects.push(runItemScenario(baseRun('item-critCloak-allcrit', 'damage', ['critCloak'], {rand:0, casts:[], hits:[]})));
  for(const dh of [100, 1000, 100000]) itemEffects.push(runItemScenario(baseRun('item-ruinBlade-dummyHp'+dh, 'damage', ['ruinBlade'], {dummyHp:dh, casts:[], hits:[]})));
  itemEffects.push(runItemScenario(baseRun('item-titanPlate-aura-bewegt', 'tank', ['titanPlate'], {layout:'field', auto:false, dummySpd:60, casts:[], hits:[], hpFrac:1})));
  itemEffects.push(runItemScenario(baseRun('item-ohne-titanPlate-bewegt', 'tank', [], {layout:'field', auto:false, dummySpd:60, casts:[], hits:[], hpFrac:1})));
  itemEffects.push(runItemScenario(baseRun('item-lifeSpring-lebensfluss', 'tank', ['lifeSpring'], {auto:false, casts:[], hits:[{t:0, dmg:200, src:0}], hpFrac:.4})));
  itemEffects.push(runItemScenario(baseRun('item-ohne-items-damage', 'damage', [], {})));
  itemEffects.push(runItemScenario(baseRun('item-ohne-items-caster', 'caster', [], {})));
  itemEffects.push(runItemScenario(baseRun('item-ohne-items-tank', 'tank', [], {})));
  // Bauplaene der Bots (Rucksack durch echte Kaeufe mit unbegrenztem Gold)
  const planBag = (hero, plan) => sim({hero, inBase:true}, (P,E)=>{
    G.gold = 1e9; const I = {b:{step:0}, build:plan}; botShop(I); return H.bag.slice();
  });
  const plans = [['standard', BOT_BUILD]];
  for(const hero of Object.keys(BOT_POOL)) BOT_POOL[hero].forEach((pl,i)=>plans.push([hero+'-pool'+i, null, hero, pl]));
  for(const hero of Object.keys(BOT_BUILD)) itemEffects.push(runItemScenario(baseRun('plan-'+hero+'-standard', hero, planBag(hero, BOT_BUILD[hero]), {lvl:10})));
  for(const [name, , hero, pl] of plans.slice(1)) itemEffects.push(runItemScenario(baseRun('plan-'+name, hero, planBag(hero, pl), {lvl:10})));

  // Preistabelle aller Items: Rezeptgeld, Gesamtpreis, Kaufpreis aus leerem Rucksack, Verkaufspreis (floor(0.7 * Gesamtpreis), Double-Rechnung wie im Prototyp)
  const priceTable = ITEM_LIST.map(i=>({id:i.id, group:i.group, cost:i.cost, total:totalCost(i.id), buyFromEmpty:i.consumable ? i.cost : resolveBuy(i.id, []).cost, sell:Math.floor(totalCost(i.id)*CFG.sellRatio), sellRaw:totalCost(i.id)*CFG.sellRatio}));
  // =====================================================================================================
  const data = {
    _hinweis: 'Automatisch erzeugt von regelwerk/golden-economy.js aus index.html. Nicht von Hand aendern.',
    version: VERSION, dt: DT,
    economy, items, itemEffects, priceTable,
  };
  window.GOLDEN_ECO = data;
  const json = JSON.stringify(data);
  let status = 'nicht gespeichert';
  if(SAVE){ const r = await fetch('/save-golden-economy', {method:'POST', body: json}); status = 'gespeichert: HTTP '+r.status; }
  return {bytes: json.length, status, sections:Object.keys(data).filter(k=>!k.startsWith('_'))};
})();
