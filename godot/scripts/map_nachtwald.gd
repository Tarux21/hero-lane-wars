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
func decorate(wall_xs: Array, river_x: float, lane_xs: Array, half: float, x_min: float, x_max: float) -> void:
	var z_near := 10.0
	var z_far: float = -float(g.cfg["laneLen"]) * g.S - 6.0
	var gap_z: float = -float(g.WALL_OPEN_BASE) * g.S                        # bis hierhin ist die Basis offen (keine Bäume in der Lücke)
	var dead: Array = []
	var pine: Array = []
	# Baumwände: drei Reihen je Wand, Lücken nur in der offenen Basis zwischen den Lanes eines Teams
	for w in wall_xs:
		var gapped: bool = bool(w["gapped"])
		var wx: float = w["x"]
		var z := z_near
		while z > z_far:
			z -= rng.randf_range(1.6, 2.4)
			if gapped and z > gap_z:
				continue
			for off in [-1.1, 0.0, 1.1]:
				var s := rng.randf_range(0.6, 1.0)
				var t := _t(wx + off + rng.randf_range(-0.35, 0.35), z + rng.randf_range(-0.5, 0.5), s)
				(dead if rng.randf() < 0.45 else pine).append(t)
	# Wald außen links und rechts der Karte
	for side in [-1.0, 1.0]:
		var edge: float = x_min - 2.0 if side < 0.0 else x_max + 2.0
		var zz := z_near + 4.0
		while zz > z_far - 8.0:
			zz -= 3.2
			var d := 0.0
			for row in 6:
				d += rng.randf_range(2.6, 4.2)
				if rng.randf() < 0.85:
					var s2 := rng.randf_range(0.7, 1.3)
					var t2 := _t(edge + side * d, zz + rng.randf_range(-1.2, 1.2), s2)
					(dead if rng.randf() < 0.5 else pine).append(t2)
	# Baumreihen zwischen den Wänden und dem Fluss (Ufer bleibt frei)
	var zr := z_near
	while zr > z_far:
		zr -= rng.randf_range(3.5, 6.0)
		for sd in [-1.0, 1.0]:
			var bank: float = river_x + sd * rng.randf_range(7.5, 11.0)
			(dead if rng.randf() < 0.6 else pine).append(_t(bank, zr, rng.randf_range(0.6, 1.0)))
	_scatter("tree_dead", dead)
	_scatter("tree_pine", pine)

	# Knochensäulen und Pilze an den Lane-Rändern, Feuerschalen mit Licht
	var pillars: Array = []
	var shrooms: Array = []
	var rocks: Array = []
	var skulls: Array = []
	var braziers: Array = []
	var lava_rocks: Array = []
	for cx in lane_xs:
		for side in [-1.0, 1.0]:
			var edge_x: float = cx + side * (half - 0.7)
			var zp := -16.0
			var idx := 0
			while zp > z_far + 6.0:
				pillars.append(_t(edge_x, zp, rng.randf_range(0.95, 1.2), 0.0 if side < 0.0 else PI))
				if idx % 3 == 1:
					braziers.append(_t(edge_x - side * 0.2, zp - 12.0, 1.0))
					_light(Vector3(edge_x - side * 0.2, 2.0, zp - 12.0), Color("#ff8a3a"), 1.7, 11.0)
				zp -= rng.randf_range(20.0, 26.0)
				idx += 1
			var zs := -4.0
			var k := 0
			while zs > z_far:
				var sx: float = cx + side * (half + 0.2)
				shrooms.append(_t(sx, zs, rng.randf_range(0.5, 0.85)))
				if k % 3 == 0:
					_light(Vector3(sx, 0.8, zs), Color("#6aff5a"), 0.9, 6.0)
				if k % 5 == 2:
					skulls.append(_t(cx + side * (half - 1.6), zs - 3.0, 1.0))
				zs -= rng.randf_range(7.0, 10.5)
				k += 1
	# Steine verstreut, Lava-Ufer
	for i in 120:
		var rx := rng.randf_range(x_min - 20.0, x_max + 20.0)
		var rz := rng.randf_range(z_far, z_near)
		var on_lane := false
		for cx2 in lane_xs:
			if absf(rx - cx2) < half + 1.5:
				on_lane = true
		if not on_lane and absf(rx - river_x) > 4.0:
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

	# Basis: Knochenbögen links und rechts des Platzes, Schädelhaufen, Feuerschalen
	var mid_x: float = (lane_xs[0] + lane_xs[lane_xs.size() - 1]) / 2.0
	var arches: Array = []
	for sd in [-1.0, 1.0]:
		arches.append(_t(mid_x + sd * ((x_max - x_min) / 2.0 + 3.0), 4.0, 1.6, PI / 2.0))
		skulls.append(_t(mid_x + sd * ((x_max - x_min) / 2.0 + 1.0), 10.0, 1.2))
	_scatter("bone_arch", arches)

	# Lava: Licht entlang des Flusses, aufsteigende Glut; Sporen im Wald
	var zc: float = (z_near + z_far) / 2.0
	var zl2: float = z_near - 10.0
	while zl2 > z_far:
		_light(Vector3(river_x, 1.5, zl2), Color("#ff6a2a"), 2.0, 16.0)
		zl2 -= 28.0
	_motes(Vector3(river_x, 0.6, zc), Vector3(2.4, 0.2, (z_near - z_far) / 2.0), 90, Color("#ff9a3a"), 0.28, 1.6, 4.0)
	_motes(Vector3((x_min + x_max) / 2.0, 1.4, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.2, (z_near - z_far) / 2.0), 150, Color("#7aff7a"), 0.22, 0.4, 7.0)
	_motes(Vector3((x_min + x_max) / 2.0, 2.5, zc), Vector3((x_max - x_min) / 2.0 + 10.0, 1.5, (z_near - z_far) / 2.0), 70, Color("#7ad0ff"), 0.2, 0.3, 8.0)
