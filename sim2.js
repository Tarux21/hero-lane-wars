// PvP-Balancing-Simulation mit dem Bot aus dem Spiel (botStep in index.html).
// Zwei Instanzen (A = "Spieler", B = "Gegner"), beide vom Bot gesteuert, jeweils mit eigener Schwierigkeit.
// Benutzung: (0,eval)(await (await fetch('/sim2.js')).text()); duels('tank','damage',16,{diff:['normal','normal']})
(function(){
  const stub = ()=>{};
  const orig = {updateHud, buildShop, buildSend, buildSkills};

  function makeInst(heroKey, diffKey){
    const I = makeState(heroKey);
    I.diff = DIFF[diffKey]; I.G.goldMul = I.diff.goldMul; I.H.mul = I.diff.heroMul;
    I.b = {mode:'fight', step:0, trips:0, deaths:0, deathTimes:[], wasDead:false, clock:0, lastSend:0};
    I.leaks = {}; I.tl = [];
    return I;
  }
  const rnd = Math.random;

  window.duel = function(keyA, keyB, o={}){
    const maxT = o.maxT || 1800, dt = .05, diff = o.diff || ['normal','normal'];
    updateHud = buildShop = buildSend = buildSkills = stub; simMode = true;   // kein Sound/Wackeln in der Simulation
    const A = makeInst(keyA, diff[0]), B = makeInst(keyB, diff[1]);
    if(o.build){ A.build = o.build[0] ? BOT_VARIANTS[o.build[0]] : undefined; B.build = o.build[1] ? BOT_VARIANTS[o.build[1]] : undefined; }   // Bauplan je Seite (Schlüssel aus BOT_VARIANTS)
    P = A; E = B; let lastMin = 0;
    while(A.G.t < maxT){
      const order = rnd()<.5 ? [[A,B],[B,A]] : [[B,A],[A,B]];
      for(const [I,O] of order) botStep(I,O,dt);
      for(const [I] of order){ useInst(I); update(dt); }
      if(A.G.lives<=0 || B.G.lives<=0) break;
      if(A.G.t/60 >= lastMin+1){ lastMin++; for(const I of [A,B]) I.tl.push({min:lastMin, lives:I.G.lives, lvl:I.H.lvl, gold:Math.round(I.G.gold), inc:+I.G.income.toFixed(1)}); }
    }
    let winner;
    if(A.G.lives<=0 && B.G.lives<=0) winner='draw'; else if(A.G.lives<=0) winner='B'; else if(B.G.lives<=0) winner='A';
    else winner = A.G.lives===B.G.lives ? 'draw' : (A.G.lives>B.G.lives ? 'A' : 'B');
    const pack = (I,k,d)=>({hero:k, diff:d, lives:I.G.lives, lvl:I.H.lvl, deaths:I.b.deaths, trips:I.b.trips, inc:+I.G.income.toFixed(1), tl:I.tl});
    const res = {winner, time:Math.round(A.G.t), timeout:(A.G.lives>0 && B.G.lives>0), A:pack(A,keyA,diff[0]), B:pack(B,keyB,diff[1])};
    updateHud = orig.updateHud; buildShop = orig.buildShop; buildSend = orig.buildSend; buildSkills = orig.buildSkills; running = false; simMode = false;
    return res;
  };

  // Mehrere Partien: Siegquote von A in % (Unentschieden = 0,5)
  window.duels = function(keyA, keyB, n=10, o={}){
    let wa=0, draws=0, tsum=0, to=0;
    for(let i=0;i<n;i++){ const r = duel(keyA,keyB,o); if(r.winner==='A') wa++; else if(r.winner==='draw') draws++; tsum += r.time; if(r.timeout) to++; }
    return {A:keyA, B:keyB, n, winA:+((wa+draws/2)/n*100).toFixed(0), draws, avgTime:Math.round(tsum/n), timeouts:to};
  };
})();

