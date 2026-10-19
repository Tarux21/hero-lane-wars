extends SceneTree
## Balancing-Auswertung: liest alle Partie-Ergebnisse (JSON aus tools/balance/run_matrix.sh) und schreibt eine Zusammenfassung.
## Aufruf: <Godot-Konsole> --headless --path godot -s res://tools/balance_summary.gd -- <Ordner mit JSON> <Ausgabe.json>
## Blöcke nach Dateinamen: klassen_*, stile_*, stufen_*.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var out_path: String = args[1]
	var games: Array = []
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json") or f == "jobs.txt":
			continue
		var txt := FileAccess.get_file_as_string(dir.path_join(f))
		var d: Variant = JSON.parse_string(txt)
		if d is Dictionary:
			d["name"] = f.get_basename()
			games.append(d)
	var res := {"count": games.size()}
	res["dauer"] = _durations(games)
	res["klassen"] = _matrix(games, "klassen_", func(g): return [_cls(g, 0), _cls(g, 1)])
	res["stile"] = _matrix(games, "stile_", func(g): return [str(g["style"]), str(g["estyle"])])
	res["stufen"] = _pairs(games)
	res["leben"] = _lives_curve(games)
	res["leak"] = _leaks(games)
	res["wirtschaft"] = _economy(games)
	res["comeback"] = _comeback(games)
	res["senden"] = _sending(games)
	res["frueh_raus"] = _early_out(games)
	var fo := FileAccess.open(out_path, FileAccess.WRITE)
	fo.store_string(JSON.stringify(res, "  "))
	fo.close()
	print("AUSWERTUNG ", games.size(), " Partien -> ", out_path)
	quit()


func _cls(g: Dictionary, side: int) -> String:
	for p in g["players"]:
		if int(p["side"]) == side:
			return str(p["key"])
	return "?"


func _durations(games: Array) -> Dictionary:
	var mins: Array = []
	var waves: Array = []
	var bins := {}
	var no_end := 0
	for g in games:
		var m: float = float(g["t_end"]) / 60.0
		mins.append(m)
		waves.append(maxi(int(g["waves"][0]), int(g["waves"][1])))
		var b := mini(int(m / 5.0) * 5, 45)
		bins[str(b)] = int(bins.get(str(b), 0)) + 1
		if int(g["winner"]) < 0:
			no_end += 1
	mins.sort()
	waves.sort()
	return {"median_min": mins[mins.size() / 2] if not mins.is_empty() else 0.0, "mean_min": _mean(mins), "min_min": mins[0] if not mins.is_empty() else 0.0,
		"max_min": mins[-1] if not mins.is_empty() else 0.0, "median_wave": waves[waves.size() / 2] if not waves.is_empty() else 0, "bins": bins, "ohne_sieger": no_end}


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


## Siegquote Zeile gegen Spalte (beide Seiten zusammengefasst)
func _matrix(games: Array, prefix: String, keyfn: Callable) -> Dictionary:
	var w := {}
	var n := {}
	for g in games:
		if not str(g["name"]).begins_with(prefix) or int(g["winner"]) < 0:
			continue
		var k: Array = keyfn.call(g)
		var a: String = k[0]
		var b: String = k[1]
		var win_a := int(g["winner"]) == 0
		for pair in [[a, b, win_a], [b, a, not win_a]]:
			var key := "%s|%s" % [pair[0], pair[1]]
			n[key] = int(n.get(key, 0)) + 1
			w[key] = int(w.get(key, 0)) + (1 if pair[2] else 0)
	var out := {}
	for key in n:
		out[key] = {"quote": float(w[key]) / float(n[key]), "n": n[key]}
	return out


func _pairs(games: Array) -> Dictionary:
	var out := {}
	for g in games:
		if not str(g["name"]).begins_with("stufen_"):
			continue
		var key := "%s|%s" % [g["diff"], g["ediff"]]
		if not out.has(key):
			out[key] = {"siege_a": 0, "n": 0, "dauer": []}
		if int(g["winner"]) >= 0:
			out[key]["n"] += 1
			out[key]["siege_a"] += 1 if int(g["winner"]) == 0 else 0
		out[key]["dauer"].append(float(g["t_end"]) / 60.0)
	for key in out:
		out[key]["quote_a"] = float(out[key]["siege_a"]) / maxf(1.0, float(out[key]["n"]))
		out[key]["dauer_min"] = _mean(out[key]["dauer"])
		out[key].erase("dauer")
	return out


## Durchschnittliche Leben je Welle (alle Seiten aller Partien, solange die Partie noch läuft)
func _lives_curve(games: Array) -> Dictionary:
	var sum := {}
	var cnt := {}
	var lost_first := []
	for g in games:
		var seen := {}
		for e in g["log"]:
			var w := str(int(e["wave"]))
			sum[w] = float(sum.get(w, 0.0)) + float(e["lives"])
			cnt[w] = int(cnt.get(w, 0)) + 1
			var sk := int(e["side"])
			if not seen.has(sk) and float(e["lives"]) < float(g["log"][0]["lives"]):
				seen[sk] = true
				lost_first.append(int(e["wave"]) - 1)
	var curve := {}
	for w in sum:
		curve[w] = {"leben": float(sum[w]) / float(cnt[w]), "n": cnt[w]}
	lost_first.sort()
	# Früher Lebensverlust: verlorene Leben bis Welle w (Mittel) und Anteil der Seiten mit mindestens einem verlorenen Leben
	var early := {}
	for w in [5, 10, 15, 20, 30]:
		var lost_sum := 0.0
		var any := 0
		var n := 0
		for g in games:
			var start: float = float(g["log"][0]["lives"]) if not g["log"].is_empty() else 0.0
			for e in g["log"]:
				if int(e["wave"]) == w + 1:
					var l: float = start - float(e["lives"])
					lost_sum += l
					any += 1 if l > 0.0 else 0
					n += 1
		early[str(w)] = {"verloren_mittel": lost_sum / maxf(1.0, float(n)), "anteil_mind_1": float(any) / maxf(1.0, float(n)), "n": n}
	var short := 0
	for g in games:
		if float(g["t_end"]) < 15.0 * 60.0:
			short += 1
	return {"kurve": curve, "erstes_leben_median_welle": lost_first[lost_first.size() / 2] if not lost_first.is_empty() else -1,
		"bis_welle": early, "unter_15_min": float(short) / maxf(1.0, float(games.size()))}


func _leaks(games: Array) -> Dictionary:
	var out := {}
	for g in games:
		for side in g["leak"]:
			for t in side:
				out[t] = float(out.get(t, 0.0)) + float(side[t])
	for t in out:
		out[t] = out[t] / maxf(1.0, float(games.size()))
	return out                                                              # verlorene Leben je Partie und Monstertyp (beide Seiten)


func _economy(games: Array) -> Dictionary:
	var by_wave := {}
	for g in games:
		if not str(g["name"]).begins_with("klassen_"):
			continue
		for e in g["log"]:
			var w := str(int(e["wave"]))
			if not by_wave.has(w):
				by_wave[w] = {"lvl": 0.0, "income": 0.0, "gold": 0.0, "items": 0.0, "n": 0}
			for p in e["players"]:
				by_wave[w]["lvl"] += float(p["lvl"])
				by_wave[w]["income"] += float(p["income"])
				by_wave[w]["gold"] += float(p["gold"])
				by_wave[w]["items"] += float(p["items"])
				by_wave[w]["n"] += 1
	for w in by_wave:
		var n := maxf(1.0, float(by_wave[w]["n"]))
		for k in ["lvl", "income", "gold", "items"]:
			by_wave[w][k] = by_wave[w][k] / n
	return by_wave


## Comeback: Wer zur Hälfte der Partie mindestens 4 Leben zurücklag, wie oft gewann er trotzdem?
func _comeback(games: Array) -> Dictionary:
	var behind := 0
	var won := 0
	for g in games:
		if int(g["winner"]) < 0 or g["log"].is_empty():
			continue
		var half: float = float(g["t_end"]) / 2.0
		var lv := [-1, -1]
		for e in g["log"]:
			if float(e["t"]) <= half:
				lv[int(e["side"])] = int(e["lives"])
		if lv[0] < 0 or lv[1] < 0 or absi(lv[0] - lv[1]) < 4:
			continue
		behind += 1
		var trailing := 0 if lv[0] < lv[1] else 1
		if int(g["winner"]) == trailing:
			won += 1
	return {"partien": behind, "aufgeholt": won, "quote": float(won) / maxf(1.0, float(behind))}


## Anteil der Verlierer-Seiten je Klasse, die vor Welle 20 ausscheiden (früher Zusammenbruch)
func _early_out(games: Array) -> Dictionary:
	var out := {}
	for g in games:
		if int(g["winner"]) < 0:
			continue
		for p in g["players"]:
			var k := str(p["key"])
			if not out.has(k):
				out[k] = {"seiten": 0, "vor_welle_20": 0}
			out[k]["seiten"] += 1
			if int(p["side"]) != int(g["winner"]) and int(g["waves"][int(p["side"])]) < 20:
				out[k]["vor_welle_20"] += 1
	for k in out:
		out[k]["anteil"] = float(out[k]["vor_welle_20"]) / maxf(1.0, float(out[k]["seiten"]))
	return out


func _sending(games: Array) -> Dictionary:
	var out := {}
	for g in games:
		if not str(g["name"]).begins_with("stile_"):
			continue
		for p in g["players"]:
			var st := str(g["style"]) if int(p["side"]) == 0 else str(g["estyle"])
			if not out.has(st):
				out[st] = {"gesendet": 0.0, "einkommen": 0.0, "n": 0}
			var sn := 0
			for k in p["sent"]:
				sn += int(p["sent"][k])
			out[st]["gesendet"] += sn
			out[st]["einkommen"] += float(p["income"])
			out[st]["n"] += 1
	for st in out:
		var n := maxf(1.0, float(out[st]["n"]))
		out[st]["gesendet"] /= n
		out[st]["einkommen"] /= n
	return out
