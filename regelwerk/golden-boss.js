// Golden Values fuer Boss und Elite-Wellen ueber die Zeit -> regelwerk/golden-boss.json
// Fuer den Godot-Szenario-Runner: gleiche Eingaben, Zahl fuer Zahl vergleichen. Alles laeuft mit dem echten Spielcode aus index.html
// (spawn, spawnWave, bossThink ueber update(), damageHero, hitUnit, affect).
//
// Benutzung (Seite ueber den lokalen Server geoeffnet, serve.ps1 laeuft), in der Konsole:
//   (0,eval)(await (await fetch('/regelwerk/golden-boss.js')).text());
// Standard: speichert per POST /save-golden-boss nach regelwerk/golden-boss.json. Ohne Speichern: window.GOLDEN_SAVE = false; vorher setzen
// (das Ergebnis steht dann in window.GOLDEN_BOSS).
//
// Regeln: dt = 0.05 s, Math.random() fest 0.5 (Spawn-Positionen: x = spawnX + offX + 15, y = 0; Verstaerkung y = 0), Held steht still (greift nicht an),
// hat 1e6 Zusatzleben und ueberlebt, Waehrend der Szenarien kommen keine Wellen (ausser ein Szenario ruft spawnWave auf).
// Ereignisse (events) werden vor dem update() des jeweiligen Schritts ausgefuehrt; Schnappschuesse nach dem update (Schritt 0 = vor dem ersten update).
(async function(){
  const SAVE = (typeof window.GOLDEN_SAVE === 'undefined') ? true : window.GOLDEN_SAVE;
  const DT = 0.05;
  const SNAP_T = [0, 2, 5, 6, 10, 20, 30, 40];
  const SNAP = SNAP_T.map(t => Math.round(t/DT));
  const LAST = SNAP[SNAP.length-1];
  const r3 = x => Math.round(x*1000)/1000;

  function sim(fn){
    const saved = {G, H, cam, mouse, P, E, rnd: Math.random, uh: updateHud, bs: buildShop, bn: buildSend, bk: buildSkills, sm: simMode, tt: toast, ua: uiAlert, run: running};
    const stub = ()=>{};
    try{
      updateHud = buildShop = buildSend = buildSkills = toast = uiAlert = stub; simMode = true; running = false;
      P = makeState('damage'); E = makeState('damage');
      useInst(P); mouse = {x:0, y:0, wx:0, wy:0};
      Math.random = ()=> 0.5;
      P.G.waveT = 1e9; E.G.waveT = 1e9; P.G.lives = 1e9; E.G.lives = 1e9;
      return fn(P, E);
    } finally {
      G = saved.G; H = saved.H; cam = saved.cam; mouse = saved.mouse; P = saved.P; E = saved.E; Math.random = saved.rnd;
      updateHud = saved.uh; buildShop = saved.bs; buildSend = saved.bn; buildSkills = saved.bk; simMode = saved.sm; toast = saved.tt; uiAlert = saved.ua; running = saved.run;
    }
  }

  // Szenario: {id, note, start:'boss'|'wave', wave (nur start 'wave'), bossX, bossFrac, heroX, hero, heroLvl, events:[{t, op, ...}]}
  // events: {op:'frac', f} Boss-Leben auf Anteil f setzen (direkt, ohne Treffer) | {op:'hit', dmg} hitUnit auf den Boss | {op:'stun', s} affect(stun s)
  //         | {op:'slow', s} | {op:'kill'} | {op:'wave'} spawnWave() | {op:'clearGrunts'} alle Grunts entfernen | {op:'heroX', x} Held versetzen
  function run(sc){
    return sim((P,E)=>{
      H = P.H; G = P.G;
      H.bonusHp = 1e6; H.lvl = sc.heroLvl || 5; H.x = sc.heroX; H.y = 0; H.hp = hMaxHp(); H.atkT = 1e9;
      let boss = null;
      if(sc.start === 'boss'){
        spawn('boss', 0, 0, CFG.waveSpeedMul); boss = G.units[0]; boss.x = sc.bossX; boss.y = 0;
        if(sc.bossFrac !== undefined) boss.hp = boss.max * sc.bossFrac;
      } else {
        G.wave = sc.wave - 1; spawnWave(); boss = G.units.find(u=>u.boss) || null;
      }
      const events = (sc.events || []).map(e=>({...e, step:Math.round(e.t/DT)})).sort((a,b)=>a.step-b.step);
      let ei = 0; const snaps = [], log = [];
      let prevStomp = boss ? boss.stompT : 0, prevSummon = boss ? boss.summonT : 0, prevGrunts = G.units.filter(u=>u.type==='grunt').length, prevHp = H.hp, prevPhase = boss ? boss.phase : 0;
      const bossRow = () => boss && G.units.includes(boss) ? {alive:true, x:r3(boss.x), y:r3(boss.y), hp:r3(boss.hp), frac:r3(boss.hp/boss.max), phase:boss.phase, spd:r3(boss.spd), base:r3(boss.base), stompT:r3(boss.stompT), summonT:r3(boss.summonT), stun:r3(boss.stun), slow:r3(boss.slow), atkT:r3(boss.atkT)} : {alive:false};
      const snap = step => ({
        step, t:r3(step*DT), boss:bossRow(),
        grunts:G.units.filter(u=>u.type==='grunt').map(u=>[r3(u.x), r3(u.y), r3(u.hp), r3(u.stun)]),
        others:G.units.filter(u=>u.type!=='grunt' && !u.boss).map(u=>({type:u.type, x:r3(u.x), y:r3(u.y), hp:r3(u.hp), stun:r3(u.stun), slow:r3(u.slow), atkT:r3(u.atkT)})),
        hero:{hp:r3(H.hp), lost:r3(hMaxHp()-H.hp), x:r3(H.x), y:r3(H.y), dead:H.dead>0, deaths:H.deaths},
        gold:r3(G.gold), xp:r3(H.xp), lvl:H.lvl, bossIncome:G.bossIncome, wave:G.wave, bossSpawned:G.bossSpawned,
      });
      for(let step = 0; step <= LAST; step++){
        while(ei < events.length && events[ei].step <= step){
          const e = events[ei++];
          if(e.op === 'frac'){ if(boss) boss.hp = boss.max*e.f; }
          else if(e.op === 'hit'){ if(boss) hitUnit(boss, e.dmg); }
          else if(e.op === 'stun'){ if(boss && G.units.includes(boss)) affect(boss, 0, {stun:e.s}); }
          else if(e.op === 'slow'){ if(boss && G.units.includes(boss)) affect(boss, 0, {slow:e.s}); }
          else if(e.op === 'kill'){ if(boss) hitUnit(boss, 1e12); }
          else if(e.op === 'wave'){ spawnWave(); }
          else if(e.op === 'clearGrunts'){ G.units = G.units.filter(u=>u.type!=='grunt'); }
          else if(e.op === 'heroX'){ H.x = e.x; }
          log.push({step, t:r3(step*DT), event:e.op});
        }
        if(SNAP.includes(step)) snaps.push(snap(step));
        if(step < LAST){
          update(DT);
          if(boss && G.units.includes(boss)){            // Ereignisse erkennen: Stampfen (stompT springt nach oben), Verstaerkung (summonT springt nach oben)
            if(boss.stompT > prevStomp + 1e-9) log.push({step:step+1, t:r3((step+1)*DT), event:'stomp', phase:boss.phase, heroLost:r3(prevHp-H.hp), heroX:r3(H.x), bossX:r3(boss.x)});
            if(boss.summonT > prevSummon + 1e-9){ const n = G.units.filter(u=>u.type==='grunt').length - prevGrunts; log.push({step:step+1, t:r3((step+1)*DT), event:'summon', phase:boss.phase, spawned:n}); }
            if(boss.phase !== prevPhase) log.push({step:step+1, t:r3((step+1)*DT), event:'phase', from:prevPhase, to:boss.phase, spd:r3(boss.spd)});
            prevStomp = boss.stompT; prevSummon = boss.summonT; prevPhase = boss.phase;
          }
          prevGrunts = G.units.filter(u=>u.type==='grunt').length; prevHp = H.hp;
        }
      }
      return {id:sc.id, input:sc, result:{log, snaps}};
    });
  }

  const SC = [];
  const add = o => SC.push({start:'boss', bossX:2965, heroX:1000, ...o});
  // Boss allein, Held weit weg (kein Jagen, kein Stampfen): Zeitverlauf der Phase 1 und Verstaerkung; Boss laeuft zur Basis
  add({id:'boss-allein-held-fern', note:'Boss bei x=2965, Held bei 1000 (ausserhalb Aggro 350): laeuft nach links; Stampfen alle 6 s, Verstaerkung bei 12 s', events:[]});
  // Phasenwechsel durch Leben (direkt gesetzt): Anteile an den Grenzen 0.66 und 0.33
  for(const f of [1, 0.7, 0.67, 0.661, 0.66, 0.5, 0.34, 0.331, 0.33, 0.1])
    add({id:'boss-leben-'+f, note:'Boss startet mit Lebensanteil '+f+' (Phase aus hp/max: > 0.66 → 1, > 0.33 → 2, sonst 3)', bossFrac:f});
  // Phasenwechsel durch Schaden waehrend des Spiels
  add({id:'boss-phase-durch-schaden', note:'Boss-Leben wird per Treffer gesenkt: t=3 auf ~70 %, t=8 auf ~50 %, t=14 auf ~30 % (hitUnit mit Ruestung 20)', events:[
    {t:3, op:'frac', f:0.7}, {t:8, op:'frac', f:0.5}, {t:14, op:'frac', f:0.3}]});
  add({id:'boss-phase-durch-treffer-ruestung', note:'Wie oben, aber mit echten Treffern (Ruestung 20 des Bosses zaehlt): hit 200, 300, 400 in kurzen Abstaenden', events:[
    {t:3, op:'hit', dmg:300}, {t:3.05, op:'hit', dmg:300}, {t:8, op:'hit', dmg:300}, {t:8.05, op:'hit', dmg:300}, {t:14, op:'hit', dmg:300}, {t:14.05, op:'hit', dmg:300}]});
  // Held in Reichweite: Stampfen trifft ab Abstand <= 150+14, Nahkampf des Bosses (Reichweite 46+14)
  add({id:'boss-held-im-stampfradius', note:'Boss bei x=1100, Held bei 1000 (Abstand 100): Stampfen trifft, Boss laeuft zum Helden und greift an', bossX:1100});
  add({id:'boss-held-knapp-ausserhalb', note:'Boss bei x=1170, Held bei 1000 (Abstand 170 > 164): Stampfen trifft zuerst nicht, Boss jagt den Helden', bossX:1170});
  add({id:'boss-held-weit-hinter', note:'Boss bei x=1250, Held bei 1000 (Abstand 250, Held liegt vor dem Boss im Sinne von hx<=40): Boss jagt', bossX:1250});
  add({id:'boss-held-hinter-dem-boss', note:'Held bei x=1300, Boss bei x=1200 (Held hinter dem Boss, hx=100 > 40): Aggro nur bis 110', bossX:1200, heroX:1300});
  add({id:'boss-held-aggro-grenze', note:'Boss bei x=1340, Held bei 1000 (Abstand 340 < 350): Jagen', bossX:1340});
  add({id:'boss-held-aggro-ausserhalb', note:'Boss bei x=1360, Held bei 1000 (Abstand 360 > 350): kein Jagen', bossX:1360});
  add({id:'boss-held-wegversetzt', note:'Boss bei 1100 / Held 1000, bei t=7 Held nach x=500 versetzt', bossX:1100, events:[{t:7, op:'heroX', x:500}]});
  // Betaeubung und Verlangsamung: Boss ×0.3
  add({id:'boss-betaeubung-3s', note:'Betaeubung 3 s bei t=0 und t=4 (Boss: ×0.3 = 0.9 s): Timer stehen waehrend der Betaeubung still', events:[{t:0, op:'stun', s:3}, {t:4, op:'stun', s:3}, {t:8, op:'stun', s:10}]});
  add({id:'boss-betaeubung-im-stampf', note:'Betaeubung kurz vor dem Stampfen (t=4.9), Held im Radius', bossX:1100, events:[{t:4.9, op:'stun', s:5}]});
  add({id:'boss-verlangsamung', note:'Verlangsamung 4 s bei t=1 (halbes Tempo)', events:[{t:1, op:'slow', s:4}]});
  // Tod des Bosses: Gold, XP, Boss-Einkommen
  add({id:'boss-tod', note:'Boss stirbt bei t=5 (Gold 300, XP 400, bossIncome +50); bei t=6 kommt eine Welle: +50 Gold', events:[{t:5, op:'kill'}, {t:6, op:'wave'}]});
  add({id:'boss-tod-nach-verstaerkung', note:'Boss stirbt bei t=15 (Verstaerkung bleibt auf der Lane)', events:[{t:15, op:'kill'}]});
  // Verstaerkung aufraeumen, um die Wiederholung zu sehen
  add({id:'boss-verstaerkung-phase3', note:'Boss in Phase 3 (Leben 0.2): Verstaerkung alle 10 s mit 5 Grunts; Grunts werden bei t=12 entfernt', bossFrac:0.2, events:[{t:12, op:'clearGrunts'}]});
  // Boss-Welle komplett (Welle 20 mit Elites und Grunts) und Elite-Welle 10
  SC.push({id:'bosswelle-20-held-fern', note:'spawnWave() fuer Welle 20: 27 Grunts, 2 Elites, 1 Boss; Held weit weg', start:'wave', wave:20, heroX:1000, events:[]});
  SC.push({id:'bosswelle-20-held-nah', note:'wie oben, Held bei x=2400 (vor der Welle)', start:'wave', wave:20, heroX:2400, events:[]});
  SC.push({id:'elitewelle-10-held-fern', note:'spawnWave() fuer Welle 10: 15 Grunts + 2 Elites; Held weit weg', start:'wave', wave:10, heroX:1000, events:[]});
  SC.push({id:'elitewelle-10-held-nah', note:'Welle 10, Held bei x=2500: Elites und Grunts jagen den Helden', start:'wave', wave:10, heroX:2500, events:[]});
  SC.push({id:'normale-welle-5', note:'Welle 5 (9 Grunts) zum Vergleich der Bewegung', start:'wave', wave:5, heroX:1000, events:[]});


  const out = SC.map(run);
  // Elite-Kill (Gold/XP) als eigener kleiner Fall
  out.push(sim((P,E)=>{
    H = P.H; G = P.G; H.lvl = 1; H.xp = 0; G.gold = 0; spawn('elite', 0, 0, 1); const u = G.units[0]; hitUnit(u, 1e9);
    return {id:'elite-kill', input:{}, result:{gold:r3(G.gold), xp:r3(H.xp), lvl:H.lvl, kills:G.stats.kills}};
  }));
  const data = {
    _hinweis: 'Automatisch erzeugt von regelwerk/golden-boss.js aus index.html. Nicht von Hand aendern.',
    version: VERSION, dt: DT, snapshotZeiten: SNAP_T, bossConfig:{bossWave:CFG.bossWave, bossStompR:CFG.bossStompR, bossStompMul:CFG.bossStompMul, bossStompEvery:CFG.bossStompEvery, bossSummonEvery:CFG.bossSummonEvery, bossSpeedMul:CFG.bossSpeedMul, bossIncome:CFG.bossIncome, eliteEvery:CFG.eliteEvery, eliteCount:CFG.eliteCount},
    scenarios: out,
  };
  window.GOLDEN_BOSS = data;
  const json = JSON.stringify(data);
  let status = 'nicht gespeichert';
  if(SAVE){ const r = await fetch('/save-golden-boss', {method:'POST', body: json}); status = 'gespeichert: HTTP '+r.status; }
  return {szenarien: out.length, bytes: json.length, status};
})();
