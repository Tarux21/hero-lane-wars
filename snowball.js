// Snowball-Messung: Wie oft gewinnt, wer nach 3 bzw. 6 Minuten vorne liegt?
// Benutzung (Seite per lokalem Server öffnen, dann in der Konsole):
//   (0,eval)(await (await fetch('/sim2.js')).text()); (0,eval)(await (await fetch('/snowball.js')).text());
//   snowball(16)                       // mit Aufholhilfe (aktuelle CFG)
//   CFG.comebackCap=0; snowball(16)    // ohne Aufholhilfe zum Vergleich
// Ein Aufruf darf im Browserfenster nicht länger als ~40 s laufen, sonst N verkleinern.
(function(){
  const pairs = [['tank','damage'],['tank','caster'],['damage','caster']];
  // "Führt" = mehr Leben; bei Gleichstand mehr Einkommen+Gold zu dem Zeitpunkt
  const lead = (a,b)=> a.lives!==b.lives ? (a.lives>b.lives?'A':'B') : ((a.inc+a.gold/50)===(b.inc+b.gold/50) ? null : ((a.inc+a.gold/50)>(b.inc+b.gold/50)?'A':'B'));
  window.snowball = function(N=8, diff=['normal','normal']){
    const S = {3:{n:0,win:0}, 6:{n:0,win:0}}; let games=0, tsum=0, comeback=0;
    for(const [ka,kb] of pairs){ for(let i=0;i<N;i++){
      const r = duel(ka,kb,{diff}); games++; tsum += r.time;
      for(const m of [3,6]){
        const a = r.A.tl.find(x=>x.min===m), b = r.B.tl.find(x=>x.min===m); if(!a||!b||r.winner==='draw') continue;
        const l = lead(a,b); if(!l) continue; S[m].n++; if(l===r.winner) S[m].win++;
      }
    } }
    const q = m=> S[m].n ? Math.round(100*S[m].win/S[m].n)+'% ('+S[m].n+')' : '–';
    return {partien:games, spielzeitMin:+(tsum/games/60).toFixed(1), fuehrungGewinntNach3Min:q(3), fuehrungGewinntNach6Min:q(6)};
  };
})();
