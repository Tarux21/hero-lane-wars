extends RefCounted
## Items, Rucksack, Shop-Regeln und Heiltrank, 1:1 aus dem Browser-Prototyp (index.html: ITEM_LIST, resolveBuy, buy, sell, recalcItems).
## Alle Funktionen bekommen den Spieler `p` (Held-Dictionary). Die Effekte der Items (Krit, Dornen, Aura ...) stehen in game.gd/skills.gd.

var g: Node
var cfg: Dictionary
var item: Dictionary = {}            # id -> Item-Daten
var order: Array = []                # Reihenfolge wie im Prototyp


func _init(game: Node) -> void:
	g = game
	cfg = Data.cfg
	for it in Data.raw["items"]:
		item[it["id"]] = it
		order.append(it["id"])


## Gesamtpreis eines Items inklusive aller Teile (für den Verkauf)
func total_cost(id: String) -> int:
	var it: Dictionary = item[id]
	if it.has("parts"):
		var c := int(it["cost"])
		for part in it["parts"]:
			c += total_cost(str(part))
		return c
	return int(it["cost"])


## Was kostet der Kauf jetzt? Teile im Rucksack werden verbraucht, fehlende Teile werden zum Teilepreis
## (bei Zwischenstufen inkl. Rezept) mitgekauft. Rückgabe: {cost, consumed: [Rucksack-Indizes]}
func resolve_buy(id: String, bag: Array) -> Dictionary:
	var used: Array = []
	var cost := _rec(id, bag, used)
	return {"cost": cost, "consumed": used}


func _rec(id: String, bag: Array, used: Array) -> int:
	var it: Dictionary = item[id]
	if not it.has("parts"):
		return int(it["cost"])
	var cost := int(it["cost"])
	for part in it["parts"]:
		var idx := -1
		for i in bag.size():
			if bag[i] == part and not used.has(i):
				idx = i
				break
		if idx >= 0:
			used.append(idx)
		else:
			cost += _rec(str(part), bag, used)
	return cost


func in_base(p: Dictionary) -> bool:
	return p["x"] < float(cfg["baseX"]) and p["dead"] <= 0.0


## Warum geht der Kauf nicht? ("" = er geht)
func buy_reason(p: Dictionary, id: String) -> String:
	if not item.has(id):
		return "unbekannt"
	var it: Dictionary = item[id]
	if not in_base(p):
		return "nur in der Basis (Backport: B)"
	if it.get("consumable", false):
		if p["cons"].get(id, 0) >= int(cfg["consMax"]):
			return "Vorrat voll"
		return "" if p["gold"] >= float(it["cost"]) else "noch %d g" % int(ceil(float(it["cost"]) - p["gold"]))
	var r := resolve_buy(id, p["bag"])
	if p["bag"].size() - r["consumed"].size() + 1 > int(cfg["bagSize"]):
		return "Rucksack voll – erst ein Item verkaufen"
	# Hüte: nur ein Hut gleichzeitig (der Basis-Hut wird beim Aufwerten verbraucht)
	if it.get("slot", "") == "hat":
		for i in p["bag"].size():
			if item[p["bag"][i]].get("slot", "") == "hat" and not r["consumed"].has(i):
				return "du trägst schon einen Hut"
	return "" if p["gold"] >= float(r["cost"]) else "noch %d g" % int(ceil(float(r["cost"]) - p["gold"]))


func can_buy(p: Dictionary, id: String) -> bool:
	return not g.over and buy_reason(p, id) == ""


func buy(p: Dictionary, id: String) -> bool:
	if not can_buy(p, id):
		return false
	var it: Dictionary = item[id]
	if it.get("consumable", false):
		p["gold"] -= float(it["cost"])
		p["cons"][id] = p["cons"].get(id, 0) + 1
		return true
	var r := resolve_buy(id, p["bag"])
	p["gold"] -= float(r["cost"])
	var nb: Array = []
	for i in p["bag"].size():
		if not r["consumed"].has(i):
			nb.append(p["bag"][i])
	nb.append(id)
	p["bag"] = nb
	recalc(p)
	return true


func sell(p: Dictionary, i: int) -> bool:
	if i < 0 or i >= p["bag"].size() or not in_base(p):
		return false
	p["gold"] += floor(total_cost(p["bag"][i]) * float(cfg["sellRatio"]))
	p["bag"].remove_at(i)
	recalc(p)
	return true


## Werte aus dem Rucksack neu berechnen (nach jedem Kauf/Verkauf)
func recalc(p: Dictionary) -> void:
	var old_max: float = g.skills.h_max_hp(p)
	var t := {"dmg": 0.0, "armor": 0.0, "hp": 0.0, "as": 0.0, "sp": 0.0, "spd": 0.0, "crit": 0.0, "cdr": 0.0, "regen": 0.0, "ls": 0.0, "sv": 0.0, "dr": 0.0, "gps": 0.0, "bpRed": 0.0}
	var un := {}
	for id in p["bag"]:
		var it: Dictionary = item[id]
		var s: Dictionary = it.get("stats", {})
		for k in s.keys():
			t[k] += float(s[k])
		for u in it.get("unique", []):
			un[str(u)] = true
	p["bonus_dmg"] = t["dmg"]
	p["bonus_armor"] = t["armor"]
	p["bonus_hp"] = t["hp"]
	p["bonus_as"] = t["as"]
	p["bonus_sp"] = t["sp"]
	p["bonus_spd"] = t["spd"]
	p["crit_ch"] = minf(1.0, t["crit"])
	p["uniq"] = un
	p["cdr"] = minf(float(cfg["cdrCap"]), t["cdr"])
	p["bonus_regen"] = t["regen"]
	p["lifesteal"] = minf(0.5, t["ls"])
	p["spell_vamp"] = minf(0.5, t["sv"])
	p["dr"] = minf(float(cfg["drCap"]), t["dr"])
	p["gps"] = t["gps"]
	p["bp_red"] = minf(0.8, t["bpRed"])
	var nm: float = g.skills.h_max_hp(p)
	p["hp"] = minf(nm, p["hp"] + maxf(0.0, nm - old_max))          # steigt das max. Leben, steigt auch das aktuelle


func drink_potion(p: Dictionary) -> bool:
	if p["dead"] > 0.0 or p["cons"].get("potion", 0) < 1 or p["pot_cd"] > 0.0 or p["hp"] >= g.skills.h_max_hp(p):
		return false
	p["cons"]["potion"] -= 1
	p["pot_cd"] = float(cfg["potionCd"])
	var heal: float = float(cfg["potionHeal"]) * g.skills.h_max_hp(p)
	p["hp"] = minf(g.skills.h_max_hp(p), p["hp"] + heal)
	g.fx_text(p["x"] - 10.0, p["y"] - 34.0, "+%d" % int(round(heal)), "#7be07b", 0.8, 28)
	return true
