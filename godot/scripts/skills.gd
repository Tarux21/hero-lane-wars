extends RefCounted
## Skills der drei Helden, 1:1 aus dem Browser-Prototyp (index.html, Abschnitt "SKILLS") nachgebaut.
## Alle Funktionen bekommen den Spieler `p` (Held-Dictionary), damit später auch Bots und Mitspieler dieselben Skills nutzen.
## `g` ist das Spiel (game.gd): Einheiten, Zonen, Zeitgeber, Effekte.

const CRIT_BY_RANK := [0.10, 0.125, 0.15, 0.225, 0.30]                      # Kettenblitz-Krit-Chance je Rang
const IRON := [                                                             # Tank-Passive "Eiserne Haut" je Rang
	{"armor": 6.0, "reflect": 0.20, "regen": 0.0}, {"armor": 10.0, "reflect": 0.30, "regen": 0.0},
	{"armor": 20.0, "reflect": 0.40, "regen": 0.01}, {"armor": 24.0, "reflect": 0.50, "regen": 0.01},
	{"armor": 40.0, "reflect": 0.60, "regen": 0.025}]
const ELEM_KEYS := ["fire", "frost", "lightning"]
const ELEM_COL := {"fire": "#ff6a2a", "frost": "#8fd8ff", "lightning": "#ffe066"}

var g: Node
var cfg: Dictionary


func _init(game: Node) -> void:
	g = game
	cfg = Data.cfg


# ---------------------------------------------------------------- Werte
func skill_def(p: Dictionary, i: int) -> Dictionary:
	return Data.raw["skills"][p["key"]][i]


func iron_passive(p: Dictionary) -> Dictionary:
	if p["key"] == "tank" and p["ranks"][1] > 0:
		return IRON[p["ranks"][1] - 1]
	return {"armor": 0.0, "reflect": float(cfg["innateReflect"]) if p["key"] == "tank" else 0.0, "regen": 0.0}


func buff(p: Dictionary, name: String) -> Variant:
	var b: Variant = p["buffs"].get(name)
	return b if b != null and b["t"] > 0.0 else null


func h_max_hp(p: Dictionary) -> float:
	return float(p["d"]["hp"]) + float(p["d"]["hpl"]) * (p["lvl"] - 1) + p["bonus_hp"]


func h_dmg(p: Dictionary) -> float:
	return float(p["d"]["dmg"]) + float(p["d"]["dpl"]) * (p["lvl"] - 1) + p["bonus_dmg"] * float(cfg["adEff"].get(p["key"], 1.0))


func h_armor(p: Dictionary) -> float:
	return float(p["d"]["armor"]) + float(p["d"]["armorl"]) * (p["lvl"] - 1) + p["bonus_armor"] + float(iron_passive(p)["armor"])


func h_as(p: Dictionary) -> float:
	var bonus: float = p["bonus_as"]
	for n in ["rage", "storm", "critAs"]:
		var b: Variant = buff(p, n)
		if b != null:
			bonus += float(b["as"])
	return float(p["d"]["as"]) * (1.0 + bonus)


func h_spd(p: Dictionary) -> float:
	var b: Variant = buff(p, "rage")
	return float(p["d"]["spd"]) + p["bonus_spd"] + (float(b["spd"]) if b != null else 0.0)


func h_sp(p: Dictionary) -> float:
	var sp: float = p["bonus_sp"] + (p["bonus_hp"] * float(cfg["hpApRatio"]) if p["uniq"].has("hpAp") else 0.0)
	return sp * (1.0 + (float(cfg["spMulBonus"]) if p["uniq"].has("spMul") else 0.0))


## Skillschaden: Basis + Rang-Zuwachs + Zauberkraft- und Angriffsanteil, mit Heldenstärke, Kombo und Frühphasen-Bonus.
func dmg_of(p: Dictionary, base: float, per: float, r: int, sc: float, k: float) -> float:
	var power: float = float(cfg["power"].get(p["key"], 1.0))
	var early: float = float(cfg["earlyBoost"].get(p["key"], 0.0)) * maxf(0.0, 1.0 - (p["lvl"] - 1) / (float(cfg["maxLevel"]) - 1.0))
	var amp: float = (1.0 + float(cfg["comboAmp"])) if p["amp_now"] else 1.0
	return (base + per * (r - 1) + sc * h_sp(p) + k * h_dmg(p)) * power * p["mul"] * amp * (1.0 + early)


# ---------------------------------------------------------------- Treffer und Statuseffekte
func affect(p: Dictionary, u: Dictionary, dmg: float, o: Dictionary = {}) -> void:
	var dealt: float = g.hit_unit(u, dmg, p)
	if p["spell_vamp"] > 0.0 and dealt > 0.0:                       # Zauberraub: Fähigkeitsschaden heilt (abgeschwächt)
		var vf := 2.0 if p["uniq"].has("vengeance") and p["hp"] < 0.4 * h_max_hp(p) else 1.0
		p["hp"] = minf(h_max_hp(p), p["hp"] + dealt * p["spell_vamp"] * vf * float(cfg["svFactor"]))
	if not g.units_of(p).has(u):
		return
	g.apply_torment(p, u)
	if o.get("stun", 0.0) > 0.0:
		u["stun"] = maxf(u["stun"], float(o["stun"]) * (0.3 if u["type"] == "boss" else 1.0))   # Bosse sind kaum betäubbar
	if o.get("slow", 0.0) > 0.0:
		u["slow"] = maxf(u["slow"], float(o["slow"]))
	if o.get("knock", 0.0) > 0.0:
		u["x"] = minf(float(cfg["spawnX"]) + 80.0, u["x"] + float(o["knock"]))
	if o.get("bleed", 0.0) > 0.0:
		u["bleed"] = maxf(u["bleed"], float(o["bleed"]))
		u["bleed_pct"] = maxf(u["bleed_pct"], float(o.get("bleed_pct", 0.0)))
	if o.get("burn", 0.0) > 0.0:
		u["burn"] = maxf(u["burn"], float(o["burn"]))
		u["burn_dps"] = maxf(u["burn_dps"], float(o.get("burn_dps", 0.0)))


func _dist(u: Dictionary, x: float, y: float) -> float:
	return Vector2(u["x"] - x, u["y"] - y).length()


func circle_hit(p: Dictionary, cx: float, cy: float, radius: float, dmg: float, o: Dictionary = {}, col: String = "", ring: bool = true) -> int:
	var n := 0
	for u in g.units_of(p).duplicate():
		if g.units_of(p).has(u) and _dist(u, cx, cy) <= radius + u["r"]:
			affect(p, u, dmg, o)
			n += 1
	if ring:
		g.fx_ring(cx, cy, radius, 0.45, col if col != "" else str(p["d"]["col"]))
	return n


func cone_hit(p: Dictionary, ox: float, oy: float, ang: float, range_: float, half: float, dmg: float, o: Dictionary = {}, col: String = "", a0: float = 0.5) -> void:
	var ux := cos(ang)
	var uy := sin(ang)
	for u in g.units_of(p).duplicate():
		if not g.units_of(p).has(u):
			continue
		var vx: float = u["x"] - ox
		var vy: float = u["y"] - oy
		var d := sqrt(vx * vx + vy * vy)
		if d > range_ + u["r"]:
			continue
		if d < 1.0 or acos(clampf((vx * ux + vy * uy) / d, -1.0, 1.0)) <= half:
			affect(p, u, dmg, o)
	g.fx_cone(ox, oy, ang, range_, half, 0.4, col if col != "" else str(p["d"]["col"]), a0)


## Kettenblitz: springt ab `first` von Gegner zu Gegner. Krit = doppelter Schaden + 0,5 s Betäubung.
func chain_lightning(p: Dictionary, from: Vector2, first: Dictionary, count: int, dmg: float, crit: float, falloff: float, jump: float = 170.0, hand: bool = false) -> void:
	var cur: Variant = first
	var hit: Array = []
	var link := 0
	var side_i: int = p["side"]["idx"]
	while cur != null and count > 0:
		count -= 1
		var is_crit: bool = g.rand() < crit
		hit.append(cur)
		g.vfx.bolt_later(link * 0.08, from.x, from.y, cur["x"], cur["y"], side_i, is_crit, hand and link == 0)
		g.sfx_after(p, "zap_crit" if is_crit else "zap", link * 0.08, 0.8, 0.85 if is_crit else 1.0 + 0.04 * link, Vector2(cur["x"], cur["y"]))
		link += 1
		from = Vector2(cur["x"], cur["y"])
		if is_crit:
			g.fx_text(cur["x"], cur["y"] - 28.0, "KRIT!", "#ffe066", 0.7, 34)
		affect(p, cur, dmg * 2.0 if is_crit else dmg, {"stun": 0.5 if is_crit else 0.0})
		dmg *= falloff
		var best: Variant = null
		var bd := 1e9
		for u in g.units_of(p):
			if hit.has(u):
				continue
			var d := _dist(u, from.x, from.y)
			if d <= jump and d < bd:
				bd = d
				best = u
		cur = best


func ground_point(p: Dictionary, m: Dictionary, range_: float) -> Vector2:
	var k: float = minf(m["dist"], range_) / m["dist"]
	return Vector2(p["x"] + m["dx"] * k, g.clamp_lane_y(p["y"] + m["dy"] * k))


func nearest_enemy(p: Dictionary, x: float, y: float, max_d: float) -> Variant:
	var best: Variant = null
	var bd := max_d
	for u in g.units_of(p):
		var d := _dist(u, x, y)
		if d < bd:
			bd = d
			best = u
	return best


# ---------------------------------------------------------------- Fähigkeiten einsetzen
func learn(p: Dictionary, i: int) -> void:
	var s := skill_def(p, i)
	if p["sp"] < 1 or p["ranks"][i] >= int(s["max"]) or p["lvl"] < int(cfg["unlock"][i]):
		return
	p["ranks"][i] += 1
	p["sp"] -= 1


func can_learn(p: Dictionary, i: int) -> bool:
	return p["sp"] >= 1 and p["ranks"][i] < int(skill_def(p, i)["max"]) and p["lvl"] >= int(cfg["unlock"][i])


## m = {dx, dy, dist, ang, wx, wy}: Richtung und Zielpunkt der Maus relativ zum Helden (Spielkoordinaten).
func cast_slot(p: Dictionary, i: int, m: Dictionary) -> bool:
	g.cur_side = p["side"]["idx"]
	if p["dead"] > 0.0 or g.over:
		return false
	var s := skill_def(p, i)
	var r: int = p["ranks"][i]
	if r < 1 or p["cds"][i] > 0.0 or s.get("passive", false):
		return false
	var amp: bool = p["uniq"].has("comboAmp") and p["combo_t"] > 0.0           # Zeitzauberstab: nächste Fähigkeit stärker
	p["amp_now"] = amp
	var res := _cast(p, i, r, m)
	p["amp_now"] = false
	if not res:
		return false                                                          # nicht gewirkt: kein Cooldown
	g.sfx_cast(p, i)
	if p["key"] == "caster" and i < 3:
		p["last_elem"] = ELEM_KEYS[i]
	p["cds"][i] = float(s["cd"]) * (1.0 - p["cdr"])                           # Abklingzeitverkürzung durch Items
	if p["uniq"].has("comboAmp"):
		p["combo_t"] = 0.0 if amp else float(cfg["comboWindow"])
		if amp:
			g.fx_text(p["x"] - 10.0, p["y"] - 50.0, "KOMBO +%d%%" % int(round(float(cfg["comboAmp"]) * 100.0)), "#9fe0ff", 0.7, 30)
	return true


func _cast(p: Dictionary, i: int, r: int, m: Dictionary) -> bool:
	match p["key"]:
		"tank":
			match i:
				0: return _tank_q(p, r, m)
				2: return _tank_e(p, r, m)
				3:
					circle_hit(p, p["x"], p["y"], 190.0, dmg_of(p, 200.0, 0.0, 1, 0.0, 1.0), {"stun": 3.0, "knock": 120.0})
					return true
		"damage":
			match i:
				0: return _dmg_q(p, r)
				1:
					p["buffs"]["rage"] = {"t": 10.0 if r >= 3 else 6.0, "as": 0.4 + 0.12 * (r - 1), "spd": 40.0, "cleave": r >= 5}
					g.fx_ring(p["x"], p["y"], 35.0, 0.5, "#ff8a7a")
					return true
				2: return _dmg_e(p, r, m)
				3: return _dmg_r(p)
		"caster":
			match i:
				0: return _cas_q(p, r, m)
				1: return _cas_w(p, r, m)
				2: return _cas_e(p, r, m)
				3: return _cas_r(p)
	return false


# ---- Tank
func _tank_q(p: Dictionary, r: int, m: Dictionary) -> bool:
	var range_ := 200.0 + 15.0 * (r - 1)
	var half := 0.62
	var dmg := dmg_of(p, float(cfg["tankQBase"]), 8.0, r, 0.0, 0.5)
	var stun := 0.8 + 0.12 * (r - 1)
	var o := {"stun": stun, "knock": 80.0 if r >= 3 else 0.0}
	var ang: float = m["ang"]
	cone_hit(p, p["x"], p["y"], ang, range_, half, dmg, o)
	if r >= 5:                                                               # zweite, stärkere Welle
		var o2 := {"stun": stun + 0.4, "knock": o["knock"]}
		g.later(0.6, func(): cone_hit(p, p["x"], p["y"], ang, range_ + 40.0, half, dmg * 1.25, o2))
	return true


func _tank_e(p: Dictionary, r: int, m: Dictionary) -> bool:
	var dmg := dmg_of(p, 35.0, 14.0, r, 0.0, 0.8)
	var targets := 5 if r >= 3 else 3
	var cands: Array = g.units_of(p).filter(func(u): return _dist(u, p["x"], p["y"]) <= 450.0)
	if cands.is_empty():
		g.fx_text(p["x"] - 30.0, p["y"] - 40.0, "Keine Ziele!", "#ff9a8a", 1.2, 30)
		return false
	cands.sort_custom(func(a, b): return _dist(a, m["wx"], m["wy"]) < _dist(b, m["wx"], m["wy"]))
	_hop(p, Vector2(p["x"], p["y"]), cands[0], targets, dmg, r >= 5, [])
	return true


func _hop(p: Dictionary, from: Vector2, u_in: Variant, left: int, dmg: float, bleed: bool, hit: Array) -> void:
	var u: Variant = u_in
	if not g.units_of(p).has(u):                                                   # Ziel ist inzwischen tot: nächstes suchen
		u = _nearest_not_hit(p, from, hit, 1e9)
	if u == null or left <= 0:
		_come_back(p, from)
		return
	hit.append(u)
	g.fx_line(from.x, from.y, u["x"], u["y"], 0.2, "#cfd8e8", 6.0)
	var pos := Vector2(u["x"], u["y"])
	affect(p, u, dmg, {"bleed": 3.0 if bleed else 0.0, "bleed_pct": 0.05})
	var nxt: Variant = _nearest_not_hit(p, pos, hit, 220.0)
	g.later(0.15, func():
		if nxt != null and left > 1:
			_hop(p, pos, nxt, left - 1, dmg, bleed, hit)
		else:
			_come_back(p, pos))


func _nearest_not_hit(p: Dictionary, from: Vector2, hit: Array, max_d: float) -> Variant:
	var best: Variant = null
	var bd := max_d
	for e in g.units_of(p):
		if hit.has(e):
			continue
		var d := _dist(e, from.x, from.y)
		if d <= max_d and d < bd:
			bd = d
			best = e
	return best


func _come_back(p: Dictionary, from: Vector2) -> void:
	var d := Vector2(from.x - p["x"], from.y - p["y"]).length()
	g.later(minf(0.6, 0.1 + d / 900.0), func():
		g.fx_line(from.x, from.y, p["x"], p["y"], 0.2, "#7be07b", 5.0)
		if p["dead"] <= 0.0:
			var heal: float = float(cfg["shieldHeal"]) * h_max_hp(p)
			p["hp"] = minf(h_max_hp(p), p["hp"] + heal)
			g.fx_text(p["x"] - 10.0, p["y"] - 34.0, "+%d" % int(round(heal)), "#7be07b", 0.8, 28))


# ---- Damage
func _dmg_q(p: Dictionary, r: int) -> bool:
	var radius := 95.0 + 5.0 * (r - 1)
	var dmg := dmg_of(p, 30.0, 10.0, r, 0.0, 0.7)
	var n := circle_hit(p, p["x"], p["y"], radius, dmg)
	var pct: float = float(cfg["whirlHeal"][r - 1])
	if pct > 0.0 and n > 0:
		var heal: float = minf(n, int(cfg["whirlHealCap"])) * pct * h_max_hp(p)
		p["hp"] = minf(h_max_hp(p), p["hp"] + heal)
		g.fx_text(p["x"] - 10.0, p["y"] - 34.0, "+%d" % int(round(heal)), "#7be07b", 0.8, 28)
	return true


func _dmg_e(p: Dictionary, r: int, m: Dictionary) -> bool:
	var pt := ground_point(p, m, 420.0)
	var sx: float = p["x"]
	var sy: float = p["y"]
	if Vector2(pt.x - sx, pt.y - sy).length() < 30.0:
		return false
	g.cancel_backport(p)
	p["move_to"] = null
	p["target"] = null
	var dmg := dmg_of(p, 20.0, 8.0, r, 0.0, 0.4)
	var fdmg := dmg_of(p, 10.0, 4.0, r, 0.0, 0.15)
	g.fx_line(sx, sy, pt.x, pt.y, 0.25, "#ffb36b", 6.0)
	p["leap"] = {"sx": sx, "sy": sy, "tx": pt.x, "ty": pt.y, "t": 0.22, "T": 0.22, "r": r, "dmg": dmg, "fdmg": fdmg}
	return true


func leap_land(p: Dictionary) -> void:
	var L: Dictionary = p["leap"]
	var r: int = L["r"]
	circle_hit(p, p["x"], p["y"], 80.0 + 4.0 * (r - 1), L["dmg"], {"stun": 1.5 if r >= 5 else 0.0}, "#ffb36b")
	if r >= 3:
		g.add_zone({"x": p["x"], "y": p["y"], "r": 100.0, "t": 4.0, "tick": 0.0, "every": 1.0, "dmg": L["fdmg"], "c": "#ff9a4a", "p": p})


func _dmg_r(p: Dictionary) -> bool:
	var pool: Array = g.pick_random(g.units_of(p).filter(func(u): return _dist(u, p["x"], p["y"]) <= 650.0), 5)
	if pool.is_empty():
		g.fx_text(p["x"] - 30.0, p["y"] - 40.0, "Keine Ziele!", "#ff9a8a", 1.2, 30)
		return false
	var dmg := dmg_of(p, 60.0, 0.0, 1, 0.0, 0.8)
	var fdmg := dmg_of(p, 18.0, 0.0, 1, 0.0, 0.3)
	for idx in pool.size():
		var u: Dictionary = pool[idx]
		var x: float = u["x"]
		var y: float = u["y"]
		g.fx_ring(x, y, 55.0, 0.5, "#fff3a0")
		g.later(0.3 + 0.25 * idx, func():
			g.fx_line(x, y - 320.0, x, y, 0.2, "#dfe6f0", 6.0)
			circle_hit(p, x, y, 60.0, dmg, {}, "#ffe066")
			g.add_zone({"x": x, "y": y, "r": 70.0, "t": 8.0, "tick": 0.0, "every": 1.0, "dmg": fdmg, "c": "#ffe066", "p": p}))
	return true


# ---- Caster
func _cas_w(p: Dictionary, r: int, m: Dictionary) -> bool:
	var ang: float = m["ang"]
	var range_ := 200.0 + 15.0 * (r - 1)
	cone_hit(p, p["x"], p["y"], ang, range_, 0.62, dmg_of(p, 20.0, 10.0, r, 0.3, 0.0),
		{"slow": 3.0 + 0.5 * (r - 1), "stun": 1.6 if r >= 5 else (0.8 if r >= 3 else 0.0)}, "#9fdcff", 0.2)
	g.vfx.cast_burst(p, Color("#8fd8ff"), p["x"] + cos(ang) * 100.0, p["y"] + sin(ang) * 100.0)
	g.vfx.frost_breath(p, ang, range_, 0.62, r)
	g.sfx_p(p, "frost_cast")
	return true


func _cas_q(p: Dictionary, r: int, m: Dictionary) -> bool:
	var pt := ground_point(p, m, 380.0)
	var radius := 90.0 + 6.0 * (r - 1)
	var tick := dmg_of(p, 9.0, 5.0, r, 0.2, 0.08)
	var follow: String = "enemy" if r >= 3 else ""
	g.vfx.cast_burst(p, Color("#ff8a3a"), pt.x, pt.y)
	g.vfx.fireball(p, pt.x, pt.y, r >= 5)
	g.sfx_p(p, "fire_cast")
	if r >= 5:                                                               # nur ein Feld: es entsteht erst nach dem Meteoreinschlag
		g.sfx_p(p, "meteor_fall", 1.0, 1.0, Vector2(pt.x, pt.y))
		g.sfx_after(p, "meteor_hit", 0.9, 1.0, 1.0, Vector2(pt.x, pt.y))
		g.sfx_after(p, "fire_ignite", 1.2, 1.0, 1.0, Vector2(pt.x, pt.y))                       # danach knistert das Feuerfeld am Boden
		g.later(0.9, func():
			circle_hit(p, pt.x, pt.y, 100.0, dmg_of(p, 120.0, 0.0, 1, 0.8, 0.3), {}, "#ff5a2a", false)
			g.add_zone({"x": pt.x, "y": pt.y, "r": radius, "t": 6.0, "tick": 0.0, "every": 1.0, "dmg": tick, "c": "#ff7a2a", "follow": follow, "p": p, "kind": "fire"}))
	else:
		g.sfx_after(p, "fire_ignite", 0.28, 1.0, 1.0, Vector2(pt.x, pt.y))
		g.add_zone({"x": pt.x, "y": pt.y, "r": radius, "t": 5.0, "tick": 0.0, "every": 1.0, "dmg": tick, "c": "#ff7a2a", "follow": follow, "p": p, "kind": "fire", "fx_delay": 0.28})
	return true


func _cas_e(p: Dictionary, r: int, m: Dictionary) -> bool:
	var pool: Array = g.units_of(p).filter(func(u): return _dist(u, p["x"], p["y"]) <= 520.0)
	if pool.is_empty():
		return true                                                          # Prototyp: kein Ziel, aber Cooldown läuft trotzdem
	pool.sort_custom(func(a, b): return _dist(a, m["wx"], m["wy"]) < _dist(b, m["wx"], m["wy"]))
	g.vfx.cast_burst(p, Color("#9fc8ff"), pool[0]["x"], pool[0]["y"])
	chain_lightning(p, Vector2(p["x"], p["y"]), pool[0], 3 + r, dmg_of(p, 40.0, 18.0, r, 0.6, 0.0), CRIT_BY_RANK[r - 1], 1.0 if r >= 5 else 0.9, 170.0, true)
	return true


func _cas_r(p: Dictionary) -> bool:
	if p["last_elem"] == "":
		g.fx_text(p["x"] - 40.0, p["y"] - 40.0, "Erst Q, W oder E benutzen!", "#ff9a8a", 1.5, 30)
		return false
	var t: String = p["last_elem"]
	g.set_elementar({"type": t, "x": p["x"] + 35.0, "y": p["y"], "hp": float(cfg["elemHp"]), "max": float(cfg["elemHp"]), "t": float(cfg["elemTime"]),
		"atk_t": 1.0, "ab_t": 2.0, "e_rank": maxi(1, p["ranks"][2]), "sp": h_sp(p), "p": p})     # nur ein Elementar gleichzeitig
	g.vfx.cast_burst(p, Color.html(ELEM_COL[t]), p["x"] + 35.0, p["y"])
	g.vfx.summon(p["x"] + 35.0, p["y"], p["side"]["idx"], t)
	g.sfx_p(p, "summon_" + t, 1.0, 1.0, Vector2(p["x"] + 35.0, p["y"]))
	return true


# ---------------------------------------------------------------- Elementare (Caster-Ultimate)
func elem_ability(e: Dictionary) -> bool:
	var tgt: Variant = nearest_enemy(e["p"], e["x"], e["y"], float(cfg["elemRange"]))
	if tgt == null:
		return false                                                         # kein Ziel: bald nochmal versuchen
	var p: Dictionary = e["p"]
	var sp: float = e["sp"]
	if e["type"] == "fire":
		var ang := atan2(tgt["y"] - e["y"], tgt["x"] - e["x"])
		cone_hit(p, e["x"], e["y"], ang, 260.0, 0.6, 45.0 + 0.5 * sp, {"burn": 6.0, "burn_dps": 16.0 + 0.3 * sp}, "#ff6a2a")
		g.vfx.flame_jet(e["x"], e["y"], p["side"]["idx"], ang, 260.0, 0.6)
		g.sfx_p(p, "flame_jet", 0.7, 1.0, Vector2(e["x"], e["y"]))
	elif e["type"] == "frost":
		var pool: Array = g.pick_random(g.units_of(p).filter(func(u): return _dist(u, e["x"], e["y"]) <= float(cfg["elemRange"])), 3)
		if not pool.is_empty():
			g.sfx_p(p, "frost_zone", 0.8, 1.0, Vector2(e["x"], e["y"]))
		for u in pool:
			g.add_zone({"x": u["x"], "y": u["y"], "r": 75.0, "t": 5.0, "tick": 0.0, "every": 1.0, "dmg": 7.0 + 0.2 * sp, "c": "#8fd8ff", "o": {"slow": 1.5}, "p": p, "kind": "frost"})
	else:
		var er: int = e["e_rank"]
		chain_lightning(p, Vector2(e["x"], e["y"]), tgt, 3 + er + 3, dmg_of(p, 40.0, 18.0, er, 0.6, 0.0) * 0.8, CRIT_BY_RANK[er - 1], 1.0 if er >= 5 else 0.9, 210.0)
	return true


func update_elem(e: Dictionary, dt: float) -> bool:
	## gibt false zurück, wenn der Elementar verschwindet
	e["t"] -= dt
	if e["hp"] <= 0.0 or e["t"] <= 0.0:
		g.fx_ring(e["x"], e["y"], 35.0, 0.5, str(ELEM_COL[e["type"]]))
		g.vfx.elem_vanish(e["x"], e["y"], e["p"]["side"]["idx"], str(e["type"]))
		g.sfx_p(e["p"], "elem_vanish", 0.7, 1.0, Vector2(e["x"], e["y"]))
		return false
	e["atk_t"] -= dt
	if e["atk_t"] <= 0.0:
		var t: Variant = nearest_enemy(e["p"], e["x"], e["y"], 170.0)
		if t != null:
			e["atk_t"] = 1.2
			g.vfx.elem_shot(str(e["type"]), e["x"], e["y"], t["x"], t["y"], e["p"]["side"]["idx"])
			g.sfx_p(e["p"], "elem_shot_" + str(e["type"]), 0.5, 1.0, Vector2(e["x"], e["y"]))
			g.hit_unit(t, 8.0 + 0.15 * e["sp"], e["p"])
		else:
			e["atk_t"] = 0.3
	e["ab_t"] -= dt
	if e["ab_t"] <= 0.0:
		e["ab_t"] = 6.0 + g.rand() * 4.0 if elem_ability(e) else 1.0
	return true
