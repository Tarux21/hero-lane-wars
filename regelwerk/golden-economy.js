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
  const data = {
    _hinweis: 'Automatisch erzeugt von regelwerk/golden-economy.js aus index.html. Nicht von Hand aendern.',
    version: VERSION, dt: DT,
    economy,
  };
  window.GOLDEN_ECO = data;
  const json = JSON.stringify(data);
  let status = 'nicht gespeichert';
  if(SAVE){ const r = await fetch('/save-golden-economy', {method:'POST', body: json}); status = 'gespeichert: HTTP '+r.status; }
  return {bytes: json.length, status, sections:Object.keys(data).filter(k=>!k.startsWith('_'))};
})();
