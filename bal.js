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
