extends RefCounted
## Szenario-Runner: spielt die Vergleichs-Szenarien aus data/golden-skills.json (aus dem Browser-Prototyp erzeugt)
## in Godot nach und vergleicht Zahl für Zahl. Aufruf: Godot --headless --path godot -- --golden  (oder --golden=<Teil der ID>)
## Szenarien, die Item-Effekte brauchen, die noch nicht in Godot sind, werden als "übersprungen" gezählt.

const SUPPORTED_UNIQ := ["vengeance", "spMul", "hpAp", "comboAmp", "thorns", "critDmg", "stormCrit", "torment", "ruin", "giants", "cleave", "lifeflow", "slowAura", "onHitMagic"]   # alle Item-Effekte umgesetzt
const SNAP_TIMES := [0.0, 0.5, 1.0, 2.0, 4.0, 8.0, 12.0]

var g: Node
var data: Dictionary
var n_pass := 0
var n_fail := 0
var skipped: Array = []
var failed: Array = []


func _init(game: Node) -> void:
	g = game


func run(filter: String = "") -> void:
	var f := FileAccess.open("res://data/golden-skills.json", FileAccess.READ)
	if f == null:
		print("GOLDEN: data/golden-skills.json fehlt")
		return
	data = JSON.parse_string(f.get_as_text())
	for sc in data["scenarios"]:
		var id: String = sc["id"]
		if filter != "" and not id.contains(filter):
			continue
		var why := _unsupported(sc["input"])
		if why != "":
			skipped.append([id, why])
			continue
		var diffs := _compare(sc)
		if diffs.is_empty():
			n_pass += 1
		else:
			n_fail += 1
			failed.append([id, diffs])
	for fl in failed:
		print("FAIL  %s" % fl[0])
		for d in fl[1].slice(0, 6):
			print("        " + d)
	print("GOLDEN: %d bestanden, %d fehlgeschlagen, %d übersprungen (Items/spätere Funktionen)" % [n_pass, n_fail, skipped.size()])
	if filter != "":
		for s in skipped:
			print("  übersprungen: %s (%s)" % [s[0], s[1]])


func _unsupported(inp: Dictionary) -> String:
	for u in inp.get("uniq", []):
		if not SUPPORTED_UNIQ.has(str(u)):
			return "Item-Effekt " + str(u)
	return ""


# ---------------------------------------------------------------- Simulation
func _mouse(p: Dictionary, mv: Array) -> Dictionary:
	var dx := float(mv[0])
	var dy := float(mv[1])
	return {"dx": dx, "dy": dy, "dist": maxf(1.0, Vector2(dx, dy).length()), "ang": atan2(dy, dx), "wx": p["x"] + dx, "wy": p["y"] + dy}


func _simulate(inp: Dictionary, with_casts: bool) -> Dictionary:
	g.reset_test(inp, data["heldPos"], data["layouts"])
	var p: Dictionary = g.hero
	var sk = g.skills
	var iron: Dictionary = sk.iron_passive(p)
	var derived := {"maxHp": sk.h_max_hp(p), "armor": sk.h_armor(p), "dmg": sk.h_dmg(p), "sp": sk.h_sp(p), "as": sk.h_as(p), "spd": sk.h_spd(p),
		"reflect": float(iron["reflect"])}
	var casts: Array = inp.get("casts", []) if with_casts else []
	var hits: Array = inp.get("hits", [])      # Treffer gibt es auch im Lauf ohne Casts (Basis für die Heilung)
	var cast_i := 0
	var hit_i := 0
	var cast_info: Array = []
	var snaps: Array = []
	var dummies: Array = g.units.duplicate()
	var dhp := float(inp.get("dummyHp", 100000))
	var steps_total := int(round(float(SNAP_TIMES[SNAP_TIMES.size() - 1]) / 0.05))
	var next_snap := 0
	for step in steps_total + 1:
		var now := step * 0.05
		while cast_i < casts.size() and float(casts[cast_i]["t"]) <= now + 1e-9:
			var c: Dictionary = casts[cast_i]
			var ok: bool = sk.cast_slot(p, int(c["slot"]), _mouse(p, c.get("mouse", [200, 0])))
			cast_info.append({"t": c["t"], "slot": c["slot"], "ok": ok, "cdAfter": p["cds"][int(c["slot"])]})
			cast_i += 1
		while hit_i < hits.size() and float(hits[hit_i]["t"]) <= now + 1e-9:
			var h: Dictionary = hits[hit_i]
			g._damage_hero(p, float(h["dmg"]), dummies[int(h["src"])] if int(h["src"]) < dummies.size() else null)
			hit_i += 1
		while next_snap < SNAP_TIMES.size() and absf(float(SNAP_TIMES[next_snap]) - now) < 1e-6:
			snaps.append(_snapshot(float(SNAP_TIMES[next_snap]), p, dummies, dhp))
			next_snap += 1
		if step < steps_total:
			g.step(0.05)
	return {"derived": derived, "castInfo": cast_info, "snaps": snaps}


func _snapshot(t: float, p: Dictionary, dummies: Array, dhp: float) -> Dictionary:
	var buffs := {}
	for k in p["buffs"].keys():
		buffs[k] = {"t": p["buffs"][k]["t"]}
	var dm: Array = []
	for u in g.units:                              # nur lebende (gestorbene verschwinden aus der Liste, wie im Prototyp)
		dm.append([dhp - u["hp"], u["stun"], u["slow"], u["burn"], u["burn_dps"], u["bleed"], u["torm_t"], u["x"], u["y"]])
	var zs: Array = []
	for z in g.zones:
		zs.append({"x": z["x"], "y": z["y"], "r": z["r"], "t": z["t"], "dmg": z["dmg"], "follow": z.get("follow", "")})
	var es: Array = []
	for e in g.elems:
		es.append({"type": e["type"], "x": e["x"], "y": e["y"], "hp": e["hp"], "t": e["t"], "sp": e["sp"], "eRank": e["e_rank"]})
	return {"t": t, "hero": {"hp": p["hp"], "x": p["x"], "y": p["y"], "dead": p["dead"] > 0.0, "comboT": p["combo_t"],
		"lastElem": p["last_elem"] if p["last_elem"] != "" else null, "cds": p["cds"].duplicate(), "buffs": buffs}, "dummies": dm, "zones": zs, "elems": es}


# ---------------------------------------------------------------- Vergleich
func _num_ok(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(0.06, 0.004 * absf(b))


func _chk(diffs: Array, label: String, got: Variant, want: Variant) -> void:
	if want == null:
		if got != null:
			diffs.append("%s: erwartet null, Godot %s" % [label, str(got)])
	elif typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
		if got != want:
			diffs.append("%s: erwartet %s, Godot %s" % [label, str(want), str(got)])
	elif got == null or not _num_ok(float(got), float(want)):
		diffs.append("%s: erwartet %s, Godot %s" % [label, str(want), str(got)])


func _compare(sc: Dictionary) -> Array:
	var diffs: Array = []
	var inp: Dictionary = sc["input"]
	var res: Dictionary = sc["result"]
	var a := _simulate(inp, true)
	var b := _simulate(inp, false)            # gleicher Lauf ohne Casts: Differenz = Heilung
	for k in res["derived"].keys():
		_chk(diffs, "derived." + k, a["derived"].get(k), res["derived"][k])
	var want_ci: Array = res["castInfo"]
	for i in want_ci.size():
		if i >= a["castInfo"].size():
			diffs.append("castInfo[%d] fehlt" % i)
			continue
		_chk(diffs, "castInfo[%d].ok" % i, a["castInfo"][i]["ok"], want_ci[i]["ok"])
		_chk(diffs, "castInfo[%d].cdAfter" % i, a["castInfo"][i]["cdAfter"], want_ci[i]["cdAfter"])
	var want_snaps: Array = res["snaps"]
	for si in want_snaps.size():
		if si >= a["snaps"].size():
			break
		var ws: Dictionary = want_snaps[si]
		var gs: Dictionary = a["snaps"][si]
		var pre := "t=%s " % str(ws["t"])
		var wh: Dictionary = ws["hero"]
		var gh: Dictionary = gs["hero"]
		_chk(diffs, pre + "hero.hp", gh["hp"], wh["hp"])
		_chk(diffs, pre + "hero.x", gh["x"], wh["x"])
		_chk(diffs, pre + "hero.y", gh["y"], wh["y"])
		_chk(diffs, pre + "hero.dead", gh["dead"], wh["dead"])
		_chk(diffs, pre + "hero.comboT", gh["comboT"], wh["comboT"])
		_chk(diffs, pre + "hero.lastElem", gh["lastElem"], wh["lastElem"])
		for i in 4:
			_chk(diffs, pre + "hero.cds[%d]" % i, gh["cds"][i], wh["cds"][i])
		for bn in wh["buffs"].keys():
			_chk(diffs, pre + "buff." + bn, gh["buffs"].get(bn, {}).get("t") if gh["buffs"].has(bn) else null, wh["buffs"][bn]["t"])
		for bn in gh["buffs"].keys():
			if not wh["buffs"].has(bn):
				diffs.append(pre + "Buff " + bn + " in Godot, nicht erwartet")
		if si < b["snaps"].size() and wh.has("heal"):
			_chk(diffs, pre + "hero.heal", gh["hp"] - b["snaps"][si]["hero"]["hp"], wh["heal"])
		var names := ["Schaden", "Betäubung", "Verlangsamung", "Brennen", "Brennschaden", "Blutung", "Qual", "x", "y"]
		var wd: Array = ws["dummies"]
		for di in wd.size():
			for fi in 9:
				_chk(diffs, pre + "dummy[%d].%s" % [di, names[fi]], gs["dummies"][di][fi], wd[di][fi])
		_chk(diffs, pre + "Anzahl Zonen", float(gs["zones"].size()), float(ws["zones"].size()))
		for zi in mini(ws["zones"].size(), gs["zones"].size()):
			for k in ["x", "y", "r", "t", "dmg"]:
				_chk(diffs, pre + "zone[%d].%s" % [zi, k], gs["zones"][zi][k], ws["zones"][zi][k])
		_chk(diffs, pre + "Anzahl Elementare", float(gs["elems"].size()), float(ws["elems"].size()))
		for ei in mini(ws["elems"].size(), gs["elems"].size()):
			for k in ["x", "y", "hp", "t", "sp", "eRank"]:
				_chk(diffs, pre + "elem[%d].%s" % [ei, k], gs["elems"][ei][k], ws["elems"][ei][k])
		if diffs.size() > 12:
			break
	return diffs
