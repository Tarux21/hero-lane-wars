extends RefCounted
## Computer-Spieler (Bots) für Gegner und Mitspieler. 1:1 aus dem Browser-Prototyp (index.html: BOT_*, botThink, botSend, botShop,
## botLearn, botSkills). Spielt wie ein Mensch: Reaktionszeit, gelegentliche Fehler, Einkaufsreisen per Backport, Sende-Entscheidungen.
## Jeder Bot hat seinen Zustand in p["bot_state"]; er benutzt dieselben Regeln wie du (Items kaufen, Skills, Backport, Monster senden).

const BIAS := {"tank": [0, 1, 1, -10], "damage": [0, 1, 1, -10], "caster": [0, 1, 0.5, -10]}   # Skill-Lern-Reihenfolge je Klasse
const FD := ["gloves", "heart", "potion", "sword", "potion"]
const FC := ["heart", "staff", "potion", "gloves", "potion"]
const FT := ["heart", "potion", "heart", "potion"]
const POOL := {   # Bauplan-Auswahl je Klasse (Reihenfolge der Käufe), zufällig gewählt
	"damage": [
		["bigSword", "rake", "critCloak", "mightyBlade", "hat", "hatWind"] + FD,
		["rake", "critCloak", "windCloak", "stormBreaker", "hat", "hatWind"] + FD,
		["rake", "bloodGem", "cutlass", "windCloak", "ruinBlade", "hat", "hatBlood"] + FD,
		["bigSword", "dagger", "cleaver", "hat", "hatWind"] + FD,
		["bloodGem", "spellGem", "ruby", "soulDrinker", "bigSword", "rake", "critCloak", "mightyBlade", "hat", "hatBlood", "potion", "potion"],
	],
	"caster": [
		["bigStaff", "bigStaff", "arcaneCrown", "hat", "hatSage"] + FC,
		["bigStaff", "timeAmulet", "timeStaff", "hat", "hatSage"] + FC,
		["wand", "ruby", "tome", "guise", "tormentMask", "hat", "hatSage"] + FC,
		["dagger", "wand", "windCloak", "sparkBlade", "hat", "hatWind"] + FC,
		["bloodGem", "spellGem", "ruby", "soulDrinker", "hat", "hatBlood"] + FC,
		["ruby", "tome", "guise", "regenBand", "moonstone", "hat", "hatSage"] + FC,
	],
	"tank": [
		["cloth", "cloth", "strongArmor", "cloth", "thornArmor", "thornShirt", "thornPlate", "hat", "hatGuard"] + FT,
		["cloth", "lifeStone", "regenBand", "titanPlate", "hat", "hatGuard"] + FT,
		["lifeStone", "ruby", "regenBand", "lifeSpring", "hat", "hatGuard"] + FT,
		["cloth", "cloth", "strongArmor", "ruby", "bulwark", "hat", "hatGuard"] + FT,
		["lifeStone", "bigSword", "giantsMight", "hat", "hatGuard"] + FT,
	],
}

var g: Node
var cfg: Dictionary


func _init(game: Node) -> void:
	g = game
	cfg = Data.cfg


## Gewichte beim Senden: früh viele Grunts/Brocken, später auch Elites
func send_weights(t: float) -> Dictionary:
	if t < 480.0:
		return {"grunt": 3, "tank": 3, "archer": 2, "fast": 1, "elite": 0}
	return {"grunt": 1, "tank": 3, "archer": 2, "fast": 1, "elite": 3}


func setup(p: Dictionary, diff: Dictionary, style: String) -> void:
	var styles: Array = Data.raw["bot_style"].keys()
	var st := style
	if st == "random" or not Data.raw["bot_style"].has(st):
		st = styles[randi() % styles.size()]
	var pool: Array = POOL[p["key"]]
	p["bot_state"] = {"mode": "fight", "step": 0, "trips": 0, "deaths": 0, "was_dead": false, "clock": 0.0, "last_send": 0.0,
		"diff": diff, "style": st, "build": pool[randi() % pool.size()]}


func _plan(p: Dictionary) -> Array:
	return p["bot_state"]["build"]


## Preis des nächsten Bauplan-Schritts (0 = Bauplan abgeschlossen)
func next_cost(p: Dictionary) -> float:
	var b: Dictionary = p["bot_state"]
	var plan := _plan(p)
	if b["step"] >= plan.size():
		return 0.0
	var id: String = plan[b["step"]]
	var it: Dictionary = g.items.item[id]
	return float(it["cost"]) if it.get("consumable", false) else float(g.items.resolve_buy(id, p["bag"])["cost"])


func shop(p: Dictionary) -> void:
	var b: Dictionary = p["bot_state"]
	var plan := _plan(p)
	while b["step"] < plan.size():
		var id: String = plan[b["step"]]
		var it: Dictionary = g.items.item[id]
		if g.items.buy(p, id):
			b["step"] += 1
			continue
		# Schritt überspringen, wenn er nie möglich ist (Rucksack voll / Trankvorrat voll); sonst auf mehr Gold warten
		var blocked: bool
		if it.get("consumable", false):
			blocked = p["cons"].get(id, 0) >= int(cfg["consMax"])
		else:
			blocked = p["bag"].size() - g.items.resolve_buy(id, p["bag"])["consumed"].size() + 1 > int(cfg["bagSize"])
		if blocked:
			b["step"] += 1
		else:
			break


func learn_skills(p: Dictionary) -> void:
	var bias: Array = BIAS[p["key"]]
	while p["sp"] > 0:
		var best := -1
		var bs := 1e9
		for i in 4:
			var s: Dictionary = g.skills.skill_def(p, i)
			if p["lvl"] < int(cfg["unlock"][i]) or p["ranks"][i] >= int(s["max"]):
				continue
			var sc: float = p["ranks"][i] + bias[i]
			if sc < bs:
				bs = sc
				best = i
		if best < 0:
			break
		g.skills.learn(p, best)


## Anzahl Monster auf der eigenen Seite im Umkreis r um den Helden
func near_count(p: Dictionary, r: float) -> int:
	var n := 0
	for u in g.units_of(p):
		if Vector2(u["x"] - p["x"], u["y"] - p["y"]).length() <= r:
			n += 1
	return n


## Gegner im Kegel von p in Richtung tgt (wie nearCone im Prototyp)
func near_cone(p: Dictionary, range_: float, half: float, tgt: Dictionary) -> int:
	var ang := atan2(tgt["y"] - p["y"], tgt["x"] - p["x"])
	var n := 0
	for u in g.units_of(p):
		var vx: float = u["x"] - p["x"]
		var vy: float = u["y"] - p["y"]
		var d := sqrt(vx * vx + vy * vy)
		if d > range_ + u["r"]:
			continue
		if d < 1.0 or acos(clampf((vx * cos(ang) + vy * sin(ang)) / d, -1.0, 1.0)) <= half:
			n += 1
	return n


func cast_skills(p: Dictionary, tgt: Dictionary) -> void:
	var b: Dictionary = p["bot_state"]
	var miss: float = float(b["diff"]["miss"])
	# der Bot zielt leicht daneben
	var wx: float = tgt["x"] + (randf() * 30.0 - 15.0)
	var wy: float = tgt["y"] + (randf() * 20.0 - 10.0)
	var dx: float = wx - p["x"]
	var dy: float = wy - p["y"]
	var m := {"dx": dx, "dy": dy, "dist": maxf(1.0, Vector2(dx, dy).length()), "ang": atan2(dy, dx), "wx": wx, "wy": wy}
	var cast := func(i: int) -> void:
		if randf() >= miss:                                              # Fehlerquote je Schwierigkeit
			g.skills.cast_slot(p, i, m)
	var hp: float = p["hp"] / g.skills.h_max_hp(p)
	var dist_t := Vector2(tgt["x"] - p["x"], tgt["y"] - p["y"]).length()
	if p["key"] == "tank":
		if near_count(p, 240.0) >= 1:
			cast.call(0)
		if near_count(p, 450.0) >= 1:
			cast.call(2)
		var tr := float(g.cfg["tankRRange"])
		var th := float(g.cfg["tankRHalf"])
		if near_cone(p, tr, th, tgt) >= 3 or (hp < 0.4 and near_cone(p, tr, th, tgt) >= 1):
			cast.call(3)
	elif p["key"] == "damage":
		if near_count(p, 115.0) >= 2 or (hp < 0.6 and near_count(p, 115.0) >= 1):
			cast.call(0)
		if near_count(p, 220.0) >= 3 or (near_count(p, 220.0) >= 1 and hp < 0.5):
			cast.call(1)
		if near_count(p, 420.0) >= 1 and dist_t > 110.0:
			cast.call(2)
		if near_count(p, 650.0) >= 3:
			cast.call(3)
	else:
		if near_count(p, 380.0) >= 3:
			cast.call(0)
		if near_count(p, 240.0) >= 2:
			cast.call(1)
		if near_count(p, 500.0) >= 2:
			cast.call(2)
		if near_count(p, 450.0) >= 2:
			cast.call(3)


## Monster zum Gegner schicken (Entscheidung nach Schwierigkeit, Stil, Spielzeit und Gold)
func send_decision(p: Dictionary) -> void:
	var b: Dictionary = p["bot_state"]
	var st: Dictionary = Data.raw["bot_style"].get(b["style"], Data.raw["bot_style"]["balanced"])
	var diff: Dictionary = b["diff"]
	var t: float = g.t
	if t < 35.0 or t - b["last_send"] < float(diff["sendEvery"]) * float(st["every"]):
		return
	var ph := 0 if t < 240.0 else (1 if t < 600.0 else 2)
	var f := minf(0.95, float(diff["strat"][ph]) * float(st["strat"][ph]))
	var enemy_dead := false
	for q in g.sides[1 - p["side"]["idx"]]["players"]:
		if q["dead"] > 0.0:
			enemy_dead = true
	if enemy_dead:
		f = minf(0.9, f * 1.6)                                           # Gegner-Held tot: Druck machen
	if g.units_of(p).size() > 22 * g.lanes_per_team:
		f *= 0.4                                                         # eigene Lane brennt: erst verteidigen
	var reserve := 0.0
	if not (g._in_base(p) or b["mode"] == "shop"):
		reserve = next_cost(p) * 0.7 * float(st["reserve"])
	var budget := maxf(0.0, p["gold"] - reserve) * f
	for n in 10:
		var w := send_weights(t)
		var opts: Array = []
		for k in w.keys():
			if w[k] > 0 and float(Data.units[k]["cost"]) <= budget:
				opts.append(k)
		if opts.is_empty():
			break
		var tot := 0.0
		for k in opts:
			tot += w[k]
		var r: float = g.rand() * tot
		var pick: String = opts[0]
		for k in opts:
			r -= w[k]
			if r <= 0.0:
				pick = k
				break
		g.send(p, pick)
		budget -= float(Data.units[pick]["cost"])
		b["last_send"] = t


func think(p: Dictionary, dt: float) -> void:
	if not p.has("bot_state"):
		return
	var b: Dictionary = p["bot_state"]
	var diff: Dictionary = b["diff"]
	if p["dead"] > 0.0:
		if not b["was_dead"]:
			b["deaths"] += 1
			b["was_dead"] = true
		b["mode"] = "fight"
		b["clock"] = 0.0
		return
	b["was_dead"] = false
	b["clock"] -= dt
	if b["clock"] > 0.0:
		return
	b["clock"] = float(diff["react"][0]) + randf() * (float(diff["react"][1]) - float(diff["react"][0]))   # Reaktionszeit
	learn_skills(p)
	var mx: float = g.skills.h_max_hp(p)
	if p["cons"].get("potion", 0) > 0 and p["hp"] < 0.4 * mx:             # Trank trinken bei wenig Leben
		g.items.drink_potion(p)
	if g._in_base(p):
		shop(p)
		if b["mode"] != "fight" and p["hp"] > 0.9 * mx:
			b["mode"] = "fight"
	send_decision(p)
	var lane_units: Array = []                                            # Ziele: Monster auf der eigenen Lane
	for u in g.units_of(p):
		if g.lanes_per_team < 2 or u["lane"] == p["lane"]:
			lane_units.append(u)
	var near := near_count(p, 300.0)
	var home := Vector2(100.0, p["home_y"])
	if b["mode"] == "fight":
		var nx := next_cost(p)
		if p["hp"] < float(diff["retreat"]) * mx:
			b["mode"] = "retreat"
		elif nx > 0.0 and not g._in_base(p) and p["bp_cd"] <= 0.0 and near == 0 and (p["gold"] >= float(diff["shopGold"]) * nx or (p["gold"] >= nx and (lane_units.is_empty() or p["hp"] < 0.6 * mx))):
			b["mode"] = "shop"
	if b["mode"] == "retreat" or b["mode"] == "shop":
		if g._in_base(p):
			if b["mode"] == "shop":
				b["trips"] += 1
				b["mode"] = "fight"
			return
		if p["bp"] <= 0.0:
			p["target"] = null
			if p["bp_cd"] <= 0.0 and near_count(p, 260.0) == 0:
				g._start_backport(p)
			else:
				p["move_to"] = home
		return
	if lane_units.is_empty():
		p["target"] = null
		p["move_to"] = Vector2(700.0, p["home_y"])
		return
	var best: Variant = null
	var bs := 1e9
	for u in lane_units:
		var s: float = u["x"]
		if u["type"] == "archer":
			s -= 250.0
		if u["type"] == "elite":
			s -= 120.0
		if u["type"] == "fast":
			s -= 150.0
		if Vector2(u["x"] - p["x"], u["y"] - p["y"]).length() > 800.0:
			s += 500.0
		if s < bs:
			bs = s
			best = u
	p["target"] = best
	p["move_to"] = null
	cast_skills(p, best)
