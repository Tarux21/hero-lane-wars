extends "res://scripts/map_nachtwald.gd"
## Karte "Burg" (Stil des Referenzbilds): sonnige Wiese, die Lane ist ein Weg vom Monster-Wald über Felder und Bauernhöfe
## durch die Stadt bis zur Burg. Die Basis liegt im Burghof; statt der Statue zeigt das Burgtor die Team-Leben (Schäden).
## Das Tor geht auf, wenn ein eigener Held davorsteht; durchbrechende Monster rennen dagegen und zerfallen zu Staub.
## Gesendete Monster warten am Lagerfeuer am Waldrand. Nur Optik: Lanes, Wege und Regeln bleiben wie in game.gd.
## Modelle: Quaternius Medieval Village / Fantasy Props / Stylized Nature MegaKit [Source] (CC0), aufbereitet mit
## godot/tools/blender/make_burg_assets.py nach assets/burg/; Wind- und Laub-Shader aus dem Natur-Paket (shaders/natur/).

const BCOLORS := {
	"ground": Color("#7a7a30"), "lane": Color("#8a7350"), "strip": Color("#7a6648"), "wall": Color("#6d6558"), "wall_top": Color("#857b6c"),
	"river": Color("#2a6a85"), "plaza": Color("#8b8272"), "fog": Color(0.78, 0.82, 0.88, 0.80),
}
const DIR := "res://assets/burg/"
const GATE_Z := -1.5                    # Tor auf der Durchbruchlinie (leakX = 30 -> 1,5 m vor der Basis)
const TOWN_END := -52.0                 # Stadt bis hier, danach Felder
const FIELD_END := -118.0               # Felder bis hier, danach Wald
const COURT_DEPTH := 34.0               # Burghof: so tief hinter dem Tor (größer als die alte Basis, Platz für Leben)
const POOL_R := [2.3, 3.5]              # Ringe der wartenden Monster ums Lagerfeuer

var parts_cache: Dictionary = {}        # Name -> [[Mesh, Transform3D], ...] (Naturmodelle mit Wind-Shadern)
var shaders: Dictionary = {}
var noise_tex: Texture2D
var wind_tex: Texture2D
var gates: Array = []                   # {"team", "lx", "left", "right", "open", "stage"}
var camp_c := Vector3.ZERO


func _init(game: Node) -> void:
	super(game)
	rng.seed = 515151


# ---------------------------------------------------------------- Laden
func _mesh(name: String) -> Mesh:
	var path := DIR + name + ".gltf"
	if not FileAccess.file_exists(path):
		return super(name)
	if meshes.has(name):
		return meshes[name]
	var p := _parts(name, false)
	var m: Mesh = p[0][0] if not p.is_empty() else null
	meshes[name] = m
	return m


## Alle Teil-Meshes eines Modells mit ihrer Lage (relativ zur Wurzel). natur = Wind-/Laub-Shader statt der glTF-Materialien.
func _parts(name: String, natur: bool) -> Array:
	var key := name + ("#n" if natur else "")
	if parts_cache.has(key):
		return parts_cache[key]
	var out: Array = []
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	if doc.append_from_file(DIR + name + ".gltf", st) == OK:
		var root := doc.generate_scene(st)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != root:
				xf = (n as Node3D).transform * xf if n is Node3D else xf
				n = n.get_parent()
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if natur:
				mesh = _natur_mesh(mesh, name)
			out.append([mesh, xf])
		root.free()
	parts_cache[key] = out
	return out


func _shader(file: String) -> Shader:
	if not shaders.has(file):
		shaders[file] = load("res://shaders/natur/%s.gdshader" % file)
	return shaders[file]


func _noise() -> Texture2D:
	if noise_tex == null:
		var nt := NoiseTexture2D.new()
		nt.noise = FastNoiseLite.new()
		nt.seamless = true
		noise_tex = nt
	return noise_tex


func _wind() -> Texture2D:
	if wind_tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "Noise_Wind.png"))
		if img != null:
			wind_tex = ImageTexture.create_from_image(img)
	return wind_tex


## Materialien der Naturmodelle durch die Paket-Shader ersetzen (nach Materialname im glTF)
func _natur_mesh(src: Mesh, model: String) -> Mesh:
	var mesh := src.duplicate() as Mesh
	for s in mesh.get_surface_count():
		var om := mesh.surface_get_material(s)
		var tex: Texture2D = null
		var nrm: Texture2D = null
		var mname := ""
		if om is StandardMaterial3D:
			tex = (om as StandardMaterial3D).albedo_texture
			nrm = (om as StandardMaterial3D).normal_texture
			mname = om.resource_name
		var sm := ShaderMaterial.new()
		if mname.begins_with("Grass"):
			sm.shader = _shader("M_Grass")
			var wheat := model.contains("Wheat")
			sm.set_shader_parameter("Color_Top", Color(0.86, 0.68, 0.22) if wheat else Color(0.62, 0.66, 0.12))
			sm.set_shader_parameter("Color_Bottom", Color(0.40, 0.28, 0.05) if wheat else Color(0.16, 0.26, 0.02))
			sm.set_shader_parameter("wind_line_color", Color(0.95, 0.80, 0.35) if wheat else Color(0.70, 0.66, 0.15))
			sm.set_shader_parameter("World_Color_Variation", Color(0.8, 0.62, 0.2) if wheat else Color(0.62, 0.55, 0.12))
			sm.set_shader_parameter("NoiseTexture", _wind())
			sm.set_shader_parameter("GeneratedNoise", _noise())
		elif mname.begins_with("Bark"):
			sm.shader = _shader("M_Bark")
			sm.set_shader_parameter("texture_albedo", tex)
			sm.set_shader_parameter("normal_map", nrm)
			sm.set_shader_parameter("Color_Bottom", Color(0.29, 0.35, 0.02))
		elif mname == "Flowers" or mname == "Leaves":
			sm.shader = _shader("M_BaseFoliage")
			sm.set_shader_parameter("texture_albedo", tex)
			sm.set_shader_parameter("GeneratedNoise", _noise())
			sm.set_shader_parameter("alpha_scissor_threshold", 0.6)
		elif mname.begins_with("Leaves") or mname.begins_with("Leaf"):
			var pine := mname.contains("Pine") and not mname.contains("Giant")
			sm.shader = _shader("M_Leaves_Pine" if pine else ("M_Leaves_GiantPine" if mname.contains("Giant") else "M_Leaves"))
			sm.set_shader_parameter("Alpha", tex)
			var leaf := Color(0.47, 0.63, 0.09)
			var sss := Color(0.46, 0.72, 0.0)
			if pine:
				leaf = Color(0.11, 0.32, 0.02); sss = Color(0.65, 0.7, 0.0)
			elif mname.contains("Giant"):
				leaf = Color(0.10, 0.36, 0.12); sss = Color(0.3, 0.55, 0.15)
				sm.set_shader_parameter("ExtraColor", Color(0.13, 0.33, 0.25))
			elif mname.contains("Birch"):
				leaf = Color(0.85, 0.62, 0.12); sss = Color(1.0, 0.75, 0.2)            # Birken goldgelb (Spätsommer wie im Referenzbild)
			elif mname.contains("Twisted"):
				leaf = Color(0.36, 0.55, 0.12); sss = Color(0.5, 0.7, 0.1)            # Büsche
			sm.set_shader_parameter("Leaf_Color", leaf)
			sm.set_shader_parameter("SSS_Color", sss)
			sm.set_shader_parameter("WindSpeed", 6.0)
			sm.set_shader_parameter("WindStrength", 0.08)
			sm.set_shader_parameter("SSS_Strength", 2.0)
			sm.set_shader_parameter("SSS_Blend", 0.2)
			sm.set_shader_parameter("GlobalVariation", true)
		else:
			continue
		mesh.surface_set_material(s, sm)
	return mesh


## Naturmodell vielfach zeichnen (je Teil ein MultiMesh), Transformliste in Welt-Koordinaten
func _nat_scatter(name: String, xf: Array, shadows: bool = true) -> void:
	if xf.is_empty():
		return
	for part in _parts(name, true):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, (xf[i] as Transform3D) * (part[1] as Transform3D))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		if not shadows:
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(inst)


## Modell aus mehreren Teilen einzeln setzen (z. B. Requisiten); gibt den Wurzelknoten zurück
func _put_parts(name: String, pos: Vector3, yaw: float, s: float = 1.0, scl: Vector3 = Vector3.ONE) -> Node3D:
	var parts := _parts(name, false)
	if parts.is_empty():
		return null
	var root := Node3D.new()
	root.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(scl * s), pos)
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		root.add_child(mi)
	g.add_child(root)
	return root


# ---------------------------------------------------------------- Himmel, Licht, Boden
func setup_environment(env: Environment, sun: DirectionalLight3D) -> void:
	env.background_color = Color("#9cc3e6")
	env.ambient_light_color = Color("#c9d3e6")
	env.ambient_light_energy = 0.75
	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sun.light_color = Color("#ffe2b0")
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-48, -35, 0)          # warme Nachmittagssonne von links, lange Schatten


func forest_floor(mi: MeshInstance3D) -> void:
	var sh := load("res://shaders/burg_ground.gdshader") as Shader
	if sh == null or mi == null:
		return
	var sm := ShaderMaterial.new()
	sm.shader = sh
	mi.material_override = sm


func build_lane_ground(cx: float, half: float, court_x: float) -> void:
	var sh := load("res://shaders/burg_lane.gdshader") as Shader
	if sh == null:
		return
	var s_end: float = float(g.cfg["spawnX"]) * g.S
	var z0: float = COURT_DEPTH + 2.0
	var z1: float = -(s_end + 14.0)
	var q := PlaneMesh.new()
	q.size = Vector2((half + 3.0) * 2.0, z0 - z1)
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("center_x", cx)
	sm.set_shader_parameter("half_w", half)
	sm.set_shader_parameter("town_end", TOWN_END)
	sm.set_shader_parameter("court_z", GATE_Z + 1.0)
	sm.render_priority = -20
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = sm
	mi.position = Vector3(cx, 0.02, (z0 + z1) / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


# ---------------------------------------------------------------- Stadtfluss
func build_river(river_x: float, lane_len: float) -> void:
	river_x_ = river_x
	var sh := load("res://shaders/burg_river.gdshader") as Shader
	var z0 := COURT_DEPTH + 10.0
	var z1 := -(lane_len + 24.0)
	if sh != null:
		var q := PlaneMesh.new()
		q.size = Vector2(5.0, z0 - z1)
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("river_x", river_x)
		sm.set_shader_parameter("half_w", 2.5)
		sm.render_priority = -21
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = sm
		mi.position = Vector3(river_x, -0.12, (z0 + z1) / 2.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	# Kaimauern in der Stadt (flache Mauerstücke), danach natürliches Ufer mit Steinen und Gras
	var z := z0
	while z > TOWN_END:
		for sd in [-1.0, 1.0]:
			var mi2 := _put("Burg_Mauer", Vector3(river_x + sd * 2.85, -0.35, z), PI / 2.0, 1.0)
			if mi2 != null:
				mi2.transform.basis = Basis(Vector3.UP, PI / 2.0).scaled(Vector3(0.25, 0.13, 1.0))     # global skaliert: dünn (x), niedrig (y), Länge bleibt (z)
		z -= 2.0
	var stones: Array = []
	var reeds: Array = []
	z = TOWN_END
	while z > z1:
		for sd in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				stones.append(_t(river_x + sd * rng.randf_range(2.4, 3.1), z + rng.randf_range(-1.0, 1.0), rng.randf_range(0.5, 0.9)))
			if rng.randf() < 0.8:
				reeds.append(_t(river_x + sd * rng.randf_range(2.6, 3.4), z + rng.randf_range(-1.0, 1.0), rng.randf_range(0.9, 1.3)))
		z -= 1.6
	_nat_scatter("Pebble_Round_3", stones)
	_nat_scatter("Grass_Wispy_Tall", reeds, false)
	build_pool_island()


# ---------------------------------------------------------------- Lager der gesendeten Monster (Lagerfeuer am Waldrand)
func _island_center() -> Vector3:
	return Vector3(river_x_ - 9.0, 0.0, FIELD_END + 6.0)


func build_pool_island() -> void:
	var c := _island_center()
	camp_c = c
	_put_parts("FirePit", c, 0.0, 1.6)
	_put_parts("CampfireTripod", c, 0.4, 1.6)
	for k in 6:                                                            # Holzbänke/Kisten im Kreis
		var a := float(k) / 6.0 * TAU + 0.3
		if k % 2 == 0:
			_put_parts("Bench", c + Vector3(cos(a), 0, sin(a)) * 4.6, -a + PI / 2.0, 1.4)
	_put_parts("Barrel", c + Vector3(-5.0, 0, 2.5), 0.2, 1.4)
	_put_parts("Crate_Wooden", c + Vector3(5.2, 0, -2.0), 0.6, 1.4)
	_reserve(c.x, c.z, 6.0)
	var l := _light(c + Vector3(0.0, 1.6, 0.0), Color("#ff9a40"), 1.6, 12.0)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 1.1 * Data.user.light_factor(), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 1.9 * Data.user.light_factor(), 0.45).set_trans(Tween.TRANS_SINE)
	_motes(c + Vector3(0, 1.2, 0), Vector3(0.5, 0.1, 0.5), 30, Color("#ffaa40"), 0.22, 1.8, 2.2)
	var burst := _fog_particles(c + Vector3(0.0, 0.6, 0.0), 22, 2.2, 1.5, 3.5, true)   # Rauchstoß beim Aufbruch
	burst.direction = Vector3.UP
	burst.spread = 25.0
	burst.color = Color(0.55, 0.52, 0.5, 0.35)
	burst.emission_box_extents = Vector3(2.4, 0.2, 2.4)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 64
	lab.outline_size = 12
	lab.modulate = Color("#ffe0a0")
	lab.position = c + Vector3(0.0, 3.6, 0.0)
	lab.no_depth_test = true
	g.add_child(lab)
	pool_vis = {"c": c, "mat": null, "base_e": 1.0, "light": l, "burst": burst, "label": lab, "figs": [], "flash": 0.0}


func _pool_slot(k: int) -> Vector3:
	if k < 6:
		var a := float(k) * TAU / 6.0
		return Vector3(cos(a), 0.0, sin(a)) * float(POOL_R[0])
	var b := float(k - 6) * TAU / 12.0 + PI / 12.0
	return Vector3(cos(b), 0.0, sin(b)) * float(POOL_R[1])


# ---------------------------------------------------------------- Burgtor statt Statue
func place_statue(team: int, cx: float, col: Color) -> void:
	var first: int = team * int(g.lanes_per_team)
	var entry := {"node": null, "stage": 0, "team": team, "pos": Vector3(cx, 0.0, GATE_Z), "gates": []}
	for k in int(g.lanes_per_team):
		var lx: float = g.lane_xs[first + k]
		_put("Burg_Torbau", Vector3(lx, 0.0, GATE_Z), 0.0, 1.0)
		var left := _put("Burg_Tor", Vector3(lx - 3.0, 0.0, GATE_Z - 0.6), 0.0, 1.0)
		var right := _put("Burg_Tor", Vector3(lx + 3.0, 0.0, GATE_Z - 0.6), PI, 1.0)
		for sd in [-1.0, 1.0]:
			_gate_tower(Vector3(lx + sd * 6.0, 0.0, GATE_Z), team)
			_put_parts("Banner_Vertical_%d" % (1 if team == 0 else 2), Vector3(lx + sd * 4.2, 0.0, GATE_Z - 3.6), 0.0, 1.6)
		var gate := {"team": team, "lx": lx, "left": left, "right": right, "open": 0.0, "stage": 0, "shake": 0.0}
		gates.append(gate)
		entry["gates"].append(gate)
		g._cyl(Vector3(lx, 0.04, GATE_Z + 2.4), 1.6, 0.02, col.darkened(0.55), col)     # Farbring: Cyan = du, Orange = Gegner
	g.statues.append(entry)


func set_statue_stage(entry: Dictionary, stage: int) -> void:
	entry["stage"] = stage
	for gate in entry.get("gates", []):
		gate["stage"] = stage
		var lm: MeshInstance3D = gate["left"]
		var rm: MeshInstance3D = gate["right"]
		if lm == null or rm == null:
			continue
		if stage >= 1:
			lm.mesh = _mesh("Burg_Tor_kaputt")
		if stage >= 2:
			rm.mesh = _mesh("Burg_Tor_kaputt")
		if stage >= 3:                                                 # Tor zerschlagen: Flügel weg, Trümmer
			lm.visible = false
			rm.visible = false
			var rubble: Array = []
			for k in 7:
				rubble.append(_t(float(gate["lx"]) + rng.randf_range(-3.0, 3.0), GATE_Z + rng.randf_range(-1.5, 1.5), rng.randf_range(0.4, 0.8)))
			_nat_scatter("Rock_Medium_2", rubble)
		_burst(Vector3(float(gate["lx"]), 2.0, GATE_Z - 0.5), 60 if stage < 3 else 110)


## Torturm: kurzer Rundturm, das Ziegeldach sitzt knapp über der Mauer (verdeckt den Helden am Tor nicht)
func _gate_tower(p: Vector3, team: int) -> void:
	var tw := _put("Haus_Tower", p, 0.0, 1.0)
	if tw != null:
		tw.transform.basis = Basis.IDENTITY.scaled(Vector3(0.8, 0.32, 0.8))


## Durchbrechendes Monster rennt gegen das Tor: Staubwolke, Tor wackelt (nur Optik, aufgerufen aus game.gd)
func gate_hit(side_idx: int, wpos: Vector3) -> void:
	for gate in gates:
		if int(gate["team"]) == side_idx and absf(float(gate["lx"]) - wpos.x) < 8.0:
			gate["shake"] = 0.35
			var p := _fog_particles(Vector3(wpos.x, 0.8, GATE_Z - 1.0), 14, 1.2, 1.0, 2.6, true)
			p.color = Color(0.62, 0.56, 0.48, 0.45)
			p.direction = Vector3(0, 0.6, -1)
			p.emitting = true
			var tw := p.create_tween()
			tw.tween_interval(2.0)
			tw.tween_callback(p.queue_free)
			return


## Heilbrunnen im Burghof: Steinbecken mit Mittelschale, plätscherndes Wasser; leuchtet sanft, wenn geheilt wird (heal_lights)
func place_fountain(cx: float, z: float) -> void:
	var c := Vector3(cx, 0.0, z)
	_put_parts("Brunnen", c, 0.0, 1.0)
	var l := _light(c + Vector3(0, 1.8, 0), Color("#9ad8ff"), 0.5, 8.0)
	g.heal_lights.append(l)
	var spray := _fog_particles(c + Vector3(0, 2.15, 0), 26, 0.9, 0.6, 1.4, false)       # Wasser sprudelt aus der Schale
	spray.color = Color(0.75, 0.9, 1.0, 0.35)
	spray.direction = Vector3.UP
	spray.spread = 40.0
	spray.gravity = Vector3(0, -6.0, 0)
	spray.mesh.size = Vector2(0.35, 0.35)
	spray.emission_box_extents = Vector3(0.2, 0.05, 0.2)
	spray.emitting = true
	_motes(c + Vector3(0, 1.0, 0), Vector3(2.0, 0.4, 2.0), 14, Color("#bfe8ff"), 0.14, 0.4, 3.0)
	g.obstacles.append(Vector3(-z / g.S, (cx - g.lane_xs[0]) / g.S, 50.0))


# ---------------------------------------------------------------- Wald am Spawn (verdeckt die Öffnung) und Tor-Animation
func build_spawns(lane_xs: Array, half: float, x_min: float, x_max: float) -> void:
	var z_open: float = -float(g.cfg["spawnX"]) * g.S
	var trees := {"GiantPine_1": [], "GiantPine_2": [], "GiantPine_3": [], "CommonTree_1": [], "CommonTree_3": [], "Pine_2": []}
	var names := trees.keys()
	var x := x_min - 30.0
	while x < x_max + 30.0:
		var z := z_open + 7.0
		while z > z_open - 30.0:
			var px := x + rng.randf_range(-1.2, 1.2)
			var pz := z + rng.randf_range(-1.2, 1.2)
			var over_lane := false
			for lx in lane_xs:
				if absf(px - float(lx)) < half + 1.0:
					over_lane = true
			if over_lane and pz > z_open + 2.0:                         # vorn über dem Weg nur Kronen (Baum steht am Rand)
				z -= 3.2
				continue
			if absf(px - river_x_) < 3.0:
				z -= 3.2
				continue
			var nm: String = names[rng.randi() % names.size()]
			(trees[nm] as Array).append(_t(px, pz, rng.randf_range(1.4, 2.0)))
			z -= 3.2
		x += 3.4
	for nm in names:
		_nat_scatter(nm, trees[nm])


func update_spawns(delta: float) -> void:
	_update_gates(delta)
	_update_smith(delta)


func _update_gates(delta: float) -> void:
	for gate in gates:
		var want := 0.0
		for p in g.players:
			if int(p["side"]["idx"]) != int(gate["team"]) or float(p.get("dead", 0.0)) > 0.0:
				continue
			var pn: Node3D = p["node"]
			if pn != null and absf(pn.position.x - float(gate["lx"])) < 7.0 and absf(pn.position.z - GATE_Z) < 7.0:
				want = 1.0
		var o: float = move_toward(float(gate["open"]), want, delta * 1.6)
		gate["open"] = o
		var sh: float = maxf(0.0, float(gate["shake"]) - delta)
		gate["shake"] = sh
		var wob := sin(sh * 60.0) * sh * 0.25
		var a := o * 1.35
		var lm: MeshInstance3D = gate["left"]
		var rm: MeshInstance3D = gate["right"]
		if lm != null:
			lm.transform.basis = Basis(Vector3.UP, -a + wob)
		if rm != null:
			rm.transform.basis = Basis(Vector3.UP, PI + a - wob)


# ---------------------------------------------------------------- Schmiede im Burghof (Händler)
var smith: Dictionary = {}


## Schmiede in der Ecke vorn links im Burghof (Torseite und linke Hofmauer): Esse, Werkbank und Regale unter einem Pultdach in der Ecke,
## Amboss und Schmied davor im Freien (aus der Spielkamera sichtbar). Rußboden, Rauch aus der Esse, Karren an der Mauer.
func build_camp(cx: float, cz: float) -> void:
	var wall_x: float = cx - 5.5                                              # Innenkante der linken Hofmauer
	var face := PI / 2.0                                                      # Vorderseite zum Hof (+x)
	var z0: float = GATE_Z + 4.2                                               # Dach beginnt direkt an der Mauer am Tor (Ecke)
	var S := 1.4                                                              # eine Größe für alle Requisiten (passt zu Häusern und Helden)
	var shed_p := Vector3(wall_x + 0.3, 0.0, z0)                              # Rückseite des Unterstands an der Mauer
	var forge_p := Vector3(wall_x + 1.4, 0.0, z0 - 1.6)
	var anvil_p := Vector3(wall_x + 5.4, 0.0, z0 + 0.6)                        # vor dem Dach im Freien
	var smith_p := Vector3(wall_x + 4.3, 0.0, z0 + 0.9)
	var bench_p := Vector3(wall_x + 1.1, 0.0, z0 + 2.0)
	var rack_p := Vector3(wall_x + 0.9, 0.0, z0 + 4.6)
	_soot(Vector3(wall_x + 3.6, 0.0, z0 + 1.6), Vector2(8.0, 9.0))
	_put_parts("Unterstand", shed_p + Vector3(0.0, 0.0, 1.0), face, 1.0)             # Pultdach: hoch an der Mauer, niedrig zum Hof
	_put_parts("FirePit", forge_p, 0.0, S)
	_put_parts("Bellows", forge_p + Vector3(0.0, 0.0, -1.5), face, S)
	_put_parts("Prop_Chimney", forge_p + Vector3(-0.9, 0.0, 0.0), face, 1.0)
	_put_parts("Anvil_Log", anvil_p, face + 0.15, S)
	_put_parts("Workbench_Vice", bench_p, face, S)
	_put_parts("Hammer_Rack", bench_p + Vector3(-0.6, 0.0, 1.5), face, S)
	_put_parts("WeaponStand", rack_p, face, S)
	_put_parts("Shield_Metal", rack_p + Vector3(0.1, 0.0, 1.3), face, S)
	_put_parts("Bucket_Metal", anvil_p + Vector3(0.9, 0.0, -0.9), 0.0, S)
	_put_parts("Whetstone", anvil_p + Vector3(1.0, 0.0, 1.6), face, S)
	_put_parts("Barrel", forge_p + Vector3(0.8, 0.0, -2.6), 0.0, S)
	_put_parts("Crate_Wooden", forge_p + Vector3(1.9, 0.0, -2.9), 0.3, S)
	if true:                                                                  # Karren mit Heu neben der Werkstatt an der Mauer
		_put_parts("Prop_Wagon", Vector3(wall_x + 1.8, 0.0, z0 + 9.5), 0.05, 1.3)
		_nat_scatter("Grass_Wheat", [_t(wall_x + 1.6, z0 + 8.9, 1.5), _t(wall_x + 2.1, z0 + 9.6, 1.4)], false)
		_put_parts("Bag", Vector3(wall_x + 3.4, 0.0, z0 + 8.6), 0.4, S)
	for e in [[anvil_p, 1.4], [forge_p, 2.0], [rack_p, 1.6], [bench_p, 2.0], [smith_p, 1.2], [Vector3(wall_x + 3.0, 0.0, z0 + 2.0), 5.5]]:
		_reserve(e[0].x, e[0].z, e[1])
	var fl := _light(forge_p + Vector3(0, 1.0, 0), Color("#ff7a2a"), 2.0, 9.0)            # Glut der Esse flackert
	var tw := fl.create_tween().set_loops()
	tw.tween_property(fl, "light_energy", 1.4 * Data.user.light_factor(), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fl, "light_energy", 2.4 * Data.user.light_factor(), 0.4).set_trans(Tween.TRANS_SINE)
	_motes(forge_p + Vector3(0, 1.2, 0), Vector3(0.5, 0.1, 0.5), 26, Color("#ffaa40"), 0.2, 1.6, 2.0)
	var smoke := _fog_particles(forge_p + Vector3(-0.9, 3.2, 0.0), 18, 4.5, 0.4, 0.9, false)   # Rauch aus dem Esse-Schornstein
	smoke.color = Color(0.45, 0.43, 0.42, 0.28)
	smoke.direction = Vector3(0.3, 1.0, 0.1)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.2, 0.15, 0.0)
	smoke.emission_box_extents = Vector3(0.15, 0.05, 0.15)
	smoke.emitting = true
	var work_yaw: float = atan2(anvil_p.x - smith_p.x, anvil_p.z - smith_p.z)
	var fig: Dictionary = g._make_figure("res://assets/heroes/Smith.glb", 2.9)
	if not fig.is_empty():
		var n: Node3D = fig["model"]
		n.position = smith_p
		(fig["inner"] as Node3D).rotation.y = work_yaw                          # Blick zum Amboss
		g.add_child(n)
		var ap: AnimationPlayer = fig["anim"]
		if ap != null:
			for an in ["Work", "Idle"]:
				if ap.has_animation(an):
					ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
			if ap.has_animation("Work"):
				ap.play("Work")
		smith = {"fig": fig, "state": "work", "t": 0.0, "anvil": anvil_p, "sparks_t": 0.0, "yaw": work_yaw}
	var pst: Label3D = g._label3d("Psst! Waffen und Tränke!", 40, Color("#ffe066"))
	pst.position = smith_p + Vector3(0.0, 3.4, 0.0)
	pst.modulate.a = 0.0
	pst.outline_modulate.a = 0.0
	g.add_child(pst)
	var tag: Label3D = g._label3d("Schmied", 30, Color("#e8e0cc"))
	tag.position = smith_p + Vector3(0.0, 3.0, 0.0)
	tag.modulate.a = 0.0
	tag.outline_modulate.a = 0.0
	g.add_child(tag)
	g.merchant = {"goblin": smith_p, "wagon": rack_p, "counter": anvil_p, "armor": forge_p, "pst": pst, "tag": tag, "near": false, "pst_t": 0.0, "hover": false}


## Rußiger, festgetretener Erdboden unter der Werkstatt (weicher Rand, liegt über dem Pflaster)
func _soot(c: Vector3, size: Vector2) -> void:
	var q := PlaneMesh.new()
	q.size = size
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode diffuse_lambert, specular_disabled;\nuniform vec2 size;\nvarying vec3 lp;\nfloat h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5);}\nfloat n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),u.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),u.x),u.y);}\nvoid vertex(){lp=VERTEX;}\nvoid fragment(){vec2 d=abs(lp.xz)/(size*0.5);float r=max(d.x,d.y);float e=1.0-smoothstep(0.62,1.0,r+0.25*n(lp.xz*1.3));vec3 c=mix(vec3(0.20,0.16,0.12),vec3(0.36,0.29,0.21),n(lp.xz*2.2));ALBEDO=c;ALPHA=e*0.95;ROUGHNESS=1.0;}\n"
	sm.shader = sh
	sm.set_shader_parameter("size", size)
	sm.render_priority = -18
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = sm
	mi.position = c + Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


## Schmied: hämmert; kommt ein Held, dreht er sich um und nickt, danach wieder an die Arbeit. Funken im Takt der Schläge.
func _update_smith(delta: float) -> void:
	if smith.is_empty() or g.merchant.is_empty():
		return
	var fig: Dictionary = smith["fig"]
	var ap: AnimationPlayer = fig["anim"]
	if ap == null:
		return
	var near: bool = g.merchant.get("near", false)
	var st: String = smith["state"]
	smith["t"] = float(smith["t"]) + delta
	var inner: Node3D = fig["inner"]
	if near and st == "work":
		smith["state"] = "greet"
		smith["t"] = 0.0
		if ap.has_animation("Greet"):
			ap.play("Greet", 0.2)
	elif st == "greet" and float(smith["t"]) > 1.6:
		smith["state"] = "wait" if near else "work"
		if not near and ap.has_animation("Work"):
			ap.play("Work", 0.3)
		elif ap.has_animation("Idle"):
			ap.play("Idle", 0.3)
	elif st == "wait" and not near:
		smith["state"] = "work"
		if ap.has_animation("Work"):
			ap.play("Work", 0.3)
	var want_yaw: float = float(smith.get("yaw", PI / 2.0))
	if st != "work" and not g.hero.is_empty():
		var hp: Vector3 = (g.hero["node"] as Node3D).position
		var sp: Vector3 = (fig["model"] as Node3D).position
		want_yaw = atan2(hp.x - sp.x, hp.z - sp.z)
	inner.rotation.y = lerp_angle(inner.rotation.y, want_yaw, 1.0 - exp(-delta * 6.0))
	if st == "work" and ap.current_animation == "Work":                    # Funken, wenn der Hammer unten ist
		var len_: float = maxf(0.1, ap.get_animation("Work").length)
		var ph: float = fmod(ap.current_animation_position, len_) / len_
		var prev: float = float(smith["sparks_t"])
		if prev < 0.45 and ph >= 0.45:
			_motes_burst(smith["anvil"] + Vector3(0, 1.3, 0))
		smith["sparks_t"] = ph


func _motes_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_texture()
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = maxi(4, int(round(14 * Data.user.particle_factor())))
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.0, 0)
	p.color = Color("#ffc050")
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- Burg, Hof, Stadt, Felder, Wiese
func decorate(wall_xs: Array, river_x: float, lane_xs: Array, half: float, x_min: float, x_max: float) -> void:
	if g.test_mode:
		return
	var lpt: int = int(g.lanes_per_team)
	for t in 2:
		var first: int = t * lpt
		var cxt: float = (lane_xs[first] + lane_xs[first + lpt - 1]) / 2.0
		var hw: float = (lane_xs[first + lpt - 1] - lane_xs[first]) / 2.0 + half + float(g.WALL) + 9.0
		_castle(t, cxt, hw, lane_xs.slice(first, first + lpt), river_x)
		for k in lpt:
			var lx: float = lane_xs[first + k]
			_town(lx, half, t, k, lpt, river_x)
			_fields(lx, half, t, k, lpt, river_x)
	build_camp(x_min - 4.5, 9.0)                                             # Schmiede im Burghof (vorn links)
	build_spawns(lane_xs, half, x_min, x_max)
	_meadow(x_min, x_max, half, lane_xs, river_x)


func _castle(team: int, cxt: float, hw: float, lxs: Array, river_x: float) -> void:
	var x := cxt - hw
	while x < cxt + hw:                                                  # Mauer quer, Lücken an den Toren
		var skip := false
		for lx in lxs:
			if absf(x + 1.0 - float(lx)) < 7.6:
				skip = true
		if not skip and absf(x + 1.0 - river_x) > 3.2:
			_put("Burg_Mauer", Vector3(x + 1.0, 0.0, GATE_Z), 0.0, 1.0)
		x += 2.0
	for sd in [-1.0, 1.0]:                                              # Ecktürme (gleicher Stil wie am Tor)
		_gate_tower(Vector3(cxt + sd * (hw + 1.0), 0.0, GATE_Z), team)
	# Seitenmauern des Hofs und Bergfried hinten
	for sd in [-1.0, 1.0]:
		var z := GATE_Z + 2.0
		while z < COURT_DEPTH:
			var mx: float = cxt + sd * (hw + 1.0)
			if absf(mx - river_x) > 3.2:
				_put("Burg_Mauer", Vector3(mx, 0.0, z + 1.0), PI / 2.0, 1.0)
			z += 2.0
	var keep := _put("Haus_Tower", Vector3(cxt + (hw - 6.0) * (-1.0 if team == 0 else 1.0), 0.0, COURT_DEPTH - 6.0), 0.0, 1.0)
	if keep != null:
		keep.transform.basis = Basis.IDENTITY.scaled(Vector3(1.2, 0.75, 1.2))
	_put("Haus_Houses_A", Vector3(cxt, 0.0, COURT_DEPTH - 4.0), PI, 0.9)           # Gebäude hinten im Hof
	# Leben im Hof: Marktstände, Schmiede, Fässer, Wagen, Übungspuppe, Fackeln
	var props := [["Stall_Blacksmith", -8.0, 20.0, PI], ["Stall_Vegetables_Full", -3.5, 21.5, PI], ["Stall_Potions", 1.5, 21.5, PI],
		["Stall_Empty", 6.0, 20.0, PI], ["Anvil", -10.5, 17.0, 0.4], ["WeaponStand", -12.0, 19.0, 1.2], ["Dummy", 11.0, 12.0, 2.6],
		["Dummy", 13.0, 14.5, 2.2], ["Wagon", 10.5, 24.0, 0.3], ["Table_Large", -6.0, 26.5, 0.0], ["Stool", -7.4, 26.0, 0.5], ["Stool", -4.6, 27.2, 2.0],
		["Barrel", -13.0, 22.5, 0.0], ["Barrel_Apples", -12.0, 24.0, 0.0], ["Crate_Wooden", 13.5, 21.0, 0.2], ["Bag", 12.5, 22.0, 0.0],
		["Sign_Pub", -6.0, 29.0, 0.0], ["FarmCrate_Apple", 3.0, 24.0, 0.3], ["FarmCrate_Carrot", 4.2, 24.6, 1.0]]
	var sgn := 1.0 if team == 0 else -1.0
	for e in props:
		var px: float = cxt + sgn * float(e[1]) * hw / 16.0
		_put_parts(str(e[0]), Vector3(px, 0.0, float(e[2])), float(e[3]), 1.5)
		_reserve(px, float(e[2]), 1.8)
	for sd in [-1.0, 1.0]:
		for k in 4:
			var tp := Vector3(cxt + sd * (hw - 0.4), 2.4, GATE_Z + 4.0 + k * 7.0)
			_put_parts("Torch_Metal", tp - Vector3(0, 2.4, 0), PI / 2.0 * -sd, 1.6)
			_light(tp + Vector3(0, 0.8, 0), Color("#ffb060"), 0.6, 6.0)
	_reserve(cxt, (GATE_Z + COURT_DEPTH) / 2.0, hw)
	var sh := load("res://shaders/burg_lane.gdshader") as Shader       # ganzer Hof gepflastert
	if sh != null:
		var q := PlaneMesh.new()
		q.size = Vector2(hw * 2.0, COURT_DEPTH - GATE_Z)
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("center_x", cxt)
		sm.set_shader_parameter("half_w", hw)
		sm.set_shader_parameter("court_z", -1000.0)
		sm.render_priority = -19
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = sm
		mi.position = Vector3(cxt, 0.015, (GATE_Z + COURT_DEPTH) / 2.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)


## Häuserzeilen an der Stadtstraße: Vorderseite zur Straße, Lücken mit Bäumen, Fässern, Karren, Laternen
func _town(lx: float, half: float, team: int, k: int, lpt: int, river_x: float) -> void:
	var kinds := ["Haus_House_C", "Haus_House_C2", "Haus_Houses_D", "Haus_Houses_D"]
	var depth := {"Haus_House_C": 11.6, "Haus_House_C2": 11.6, "Haus_Houses_D": 12.0}
	var width := {"Haus_House_C": 13.6, "Haus_House_C2": 13.6, "Haus_Houses_D": 8.9}
	for sd in [-1.0, 1.0]:
		var outer: bool = (sd < 0.0 and k == 0) or (sd > 0.0 and k == lpt - 1)
		var toward_river: bool = (river_x - lx) * sd > 0.0
		if not outer:                                                   # zwischen zwei Lanes desselben Teams: niedrige Mauer statt Häuser
			var z := GATE_Z - 2.0
			while z > TOWN_END:
				var mi := _put("Burg_Mauer", Vector3(lx + sd * (half + float(g.WALL) / 2.0), 0.0, z - 1.0), PI / 2.0, 1.0)
				if mi != null:
					mi.transform.basis = Basis(Vector3.UP, PI / 2.0).scaled(Vector3(0.7, 0.25, 1.0))
				z -= 2.0
			continue
		var z := GATE_Z - 3.0
		var yaw: float = -PI / 2.0 * sd                                       # Vorderseite (glTF +z) zur Straße
		while z > TOWN_END + 4.0:
			if rng.randf() < 0.22:
				_nat_scatter("CommonTree_%d" % (1 + rng.randi() % 4), [_t(lx + sd * (half + 5.0), z - 2.5, rng.randf_range(0.9, 1.2))])
				for j in 3:
					_put_parts(["Barrel", "Crate_Wooden", "Barrel_Holder", "Bucket_Wooden_1", "Bench"][rng.randi() % 5],
						Vector3(lx + sd * (half + rng.randf_range(1.0, 2.6)), 0.0, z - rng.randf_range(0.5, 4.5)), rng.randf() * TAU, 1.4)
				if rng.randf() < 0.5:
					_put_parts("Stall_Cart_Empty", Vector3(lx + sd * (half + 3.0), 0.0, z - 2.5), yaw, 1.4)
				z -= 5.5
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			var dep: float = depth[kind]
			if toward_river and dep > 11.0 and absf(river_x - lx) - half - 2.8 < 11.6:
				kind = "Haus_Houses_D"
				dep = depth[kind]
			var w: float = width[kind]
			_put(kind, Vector3(lx + sd * (half + 0.8 + dep / 2.0), 0.0, z - w / 2.0), yaw, 1.0)
			_reserve(lx + sd * (half + 0.8 + dep / 2.0), z - w / 2.0, maxf(w, dep) * 0.6)
			z -= w + rng.randf_range(0.5, 2.0)
			if rng.randf() < 0.5:
				_put_parts("Lantern_Wall", Vector3(lx + sd * (half + 0.6), 2.6, z + 1.0), yaw, 1.4)
				_light(Vector3(lx + sd * (half + 0.2), 2.9, z + 1.0), Color("#ffc070"), 0.35, 4.0)


## Felder: Holzzaun an der Lane, Weizen (Wind), Gemüsebeete, Bauernhöfe
func _fields(lx: float, half: float, team: int, k: int, lpt: int, river_x: float) -> void:
	var wheat: Array = []
	for sd in [-1.0, 1.0]:
		var outer: bool = (sd < 0.0 and k == 0) or (sd > 0.0 and k == lpt - 1)
		var fx: float = lx + sd * (half + 0.45)
		var z := TOWN_END - 1.0
		var fence: Array = []
		while z > FIELD_END:                                             # Zaun
			fence.append(_t(fx, z, 1.4, PI / 2.0))
			z -= 2.8
		_nat_scatter("Prop_WoodenFence_Extension1", fence)
		if not outer:
			continue
		var limit: float = absf(river_x - lx) - half - 4.0 if (river_x - lx) * sd > 0.0 else 22.0
		z = TOWN_END - 3.0
		while z > FIELD_END + 6.0:
			var L := rng.randf_range(10.0, 15.0)
			var x0: float = half + 1.6
			var x1: float = minf(half + 1.6 + 13.0, half + limit)
			var kind := rng.randf()
			if kind < 0.55:                                              # Weizenfeld
				var zz := z - 0.5
				while zz > z - L:
					var xx := x0
					while xx < x1:
						wheat.append(_t(lx + sd * xx + rng.randf_range(-0.2, 0.2), zz + rng.randf_range(-0.2, 0.2), rng.randf_range(1.0, 1.3)))
						xx += 0.75
					zz -= 0.75
			elif kind < 0.85:                                            # Gemüsebeet
				var veg: String = ["Leek", "Carrot", "Radish"][rng.randi() % 3]
				var beds: Array = []
				var zz := z - 0.6
				while zz > z - L:
					var xx := x0 + 0.4
					while xx < x1:
						beds.append(_t(lx + sd * xx, zz, 2.6))
						xx += 1.0
					zz -= 0.9
				_nat_scatter(veg, beds)
			_reserve(lx + sd * (x0 + x1) / 2.0, z - L / 2.0, (x1 - x0) * 0.55)
			z -= L + 2.0
		var fz := rng.randf_range(-100.0, -70.0)                         # Bauernhof
		var hx: float = lx + sd * (half + minf(limit, 22.0) - 2.0)
		if limit > 12.0:
			_put("Haus_Houses_D", Vector3(hx, 0.0, fz), rng.randf() * TAU, 1.0)
			_reserve(hx, fz, 7.0)
			for j in 4:
				_put_parts(["FarmCrate_Apple", "FarmCrate_Carrot", "FarmCrate_Radish", "Barrel", "Bucket_Wooden_2"][rng.randi() % 5],
					Vector3(hx - sd * 6.0 + rng.randf_range(-1.5, 1.5), 0.0, fz + rng.randf_range(-4.0, 4.0)), rng.randf() * TAU, 1.4)
			_put_parts("Wagon", Vector3(hx - sd * 5.0, 0.0, fz + 7.0), rng.randf() * TAU, 1.4)
	_nat_scatter("Grass_Wheat", wheat, false)


## Wiese außerhalb: Gras (Wind), Blumen, Büsche, Steine, einzelne Bäume; nichts auf Lanes, Fluss und reservierten Flächen
func _meadow(x_min: float, x_max: float, half: float, lane_xs: Array, river_x: float) -> void:
	var lists := {}
	var choose := [["Grass_Common_Short", 0.32], ["Grass_Common_Tall", 0.16], ["Grass_Wispy_Short", 0.14], ["Grass_Wide_Short", 0.1],
		["Flower_3_Group", 0.05], ["Flower_4_Group", 0.04], ["Flower_1_Group", 0.03], ["Clover_1", 0.04], ["Bush_Common", 0.03],
		["Bush_Common_Flowers", 0.02], ["Fern_1", 0.02], ["Rock_Medium_1", 0.01], ["Pebble_Round_1", 0.02], ["Mushroom_Common", 0.02]]
	var trees := {"CommonTree_1": [], "CommonTree_2": [], "CommonTree_4": [], "Birch_1": [], "Birch_3": [], "Pine_1": []}
	var z := COURT_DEPTH + 10.0
	var z_end: float = -float(g.cfg["spawnX"]) * g.S + 4.0
	while z > z_end:
		var x := x_min - 40.0
		while x < x_max + 40.0:
			var px := x + rng.randf_range(-0.9, 0.9)
			var pz := z + rng.randf_range(-0.9, 0.9)
			x += 1.9
			var on_lane := false
			for lx in lane_xs:
				if absf(px - float(lx)) < half + 0.6:
					on_lane = true
			if on_lane or absf(px - river_x) < 3.4 or (pz > GATE_Z - 2.0 and px > x_min - 6.0 and px < x_max + 6.0):
				continue
			if not _free(px, pz, 0.6):
				continue
			var r := rng.randf()
			if r < 0.012 and (px < x_min - 8.0 or px > x_max + 8.0):
				var tn: String = trees.keys()[rng.randi() % trees.size()]
				(trees[tn] as Array).append(_t(px, pz, rng.randf_range(1.0, 1.5)))
				_reserve(px, pz, 2.5)
				continue
			var acc := 0.0
			for c in choose:
				acc += float(c[1])
				if r < acc:
					if not lists.has(c[0]):
						lists[c[0]] = []
					(lists[c[0]] as Array).append(_t(px, pz, rng.randf_range(0.9, 1.4)))
					break
		z -= 1.9
	for nm in lists:
		_nat_scatter(nm, lists[nm], str(nm).begins_with("Bush") or str(nm).begins_with("Rock"))
	for nm in trees:
		_nat_scatter(nm, trees[nm])
