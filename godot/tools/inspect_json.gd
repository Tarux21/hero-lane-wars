extends SceneTree
## Hilfsskript: zeigt die Struktur einer JSON-Datei (Schlüssel, Listenlängen, erste Beispielwerte).
## Aufruf: Godot --headless --path godot --script tools/inspect_json.gd -- <res://pfad.json> [maxTiefe]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://data/golden-economy.json"
	var depth := int(args[1]) if args.size() > 1 else 4
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	_show(data, "", depth)
	quit()


func _show(v: Variant, indent: String, depth: int) -> void:
	if depth < 0:
		return
	if v is Dictionary:
		for k in v.keys():
			var c: Variant = v[k]
			if c is Dictionary:
				print("%s%s {%d}" % [indent, k, c.size()])
				_show(c, indent + "  ", depth - 1)
			elif c is Array:
				print("%s%s [%d]" % [indent, k, c.size()])
				if c.size() > 0:
					var first: Variant = c[0]
					if first is Dictionary or first is Array:
						print("%s  [0]:" % indent)
						_show(first, indent + "    ", depth - 1)
					else:
						print("%s  [0] = %s" % [indent, str(first).substr(0, 80)])
			else:
				print("%s%s = %s" % [indent, k, str(c).substr(0, 80)])
	elif v is Array:
		for i in mini(v.size(), 3):
			print("%s[%d] = %s" % [indent, i, str(v[i]).substr(0, 100)])
