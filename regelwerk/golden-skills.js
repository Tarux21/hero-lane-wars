// Golden Values fuer die Skills (und Item-Effekte) aus index.html -> regelwerk/golden-skills.json
// Fuer den Godot-Szenario-Runner: gleiche Eingaben, Zahl fuer Zahl vergleichen.
//
// Benutzung (Seite ueber den lokalen Server geoeffnet, serve.ps1 laeuft, KEINE laufende Partie noetig), in der Konsole:
//   (0,eval)(await (await fetch('/regelwerk/golden-skills.js')).text());
// Standard: speichert per POST /save-golden nach regelwerk/golden-skills.json und gibt eine Kurzfassung zurueck.
// Nur ausgeben, nicht speichern:  window.GOLDEN_SAVE = false;  vor dem eval setzen (das JSON steht dann in window.GOLDEN).
//
// Aufbau jedes Szenarios (siehe docs/spec/skills.md, Abschnitt "Golden Values"):
//   input:  hero, lvl, ranks[4], bonus{sp,dmg,hp,armor,as}, uniq[], cdr, spellVamp, lifesteal, dr, critCh, regen, hpFrac,
//           layout, dummyHp, dummyArmor, dummySpd, rand, auto, casts[{t,slot,mouse:[dx,dy]}], hits[{t,dmg,src}]
//   result: derived (maxHp, armor, dmg, sp, as, spd), castInfo (je Cast: ok, cdNachCast), snaps (Zustand nach 0/0.5/1/2/4/8/12 s)
// Regeln der Simulation: feste Zeitschritte dt = 0.05 s, Math.random() ist fest (rand, Standard 0.5 = nie Krit, stabile Reihenfolge;
// rand = 0 laesst jeden Zufallswurf < Chance gelingen = immer Krit). Held steht bei (1000, 0). Dummys: lane 0, hp = dummyHp,
// Ruestung 0, Tempo 0, Schaden 0 (greifen nicht an, bewegen sich nur durch Rueckstoss). Der Held greift nur an, wenn auto = true.
// Vor jedem Update(dt) werden die faelligen Ereignisse (Casts/Treffer mit t <= aktuelle Zeit) ausgefuehrt, danach der Schnappschuss.
(async function(){
  const SAVE = (typeof window.GOLDEN_SAVE === 'undefined') ? true : window.GOLDEN_SAVE;
  const DT = 0.05, SNAP = [0, 10, 20, 40, 80, 160, 240];      // Schritte -> 0, 0.5, 1, 2, 4, 8, 12 s
  const HX = 1000, HY = 0, DUMMY_HP = 100000;
  const LAYOUTS = {   // Dummy-Positionen relativ zum Helden [dx, dy]
    field: [[60,0],[100,20],[140,-20],[200,0],[260,30],[300,10],[330,-30],[420,0],[-60,0],[60,60]],
    melee: [[30,0],[50,25],[70,-20],[90,10],[30,-85],[60,40]],
  };
  const r3 = x => Math.round(x*1000)/1000;

  function runOne(sc, noCast){
    const saved = {G, H, cam, mouse, P, E, rnd: Math.random, uh: updateHud, bs: buildShop, bn: buildSend, bk: buildSkills, sm: simMode};
    const stub = ()=>{};
    try{
      P = null; E = null; updateHud = buildShop = buildSend = buildSkills = stub; simMode = true;
      const st = makeState(sc.hero); G = st.G; H = st.H; cam = st.cam; mouse = {x:0, y:0, wx:HX+200, wy:HY};
      Math.random = ()=> sc.rand === undefined ? 0.5 : sc.rand;
      const b = sc.bonus || {};
      H.lvl = sc.lvl; H.ranks = sc.ranks.slice(); H.sp = 0;
      H.bonusSp = b.sp||0; H.bonusDmg = b.dmg||0; H.bonusHp = b.hp||0; H.bonusArmor = b.armor||0; H.bonusAs = b.as||0;
      H.uniq = new Set(sc.uniq||[]); H.cdr = sc.cdr||0; H.spellVamp = sc.spellVamp||0; H.lifesteal = sc.lifesteal||0;
      H.dr = sc.dr||0; H.critCh = sc.critCh||0; H.bonusRegen = sc.regen||0;
      H.x = HX; H.y = HY; H.hp = hMaxHp() * (sc.hpFrac === undefined ? 0.5 : sc.hpFrac);
      H.atkT = sc.auto ? 0 : 1e9;
      G.waveT = 1e9;
      const dhp = sc.dummyHp || DUMMY_HP;
      for(const [dx, dy] of LAYOUTS[sc.layout || 'field'])
        G.units.push({type:'grunt', lane:0, x:HX+dx, y:HY+dy, hp:dhp, max:dhp, dmg:0, spd:sc.dummySpd||0, range:0, armor:sc.dummyArmor||0, r:9, atkT:1e9, stun:0, slow:0});
      const derived = {maxHp:r3(hMaxHp()), armor:r3(hArmor()), dmg:r3(hDmg()), sp:r3(hSp()), as:r3(hAs()), spd:r3(hSpd()), reflect:r3(ironPassive().reflect)};

      const ev = [];
      if(!noCast) (sc.casts||[]).forEach(c=>ev.push({t:c.t, k:'cast', slot:c.slot, m:c.mouse||[200,0]}));
      (sc.hits||[]).forEach(h=>ev.push({t:h.t, k:'hit', dmg:h.dmg, src:h.src}));
      ev.sort((a,b)=>a.t-b.t);
      const castInfo = [], snaps = [];
      const snap = t => ({
        t: r3(t),
        hero: {hp:r3(H.hp), x:r3(H.x), y:r3(H.y), dead:H.dead>0, comboT:r3(H.comboT), lastElem:H.lastElem||null, cds:H.cds.map(r3),
               buffs:Object.fromEntries(Object.entries(H.buffs).map(([n,v])=>[n, Object.fromEntries(Object.entries(v).map(([k,x])=>[k, typeof x==='number' ? r3(x) : x]))]))},
        // je Dummy: [Schaden gesamt, Betaeubung Rest, Verlangsamung Rest, Brennen Rest, Brennschaden/s, Blutung Rest, Qual Rest, x, y]
        dummies: G.units.map(u=>[r3(dhp-u.hp), r3(u.stun), r3(u.slow), r3(u.burn||0), r3(u.burnDps||0), r3(u.bleed||0), r3(u.tormT||0), r3(u.x), r3(u.y)]),
        zones: G.zones.map(z=>({x:r3(z.x), y:r3(z.y), r:z.r, t:r3(z.t), dmg:r3(z.dmg), follow:z.follow||null})),
        elems: G.elems.map(e=>({type:e.type, x:r3(e.x), y:r3(e.y), hp:r3(e.hp), t:r3(e.t), sp:r3(e.sp), eRank:e.eRank})),
      });
      let ei = 0; const last = SNAP[SNAP.length-1];
      for(let step = 0; step <= last; step++){
        const now = step*DT;
        while(ei < ev.length && ev[ei].t <= now + 1e-9){
          const e = ev[ei++];
          if(e.k === 'cast'){
            mouse = {x:0, y:0, wx:HX+e.m[0], wy:HY+e.m[1]};
            const before = H.cds[e.slot]; castSlot(e.slot);
            castInfo.push({t:e.t, slot:e.slot, ok: before <= 0 && H.cds[e.slot] > 0, cdAfter:r3(H.cds[e.slot])});
          } else damageHero(e.dmg, e.src === undefined ? null : G.units[e.src]);
        }
        if(SNAP.includes(step)) snaps.push(snap(now));
        if(step < last) update(DT);
      }
      return {derived, castInfo, snaps};
    } finally {
      G = saved.G; H = saved.H; cam = saved.cam; mouse = saved.mouse; P = saved.P; E = saved.E; Math.random = saved.rnd;
      updateHud = saved.uh; buildShop = saved.bs; buildSend = saved.bn; buildSkills = saved.bk; simMode = saved.sm;
    }
  }
  function run(sc){
    const res = runOne(sc, false), ctl = runOne(sc, true);   // ctl: gleiche Lage ohne Casts -> Heilung = hp(mit) - hp(ohne)
    res.snaps.forEach((s,i)=>{ s.hero.heal = r3(s.hero.hp - ctl.snaps[i].hero.hp); });
    return {id:sc.id, input:sc, result:res};
  }

  // ---------- Szenarien ----------
  const SC = [];
  const NAMES = ['q','w','e','r'];
  const MAXR = [5,5,5,1];
  const COMBOS = [['b0',{}], ['sp100',{sp:100}], ['dmg60',{dmg:60}]];
  for(const hero of ['tank','damage','caster']) for(let slot=0; slot<4; slot++){
    if(hero==='tank' && slot===1) continue;          // Eiserne Haut ist passiv -> eigene Szenarien unten
    if(hero==='caster' && slot===3) continue;        // Elementar -> eigene Szenarien unten
    const ranks = slot===3 ? [1] : [1, MAXR[slot]];
    for(const rk of ranks) for(const lvl of [1,15]) for(const [cn, bonus] of COMBOS){
      const rs = [0,0,0,0]; rs[slot] = rk;
      const mouse = (hero==='damage' && slot===2) ? [300,0] : [200,0];   // Sprung: Landung bei +300
      SC.push({id:`${hero}-${NAMES[slot]}-r${rk}-l${lvl}-${cn}`, hero, lvl, ranks:rs, bonus, layout:'field', casts:[{t:0, slot, mouse}]});
    }
  }
  // Kettenblitz: alle Wuerfe = Krit (rand 0) und keiner (Standard oben)
  for(const rk of [1,5]) SC.push({id:`caster-e-r${rk}-l15-sp100-allcrit`, hero:'caster', lvl:15, ranks:[0,0,rk,0], bonus:{sp:100}, layout:'field', rand:0, casts:[{t:0, slot:2}]});
  // Caster-Elementar je Element (zuletzt benutzter Skill Q/W/E, dann R)
  for(const [slot, el] of [[0,'fire'],[1,'frost'],[2,'lightning']]) for(const rk of [1,5]) for(const sp of [0,100]){
    const rs = [1,1,rk,1];
    SC.push({id:`caster-r-${el}-e${rk}-l15-sp${sp}`, hero:'caster', lvl:15, ranks:rs, bonus:{sp}, layout:'field', casts:[{t:0, slot}, {t:0.5, slot:3}]});
  }
  SC.push({id:'caster-r-ohne-vorskill', hero:'caster', lvl:15, ranks:[1,1,1,1], bonus:{sp:0}, layout:'field', casts:[{t:0, slot:3}]});
  // Tank-Passive Eiserne Haut: ein Treffer von 100 Schaden durch Dummy 0 (vor Ruestung), Rang 0..5
  for(const rk of [0,1,2,3,4,5]) for(const lvl of [1,15]) for(const bonusArmor of [0,100])
    SC.push({id:`tank-w-passiv-r${rk}-l${lvl}-arm${bonusArmor}`, hero:'tank', lvl, ranks:[0,rk,0,0], bonus:{armor:bonusArmor}, layout:'field', hpFrac:1, hits:[{t:0, dmg:100, src:0}]});
  // Item-Dornen
  SC.push({id:'tank-dornen-item', hero:'tank', lvl:5, ranks:[0,0,0,0], bonus:{armor:100}, uniq:['thorns'], layout:'field', hpFrac:1, hits:[{t:0, dmg:100, src:0}]});
  SC.push({id:'tank-dornen-item-plus-haut-r5', hero:'tank', lvl:5, ranks:[0,5,0,0], bonus:{armor:100}, uniq:['thorns'], layout:'field', hpFrac:1, hits:[{t:0, dmg:100, src:0}]});
  SC.push({id:'tank-schaden-minus-15', hero:'tank', lvl:5, ranks:[0,0,0,0], bonus:{}, dr:.15, layout:'field', hpFrac:1, hits:[{t:0, dmg:100, src:0}]});
  // Wechselwirkungen mit Items
  SC.push({id:'caster-kombo-zeitzauberstab', hero:'caster', lvl:15, ranks:[3,3,3,0], bonus:{sp:90}, uniq:['comboAmp'], cdr:.2, layout:'field', casts:[{t:0,slot:0},{t:1,slot:1},{t:2,slot:2},{t:3,slot:0}]});
  SC.push({id:'caster-qual-maske', hero:'caster', lvl:15, ranks:[3,0,3,0], bonus:{sp:100}, uniq:['torment'], layout:'field', casts:[{t:0,slot:2},{t:0.5,slot:0}]});
  SC.push({id:'caster-zauberkrone', hero:'caster', lvl:15, ranks:[0,0,3,0], bonus:{sp:128}, uniq:['spMul'], layout:'field', casts:[{t:0,slot:2}]});
  SC.push({id:'caster-seelenreif-hpap', hero:'caster', lvl:15, ranks:[0,0,3,0], bonus:{sp:60, hp:500}, uniq:['hpAp'], layout:'field', casts:[{t:0,slot:2}]});
  SC.push({id:'caster-cdr-40', hero:'caster', lvl:15, ranks:[3,3,3,1], bonus:{}, cdr:.4, layout:'field', casts:[{t:0,slot:0},{t:0,slot:1},{t:0,slot:2},{t:0.5,slot:3}]});
  for(const hero of ['tank','damage','caster']) for(const [cn, vf] of [['zauberraub22', 0.5], ['rachsucht-doppelt', 0.3]])
    SC.push({id:`${hero}-${cn}`, hero, lvl:15, ranks:[3,0,3,0], bonus:{sp:100}, spellVamp:.22, uniq: cn.startsWith('rachsucht') ? ['vengeance'] : [], hpFrac:vf, layout:'field', casts:[{t:0,slot:0},{t:0,slot:2}]});
  // Damage: Kampfrausch (Rang 1/3/5) zusammen mit Auto-Angriffen
  for(const rk of [1,3,5]) SC.push({id:`damage-w-r${rk}-auto`, hero:'damage', lvl:5, ranks:[0,rk,0,0], bonus:{}, layout:'melee', auto:true, casts:[{t:0,slot:1}]});
  // Auto-Angriffe und Item-Effekte (Held lvl 5, Gegner in Nahkampfreichweite)
  const AUTO = [
    ['basis', {}],
    ['krit-ohne-bonus', {critCh:1, rand:0}],
    ['krit-mit-mightyBlade', {critCh:1, rand:0, uniq:['critDmg']}],
    ['sturmbrecher', {critCh:1, rand:0, uniq:['stormCrit'], bonus:{as:.30}}],
    ['lebensraub10', {lifesteal:.10}],
    ['rachsucht-lebensraub', {lifesteal:.12, uniq:['vengeance'], hpFrac:.3}],
    ['funkenklinge', {uniq:['onHitMagic'], bonus:{sp:100}}],
    ['gigantenschlag', {uniq:['giants'], bonus:{hp:300}}],
    ['splitteraxt', {uniq:['cleave']}],
    ['monarch-hoch', {uniq:['ruin']}],
    ['monarch-mittel', {uniq:['ruin'], dummyHp:1000}],
    ['monarch-niedrig', {uniq:['ruin'], dummyHp:100}],
    ['ruestung-gegner-50', {dummyArmor:50}],
  ];
  for(const hero of ['tank','damage','caster']) for(const [n, o] of AUTO)
    SC.push({id:`auto-${hero}-${n}`, hero, lvl:5, ranks:[0,0,0,0], bonus:{}, layout:'melee', auto:true, ...o, bonus:{dmg:20, ...(o.bonus||{})}});
  // Titanenpanzer-Aura: Gegner laufen (Tempo 60) auf den Helden zu; mit Aura 20 % langsamer im Umkreis von 150
  SC.push({id:'aura-ohne', hero:'tank', lvl:5, ranks:[0,0,0,0], bonus:{}, layout:'field', dummySpd:60, hpFrac:1});
  SC.push({id:'aura-titanenpanzer', hero:'tank', lvl:5, ranks:[0,0,0,0], bonus:{}, uniq:['slowAura'], layout:'field', dummySpd:60, hpFrac:1});

  const out = [];
  const t0 = performance.now();
  for(const sc of SC) out.push(run(sc));
  const data = {
    _hinweis: 'Automatisch erzeugt von regelwerk/golden-skills.js aus index.html. Nicht von Hand aendern.',
    version: VERSION, dt: DT, snapshotZeiten: SNAP.map(s=>r3(s*DT)), heldPos:[HX,HY], dummyHp: DUMMY_HP, layouts: LAYOUTS,
    dummyFelder: ['Schaden gesamt','Betaeubung Rest s','Verlangsamung Rest s','Brennen Rest s','Brennschaden/s','Blutung Rest s','Qual Rest s','x','y'],
    scenarios: out,
  };
  window.GOLDEN = data;
  const json = JSON.stringify(data);
  let status = 'nicht gespeichert';
  if(SAVE){ const r = await fetch('/save-golden', {method:'POST', body: json}); status = 'gespeichert: HTTP '+r.status; }
  return {szenarien: out.length, bytes: json.length, ms: Math.round(performance.now()-t0), status};
})();
