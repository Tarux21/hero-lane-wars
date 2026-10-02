extends "res://scripts/golden_economy_runner.gd"
## Prüfer für Boss und Elite-Wellen über die Zeit: spielt die Szenarien aus data/golden-boss.json (aus dem Prototyp erzeugt) nach.
## Aufruf: Godot --headless --path godot -- --golden-boss

const SNAP_T := [0, 2, 5, 6, 10, 20, 30, 40]


func run_boss(filter: String = "") -> void:
	var f := FileAccess.open("res://data/golden-boss.json", FileAccess.READ)
	if f == null:
		print("GOLDEN-BOSS: data/golden-boss.json fehlt")
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	g.deterministic = true
	cur_section = "boss"
	for sc in d["scenarios"]:
		var id: String = sc["id"]
		if filter != "" and not id.contains(filter):
			continue
		var diffs: Array = []
		if id == "elite-kill":
			var p := _setup("damage", false)
			p["lvl"] = 1
			p["xp"] = 0.0
			p["gold"] = 0.0
			g._spawn_unit("elite", 0.0, 1.0, 0, 0)
			g.hit_unit(g.units[0], 1e9, p)
			var r: Dictionary = sc["result"]
			_cmp(diffs, "gold", p["gold"], r["gold"])
			_cmp(diffs, "xp", p["xp"], r["xp"])
			_cmp(diffs, "lvl", float(p["lvl"]), r["lvl"])
			_cmp(diffs, "kills", float(p["kills"]), r["kills"])
		else:
			var got := _run_scenario(sc["input"])
			_cmp(diffs, "log", got["log"], sc["result"]["log"])
			if filter != "":
				for i in [5]:
					print("Godot  grunts: ", got["snaps"][i]["grunts"])
					print("Prototyp grunts: ", sc["result"]["snaps"][i]["grunts"])
			var ws: Array = sc["result"]["snaps"]
			for i in ws.size():
				_cmp(diffs, "t=%s" % str(ws[i]["t"]), got["snaps"][i], ws[i])
				if diffs.size() > 6:
					break
		_record("boss/" + id, diffs)
	for fl in failed:
		print("FAIL  %s" % fl[0])
		for x in fl[1].slice(0, 6):
			print("        " + x)
	print("GOLDEN-BOSS: %d bestanden, %d fehlgeschlagen" % [n_pass, n_fail])


func _run_scenario(sc: Dictionary) -> Dictionary:
	var p := _setup("damage", false)
	g.team_lives = [1000000000, 1000000000]
	p["bonus_hp"] = 1e6
	p["lvl"] = int(sc.get("heroLvl", 5))
	p["x"] = float(sc["heroX"])
	p["y"] = 0.0
	p["hp"] = g.skills.h_max_hp(p)
	p["atk_t"] = 1e9
	var side: Dictionary = g.sides[0]
	var boss: Variant = null
	if sc["start"] == "boss":
		g._spawn_unit("boss", 0.0, float(g.cfg["waveSpeedMul"]), 0, 0)
		boss = g.units[0]
		boss["x"] = float(sc["bossX"])
		boss["y"] = 0.0
		if sc.has("bossFrac"):
			boss["hp"] = boss["max"] * float(sc["bossFrac"])
	else:
		side["wave"] = int(sc["wave"]) - 1
		g._spawn_wave(side)
		for u in g.units:
			if u["boss"]:
				boss = u
				break
	var events: Array = []
	for e in sc.get("events", []):
		var ev: Dictionary = e.duplicate()
		ev["step"] = int(round(float(e["t"]) / DT))
		events.append(ev)
	events.sort_custom(func(a, b): return a["step"] < b["step"])
	var snap_steps: Array = []
	for t in SNAP_T:
		snap_steps.append(int(round(float(t) / DT)))
	var last: int = snap_steps[snap_steps.size() - 1]
	var snaps: Array = []
	var log: Array = []
	var ei := 0
	var prev_stomp: float = boss["stomp_t"] if boss != null else 0.0
	var prev_summon: float = boss["summon_t"] if boss != null else 0.0
	var prev_phase: int = boss["phase"] if boss != null else 0
	var prev_grunts := _count_grunts()
	var prev_hp: float = p["hp"]
	for step in last + 1:
		while ei < events.size() and events[ei]["step"] <= step:
			var e: Dictionary = events[ei]
			ei += 1
			match str(e["op"]):
				"frac":
					if boss != null:
						boss["hp"] = boss["max"] * float(e["f"])
				"hit":
					if boss != null:
						g.hit_unit(boss, float(e["dmg"]), p)
				"stun":
					if boss != null and g.units.has(boss):
						g.skills.affect(p, boss, 0.0, {"stun": float(e["s"])})
				"slow":
					if boss != null and g.units.has(boss):
						g.skills.affect(p, boss, 0.0, {"slow": float(e["s"])})
				"kill":
					if boss != null:
						g.hit_unit(boss, 1e12, p)
				"wave":
					g._spawn_wave(side)
				"clearGrunts":
					for u in g.units.duplicate():
						if u["type"] == "grunt":
							g.units.erase(u)
				"heroX":
					p["x"] = float(e["x"])
			log.append({"step": step, "t": step * DT, "event": e["op"]})
		if snap_steps.has(step):
			snaps.append(_snap(step, boss, p, side))
		if step < last:
			g.step(DT)
			if boss != null and g.units.has(boss):
				if boss["stomp_t"] > prev_stomp + 1e-9:
					log.append({"step": step + 1, "t": (step + 1) * DT, "event": "stomp", "phase": boss["phase"], "heroLost": prev_hp - p["hp"], "heroX": p["x"], "bossX": boss["x"]})
				if boss["summon_t"] > prev_summon + 1e-9:
					log.append({"step": step + 1, "t": (step + 1) * DT, "event": "summon", "phase": boss["phase"], "spawned": _count_grunts() - prev_grunts})
				if boss["phase"] != prev_phase:
					log.append({"step": step + 1, "t": (step + 1) * DT, "event": "phase", "from": prev_phase, "to": boss["phase"], "spd": boss["spd"]})
				prev_stomp = boss["stomp_t"]
				prev_summon = boss["summon_t"]
				prev_phase = boss["phase"]
			prev_grunts = _count_grunts()
			prev_hp = p["hp"]
	return {"log": log, "snaps": snaps}


func _count_grunts() -> int:
	var n := 0
	for u in g.units:
		if u["type"] == "grunt":
			n += 1
	return n


func _snap(step: int, boss: Variant, p: Dictionary, side: Dictionary) -> Dictionary:
	var brow: Dictionary = {"alive": false}
	if boss != null and g.units.has(boss):
		brow = {"alive": true, "x": boss["x"], "y": boss["y"], "hp": boss["hp"], "frac": boss["hp"] / boss["max"], "phase": boss["phase"], "spd": boss["spd"],
			"base": boss["base"], "stompT": boss["stomp_t"], "summonT": boss["summon_t"], "stun": boss["stun"], "slow": boss["slow"], "atkT": boss["atk_t"]}
	var grunts: Array = []
	var others: Array = []
	for u in g.units:
		if u["type"] == "grunt":
			grunts.append([u["x"], u["y"], u["hp"], u["stun"]])
		elif not u["boss"]:
			others.append({"type": u["type"], "x": u["x"], "y": u["y"], "hp": u["hp"], "stun": u["stun"], "slow": u["slow"], "atkT": u["atk_t"]})
	return {"step": step, "t": step * DT, "boss": brow, "grunts": grunts, "others": others,
		"hero": {"hp": p["hp"], "lost": g.skills.h_max_hp(p) - p["hp"], "x": p["x"], "y": p["y"], "dead": p["dead"] > 0.0, "deaths": p["deaths"]},
		"gold": p["gold"], "xp": p["xp"], "lvl": p["lvl"], "bossIncome": p["boss_income"], "wave": side["wave"], "bossSpawned": side["boss_spawned"]}
