extends RefCounted
## Karte "Giftiger Nachtwald" (Prototyp): dunkler Wald statt Felswänden, Lava als Fluss, Knochensäulen, leuchtende Pilze, Feuerschalen,
## violetter Nebel. Die Modelle stammen aus Blender (godot/tools/blender/make_nachtwald_props.py) und liegen als GLB in assets/props/.
## Fehlt eine Datei, wird die Dekoration einfach weggelassen. Die Spielfläche (Lanes, Basis) bleibt unverändert und liegt weiter in game.gd.
## Platzierung: eigener Zufallsgenerator mit festem Startwert (kein Einfluss auf die Spielregeln, immer dieselbe Karte).

const COLORS := {
	"ground": Color("#14111e"), "lane": Color("#5c5750"), "strip": Color("#4a4640"), "wall": Color("#0b0912"), "wall_top": Color("#15101c"),
	"river": Color("#e8421a"), "plaza": Color("#4a4640"), "fog": Color(0.10, 0.07, 0.16, 0.82),
}

var g: Node
var rng := RandomNumberGenerator.new()
var meshes: Dictionary = {}
var glow_tex: Texture2D
var tree_hash: Dictionary = {}          # Raster der gesetzten Bäume: verhindert, dass Bäume ineinander stehen
var dead_xf: Array = []
var pine_xf: Array = []


func _init(game: Node) -> void:
	g = game
	rng.seed = 424242


## Himmel, Nebel, Licht und Leuchten
func setup_environment(env: Environment, sun: DirectionalLight3D) -> void:
	env.background_color = Color("#0a0710")
	env.ambient_light_color = Color("#6a6a98")
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("#2a1a3e")
	env.fog_density = 0.010
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	sun.light_color = Color("#a8b8ff")
	sun.light_energy = 0.95


func _mesh(name: String) -> Mesh:
	if meshes.has(name):
		return meshes[name]
	var path := "res://assets/props/%s.glb" % name
	var m: Mesh = null
	if FileAccess.file_exists(path):
		var st := GLTFState.new()
		var doc := GLTFDocument.new()
		if doc.append_from_file(path, st) == OK:
			var root := doc.generate_scene(st)
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				m = (mi as MeshInstance3D).mesh
				break
			root.free()
	meshes[name] = m
	return m


## Viele gleiche Modelle mit einem Aufruf zeichnen (MultiMesh)
func _scatter(name: String, xf: Array, shadows: bool = true) -> void:
	var mesh := _mesh(name)
	if mesh == null or xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(inst)


## Baum setzen, wenn er keinen anderen berührt (Radius der Krone). Gibt zurück, ob er gesetzt wurde.
func _place_tree(x: float, z: float, s: float, is_dead: bool) -> bool:
	var r: float = (1.15 if is_dead else 1.45) * s
	var cx := int(floor(x / 3.0))
	var cz := int(floor(z / 3.0))
	for ix in range(cx - 1, cx + 2):
		for iz in range(cz - 1, cz + 2):
			var key := Vector2i(ix, iz)
			if tree_hash.has(key):
				for o in tree_hash[key]:
					var dx: float = x - o.x
					var dz: float = z - o.y
					var minr: float = (r + o.z) * 0.78
					if dx * dx + dz * dz < minr * minr:
						return false
	var k0 := Vector2i(cx, cz)
	if not tree_hash.has(k0):
		tree_hash[k0] = []
	tree_hash[k0].append(Vector3(x, z, r))
	(dead_xf if is_dead else pine_xf).append(_t(x, z, s))
	return true


func _t(x: float, z: float, s: float = 1.0, yaw: float = -1.0, y: float = 0.0) -> Transform3D:
	var a := rng.randf() * TAU if yaw < 0.0 else yaw
	return Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * s), Vector3(x, y, z))


func _light(pos: Vector3, col: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy * Data.user.light_factor()
	l.omni_range = rng_m
	l.shadow_enabled = false
	l.position = pos
	g.add_child(l)
	return l


func _glow_texture() -> Texture2D:
	if glow_tex == null:
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		glow_tex = gt
	return glow_tex


## Funken, Sporen: schwebende Lichtpunkte in einem Quader
func _motes(center: Vector3, extents: Vector3, amount: int, col: Color, size: float, up: float, life: float) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_texture()
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = maxi(1, int(round(amount * Data.user.particle_factor())))
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = up * 0.5
	p.initial_velocity_max = up
	p.gravity = Vector3.ZERO
	p.color = col
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.position = center
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(p)


## Alles Dekorative setzen. Aufruf aus game.gd nach dem Bau der Spielfläche.
## Einzelnes Modell setzen (nicht als Gruppe), z. B. für das Händler-Camp
func _put(name: String, pos: Vector3, yaw: float, s: float = 1.0) -> MeshInstance3D:
	var mesh := _mesh(name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos)
	g.add_child(mi)
	return mi


## Goblin-Händler-Camp an der Basis (links neben dem Platz): Marktwagen, Wildschwein mit Sattel, Lagerfeuer mit Kessel, Sack mit Knochen.
## Klick auf den Goblin oder den Wagen öffnet den Shop (game.gd, _over_merchant). Der Goblin ruft "Pst!", wenn der Held näher kommt.
func build_camp(cx: float, cz: float) -> void:
	var wagon_p := Vector3(cx, 0.0, cz)
	var goblin_p := Vector3(cx + 1.7, 0.0, cz + 2.1)                        # steht hinter dem Tresen
	var counter_p := Vector3(cx + 1.7, 0.0, cz + 3.6)
	var armor_p := Vector3(cx - 2.4, 0.0, cz + 2.6)
	var crates_p := Vector3(cx + 5.0, 0.0, cz + 1.6)
	var boar_p := Vector3(cx - 5.2, 0.0, cz + 0.6)
	var fire_p := Vector3(cx - 1.6, 0.0, cz + 6.2)
	var sack_p := Vector3(cx + 4.8, 0.0, cz + 5.0)
	_put("market_wagon", wagon_p, PI, 1.0)
	_put("boar", boar_p, PI + 0.35, 1.0)
	_put("goblin_merchant", goblin_p, PI - 0.15, 1.15)
	_put("cauldron_fire", fire_p, 0.0, 1.0)
	_put("loot_sack", sack_p, PI + 0.3, 1.0)
	_put("counter", counter_p, PI, 1.0)
	_put("armor_stand", armor_p, PI - 0.25, 1.0)
	_put("crate_stack", crates_p, PI + 0.2, 1.0)
	for e in [[wagon_p, 3.2], [boar_p, 2.6], [goblin_p, 1.3], [counter_p, 1.9], [armor_p, 1.4], [crates_p, 1.9], [fire_p, 2.0], [sack_p, 1.1], [Vector3(cx - 0.3, 0.0, cz + 3.2), 6.5]]:
		_reserve(e[0].x, e[0].z, e[1])
	var fl := _light(fire_p + Vector3(0, 1.2, 0), Color("#ff8a3a"), 2.4, 13.0)       # Lagerfeuer flackert
	var tw := fl.create_tween().set_loops()
	tw.tween_property(fl, "light_energy", 1.7 * Data.user.light_factor(), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fl, "light_energy", 2.8 * Data.user.light_factor(), 0.45).set_trans(Tween.TRANS_SINE)
	_light(wagon_p + Vector3(0, 2.1, 0.9), Color("#ffc060"), 1.3, 8.0)                 # Laterne am Wagen
	_light(counter_p + Vector3(0.0, 1.9, 0.2), Color("#ffd070"), 1.0, 5.0)              # warmes Licht auf den Münzen und Tränken
	_light(boar_p + Vector3(0, 2.0, 0.5), Color("#ffb070"), 0.6, 5.0)
	_motes(fire_p + Vector3(0, 1.6, 0), Vector3(0.4, 0.1, 0.4), 28, Color("#ffaa40"), 0.2, 1.6, 2.4)
	_motes(fire_p + Vector3(0, 2.2, 0), Vector3(0.3, 0.1, 0.3), 12, Color("#9aff7a"), 0.16, 0.9, 3.0)         # Dampf aus dem Kessel
	var pst: Label3D = g._label3d("Pst!", 46, Color("#ffe066"))
	pst.position = goblin_p + Vector3(0.0, 3.1, 0.0)
	pst.modulate.a = 0.0
	pst.outline_modulate.a = 0.0
	g.add_child(pst)
	var tag: Label3D = g._label3d("Händler", 30, Color("#e8e0cc"))
	tag.position = goblin_p + Vector3(0.0, 2.55, 0.0)
	tag.modulate.a = 0.0
	tag.outline_modulate.a = 0.0
	g.add_child(tag)
	g.merchant = {"goblin": goblin_p, "wagon": wagon_p, "counter": counter_p, "armor": armor_p, "pst": pst, "tag": tag, "near": false, "pst_t": 0.0, "hover": false}


## Wächterstatue als Basisobjekt eines Teams (4 Zerfallsstufen je nach Team-Leben, siehe game.gd _update_statues)
func place_statue(team: int, cx: float, col: Color) -> void:
	var pos := Vector3(cx, 0.0, 0.8)
	var mi := _put("guardian_0", pos, PI, 1.0)                                   # blickt zur Kamera
	if mi == null:
		return
	g.statues.append({"node": mi, "stage": 0, "team": team, "pos": pos})
	g._cyl(Vector3(cx, 0.06, 0.8), 2.1, 0.03, col.darkened(0.55), col)           # Farbring: Cyan = du, Orange = Gegner
	var l := _light(pos + Vector3(0, 2.2, 1.8), col, 1.1, 9.0)
	l.shadow_enabled = false
	g.obstacles.append(Vector3(-pos.z / g.S, (cx - g.lane_xs[0]) / g.S, 40.0))   # Spielkoordinaten: Held läuft um die Statue herum


## Heilbrunnen mit Runenkreis hinter der Statue (hier heilt der Held 12 % pro Sekunde)
func place_fountain(cx: float, z: float) -> void:
	_put("heal_circle", Vector3(cx, 0.0, z), 0.0, 0.9)
	_put("heal_fountain", Vector3(cx, 0.0, z), PI, 1.0)
	var l := _light(Vector3(cx, 1.6, z), Color("#6aff7a"), 1.4, 11.0)
	g.heal_lights.append(l)
	_motes(Vector3(cx, 1.2, z), Vector3(2.4, 0.6, 2.4), 36, Color("#8aff8a"), 0.2, 0.9, 3.5)
	g.obstacles.append(Vector3(-z / g.S, (cx - g.lane_xs[0]) / g.S, 30.0))


func set_statue_stage(entry: Dictionary, stage: int) -> void:
	var mesh := _mesh("guardian_%d" % stage)
	if mesh == null:
		return
	(entry["node"] as MeshInstance3D).mesh = mesh
	entry["stage"] = stage
	var pos: Vector3 = entry["pos"]
	_burst(pos + Vector3(0, 1.8, 0.4), 60 if stage < 3 else 110)


## Staubwolke und Brocken beim Zerfall
func _burst(pos: Vector3, amount: int) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_texture()
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = maxi(8, int(round(amount * Data.user.particle_factor())))
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 160.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -2.0, 0)
	p.color = Color(0.55, 0.55, 0.6, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(p.queue_free)
	g.shake_near(pos, 9.0)


## Hintere Linie: zerfallene Burg (Mauer mit Lücken, großer Turm je Team, Tor in der Mitte) und davor das Schlachtfeld der Gefallenen.
## Das Schlachtfeld ist für beide Teams gleich (der Gegner bekommt es gespiegelt): zerstörte Ramme, totes Pferd mit Pfeilen,
## Gefallene, zerbrochene Waffen und Schilde, zerfetzte Banner, Knochenhaufen und Schädel.
func build_back_line(lane_xs: Array, half: float, x_min: float, x_max: float, river_x: float) -> void:
	var z_wall := 20.5
	var variants := [0, 1, 2, 0, 2, 1, 0, 1]
	var xs_list: Array = []
	var x := x_min - 12.0
	var vi := 0
	while x < x_max + 12.0:
		var is_gate: bool = absf(x - river_x) < 3.0
		var tower_x := false
		for t in 2:
			var first: int = t * int(g.lanes_per_team)
			var cxt: float = (lane_xs[first] + lane_xs[first + int(g.lanes_per_team) - 1]) / 2.0
			if absf(x - cxt) < 3.0:
				tower_x = true
		if is_gate:
			_put("castle_gate", Vector3(x, 0.0, z_wall), 0.0, 1.0)
		elif tower_x:
			_put("castle_tower", Vector3(x, 0.0, z_wall + 0.6), 0.0, 1.0)
		else:
			_put("castle_wall_%d" % variants[vi % variants.size()], Vector3(x, 0.0, z_wall), 0.0, 1.0)
			vi += 1
		_reserve(x, z_wall, 3.6)
		x += 6.0
	# Schlachtfeld: Lage (u = Querposition -1..1 bezogen auf die Breite des Teams, z) je Eintrag
	var layout := [
		["siege_ram", -0.42, 13.5, 0.30, 4.2, 1.5], ["horse_dead", 0.50, 13.0, -0.45, 2.6],
		["corpse_0", -0.92, 12.5, 0.8, 1.2], ["corpse_2", -0.12, 14.7, 2.3, 1.4], ["corpse_1", 0.08, 12.3, 0.3, 1.2], ["corpse_0", 0.92, 14.4, 3.7, 1.2],
		["corpse_1", -0.72, 14.9, 1.4, 1.2], ["corpse_2", 0.32, 15.0, 0.1, 1.4], ["corpse_2", 0.98, 12.6, 2.0, 1.4],
		["weapon_field", -0.78, 12.0, 0.4, 1.8], ["weapon_field", -0.10, 13.7, 1.9, 1.8], ["weapon_field", 0.72, 14.2, 0.7, 1.8], ["weapon_field", 0.18, 12.0, 2.7, 1.8],
		["weapon_field", 1.0, 13.6, 0.0, 1.8],
		["banner_torn", -0.80, 15.4, 0.0, 1.0], ["banner_torn", -0.02, 15.7, 0.5, 1.0], ["banner_torn", 0.78, 15.4, -0.3, 1.0],
		["bone_heap", -0.55, 12.3, 0.0, 1.1], ["bone_heap", 0.62, 12.2, 1.0, 1.1], ["bone_heap", -0.30, 15.2, 2.0, 1.1],
		["skull_pile", 0.38, 13.9, 0.0, 1.2], ["skull_pile", -0.98, 14.0, 0.0, 1.2],
	]
	for t in 2:
		var first: int = t * int(g.lanes_per_team)
		var last: int = first + int(g.lanes_per_team) - 1
		var cxt: float = (lane_xs[first] + lane_xs[last]) / 2.0
		var hw: float = maxf((lane_xs[last] - lane_xs[first]) / 2.0 + half, 15.0)                  # auch bei 1 gegen 1 über die ganze Breite des Platzes verteilen
		var sgn: float = 1.0 if t == 0 else -1.0                                      # Gegner: gespiegelt
		var by_name: Dictionary = {}
		for e in layout:
			var px: float = cxt + sgn * float(e[1]) * hw * 0.95
			var yaw: float = sgn * float(e[3]) + (0.0 if t == 0 else PI * 0.0)
			var mi := _put(str(e[0]), Vector3(px, 0.0, 12.0 + (float(e[2]) - 11.8) * 2.0), yaw, float(e[5]) if e.size() > 5 else 1.0)
			_reserve(px, 12.0 + (float(e[2]) - 11.8) * 2.0, float(e[4]))


## Szenen am Wegrand: Name -> [Radius (Platzbedarf), Größe von, Größe bis]
const SCENES := {
	"skel_sit": [0.95, 0.9, 1.1], "skel_impaled": [0.8, 0.9, 1.1], "skel_hang": [1.5, 0.85, 1.0], "cage_skel": [1.0, 0.9, 1.1],
	"wagon": [2.0, 0.8, 0.95], "barrels": [1.4, 0.9, 1.1], "tent": [1.6, 0.85, 1.0], "campfire": [1.7, 0.8, 1.0],
	"banner": [0.8, 0.9, 1.1], "sword_grave": [1.1, 0.9, 1.1], "totem": [0.9, 0.85, 1.05], "stone_circle": [2.3, 0.6, 0.75],
}


## Hindernis (Platz für ein Modell) eintragen, damit später gesetzte Bäume nicht hineinwachsen
func _reserve(x: float, z: float, r: float) -> void:
	var k0 := Vector2i(int(floor(x / 3.0)), int(floor(z / 3.0)))
	if not tree_hash.has(k0):
		tree_hash[k0] = []
	tree_hash[k0].append(Vector3(x, z, r))


## Ist an der Stelle noch Platz (kein Baum, keine Szene)?
func _free(x: float, z: float, r: float) -> bool:
	var cx := int(floor(x / 3.0))
	var cz := int(floor(z / 3.0))
	for ix in range(cx - 1, cx + 2):
		for iz in range(cz - 1, cz + 2):
			var key := Vector2i(ix, iz)
			if tree_hash.has(key):
				for o in tree_hash[key]:
					var dx: float = x - o.x
					var dz: float = z - o.y
					var minr: float = (r + o.z) * 0.8
					if dx * dx + dz * dz < minr * minr:
						return false
	return true


## Alles Dekorative setzen. Aufruf aus game.gd nach dem Bau der Spielfläche.
func decorate(wall_xs: Array, river_x: float, lane_xs: Array, half: float, x_min: float, x_max: float) -> void:
	var z_near := 10.0
	var z_far: float = -float(g.cfg["laneLen"]) * g.S - 6.0
	var gap_z: float = -float(g.WALL_OPEN_BASE) * g.S                        # bis hierhin ist die Basis offen (keine Bäume in der Lücke)
	var own_n: int = int(g.lanes_per_team)
	var own_right: float = lane_xs[own_n - 1] + half + float(g.WALL)         # Außenkante der Baumwand rechts (eigene Seite)
	var scenes: Dictionary = {}                                              # Name -> Transformliste
	var torches: Array = []
	var pillars: Array = []
	var shrooms: Array = []
	var skulls: Array = []
	var braziers: Array = []
	var eyes: Array = []
	if not g.test_mode:
		build_camp(x_min - 3.5, -4.0)
		build_back_line(lane_xs, half, x_min, x_max, river_x)

	_reserve(lane_xs[lane_xs.size() - 1] + half + float(g.WALL) + 0.0, 4.0, 3.0)                  # Platz für den Knochenbogen an der Basis
	_reserve(lane_xs[lane_xs.size() - 1] + half + float(g.WALL) - 2.0, 10.0, 1.5)

	# 1) Am Lane-Rand (außerhalb der Lane, in der Baumwand): Knochensäulen, Feuerschalen, Pilze, Schädelhaufen. Die Lane selbst bleibt frei.
	for cx in lane_xs:
		for side in [-1.0, 1.0]:
			var gapped_side: bool = own_n == 2 and side > 0.0 and absf(cx - lane_xs[0]) < 0.01     # Wand mit Lücke (4v4): erst ab dem Ende der Lücke
			var out_x: float = cx + side * (half + 0.95)
			var zp := -16.0
			var idx := 0
			while zp > z_far + 6.0:
				if not (gapped_side and zp > gap_z) and _free(out_x, zp, 0.7):
					pillars.append(_t(out_x, zp, rng.randf_range(0.95, 1.2), -side * PI / 2.0))
					_reserve(out_x, zp, 0.7)
				var bz: float = zp - 11.0
				if idx % 3 == 1 and not (gapped_side and bz > gap_z) and _free(out_x, bz, 0.6):
					braziers.append(_t(out_x, bz, 1.0))
					_reserve(out_x, bz, 0.6)
					_light(Vector3(out_x, 2.2, bz), Color("#ff8a3a"), 1.7, 11.0)
				zp -= rng.randf_range(20.0, 26.0)
				idx += 1
			var zs := -4.0
			var k := 0
			while zs > z_far:
				var sx: float = cx + side * (half + 0.3)
				if not (gapped_side and zs > gap_z) and _free(sx, zs, 0.5):
					shrooms.append(_t(sx, zs, rng.randf_range(0.5, 0.85)))
					_reserve(sx, zs, 0.5)
					if k % 3 == 0:
						_light(Vector3(sx, 0.8, zs), Color("#6aff5a"), 0.9, 6.0)
				var skx: float = cx + side * (half + 1.7)
				var skz: float = zs - 3.0
				if k % 5 == 2 and not (gapped_side and skz > gap_z) and _free(skx, skz, 0.9):
					skulls.append(_t(skx, skz, 1.0))
					_reserve(skx, skz, 0.9)
				zs -= rng.randf_range(7.0, 10.5)
				k += 1

	# 2) Randstreifen neben der Baumwand (vorher kahl): links der eigenen Lanes und zwischen Baumwand und Lava.
	#    Jede Szene kommt je Streifen genau einmal vor, bunt gemischt von oben nach unten (kein Nachbar gleich).
	var strips := [
		{"x0": x_min - 4.6, "x1": x_min - 0.5, "face": -PI / 2.0},                       # links: Lane liegt rechts davon (+x)
		{"x0": own_right + 0.6, "x1": river_x - 4.5, "face": PI / 2.0},                  # rechts: Lane liegt links davon (-x)
	]
	for si in strips.size():
		var st: Dictionary = strips[si]
		var names: Array = SCENES.keys()
		for i in range(names.size() - 1, 0, -1):                                       # mischen (fester Zufall)
			var j := rng.randi_range(0, i)
			var tmp = names[i]
			names[i] = names[j]
			names[j] = tmp
		var span: float = (z_near - 12.0) - (z_far + 4.0)
		var step: float = span / float(names.size())
		var zc0: float = z_near - 12.0
		for i in names.size():
			var nm: String = names[i]
			var info: Array = SCENES[nm]
			var zz: float = zc0 - step * (float(i) + 0.5) + rng.randf_range(-step * 0.15, step * 0.15)
			var lo: float = float(st["x0"]) + float(info[0])
			var hi: float = float(st["x1"]) - float(info[0])
			var xx: float = (float(st["x0"]) + float(st["x1"])) / 2.0 if lo >= hi else rng.randf_range(lo, hi)
			for retry in 6:
				if _free(xx, zz, float(info[0])):
					break
				zz -= 2.5
			if not scenes.has(nm):
				scenes[nm] = []
			scenes[nm].append(_t(xx, zz, rng.randf_range(float(info[1]), float(info[2])), float(st["face"]) + rng.randf_range(-0.5, 0.5)))
			_reserve(xx, zz, float(info[0]))
		# Fackeln am Rand zur Baumwand, in den Lücken zwischen den Szenen
		var zt: float = z_near - 20.0
		while zt > z_far + 6.0:
			var tx: float = float(st["x1"]) - 0.4 if float(st["face"]) < 0.0 else float(st["x0"]) + 0.4
			if _free(tx, zt, 0.5):
				torches.append(_t(tx, zt, 1.0))
				_reserve(tx, zt, 0.5)
				_light(Vector3(tx, 2.6, zt), Color("#ff9a3a"), 1.5, 9.0)
			zt -= rng.randf_range(24.0, 30.0)
		# leuchtende Augen im Dickicht am äußeren Rand des Streifens
		var ze: float = z_near - 14.0
		while ze > z_far + 6.0:
			var ex: float = float(st["x0"]) + 0.3 if float(st["face"]) < 0.0 else float(st["x1"]) - 0.3
			eyes.append(_t(ex + rng.randf_range(-0.4, 0.4), ze, rng.randf_range(0.9, 1.3), float(st["face"]) + PI))
			ze -= rng.randf_range(11.0, 17.0)

	# 3) Bäume: Baumwände, Wald außen, Reihen am Fluss; füllen auch die Streifen zwischen den Szenen. Bäume stehen nie ineinander.
	for w in wall_xs:
		var gapped: bool = bool(w["gapped"])
		var wx: float = w["x"]
		var z := z_near
		while z > z_far:
			z -= 1.15
			if gapped and z > gap_z:
				continue
			for off in [-1.0, 0.0, 1.0]:
				for attempt in 3:
					var s := rng.randf_range(0.55, 0.9)
					if _place_tree(wx + off + rng.randf_range(-0.4, 0.4), z + rng.randf_range(-0.6, 0.6), s, rng.randf() < 0.45):
						break
	for side in [-1.0, 1.0]:
		var edge: float = x_min - 2.0 if side < 0.0 else x_max + 2.0
		var zz2 := z_near + 4.0
		while zz2 > z_far - 8.0:
			zz2 -= 2.4
			var d := 0.0
			for row in 8:
				d += rng.randf_range(2.0, 3.4)
				for attempt in 2:
					var s2 := rng.randf_range(0.7, 1.3)
					if _place_tree(edge + side * d, zz2 + rng.randf_range(-1.2, 1.2), s2, rng.randf() < 0.5):
						break
	for st2 in strips:                                                                 # Streifen mit Bäumen füllen (freie Stellen)
		var zf: float = z_near
		while zf > z_far:
			zf -= 1.6
			for attempt in 3:
				var fx: float = rng.randf_range(float(st2["x0"]), float(st2["x1"]))
				if _place_tree(fx, zf + rng.randf_range(-0.8, 0.8), rng.randf_range(0.55, 0.95), rng.randf() < 0.5):
					break
	var zr := z_near
	while zr > z_far:
		zr -= rng.randf_range(2.8, 4.6)
		for sd in [-1.0, 1.0]:
			var bank: float = river_x + sd * rng.randf_range(7.5, 11.0)
			_place_tree(bank, zr, rng.randf_range(0.6, 1.0), rng.randf() < 0.6)
	_scatter("tree_dead", dead_xf)
	_scatter("tree_pine", pine_xf)

	# 4) Steine verstreut, Lava-Ufer
	var rocks: Array = []
	var lava_rocks: Array = []
	for i in 120:
		var rx := rng.randf_range(x_min - 20.0, x_max + 20.0)
		var rz := rng.randf_range(z_far, z_near)
		var on_lane := false
		for cx2 in lane_xs:
			if absf(rx - cx2) < half + 1.5:
				on_lane = true
		if not on_lane and absf(rx - river_x) > 4.0 and _free(rx, rz, 0.8):
			rocks.append(_t(rx, rz, rng.randf_range(0.7, 1.8)))
	var zl := z_near
	while zl > z_far:
		zl -= rng.randf_range(5.0, 9.0)
		lava_rocks.append(_t(river_x + (3.1 if rng.randf() < 0.5 else -3.1), zl, rng.randf_range(0.5, 0.9)))
	_scatter("bone_pillar", pillars)
	_scatter("mushroom_glow", shrooms, false)
	_scatter("rock_dark", rocks, false)
	_scatter("skull_pile", skulls, false)
	_scatter("brazier", braziers, false)
	_scatter("lava_rock", lava_rocks, false)
	for nm in scenes:
		_scatter(nm, scenes[nm], false)
	_scatter("torch", torches, false)
	_scatter("eyes", eyes, false)

	# 5) Basis: Knochenbogen und Schädelhaufen rechts des Platzes (links steht das Händler-Camp)
	var mid_x: float = (lane_xs[0] + lane_xs[lane_xs.size() - 1]) / 2.0
	_scatter("bone_arch", [_t(mid_x + ((x_max - x_min) / 2.0 + 3.0), 4.0, 1.6, PI / 2.0)])
	_scatter("skull_pile", [_t(mid_x + ((x_max - x_min) / 2.0 + 1.0), 10.0, 1.2)], false)

	# 6) Lava: Licht entlang des Flusses, aufsteigende Glut; Sporen im Wald
	var zc: float = (z_near + z_far) / 2.0
	var zl2: float = z_near - 10.0
	while zl2 > z_far:
		_light(Vector3(river_x, 1.5, zl2), Color("#ff6a2a"), 2.0, 16.0)
		zl2 -= 28.0
	_motes(Vector3(river_x, 0.6, zc), Vector3(2.4, 0.2, (z_near - z_far) / 2.0), 90, Color("#ff9a3a"), 0.28, 1.6, 4.0)
	_motes(Vector3((x_min + x_max) / 2.0, 1.4, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.2, (z_near - z_far) / 2.0), 150, Color("#7aff7a"), 0.22, 0.4, 7.0)
	_motes(Vector3((x_min + x_max) / 2.0, 2.5, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.5, (z_near - z_far) / 2.0), 70, Color("#7ad0ff"), 0.2, 0.3, 8.0)

	# 7) Monster-Spawn am Lane-Ende (eigener Zufallsgenerator, ändert die übrige Karte nicht)
	if not g.test_mode:
		build_spawns(lane_xs, half, x_min, x_max)


## Spawn-Stellen: je Lane ein hohler, toter Giftbaum mit Dornenwand links und rechts. Die Monster laufen aus der Öffnung (game.gd, _emerge_from_tree).
## Vor jeder Welle beginnt der Baum innen zu leuchten und giftiger Nebel strömt aus der Öffnung; beides hält an, solange Monster herauskommen.
var spawns: Array = []
var spawn_clock := 0.0
var spawn_debug := OS.get_cmdline_user_args().has("--spawndbg")      # Test: Leuchten und Nebel immer an


func build_spawns(lane_xs: Array, half: float, x_min: float, x_max: float) -> void:
	var r2 := RandomNumberGenerator.new()
	r2.seed = 777
	var z_open: float = -float(g.cfg["spawnX"]) * g.S                          # Ebene der Öffnung = Startlinie der Monster
	var tree_z: float = z_open - 1.25
	var lpt: int = int(g.lanes_per_team)
	var back_dead: Array = []
	var back_pine: Array = []
	for i in lane_xs.size():
		var cx: float = lane_xs[i]
		var mi := _put("spawn_tree", Vector3(cx, 0.0, tree_z), PI, 1.0)
		if mi == null:
			return
		var side_w: float = half - 1.95                                        # vom Stamm bis zum Lane-Rand
		var n_seg: int = maxi(1, int(ceil(side_w / 3.0)))
		var seg_w: float = side_w / n_seg
		for sd in [-1.0, 1.0]:
			for k in n_seg:
				var wx: float = cx + sd * (1.95 + seg_w * (k + 0.5))
				var wm := _put("thorn_wall_%d" % ((i * 2 + k + (0 if sd < 0.0 else 1)) % 3), Vector3(wx, 0.0, tree_z + 0.45), PI, 1.0)
				if wm != null:
					wm.transform.basis = Basis(Vector3.UP, PI).scaled(Vector3(seg_w / 3.0 * 1.05, r2.randf_range(0.9, 1.15), 1.0))
		# leuchtende Flächen heraussuchen (Material "Giftglut") und je Baum ein eigenes Material dafür anlegen
		var glow_idx := -1
		var base_e := 4.0
		var pm: StandardMaterial3D = null
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m is StandardMaterial3D and (m.resource_name.to_lower().contains("giftglut") or m.resource_name.to_lower().contains("gift")):
				glow_idx = s
				pm = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				base_e = pm.emission_energy_multiplier
				mi.set_surface_override_material(s, pm)
		var l := _light(Vector3(cx, 1.5, z_open + 0.3), Color("#9aff40"), 0.4, 6.5)
		var fog := _fog_particles(Vector3(cx, 0.55, z_open + 0.1), 30, 4.6, 0.8, 1.7, false)
		var burst := _fog_particles(Vector3(cx, 0.55, z_open + 0.1), 34, 3.2, 2.0, 4.2, true)
		spawns.append({"side": i / lpt, "lane": i % lpt, "mi": mi, "mat": pm, "base_e": base_e, "light": l, "fog": fog, "burst": burst, "glow": 0.0, "busy": false})
		# dunkle Wipfel dahinter, damit man hinter dem Baum nicht ins Leere sieht
		for k in 4:
			var bx: float = cx + (k - 1.5) * 3.4 + r2.randf_range(-0.6, 0.6)
			var bz: float = tree_z - r2.randf_range(3.2, 5.0)
			if _free(bx, bz, 1.0):
				(back_dead if k % 2 == 0 else back_pine).append(_t_fixed(bx, bz, r2.randf_range(0.8, 1.2), r2.randf() * TAU))
	var xx: float = x_min - 8.0                                                # Reihe Bäume quer hinter allen Lanes
	while xx < x_max + 8.0:
		var bz2: float = z_open - 6.0 - r2.randf_range(0.0, 3.0)
		if _free(xx, bz2, 1.0):
			(back_dead if r2.randf() < 0.5 else back_pine).append(_t_fixed(xx, bz2, r2.randf_range(0.9, 1.4), r2.randf() * TAU))
		xx += r2.randf_range(2.4, 3.6)
	_scatter("tree_dead", back_dead)
	_scatter("tree_pine", back_pine)


func _t_fixed(x: float, z: float, s: float, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, 0.0, z))


## Giftiger Bodennebel: weiche grüne Wolken, die aus der Öffnung nach vorn (zur Basis hin) strömen
func _fog_particles(pos: Vector3, amount: int, life: float, v_min: float, v_max: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _glow_texture()
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	q.material = m
	p.mesh = q
	p.amount = maxi(4, int(round(amount * Data.user.particle_factor())))
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.55, 0.25, 0.2)
	p.direction = Vector3(0.0, 0.04, 1.0)
	p.spread = 38.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0.0, -0.05, 0.0)
	p.damping_min = 0.5
	p.damping_max = 0.9
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.55))
	grow.add_point(Vector2(1.0, 1.7))
	p.scale_amount_curve = grow
	p.color = Color(0.45, 0.95, 0.22, 0.22)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.18, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.position = pos
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(p)
	return p


## Jeden Frame: Baum leuchtet auf, wenn eine Welle naht (letzte 4 s) und solange Monster herauskommen; Nebel strömt, beim Spawn ein Stoß.
func update_spawns(delta: float) -> void:
	if spawns.is_empty():
		return
	spawn_clock += delta
	var open_x: float = float(g.cfg["spawnX"])
	var busy: Dictionary = {}
	for s in g.sides:
		for u in s["units"]:
			if float(u["x"]) > open_x - 8.0:
				busy[int(s["idx"]) * 8 + int(u["lane"])] = true
	for e in spawns:
		var key: int = int(e["side"]) * 8 + int(e["lane"])
		var is_busy: bool = busy.has(key)
		var wt: float = float(g.sides[int(e["side"])]["wave_t"])
		var pre: float = clampf(1.0 - wt / 4.0, 0.0, 1.0) if wt > 0.0 and wt < 4.0 else 0.0
		var want: float = 1.0 if is_busy else pre * 0.9
		if spawn_debug:
			want = 1.0
		var glow: float = float(e["glow"])
		glow = move_toward(glow, want, delta * (1.1 if want > glow else 0.7))
		e["glow"] = glow
		var flick: float = 0.92 + 0.08 * sin(spawn_clock * 9.0 + float(e["lane"]) * 2.0)
		var pm: StandardMaterial3D = e["mat"]
		if pm != null:
			pm.emission_energy_multiplier = float(e["base_e"]) * (0.2 + 0.8 * glow * flick)
		(e["light"] as OmniLight3D).light_energy = (0.35 + 2.4 * glow * flick) * Data.user.light_factor()
		(e["fog"] as CPUParticles3D).emitting = glow > 0.22
		if is_busy and not bool(e["busy"]):
			var b: CPUParticles3D = e["burst"]
			b.restart()
			b.emitting = true
		e["busy"] = is_busy
		if spawn_debug and int(spawn_clock * 4.0) != int((spawn_clock - delta) * 4.0):
			print("SPAWNFX lane=%d glow=%.2f busy=%s wt=%.1f fog=%s mat=%s" % [int(e["lane"]), glow, is_busy, wt, (e["fog"] as CPUParticles3D).emitting, pm != null])


## Lane-Boden: alter, verwilderter Pflasterweg mit weichen Rändern (Shader), statt der eckigen Fläche. Am Lane-Ende löst er sich in Erde und Wurzeln auf.
func build_lane_ground(cx: float, half: float) -> void:
	var sh := load("res://shaders/nachtwald_lane.gdshader") as Shader
	if sh == null:
		return
	var s_end: float = float(g.cfg["spawnX"]) * g.S
	var z0: float = 14.0                                                    # bis unter den Platz an der Basis
	var z1: float = -(s_end + 12.0)
	var q := PlaneMesh.new()
	q.size = Vector2((half + 5.0) * 2.0, z0 - z1)
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("center_x", cx)
	sm.set_shader_parameter("half_w", half)
	sm.set_shader_parameter("s_end", s_end)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = sm
	mi.position = Vector3(cx, 0.02, (z0 + z1) / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
