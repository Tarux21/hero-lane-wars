// Exportiert alle Spielregeln und Zahlen aus index.html nach regelwerk/daten.json (für den Godot-Umzug).
// Benutzung (Seite über den lokalen Server geöffnet, serve.ps1 läuft), in der Konsole:
//   (0,eval)(await (await fetch('/export-regelwerk.js')).text());
// Immer nach Balance-Änderungen erneut ausführen, damit Godot dieselben Zahlen bekommt.
(async function(){
  const plain = o=>Object.fromEntries(Object.entries(o).filter(([k,v])=>typeof v!=='function'));
  const data = {
    _hinweis: 'Automatisch aus index.html erzeugt. Quelle der Zahlen für die Godot-Version. Nicht von Hand ändern, sondern in index.html ändern und neu exportieren.',
    version: VERSION, cfg: CFG, units: UNITS, heroes: HEROES, diff: DIFF, bot_style: BOT_STYLE,
    elem: Object.fromEntries(Object.entries(ELEM).map(([k,v])=>[k, plain(v)])),
    items: ITEM_LIST.map(i=>({...i, stats: typeof i.stats==='function' ? i.stats() : i.stats})),   // Basis-Items: Werte aus dem Spiel ausgerechnet
    skills: Object.fromEntries(Object.entries(SK).map(([h,arr])=>[h, arr.map(plain)])),            // Skill-Beschreibungen; die Wirkung (cast) steht im Code
  };
  const r = await fetch('/save-regelwerk', {method:'POST', body: JSON.stringify(data, null, 1)});
  console.log('Regelwerk gespeichert:', r.status);
  return r.status;
})();
