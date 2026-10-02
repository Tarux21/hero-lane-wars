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


func _light(pos: Vector3, col: Color, energy: float, rng_m: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy * Data.user.light_factor()
	l.omni_range = rng_m
	l.shadow_enabled = false
	l.position = pos
	g.add_child(l)


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

	# 5) Basis: Knochenbögen links und rechts des Platzes, Schädelhaufen
	var mid_x: float = (lane_xs[0] + lane_xs[lane_xs.size() - 1]) / 2.0
	var arches: Array = []
	var base_skulls: Array = []
	for sd in [-1.0, 1.0]:
		arches.append(_t(mid_x + sd * ((x_max - x_min) / 2.0 + 3.0), 4.0, 1.6, PI / 2.0))
		base_skulls.append(_t(mid_x + sd * ((x_max - x_min) / 2.0 + 1.0), 10.0, 1.2))
	_scatter("bone_arch", arches)
	_scatter("skull_pile", base_skulls, false)

	# 6) Lava: Licht entlang des Flusses, aufsteigende Glut; Sporen im Wald
	var zc: float = (z_near + z_far) / 2.0
	var zl2: float = z_near - 10.0
	while zl2 > z_far:
		_light(Vector3(river_x, 1.5, zl2), Color("#ff6a2a"), 2.0, 16.0)
		zl2 -= 28.0
	_motes(Vector3(river_x, 0.6, zc), Vector3(2.4, 0.2, (z_near - z_far) / 2.0), 90, Color("#ff9a3a"), 0.28, 1.6, 4.0)
	_motes(Vector3((x_min + x_max) / 2.0, 1.4, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.2, (z_near - z_far) / 2.0), 150, Color("#7aff7a"), 0.22, 0.4, 7.0)
	_motes(Vector3((x_min + x_max) / 2.0, 2.5, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.5, (z_near - z_far) / 2.0), 70, Color("#7ad0ff"), 0.2, 0.3, 8.0)
