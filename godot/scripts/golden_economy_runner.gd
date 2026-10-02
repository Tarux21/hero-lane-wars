extends RefCounted
## Prüfer für Wirtschaft, Wellen, Items und Bot: spielt die Szenarien aus data/golden-economy.json (erzeugt aus dem Browser-Prototyp,
## regelwerk/golden-economy.js) in Godot nach und vergleicht Zahl für Zahl.
## Aufruf: Godot --headless --path godot -- --golden-eco   (oder --golden-eco=<Abschnitt>, z. B. bot, items, economy, itemEffects)

const DT := 0.05
const SNAP_STEPS := [0, 10, 20, 40, 80, 160, 240]

var g: Node
var data: Dictionary
var n_pass := 0
var n_fail := 0
var failed: Array = []
var section_stats: Dictionary = {}
var cur_section := ""


func _init(game: Node) -> void:
	g = game


func run(filter: String = "") -> void:
	var f := FileAccess.open("res://data/golden-economy.json", FileAccess.READ)
	if f == null:
		print("GOLDEN-ECO: data/golden-economy.json fehlt")
		return
	data = JSON.parse_string(f.get_as_text())
	g.deterministic = true
	if filter == "" or filter == "economy":
		_economy()
	if filter == "" or filter == "items":
		_items()
	if filter == "" or filter == "itemEffects":
		_item_effects()
	if filter == "" or filter == "bot":
		_bot()
	if filter == "" or filter == "priceTable":
		_price_table()
	for fl in failed:
		print("FAIL  %s" % fl[0])
		for d in fl[1].slice(0, 5):
			print("        " + d)
	for k in section_stats.keys():
		print("  %-14s %d bestanden, %d fehlgeschlagen" % [k, section_stats[k][0], section_stats[k][1]])
	print("GOLDEN-ECO: %d bestanden, %d fehlgeschlagen" % [n_pass, n_fail])


# ---------------------------------------------------------------- Hilfen
func _record(id: String, diffs: Array) -> void:
	if not section_stats.has(cur_section):
		section_stats[cur_section] = [0, 0]
	if diffs.is_empty():
		n_pass += 1
		section_stats[cur_section][0] += 1
	else:
		n_fail += 1
		section_stats[cur_section][1] += 1
		failed.append([id, diffs])


func _num_ok(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0012 + 0.000001 * absf(b)


## Vergleicht beliebig verschachtelte Werte (Zahlen mit Toleranz)
func _cmp(diffs: Array, label: String, got: Variant, want: Variant) -> void:
	if diffs.size() > 10:
		return
	if want == null:
		if got != null:
			diffs.append("%s: erwartet null, Godot %s" % [label, str(got)])
	elif typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
		if got != want:
			diffs.append("%s: erwartet %s, Godot %s" % [label, str(want), str(got)])
	elif typeof(want) == TYPE_FLOAT or typeof(want) == TYPE_INT:
		if got == null or (typeof(got) != TYPE_FLOAT and typeof(got) != TYPE_INT) or not _num_ok(float(got), float(want)):
			diffs.append("%s: erwartet %s, Godot %s" % [label, str(want), str(got)])
	elif want is Array:
		if not (got is Array) or got.size() != want.size():
			diffs.append("%s: erwartet Liste mit %d, Godot %s" % [label, want.size(), str(got).substr(0, 60)])
		else:
			for i in want.size():
				_cmp(diffs, "%s[%d]" % [label, i], got[i], want[i])
	elif want is Dictionary:
		if not (got is Dictionary):
			diffs.append("%s: erwartet Objekt, Godot %s" % [label, str(got).substr(0, 60)])
		else:
			for k in want.keys():
				_cmp(diffs, label + "." + str(k), got.get(k), want[k])
			for k in got.keys():
				if not want.has(k):
					diffs.append("%s.%s: in Godot, aber nicht erwartet (%s)" % [label, str(k), str(got[k]).substr(0, 40)])


## Zustand wie im Prototyp-Generator (sim): ein Spieler, keine Wellen, Held bei (1000,0) oder in der Basis
func _setup(hero_key: String, in_base: bool, rnd: float = 0.5) -> Dictionary:
	g.test_mode = true
	g.units.clear()
	g.zones.clear()
	g.timers.clear()
	g.elems.clear()
	g.t = 0.0
	g.income_t = 0.0
	g.over = false
	g.winner = -1
	g.team_lives = [int(g.cfg["startLives"]), int(g.cfg["startLives"])]
	g.lane_half_g = float(g.cfg["laneHalf"])
	if not g.hero.is_empty():
		g._free(g.hero["node"])
	g.hero_key = hero_key
	g._spawn_hero()
	for s in g.sides:
		s["wave"] = 0
		s["wave_t"] = 1e9
		s["units"].clear()
		s["boss_spawned"] = false
		s["leak"] = {}
	g.sides[1]["players"].clear()
	var p: Dictionary = g.hero
	p["x"] = 120.0 if in_base else 1000.0
	p["y"] = 0.0
	p["atk_t"] = 1e9
	g.rand_fixed = rnd
	return p


func _derived(p: Dictionary) -> Dictionary:
	var sk = g.skills
	var u: Array = p["uniq"].keys()
	u.sort()
	return {"maxHp": sk.h_max_hp(p), "armor": sk.h_armor(p), "dmg": sk.h_dmg(p), "sp": sk.h_sp(p), "as": sk.h_as(p), "spd": sk.h_spd(p),
		"cdr": p["cdr"], "crit": p["crit_ch"], "lifesteal": p["lifesteal"], "spellVamp": p["spell_vamp"], "dr": p["dr"], "regen": p["bonus_regen"],
		"goldPS": p["gps"], "bpRed": p["bp_red"],
		"bonus": {"dmg": p["bonus_dmg"], "armor": p["bonus_armor"], "hp": p["bonus_hp"], "as": p["bonus_as"], "sp": p["bonus_sp"], "spd": p["bonus_spd"]},
		"uniq": u}


func _unit_row(u: Dictionary) -> Dictionary:
	return {"type": u["type"], "lane": u["lane"], "x": u["x"], "y": u["y"], "hp": u["hp"], "max": u["max"], "dmg": u["dmg"], "spd": u["spd"],
		"range": u["range"], "armor": u["armor"], "r": u["r"]}


# ---------------------------------------------------------------- (a) Wirtschaft
func _economy() -> void:
	cur_section = "economy"
	var eco: Dictionary = data["economy"]
	# a1 Einkommen-Tick
	for c in eco["incomeTick"]:
		var inp: Dictionary = c["input"]
		var p := _setup("damage", false)
		p["income"] = float(inp["income"])
		p["gold_mul"] = float(inp["goldMul"])
		p["gold"] = float(inp["gold"])
		g.team_lives = [int(inp["lives"][0]), int(minf(float(inp["lives"][1]), 1e9))]
		var diffs: Array = []
		var n := 0
		for sn in c["snaps"]:
			while n < int(sn["step"]):
				g.step(DT)
				n += 1
			_cmp(diffs, "step%d.gold" % int(sn["step"]), p["gold"], sn["gold"])
			_cmp(diffs, "step%d.statsGold" % int(sn["step"]), p["stat_gold"], sn["statsGold"])
			_cmp(diffs, "step%d.incomeT" % int(sn["step"]), g.income_t, sn["incomeT"])
		var cb_p := _setup("damage", false)
		cb_p["income"] = float(inp["income"])
		g.team_lives = [int(inp["lives"][0]), int(minf(float(inp["lives"][1]), 1e9))]
		_cmp(diffs, "comebackBonus", g.comeback_bonus(cb_p), c["comebackBonus"])
		_record("incomeTick/" + str(c["id"]), diffs)
	# a2 Monster senden
	for c in eco["send"]:
		var diffs: Array = []
		var id: String = c["id"]
		var inp: Dictionary = c["input"]
		var p := _setup("damage", false)
		var res: Dictionary = c["result"]
		if id == "send-folge":
			p["gold"] = 1000.0
			var log: Array = []
			for tp in inp["folge"]:
				g.send(p, str(tp))
				log.append({"type": tp, "gold": p["gold"], "income": p["income"]})
			_cmp(diffs, "log", log, res["log"])
			_cmp(diffs, "stats.sent", p["sent"], res["stats"]["sent"])
			_cmp(diffs, "enemyCount", float(g.sides[1]["units"].size()), res["enemyCount"])
		elif id == "send-incMul-2":
			var old: float = float(g.cfg["incMul"])
			g.cfg["incMul"] = 2.0
			p["gold"] = 1000.0
			g.send(p, "tank")
			g.cfg["incMul"] = old
			_cmp(diffs, "goldAfter", p["gold"], res["goldAfter"])
			_cmp(diffs, "incomeAfter", p["income"], res["incomeAfter"])
		elif id == "send-spiel-vorbei":
			p["gold"] = 1000.0
			g.over = true
			g.send(p, "grunt")
			_cmp(diffs, "goldAfter", p["gold"], res["goldAfter"])
			_cmp(diffs, "enemyCount", float(g.sides[1]["units"].size()), res["enemyCount"])
		else:
			p["gold"] = float(inp["gold"])
			g.t = float(inp["t"])
			var inc0: float = p["income"]
			var n0: int = g.sides[1]["units"].size()
			g.send(p, str(inp["type"]))
			var sent: bool = g.sides[1]["units"].size() > n0
			_cmp(diffs, "sent", sent, res["sent"])
			_cmp(diffs, "goldAfter", p["gold"], res["goldAfter"])
			_cmp(diffs, "incomeAfter", p["income"], res["incomeAfter"])
			_cmp(diffs, "incomeDelta", p["income"] - inc0, res["incomeDelta"])
			_cmp(diffs, "stats.sent", p["sent"], res["stats"]["sent"])
			var rows: Array = []
			for u in g.sides[1]["units"]:
				rows.append(_unit_row(u))
			_cmp(diffs, "enemyUnits", rows, res["enemyUnits"])
			_cmp(diffs, "ownUnits", float(g.units.size()), res["ownUnits"])
		_record("send/" + id, diffs)
	# a3 Skalierung
	for row in eco["unitScaling"]:
		var diffs: Array = []
		var p := _setup("damage", false)
		g.t = float(row["t"])
		_cmp(diffs, "hpMult", g._hp_mult(), row["hpMult"])
		for type in row["units"].keys():
			g.units.clear()
			g._spawn_unit(str(type), 0.0, 1.0, 0, 0)
			_cmp(diffs, str(type), _unit_row(g.units[0]), row["units"][type])
		_record("unitScaling/t%d" % int(row["t"]), diffs)
	# a4 Kill-Belohnung
	for c in eco["kill"]:
		var id: String = c["id"]
		var inp: Dictionary = c["input"]
		var diffs: Array = []
		if id == "kill-lane1" or id == "hit-ruestung-elite":
			if id == "hit-ruestung-elite":
				var p := _setup("damage", false)
				g._spawn_unit("elite", 0.0, 1.0, 0, 0)
				var u: Dictionary = g.units[0]
				var hp0: float = u["hp"]
				var d: float = g.hit_unit(u, 100.0, p)
				_cmp(diffs, "dealt", d, c["result"]["dealt"])
				_cmp(diffs, "hpAfter", u["hp"], c["result"]["hpAfter"])
				_cmp(diffs, "hp0", hp0, c["result"]["hp0"])
				_record("kill/" + id, diffs)
			continue
		var p := _setup(str(inp["hero"]), false)
		p["gold"] = 0.0
		p["xp"] = 0.0
		p["lvl"] = 1
		p["sp"] = 1
		g._spawn_unit(str(inp["type"]), 0.0, 1.0, 0, 0)
		var u: Dictionary = g.units[0]
		u["hp"] = 1.0
		var hp0: float = p["hp"]
		g.hit_unit(u, 1e6, p)
		var r: Dictionary = c["result"]
		_cmp(diffs, "gold", p["gold"], r["gold"])
		_cmp(diffs, "statsGold", p["stat_gold"], r["statsGold"])
		_cmp(diffs, "kills", float(p["kills"]), r["kills"])
		_cmp(diffs, "xp", p["xp"], r["xp"])
		_cmp(diffs, "lvl", float(p["lvl"]), r["lvl"])
		_cmp(diffs, "sp", float(p["sp"]), r["sp"])
		_cmp(diffs, "hpDelta", p["hp"] - hp0, r["hpDelta"])
		_cmp(diffs, "bossIncome", p["boss_income"], r["bossIncome"])
		_cmp(diffs, "unitsLeft", float(g.units.size()), r["unitsLeft"])
		_record("kill/" + id, diffs)
	# a5 Level-Kurve
	var lc: Dictionary = eco["levelCurve"]
	var d5: Array = []
	for row in lc["table"]:
		_cmp(d5, "xpToNext lvl%d" % int(row["lvl"]), g._xp_need(int(row["lvl"])), row["xpToNext"])
	_record("levelCurve/table", d5)
	for c in lc["runs"]:
		var diffs: Array = []
		var inp: Dictionary = c["input"]
		var p := _setup(str(inp["hero"]), false)
		var hp0: float = p["hp"]
		var max0: float = g.skills.h_max_hp(p)
		g._gain_xp(float(inp["xp"]), p)
		var r: Dictionary = c["result"]
		_cmp(diffs, "lvl", float(p["lvl"]), r["lvl"])
		_cmp(diffs, "xp", p["xp"], r["xp"])
		_cmp(diffs, "sp", float(p["sp"]), r["sp"])
		_cmp(diffs, "hp", p["hp"], r["hp"])
		_cmp(diffs, "hpDelta", p["hp"] - hp0, r["hpDelta"])
		_cmp(diffs, "maxHp", g.skills.h_max_hp(p), r["maxHp"])
		_cmp(diffs, "maxHpDelta", g.skills.h_max_hp(p) - max0, r["maxHpDelta"])
		_record("levelCurve/" + str(c["id"]), diffs)
	# a6 Respawn
	for c in eco["respawn"]:
		var diffs: Array = []
		var id: String = c["id"]
		var inp: Dictionary = c["input"]
		var r: Dictionary = c["result"]
		if id == "respawn-ablauf-damage-l5":
			var p := _setup("damage", false)
			p["lvl"] = 5
			p["hp"] = g.skills.h_max_hp(p)
			g._damage_hero(p, 1e9)
			var wait: float = p["dead"]
			_cmp(diffs, "wait", wait, r["wait"])
			var rows: Array = []
			var wsteps := int(round(wait / DT))
			for s in wsteps + 3:
				if s == wsteps - 1 or s == wsteps or s == wsteps + 1:
					rows.append({"step": s, "dead": p["dead"], "hp": p["hp"], "x": p["x"], "y": p["y"]})
				g.step(DT)
			_cmp(diffs, "rows", rows, r["rows"])
		else:
			var p := _setup(str(inp["hero"]), false)
			p["lvl"] = int(inp["lvl"])
			p["hp"] = g.skills.h_max_hp(p)
			p["buffs"] = {"rage": {"t": 5.0, "as": 0.4, "spd": 40.0, "cleave": false}}
			g._damage_hero(p, 1e9)
			_cmp(diffs, "dead", p["dead"], r["dead"])
			_cmp(diffs, "deaths", float(p["deaths"]), r["deaths"])
			_cmp(diffs, "buffsAfter", float(p["buffs"].size()), r["buffsAfter"])
		_record("respawn/" + id, diffs)
	# a7 Wellen
	var diffs7: Array = []
	var p7 := _setup("damage", false)
	g.sides[0]["wave_t"] = float(g.cfg["firstWave"])
	g.team_lives = [1000000000, 1000000000]
	var rows7: Array = []
	var last := 0
	var steps := 0
	while g.sides[0]["wave"] < 30 and steps < int(round(1000.0 / DT)):
		g.step(DT)
		steps += 1
		if g.sides[0]["wave"] != last:
			last = g.sides[0]["wave"]
			var counts := {}
			var xs: Array = []
			var first_g: Variant = null
			for u in g.units:
				counts[u["type"]] = counts.get(u["type"], 0) + 1
				xs.append(u["x"])
				if first_g == null and u["type"] == "grunt":
					first_g = u
			rows7.append({"wave": last, "step": steps, "t": g.t, "counts": counts, "firstGruntX": first_g["x"], "lastX": xs.max(), "minX": xs.min(),
				"gruntHp": first_g["hp"], "gruntSpd": first_g["spd"], "gruntDmg": first_g["dmg"], "bossSpawned": g.sides[0]["boss_spawned"], "nextWaveIn": g.sides[0]["wave_t"]})
		g.units.clear()
	var want_rows: Array = []
	for w in eco["waves"]["waves"]:
		var wr: Dictionary = w.duplicate()
		wr.erase("kind")
		want_rows.append(wr)
	_cmp(diffs7, "waves", rows7, want_rows)
	_cmp(diffs7, "totalSteps", float(steps), eco["waves"]["totalSteps"])
	_record("waves", diffs7)
	# a7b Boss-Einkommen
	var diffs8: Array = []
	var p8 := _setup("damage", false)
	g.team_lives = [1000000000, 1000000000]
	g._spawn_unit("boss", 0.0, 1.0, 0, 0)
	var bu: Dictionary = g.units[0]
	bu["hp"] = 1.0
	p8["gold"] = 0.0
	g.hit_unit(bu, 1e6, p8)
	var bi: Dictionary = eco["bossIncome"]
	_cmp(diffs8, "afterKill.gold", p8["gold"], bi["afterKill"]["gold"])
	_cmp(diffs8, "afterKill.bossIncome", p8["boss_income"], bi["afterKill"]["bossIncome"])
	_cmp(diffs8, "afterKill.xp", p8["xp"], bi["afterKill"]["xp"])
	_cmp(diffs8, "afterKill.lvl", float(p8["lvl"]), bi["afterKill"]["lvl"])
	p8["gold"] = 0.0
	g.sides[0]["wave_t"] = 0.0
	g.step(DT)
	_cmp(diffs8, "goldAfterNextWave", p8["gold"], bi["goldAfterNextWave"])
	_cmp(diffs8, "wave", float(g.sides[0]["wave"]), bi["wave"])
	_record("bossIncome", diffs8)


# ---------------------------------------------------------------- (b) Items: Aktionsfolgen
func _items() -> void:
	cur_section = "items"
	for c in data["items"]:
		var inp: Dictionary = c["input"]
		var p := _setup(str(inp["hero"]), true)
		p["gold"] = float(inp["gold"])
		p["hp"] = g.skills.h_max_hp(p)
		var diffs: Array = []
		var rows: Array = []
		for act in inp["actions"]:
			var ok: Variant = null
			var reason := ""
			match str(act["a"]):
				"buy":
					reason = g.items.buy_reason(p, str(act["id"]))
					ok = g.items.buy(p, str(act["id"]))
				"sell":
					var g0: float = p["gold"]
					var n0: int = p["bag"].size()
					g.items.sell(p, int(act["i"]))
					ok = p["bag"].size() < n0
					if ok:
						reason = "erloes " + _r3s(p["gold"] - g0)
					else:
						reason = "nur in der Basis" if int(act["i"]) < p["bag"].size() else "kein Item"
				"potion":
					ok = g.items.drink_potion(p)
				"wait":
					for k in int(round(float(act["s"]) / DT)):
						g.step(DT)
					ok = true
				"gold":
					p["gold"] = float(act["v"])
					ok = true
				"pos":
					p["x"] = 120.0 if act["base"] else 1000.0
					ok = true
					reason = "in der Basis" if g._in_base(p) else "ausserhalb"
				"hp":
					p["hp"] = g.skills.h_max_hp(p) * float(act["frac"])
					ok = true
				"lvl":
					p["lvl"] = int(act["v"])
					ok = true
				"over":
					g.over = true
					ok = true
			rows.append({"ok": ok, "reason": reason, "gold": p["gold"], "bag": p["bag"].duplicate(), "cons": p["cons"].duplicate(), "potCd": p["pot_cd"],
				"hp": p["hp"], "maxHp": g.skills.h_max_hp(p), "derived": _derived(p)})
		var want_steps: Array = c["steps"]
		for i in want_steps.size():
			var w: Dictionary = want_steps[i].duplicate()
			for k in ["a", "id", "i", "s", "v", "base", "frac"]:
				w.erase(k)
			_cmp(diffs, "Schritt %d" % i, rows[i] if i < rows.size() else null, w)
			if diffs.size() > 6:
				break
		_record("items/" + str(c["id"]), diffs)


func _r3s(x: float) -> String:
	## JS: r3(x) in einen String; ganze Zahlen ohne Nachkommastellen
	var v := roundf(x * 1000.0) / 1000.0
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return str(v)


# ---------------------------------------------------------------- (c) Item-Effekte mit echtem Rucksack
func _item_effects() -> void:
	cur_section = "itemEffects"
	for sc in data["itemEffects"]:
		var diffs: Array = []
		var inp: Dictionary = sc["input"]
		var got := _run_item_scenario(inp)
		var res: Dictionary = sc["result"]
		_cmp(diffs, "derived", got["derived"], res["derived"])
		_cmp(diffs, "castInfo", got["castInfo"], res["castInfo"])
		for i in res["snaps"].size():
			var ws: Dictionary = res["snaps"][i]
			var gs: Dictionary = got["snaps"][i]
			_cmp(diffs, "t=%s hero" % str(ws["t"]), gs["hero"], ws["hero"])
			_cmp(diffs, "t=%s dummyIds" % str(ws["t"]), gs["dummyIds"], ws["dummyIds"])
			_cmp(diffs, "t=%s dummies" % str(ws["t"]), gs["dummies"], ws["dummies"])
			_cmp(diffs, "t=%s zones" % str(ws["t"]), gs["zones"], ws["zones"])
			_cmp(diffs, "t=%s elems" % str(ws["t"]), gs["elems"], ws["elems"])
			if diffs.size() > 8:
				break
		_record("itemEffects/" + str(sc["id"]), diffs)


func _run_item_scenario(sc: Dictionary) -> Dictionary:
	var rinp := {"hero": sc["hero"], "lvl": sc["lvl"], "ranks": sc["ranks"], "layout": sc.get("layout", "melee"), "auto": sc.get("auto", false),
		"rand": sc.get("rand", 0.5), "dummyHp": sc.get("dummyHp", 100000), "dummySpd": sc.get("dummySpd", 0), "dummyArmor": sc.get("dummyArmor", 0), "hpFrac": 0.5}
	var gold: Dictionary = data.get("_skills_layouts", {})
	var layouts := {"field": [[60, 0], [100, 20], [140, -20], [200, 0], [260, 30], [300, 10], [330, -30], [420, 0], [-60, 0], [60, 60]],
		"melee": [[30, 0], [50, 25], [70, -20], [90, 10], [30, -85], [60, 40]]}
	g.reset_test(rinp, [1000, 0], layouts)
	var p: Dictionary = g.hero
	p["bag"] = sc["bag"].duplicate()
	g.items.recalc(p)
	p["hp"] = g.skills.h_max_hp(p) * float(sc.get("hpFrac", 0.5))
	p["atk_t"] = 0.0 if sc.get("auto", false) else 1e9
	for i in g.units.size():
		g.units[i]["gid"] = i
	var dhp := float(sc.get("dummyHp", 100000))
	var derived := _derived(p)
	var ev: Array = []
	for c in sc.get("casts", []):
		ev.append({"t": float(c["t"]), "k": "cast", "slot": int(c["slot"]), "m": c.get("mouse", [200, 0])})
	for h in sc.get("hits", []):
		ev.append({"t": float(h["t"]), "k": "hit", "dmg": float(h["dmg"]), "src": h.get("src")})
	ev.sort_custom(func(a, b): return a["t"] < b["t"])
	var cast_info: Array = []
	var snaps: Array = []
	var ei := 0
	var last_step: int = SNAP_STEPS[SNAP_STEPS.size() - 1]
	for step in last_step + 1:
		var now := step * DT
		while ei < ev.size() and ev[ei]["t"] <= now + 1e-9:
			var e: Dictionary = ev[ei]
			ei += 1
			if e["k"] == "cast":
				var b0: float = p["cds"][e["slot"]]
				var dx := float(e["m"][0])
				var dy := float(e["m"][1])
				var m := {"dx": dx, "dy": dy, "dist": maxf(1.0, Vector2(dx, dy).length()), "ang": atan2(dy, dx), "wx": 1000.0 + dx, "wy": dy}
				g.skills.cast_slot(p, e["slot"], m)
				cast_info.append({"t": e["t"], "slot": e["slot"], "ok": b0 <= 0.0 and p["cds"][e["slot"]] > 0.0, "cdAfter": p["cds"][e["slot"]]})
			else:
				var src: Variant = null
				if e["src"] != null and int(e["src"]) < g.units.size():
					src = g.units[int(e["src"])]
				g._damage_hero(p, e["dmg"], src)
		if SNAP_STEPS.has(step):
			var buffs := {}
			for k in p["buffs"].keys():
				var bd := {}
				for kk in p["buffs"][k].keys():
					bd[kk] = p["buffs"][k][kk]
				buffs[k] = bd
			var ids: Array = []
			var dm: Array = []
			for u in g.units:
				ids.append(u["gid"])
				dm.append([dhp - u["hp"], u["stun"], u["slow"], u["burn"], u["burn_dps"], u["bleed"], u["torm_t"], u["x"], u["y"]])
			var es: Array = []
			for el in g.elems:
				es.append({"type": el["type"], "hp": el["hp"], "t": el["t"]})
			snaps.append({"t": now, "hero": {"hp": p["hp"], "lvl": float(p["lvl"]), "xp": p["xp"], "gold": p["gold"], "kills": float(p["kills"]), "x": p["x"], "y": p["y"],
				"dmgT": p["dmg_t"], "comboT": p["combo_t"], "cds": p["cds"].duplicate(), "as": g.skills.h_as(p), "buffs": buffs},
				"dummyIds": ids, "dummies": dm, "zones": float(g.zones.size()), "elems": es})
		if step < last_step:
			g.step(DT)
	return {"derived": derived, "castInfo": cast_info, "snaps": snaps}


# ---------------------------------------------------------------- (d) Bot
func _bot_player(hero_key: String, in_base: bool, plan: Array, diff_key: String, style: String) -> Dictionary:
	var p := _setup(hero_key, in_base)
	p["bot_state"] = {"mode": "fight", "step": 0, "trips": 0, "deaths": 0, "was_dead": false, "clock": 0.0, "last_send": -100.0,
		"diff": Data.raw["diff"][diff_key], "style": style, "build": plan}
	return p


func _bot() -> void:
	cur_section = "bot"
	var bot: Dictionary = data["bot"]
	# d1 Kaufpläne
	for c in bot["plans"]:
		var diffs: Array = []
		var plan: Array = c["plan"]
		var p := _bot_player(str(c["hero"]), true, plan, "normal", "balanced")
		var rows: Array = []
		var total := 0.0
		var guard := 0
		while p["bot_state"]["step"] < plan.size() and guard < 80:
			guard += 1
			var before: int = p["bot_state"]["step"]
			var id: String = plan[before]
			var nx: float = g.bot.next_cost(p)
			p["gold"] = nx
			g.bot.shop(p)
			var row := {"planIndex": before, "id": id, "costNeeded": nx, "stepAfter": p["bot_state"]["step"], "goldLeft": p["gold"], "bag": p["bag"].duplicate(), "cons": p["cons"].duplicate()}
			total += nx - p["gold"]
			if p["bot_state"]["step"] == before:
				row["stuck"] = true
				rows.append(row)
				break
			rows.append(row)
		var want_rows: Array = c["rows"]
		_cmp(diffs, "rows", rows, want_rows)
		_cmp(diffs, "totalSpent", total, c["totalSpent"])
		_cmp(diffs, "finalBag", p["bag"], c["finalBag"])
		_cmp(diffs, "finalCons", p["cons"], c["finalCons"])
		_cmp(diffs, "derived", _derived(p), c["derived"])
		_record("bot.plans/" + str(c["name"]), diffs)
	# d2 Skill-Lernreihenfolge
	for c in bot["learn"]:
		var diffs: Array = []
		var p := _bot_player(str(c["hero"]), false, [], "normal", "balanced")
		var rows: Array = []
		for l in range(1, int(g.cfg["maxLevel"]) + 1):
			p["lvl"] = l
			if l > 1:
				p["sp"] += 1
			g.bot.learn_skills(p)
			rows.append({"lvl": l, "ranks": p["ranks"].duplicate(), "spLeft": p["sp"]})
		_cmp(diffs, "rows", rows, c["rows"])
		_record("bot.learn/" + str(c["hero"]), diffs)
	# d3 Sendeentscheidung
	for part in ["grid", "gating", "randomPicks"]:
		for c in bot["send"][part]:
			var diffs: Array = []
			var ci: Dictionary = c["in"]
			var p := _bot_player("damage", bool(ci["inBase"]), ["bigSword"], str(ci["diff"]), str(ci["style"]))
			g.rand_fixed = float(ci["rand"])
			p["bot_state"]["last_send"] = float(ci.get("lastSend", -100.0))
			g.t = float(ci["t"])
			p["gold"] = float(ci["gold"])
			p["income"] = 100.0
			p["x"] = 120.0 if ci["inBase"] else 1000.0
			for k in int(ci["lane"]):
				g._spawn_unit("grunt", 0.0, 1.0, 0, 0)
			var enemy: Dictionary = g._make_player("damage", 1, 0, true)
			enemy["dead"] = 5.0 if ci["oppDead"] else 0.0
			g.sides[1]["players"].append(enemy)
			g.sides[1]["units"].clear()
			var g0: float = p["gold"]
			var i0: float = p["income"]
			g.bot.send_decision(p)
			var sent: Array = []
			for u in g.sides[1]["units"]:
				sent.append(u["type"])
			var out: Dictionary = c["out"]
			_cmp(diffs, "sent", sent, out["sent"])
			_cmp(diffs, "gold", p["gold"], out["gold"])
			_cmp(diffs, "spent", g0 - p["gold"], out["spent"])
			_cmp(diffs, "incomeDelta", p["income"] - i0, out["incomeDelta"])
			_cmp(diffs, "lastSend", p["bot_state"]["last_send"], out["lastSend"])
			_cmp(diffs, "sentStats", p["sent"], out["sentStats"])
			_record("bot.send.%s/%s" % [part, JSON.stringify(ci).substr(0, 110)], diffs)
			g._free(enemy["node"])
	# d4 Modus
	for c in bot["mode"]:
		var diffs: Array = []
		var ci: Dictionary = c["in"]
		var p := _bot_player("damage", false, ["bigSword", "rake", "critCloak", "mightyBlade", "hat", "hatWind", "gloves", "heart", "potion", "sword", "potion"], str(ci["diff"]), "balanced")
		g.t = 10.0
		p["x"] = 1000.0
		p["y"] = 0.0
		p["bp_cd"] = float(ci["bpCd"])
		p["hp"] = g.skills.h_max_hp(p) * float(ci["hpFrac"])
		p["ranks"] = [0, 0, 0, 0]
		p["sp"] = 0
		if ci["enemies"] == "nah" or ci["enemies"] == "fern":
			g._spawn_unit("grunt", 0.0, 1.0, 0, 0)
			var u: Dictionary = g.units[0]
			u["x"] = 1100.0 if ci["enemies"] == "nah" else 2000.0
			u["y"] = 0.0
			u["hp"] = 100.0
			u["max"] = 100.0
			u["dmg"] = 0.0
			u["spd"] = 0.0
			u["range"] = 0.0
			u["armor"] = 0.0
			u["r"] = 9.0
			u["atk_t"] = 1e9
		var nx: float = g.bot.next_cost(p)
		p["gold"] = float(ci["goldRatio"]) * nx
		g.bot.think(p, DT)
		var out: Dictionary = c["out"]
		_cmp(diffs, "mode", p["bot_state"]["mode"], out["mode"])
		_cmp(diffs, "backportStarted", p["bp"] > 0.0, out["backportStarted"])
		var mv: Variant = null
		if p["move_to"] != null:
			mv = [p["move_to"].x, p["move_to"].y]
		_cmp(diffs, "moveTo", mv, out["moveTo"])
		_cmp(diffs, "hasTarget", p["target"] != null, out["hasTarget"])
		_record("bot.mode/%s" % JSON.stringify(ci).substr(0, 110), diffs)


# ---------------------------------------------------------------- Preistabelle
func _price_table() -> void:
	cur_section = "priceTable"
	var diffs: Array = []
	for row in data["priceTable"]:
		var id: String = row["id"]
		var it: Dictionary = g.items.item[id]
		var buy_empty: float = float(it["cost"]) if it.get("consumable", false) else float(g.items.resolve_buy(id, [])["cost"])
		_cmp(diffs, id + ".total", float(g.items.total_cost(id)), row["total"])
		_cmp(diffs, id + ".buyFromEmpty", buy_empty, row["buyFromEmpty"])
		_cmp(diffs, id + ".sell", floor(float(g.items.total_cost(id)) * float(g.cfg["sellRatio"])), row["sell"])
	_record("priceTable", diffs)
