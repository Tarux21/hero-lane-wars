// Balancing-Hilfen: Rahmenbaupläne je Klasse + Messfunktionen.
// Benutzung: (0,eval)(await (await fetch('/sim2.js')).text()); (0,eval)(await (await fetch('/bal.js')).text()); tune(); measure('damage',['dStorm'],'dStd',20)
(function(){
  const FD=['gloves','heart','potion','sword','potion'], FC=['heart','staff','potion','gloves','potion'], FT=['heart','potion','heart','potion'];
  const B={}, add=(k,a)=>B[k]=a;
  add('dStd',['bigSword','rake','critCloak','mightyBlade','hat','hatWind',...FD]);
  add('dStorm',['rake','critCloak','windCloak','stormBreaker','hat','hatWind',...FD]);
  add('dRuin',['rake','bloodGem','cutlass','windCloak','ruinBlade','hat','hatWind',...FD]);
  add('dCleave',['bigSword','dagger','cleaver','hat','hatWind',...FD]);
  add('dVamp',['bloodGem','spellGem','ruby','soulDrinker','hat','hatWind',...FD]);
  add('dGiant',['lifeStone','bigSword','giantsMight','hat','hatWind',...FD]);
  add('dSpark',['dagger','wand','windCloak','sparkBlade','hat','hatWind',...FD]);
  add('dGold',['coinPouch','coinPouch','merchantChain','bigSword','rake','critCloak','mightyBlade','hat','hatWind','heart','potion','potion']);
  add('dHatBlood',['bigSword','rake','critCloak','mightyBlade','hat','hatBlood',...FD]);
  add('dHatTravel',['bigSword','rake','critCloak','mightyBlade','hat','hatTravel',...FD]);
  add('dHatGuard',['bigSword','rake','critCloak','mightyBlade','hat','hatGuard',...FD]);
  add('cStd',['bigStaff','bigStaff','arcaneCrown','hat','hatSage',...FC]);
  add('cTime',['bigStaff','timeAmulet','timeStaff','hat','hatSage',...FC]);
  add('cMask',['wand','ruby','tome','guise','tormentMask','hat','hatSage',...FC]);
  add('cSpark',['dagger','wand','windCloak','sparkBlade','hat','hatSage',...FC]);
  add('cSparkWind',['dagger','wand','windCloak','sparkBlade','hat','hatWind',...FC]);
  add('cVamp',['bloodGem','spellGem','ruby','soulDrinker','hat','hatSage',...FC]);
  add('cVampHat',['bloodGem','spellGem','ruby','soulDrinker','hat','hatBlood',...FC]);
  add('cMoon',['ruby','tome','guise','regenBand','moonstone','hat','hatSage',...FC]);
  add('cHatBlood',['bigStaff','bigStaff','arcaneCrown','hat','hatBlood',...FC]);
  add('cHatGuard',['bigStaff','bigStaff','arcaneCrown','hat','hatGuard',...FC]);
  add('cHatTravel',['bigStaff','bigStaff','arcaneCrown','hat','hatTravel',...FC]);
  add('cSpring',['lifeStone','ruby','regenBand','lifeSpring','hat','hatSage',...FC]);
  add('tStd',['cloth','cloth','strongArmor','cloth','thornArmor','thornShirt','thornPlate','hat','hatGuard',...FT]);
  add('tTitan',['cloth','lifeStone','regenBand','titanPlate','hat','hatGuard',...FT]);
  add('tSpring',['lifeStone','ruby','regenBand','lifeSpring','hat','hatGuard',...FT]);
  add('tBulwark',['cloth','cloth','strongArmor','ruby','bulwark','hat','hatGuard',...FT]);
  add('tGiant',['lifeStone','bigSword','giantsMight','hat','hatGuard',...FT]);
  add('tVamp',['bloodGem','spellGem','ruby','soulDrinker','hat','hatGuard',...FT]);
  add('tCleave',['bigSword','dagger','cleaver','hat','hatGuard',...FT]);
  add('tHatWind',['cloth','cloth','strongArmor','cloth','thornArmor','thornShirt','thornPlate','hat','hatWind',...FT]);
  add('tHatBlood',['cloth','cloth','strongArmor','cloth','thornArmor','thornShirt','thornPlate','hat','hatBlood',...FT]);
  add('tHatTravel',['cloth','cloth','strongArmor','cloth','thornArmor','thornShirt','thornPlate','hat','hatTravel',...FT]);
  Object.assign(BOT_VARIANTS,B); window.BUILDS=B;
  window.vs=(hero,variant,std,N=24)=>duels(hero,hero,N,{build:[variant,std]}).winA;
  window.measure=(hero,list,std,N=24)=>Object.fromEntries(list.map(v=>[v,vs(hero,v,std,N)]));
  window.crossAgg=function(reps=1,N=16,diff=['normal','normal']){ const acc={'tank vs damage':0,'tank vs caster':0,'damage vs caster':0}; const tm={}, to={};
    for(let i=0;i<reps;i++){ for(const [a,b] of [['tank','damage'],['tank','caster'],['damage','caster']]){ const m=duels(a,b,N,{diff}); acc[a+' vs '+b]+=m.winA/reps; tm[a+b]=(tm[a+b]||0)+m.avgTime/reps; to[a+b]=(to[a+b]||0)+m.timeouts; } }
    const s={tank:(acc['tank vs damage']+acc['tank vs caster'])/2, damage:((100-acc['tank vs damage'])+acc['damage vs caster'])/2, caster:((100-acc['tank vs caster'])+(100-acc['damage vs caster']))/2};
    return {pairs:Object.fromEntries(Object.entries(acc).map(([k,v])=>[k,Math.round(v)+'%'])), siegquote:Object.entries(s).map(([k,v])=>k+' '+Math.round(v)+'%').join(' | '), avgTime:Math.round(Object.values(tm).reduce((a,b)=>a+b,0)/3), timeouts:Object.values(to).reduce((a,b)=>a+b,0)+'/'+(reps*3*N)}; };
})();

// ===== Zusätzliche Messfunktionen (Spieldauer, Siegquoten, Diagnose) =====
(function(){
  window.paceTest=(N=12,diff=['normal','normal'])=>{ const R=[]; for(const [a,b] of [['tank','damage'],['tank','caster'],['damage','caster']]) for(let i=0;i<N;i++){ const r=duel(a,b,{diff}); R.push({t:r.time,wave:Math.max(P.G.wave,E.G.wave),boss:P.G.bossSpawned||E.G.bossSpawned,to:r.timeout}); }
    const avg=f=>+(R.reduce((a,r)=>a+f(r),0)/R.length).toFixed(1);
    return {games:R.length,zeitSek:avg(r=>r.t),zeitMin:+(avg(r=>r.t)/60).toFixed(1),welle:avg(r=>r.wave),bossErreicht:Math.round(100*R.filter(r=>r.boss).length/R.length)+'%',timeout:R.filter(r=>r.to).length}; };
  window.quotes=(reps,N)=>{ const acc={td:0,tc:0,dc:0}; for(let i=0;i<reps;i++){ acc.td+=duels('tank','damage',N,{}).winA/reps; acc.tc+=duels('tank','caster',N,{}).winA/reps; acc.dc+=duels('damage','caster',N,{}).winA/reps; }
    return {tank:(acc.td+acc.tc)/2, damage:((100-acc.td)+acc.dc)/2, caster:((100-acc.tc)+(100-acc.dc))/2, pairs:{td:Math.round(acc.td),tc:Math.round(acc.tc),dc:Math.round(acc.dc)}}; };
  window.diag=(a,b,N=8)=>{ const S={A:{d:0,l:0,lv:0,k:0,g:0},B:{d:0,l:0,lv:0,k:0,g:0},t:0,wA:0}; for(let i=0;i<N;i++){ const r=duel(a,b,{}); for(const [k,S0] of [['A',P],['B',E]]){ const x=S[k]; x.d+=S0.H.deaths; x.l+=CFG.startLives-Math.max(0,S0.G.lives); x.lv+=S0.H.lvl; x.k+=S0.G.stats.kills; x.g+=S0.G.stats.gold; } S.t+=r.time; if(r.winner==='A') S.wA++; }
    const f=x=>({tode:+(x.d/N).toFixed(1),lebenVerloren:+(x.l/N).toFixed(1),level:+(x.lv/N).toFixed(1),kills:Math.round(x.k/N)}); return {duell:a+' vs '+b,A:f(S.A),B:f(S.B),zeit:Math.round(S.t/N),siegA:S.wA+'/'+N}; };
})();

// ===== Automatisches Einregeln der Held-Defensive (Leben/Rüstung je Klasse) =====
(function(){
  window.baseHeroes = {tank:{...HEROES.tank}, damage:{...HEROES.damage}, caster:{...HEROES.caster}};
  window.defS = {tank:1, damage:1, caster:1};
  window.applyDef = ()=>{ for(const h of ['tank','damage','caster']){ const b=baseHeroes[h], s=defS[h]; Object.assign(HEROES[h], b, {hp:Math.round(b.hp*s), hpl:+(b.hpl*s).toFixed(1), armor:+(b.armor*s).toFixed(1), armorl:+(b.armorl*s).toFixed(2)}); } };
  window.fitDef = (iters=2,N=10,k=0.008)=>{ const log=[]; for(let i=0;i<iters;i++){ applyDef(); const q=quotes(1,N); log.push({def:{...defS}, siege:{tank:Math.round(q.tank),damage:Math.round(q.damage),caster:Math.round(q.caster)}});
      for(const h of ['tank','damage','caster']) defS[h]=+Math.min(3,Math.max(.15,defS[h]*Math.exp(-k*(q[h]-50)))).toFixed(3); } return log; };
})();
