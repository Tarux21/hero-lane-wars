extends RefCounted
## Effekte für Fähigkeiten: Partikel, Licht, Blitze, Kristalle. Reine Optik, verändert keine Spielwerte
## und nutzt nicht den Spiel-Zufall (g.rand), damit Tests und Vergleiche unberührt bleiben.
## Alles entsteht im Code (Texturen, Partikel), es sind keine Bilddateien nötig.
## Alle Aufrufe sind in Tests (test_mode) wirkungslos.

const S := 0.05
const HAND := 1.7                    # Höhe der Stabspitze/Hand über dem Boden (m)

var g: Node
var rng := RandomNumberGenerator.new()
var tex_glow: Texture2D              # weicher runder Fleck (Funken, Flammen, Nebel)
var tex_disc: Texture2D              # Bodenfläche mit hellem Rand (Zonen)
var tex_ring: Texture2D              # dünner Ring (Druckwelle)
var tex_rune: Texture2D              # Zauberkreis
var tex_beam: Texture2D              # Lichtsäule (nach oben ausblendend)
var tex_flame: Texture2D             # Flammenzunge (Tropfenform mit zerzaustem Rand)
var pmats: Dictionary = {}
var flickers: Array = []             # Lichter, die flackern: {"node", "base", "ph"}
var elems: Array = []                # sichtbare Elementare: {"node", "type", "pivot", "arc_t"}


func _init(host: Node) -> void:
	g = host
	rng.seed = 90210
	if g.test_mode:
		return
	tex_glow = _radial([0.0, 0.28, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	tex_disc = _radial([0.0, 0.7, 0.9, 0.96, 1.0], [Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	tex_ring = _radial([0.0, 0.72, 0.88, 0.96, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	tex_rune = _make_rune()
	tex_flame = _make_flame()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.width = 8
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	tex_beam = gt


# ---------------------------------------------------------------- Bausteine
func _radial(offs: Array, cols: Array) -> Texture2D:
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array(offs)
	gr.colors = PackedColorArray(cols)
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt


## Zauberkreis: Doppelring, Hexagramm, Kerben (weiß auf transparent, wird eingefärbt)
func _make_rune() -> Texture2D:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	var rad := n / 2.0
	var tri_pts: Array = []
	for k in 6:
		var a := TAU * k / 6.0 - PI / 2.0
		tri_pts.append(Vector2(cos(a), sin(a)) * 0.74)
	for y in n:
		for x in n:
			var q := (Vector2(x, y) - c) / rad
			var r := q.length()
			var a := 0.0
			a = maxf(a, _line_a(absf(r - 0.96), 0.018))
			a = maxf(a, _line_a(absf(r - 0.86), 0.010))
			a = maxf(a, _line_a(absf(r - 0.30), 0.012))
			for t in 2:                                  # zwei Dreiecke = Hexagramm
				for e in 3:
					var p0: Vector2 = tri_pts[t + 2 * e]
					var p1: Vector2 = tri_pts[t + 2 * ((e + 1) % 3)]
					a = maxf(a, _line_a(_seg_dist(q, p0, p1), 0.012))
			if r > 0.86 and r < 0.96:                    # Kerben zwischen den Ringen
				var ang := fposmod(atan2(q.y, q.x), TAU / 24.0) / (TAU / 24.0)
				a = maxf(a, _line_a(absf(ang - 0.5) * r * 0.26, 0.010) * 0.8)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Flammenzunge: oben spitz, unten rund, Rand mit leichtem Rauschen, innen heller
func _make_flame() -> Texture2D:
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.045
	for y in h:
		var v := float(y) / h
		var half := 0.0
		if v < 0.72:
			half = 0.46 * pow(v / 0.72, 1.5)
		else:
			half = 0.46 * sqrt(maxf(0.0, 1.0 - pow((v - 0.72) / 0.28, 2.0)))
		for x in w:
			var u := (float(x) / w - 0.5)
			var edge := half + nz.get_noise_2d(x, y * 1.5) * 0.09 * v
			var d := edge - absf(u)
			var a := clampf(d / 0.12, 0.0, 1.0)
			a *= clampf(1.0 - v * 0.35, 0.0, 1.0)
			if a > 0.0:
				var core := clampf(d / maxf(0.05, half) * 1.4, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * (0.55 + 0.45 * core)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _line_a(d: float, w: float) -> float:
	return clampf(1.0 - d / w, 0.0, 1.0)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * tt)


func _pmat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var key := "%d_%s" % [tex.get_instance_id(), additive]
	if pmats.has(key):
		return pmats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	pmats[key] = m
	return m


func _ramp(stops: Array) -> Gradient:
	## stops: [[Position, Color], ...]
	var gr := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	gr.offsets = offs
	gr.colors = cols
	return gr


func _curve(vals: Array) -> Curve:
	var c := Curve.new()
	for i in vals.size():
		c.add_point(Vector2(float(i) / maxf(1.0, vals.size() - 1.0), float(vals[i])))
	return c


## Partikel-Emitter nach Beschreibung. Schlüssel: amount, life, once, explo, local, tex, add, shape (point|sphere|ring), radius, inner,
## height, dir, spread, vmin, vmax, grav, smin, smax, curve, ramp, damp
func _ps(o: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = o.get("qsize", Vector2.ONE)
	q.material = _pmat(o.get("tex", tex_glow), bool(o.get("add", true)))
	p.mesh = q
	p.amount = int(o.get("amount", 20))
	p.lifetime = float(o.get("life", 1.0))
	p.one_shot = bool(o.get("once", false))
	p.explosiveness = float(o.get("explo", 0.0))
	p.local_coords = bool(o.get("local", false))
	p.randomness = 0.6
	match str(o.get("shape", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(o.get("radius", 0.3))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = float(o.get("radius", 1.0))
			p.emission_ring_inner_radius = float(o.get("inner", 0.0))
			p.emission_ring_height = float(o.get("height", 0.1))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 20.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 2.0))
	p.gravity = o.get("grav", Vector3.ZERO)
	p.scale_amount_min = float(o.get("smin", 0.5))
	p.scale_amount_max = float(o.get("smax", 1.0))
	if o.has("curve"):
		p.scale_amount_curve = o["curve"]
	if o.has("ramp"):
		p.color_ramp = o["ramp"]
	p.damping_min = float(o.get("dmin", 0.0))
	p.damping_max = float(o.get("dmax", 0.0))
	var amax := float(o.get("ang", 180.0))
	p.angle_min = -amax
	p.angle_max = amax
	p.emitting = true
	return p


func _w(x: float, y: float, side: int) -> Vector3:
	return g._wp(x, y, side)


## Setzt einen Effekt-Knoten in die Welt; er wird nach `life` Sekunden entfernt und auf der Gegner-Seite ausgeblendet.
func _put(node: Node3D, pos: Vector3, life: float) -> void:
	g.add_child(node)
	node.position = pos
	g.fx_nodes.append({"node": node, "t": life})


func _light(col: Color, energy: float, rng_m: float, life: float, pos: Vector3, decay: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	_put(l, pos, life)
	if decay:
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, life)
	return l


func _glow_sprite(col: Color, size: float, life: float, pos: Vector3, grow: float = 1.0) -> void:
	## Ein einzelner heller Fleck (Blitz), blendet aus
	var p := _ps({"amount": 1, "life": life, "once": true, "explo": 1.0, "local": true, "vmin": 0.0, "vmax": 0.0, "smin": size, "smax": size,
		"ramp": _ramp([[0.0, Color(col.r, col.g, col.b, 0.0)], [0.15, col], [1.0, Color(col.r, col.g, col.b, 0.0)]]),
		"curve": _curve([0.5, 1.0 * grow])})
	_put(p, pos, life + 0.2)


func _ring_wave(pos: Vector3, col: Color, r_end: float, life: float, y: float = 0.15) -> void:
	## Flache Druckwelle am Boden, wächst und blendet aus
	var node := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	qm.orientation = PlaneMesh.FACE_Y
	node.mesh = qm
	var m := _flat_mat(tex_ring, col, true)
	node.material_override = m
	node.scale = Vector3.ONE * 0.1
	_put(node, pos + Vector3(0, y, 0), life + 0.1)
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector3.ONE * r_end, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)


func _flat_mat(tex: Texture2D, col: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = tex
	m.albedo_color = col
	return m


func _hand(p: Dictionary) -> Vector3:
	## Position der Stabspitze: etwas vor dem Helden in Blickrichtung
	var side: int = p["side"]["idx"]
	var base: Vector3 = _w(p["x"], p["y"], side)
	var yaw := 0.0
	if p.has("fig") and not (p["fig"] as Dictionary).is_empty():
		yaw = float(p["fig"]["yaw"])
	return base + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.7 + Vector3(0, HAND, 0)


# ---------------------------------------------------------------- Zauberpose und Funken am Stab
func cast_burst(p: Dictionary, col: Color, tx: float, ty: float) -> void:
	if g.test_mode:
		return
	g.cast_pose(p, tx, ty)
	var hp := _hand(p)
	var burst := _ps({"amount": 18, "life": 0.5, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.15, "dir": Vector3.UP, "spread": 180.0,
		"vmin": 1.0, "vmax": 3.5, "smin": 0.12, "smax": 0.3, "dmin": 1.5, "dmax": 2.5,
		"ramp": _ramp([[0.0, Color(1, 1, 1, 0.9)], [0.3, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
	_put(burst, hp, 0.8)
	_glow_sprite(Color(col.r, col.g, col.b, 0.9), 1.4, 0.3, hp)
	_light(col, 1.6, 6.0, 0.35, hp)


# ---------------------------------------------------------------- Feuer
## Feuerball fliegt von der Hand zum Zielpunkt, am Ende Einschlag. `meteor`: stattdessen Meteor aus großer Höhe.
func fireball(p: Dictionary, tx: float, ty: float, meteor: bool) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var to := _w(tx, ty, side)
	if meteor:
		meteor_fall(to, 0.9)
		return
	var from := _hand(p)
	var life := 0.28
	var node := Node3D.new()
	_put(node, from, life + 1.0)
	_glow_on(node, Color(1.0, 0.7, 0.25, 1.0), 1.5)
	var trail := _ps({"amount": 150, "life": 0.35, "local": false, "shape": "sphere", "radius": 0.12, "vmin": 0.0, "vmax": 0.6, "spread": 180.0,
		"smin": 0.9, "smax": 1.5, "curve": _curve([1.0, 0.0]),
		"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 0.9)], [0.35, Color(1.0, 0.45, 0.1, 0.7)], [1.0, Color(0.3, 0.05, 0.0, 0.0)]])})
	node.add_child(trail)
	var lt := OmniLight3D.new()
	lt.light_color = Color("#ff8a3a")
	lt.light_energy = 2.0
	lt.omni_range = 7.0
	node.add_child(lt)
	var tw := node.create_tween()
	tw.tween_method(func(f: float):
		var pos := from.lerp(to + Vector3(0, 0.3, 0), f)
		pos.y += sin(f * PI) * 1.4
		node.position = pos, 0.0, 1.0, life)
	tw.tween_callback(func():
		trail.emitting = false
		lt.light_energy = 0.0
		for c in node.get_children():
			if c is CPUParticles3D and c != trail:
				c.emitting = false
		explosion(tx, ty, side, 0.8, Color("#ff7a2a")))


## Dauerhaft leuchtender Fleck (zur Kamera gedreht) an einem Knoten: farbiger Hof + weißer Kern
func _glow_on(node: Node3D, col: Color, size: float) -> void:
	for k in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * size * (1.0 if k == 0 else 0.45)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_texture = tex_glow
		m.albedo_color = col if k == 0 else Color(1.0, 1.0, 0.92, col.a)
		mi.material_override = m
		node.add_child(mi)


func meteor_fall(to: Vector3, life: float) -> void:
	## Warnring am Boden + Meteor kommt schräg von oben; Einschlag nach `life`
	var warn := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	qm.orientation = PlaneMesh.FACE_Y
	warn.mesh = qm
	var wm := _flat_mat(tex_rune, Color(1.0, 0.55, 0.2, 0.0), true)
	warn.material_override = wm
	warn.scale = Vector3(5.5, 1.0, 5.5)
	_put(warn, to + Vector3(0, 0.12, 0), life + 0.15)
	var tw0 := warn.create_tween()
	tw0.set_parallel(true)
	tw0.tween_property(wm, "albedo_color:a", 0.9, life * 0.6)
	tw0.tween_property(warn, "rotation:y", 3.0, life)
	var start := to + Vector3(-7.0, 26.0, -9.0)
	var node := Node3D.new()
	_put(node, start, life + 1.0)
	_glow_on(node, Color(1.0, 0.55, 0.15, 1.0), 3.0)
	var trail := _ps({"amount": 90, "life": 0.7, "local": false, "shape": "sphere", "radius": 0.5, "vmin": 0.0, "vmax": 1.0, "spread": 180.0,
		"smin": 1.1, "smax": 2.0, "curve": _curve([1.0, 0.1]),
		"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 0.9)], [0.3, Color(1.0, 0.5, 0.1, 0.8)], [1.0, Color(0.25, 0.05, 0.0, 0.0)]])})
	node.add_child(trail)
	var smoke := _ps({"amount": 30, "life": 1.2, "local": false, "add": false, "shape": "sphere", "radius": 0.5, "vmin": 0.0, "vmax": 0.5, "spread": 180.0,
		"smin": 1.2, "smax": 2.4, "curve": _curve([0.6, 1.0]),
		"ramp": _ramp([[0.0, Color(0.12, 0.1, 0.1, 0.0)], [0.2, Color(0.15, 0.12, 0.1, 0.5)], [1.0, Color(0.1, 0.1, 0.1, 0.0)]])})
	node.add_child(smoke)
	var lt := OmniLight3D.new()
	lt.light_color = Color("#ff8a3a")
	lt.light_energy = 3.0
	lt.omni_range = 12.0
	node.add_child(lt)
	var tw := node.create_tween()
	tw.tween_method(func(f: float): node.position = start.lerp(to, f * f), 0.0, 1.0, life)
	tw.tween_callback(func():
		trail.emitting = false
		smoke.emitting = false
		lt.light_energy = 0.0
		for c in node.get_children():
			if c is CPUParticles3D:
				(c as CPUParticles3D).emitting = false
		g.shake_near(to, 9.0)
		explosion_at(to, 2.4, Color("#ff6a1f"), true))


func explosion(x: float, y: float, side: int, size: float, col: Color) -> void:
	explosion_at(_w(x, y, side), size, col, false)


func explosion_at(pos: Vector3, size: float, col: Color, big: bool) -> void:
	if g.test_mode:
		return
	var warm := Color(1.0, 0.85, 0.5, 1.0)
	_glow_sprite(Color(1.0, 0.9, 0.6, 1.0), 5.0 * size, 0.22, pos + Vector3(0, 0.6, 0), 1.6)
	_light(col, 4.0 * size, 11.0 * size, 0.45, pos + Vector3(0, 1.5, 0))
	var fire := _ps({"amount": int(34 * size), "life": 0.75, "once": true, "explo": 0.95, "shape": "sphere", "radius": 0.35 * size, "dir": Vector3.UP, "spread": 70.0,
		"vmin": 2.0 * size, "vmax": 6.5 * size, "smin": 1.0 * size, "smax": 2.2 * size, "dmin": 2.0, "dmax": 4.0,
		"grav": Vector3(0, 1.0, 0), "curve": _curve([0.5, 1.0, 0.2]),
		"ramp": _ramp([[0.0, warm], [0.25, Color(col.r, col.g, col.b, 0.9)], [0.7, Color(0.35, 0.08, 0.02, 0.5)], [1.0, Color(0.1, 0.05, 0.03, 0.0)]])})
	_put(fire, pos + Vector3(0, 0.3, 0), 1.2)
	var sparks := _ps({"amount": int(30 * size), "life": 0.9, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.2, "dir": Vector3.UP, "spread": 75.0,
		"vmin": 4.0 * size, "vmax": 11.0 * size, "smin": 0.1, "smax": 0.22, "grav": Vector3(0, -12.0, 0),
		"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.5, Color(1.0, 0.5, 0.1, 0.9)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])})
	_put(sparks, pos + Vector3(0, 0.3, 0), 1.3)
	var smoke := _ps({"amount": int(12 * size), "life": 1.8, "once": true, "explo": 0.7, "add": false, "shape": "sphere", "radius": 0.5 * size, "dir": Vector3.UP, "spread": 60.0,
		"vmin": 0.6, "vmax": 2.0, "smin": 1.5 * size, "smax": 3.0 * size, "grav": Vector3(0, 0.4, 0), "curve": _curve([0.4, 1.0]),
		"ramp": _ramp([[0.0, Color(0.1, 0.09, 0.08, 0.0)], [0.15, Color(0.14, 0.12, 0.1, 0.55)], [1.0, Color(0.1, 0.1, 0.1, 0.0)]])})
	_put(smoke, pos + Vector3(0, 0.5, 0), 2.2)
	_ring_wave(pos, Color(1.0, 0.65, 0.3, 0.9), 4.5 * size, 0.5)
	if big:
		_ring_wave(pos, Color(1.0, 0.45, 0.15, 0.7), 8.0, 0.8, 0.12)
		var rocks := _ps({"amount": 16, "life": 1.1, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.4, "dir": Vector3.UP, "spread": 55.0,
			"vmin": 5.0, "vmax": 11.0, "smin": 0.2, "smax": 0.38, "grav": Vector3(0, -16.0, 0), "add": false,
			"ramp": _ramp([[0.0, Color(0.2, 0.15, 0.1, 1.0)], [0.8, Color(0.1, 0.08, 0.06, 0.9)], [1.0, Color(0.1, 0.08, 0.06, 0.0)]])})
		_put(rocks, pos + Vector3(0, 0.3, 0), 1.5)


## Dauerhafte Flammen auf einem Feld (Zone). z hat x, y, r, side, node; liefert Partikel als Kinder des Zonenknotens.
func zone_attach(z: Dictionary) -> void:
	if g.test_mode or z["node"] == null:
		return
	var node: Node3D = z["node"]
	var r: float = float(z["r"]) * S
	var kind: String = z["kind"]
	if kind == "fire":
		var area := r * r
		node.add_child(_ps({"amount": int(clampf(18.0 + area * 1.3, 24.0, 80.0)), "life": 0.95, "tex": tex_flame, "qsize": Vector2(1.0, 1.7), "ang": 14.0, "shape": "ring", "radius": r * 0.92, "inner": 0.0, "height": 0.1,
			"dir": Vector3.UP, "spread": 10.0, "vmin": 1.2, "vmax": 3.2, "smin": 1.3, "smax": 2.3, "grav": Vector3(0, 0.8, 0), "curve": _curve([0.7, 1.0, 0.1]),
			"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 0.0)], [0.12, Color(1.0, 0.8, 0.3, 0.7)], [0.5, Color(1.0, 0.4, 0.08, 0.5)], [1.0, Color(0.25, 0.04, 0.0, 0.0)]])}))
		node.add_child(_ps({"amount": int(clampf(12.0 + area, 14.0, 50.0)), "life": 1.7, "shape": "ring", "radius": r * 0.85, "height": 0.1,
			"dir": Vector3.UP, "spread": 18.0, "vmin": 1.8, "vmax": 4.5, "smin": 0.09, "smax": 0.2, "grav": Vector3(0, 0.5, 0),
			"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.6, Color(1.0, 0.5, 0.1, 0.8)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])}))
		node.add_child(_ps({"amount": int(clampf(5.0 + area * 0.3, 6.0, 22.0)), "life": 2.4, "add": false, "shape": "ring", "radius": r * 0.7, "height": 0.1,
			"dir": Vector3.UP, "spread": 12.0, "vmin": 0.6, "vmax": 1.4, "smin": 1.6, "smax": 2.8, "grav": Vector3(0, 0.3, 0), "curve": _curve([0.5, 1.0]),
			"ramp": _ramp([[0.0, Color(0.1, 0.09, 0.08, 0.0)], [0.2, Color(0.12, 0.1, 0.09, 0.4)], [1.0, Color(0.1, 0.1, 0.1, 0.0)]])}))
		var lt := OmniLight3D.new()
		lt.light_color = Color("#ff8a3a")
		lt.light_energy = 1.6
		lt.omni_range = r * 2.2 + 4.0
		lt.position.y = 1.2
		node.add_child(lt)
		flickers.append({"node": lt, "base": 1.6, "ph": rng.randf() * 6.0})
	elif kind == "frost":
		var area2 := r * r
		node.add_child(_ps({"amount": int(clampf(25.0 + area2 * 2.0, 30.0, 110.0)), "life": 2.0, "shape": "ring", "radius": r * 0.95, "height": 3.0,
			"dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.3, "vmax": 0.9, "smin": 0.08, "smax": 0.18, "grav": Vector3(0, -0.6, 0),
			"ramp": _ramp([[0.0, Color(0.9, 0.97, 1.0, 0.0)], [0.2, Color(0.9, 0.97, 1.0, 0.9)], [0.9, Color(0.7, 0.9, 1.0, 0.6)], [1.0, Color(0.7, 0.9, 1.0, 0.0)]])}))
		node.add_child(_ps({"amount": int(clampf(5.0 + area2 * 0.5, 6.0, 20.0)), "life": 2.6, "add": false, "shape": "ring", "radius": r * 0.8, "height": 0.1,
			"dir": Vector3.UP, "spread": 20.0, "vmin": 0.2, "vmax": 0.7, "smin": 1.4, "smax": 2.4, "curve": _curve([0.6, 1.0]),
			"ramp": _ramp([[0.0, Color(0.7, 0.88, 1.0, 0.0)], [0.25, Color(0.75, 0.9, 1.0, 0.16)], [1.0, Color(0.8, 0.92, 1.0, 0.0)]])}))
		var sp := _ps({"amount": 14, "life": 1.1, "shape": "ring", "radius": r * 0.9, "height": 0.1, "dir": Vector3.UP, "spread": 10.0,
			"vmin": 0.0, "vmax": 0.2, "smin": 0.25, "smax": 0.5,
			"ramp": _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.4, Color(0.8, 0.95, 1.0, 1.0)], [1.0, Color(0.8, 0.95, 1.0, 0.0)]])})
		node.add_child(sp)
		var lt2 := OmniLight3D.new()
		lt2.light_color = Color("#8fd8ff")
		lt2.light_energy = 1.0
		lt2.omni_range = r * 2.0 + 3.0
		lt2.position.y = 1.0
		node.add_child(lt2)
		for k in int(clampf(r * 1.2, 3.0, 9.0)):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * r * 0.85
			_crystal(node, Vector3(cos(a) * d, 0.0, sin(a) * d), rng.randf_range(0.5, 1.2), rng.randf() * 0.4)


	_zone_delay(z, node)


func _zone_delay(z: Dictionary, node: Node3D) -> void:
	var d: float = float(z.get("fx_delay", 0.0))
	if d <= 0.0:
		return
	var ems: Array = []
	for c in node.get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = false
			ems.append(c)
	var tw := node.create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func():
		for c in ems:
			if is_instance_valid(c):
				(c as CPUParticles3D).restart())


func zone_end(z: Dictionary) -> void:
	## Feld läuft ab: Partikel nicht mehr nachschieben, Knoten erst später entfernen (Flammen verlöschen weich)
	var node: Variant = z["node"]
	if node == null:
		return
	if g.test_mode or not z.has("kind"):
		node.queue_free()
		return
	var n: Node3D = node
	for c in n.get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = false
		elif c is OmniLight3D:
			var tw: Tween = c.create_tween()
			tw.tween_property(c, "light_energy", 0.0, 0.6)
			flickers = flickers.filter(func(f): return f["node"] != c)
		elif c is MeshInstance3D and c.has_meta("crystal"):
			var tw2: Tween = c.create_tween()
			tw2.tween_property(c, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	(z["mat"] as StandardMaterial3D).albedo_color.a = 0.0
	g.fx_nodes.append({"node": n, "t": 2.8, "keep_pos": true})


func _crystal(parent: Node3D, pos: Vector3, h: float, delay: float) -> void:
	var node := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.17 * h + 0.08
	cm.height = h
	cm.radial_segments = 5
	cm.rings = 1
	node.mesh = cm
	node.material_override = _ice_mat()
	node.set_meta("crystal", true)
	node.position = pos + Vector3(0, h / 2.0, 0)
	node.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	node.scale = Vector3(0.01, 0.01, 0.01)
	parent.add_child(node)
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ice_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.92, 1.0, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission = Color(0.35, 0.8, 1.0)
	m.emission_energy_multiplier = 0.9
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	return m


# ---------------------------------------------------------------- Frost
## Frostkegel (W): eisiger Atem aus der Hand, Eiskristalle schießen im Kegel aus dem Boden
func frost_breath(p: Dictionary, ang: float, range_: float, half: float, rank: int) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var origin := _w(p["x"], p["y"], side)
	var dir3 := Vector3(sin(ang), 0.0, -cos(ang))
	var hp := origin + Vector3(0, HAND, 0) + dir3 * 0.7
	var rng_m := range_ * S
	var spread_deg := rad_to_deg(half)
	var v := rng_m / 0.55
	var breath := _ps({"amount": 150, "life": 0.55, "once": true, "explo": 0.55, "shape": "sphere", "radius": 0.15, "dir": dir3, "spread": spread_deg * 0.8,
		"vmin": v * 0.55, "vmax": v * 1.05, "smin": 0.5, "smax": 1.3, "curve": _curve([0.4, 1.0, 1.4]),
		"ramp": _ramp([[0.0, Color(0.9, 1.0, 1.0, 0.8)], [0.3, Color(0.6, 0.88, 1.0, 0.55)], [1.0, Color(0.4, 0.75, 1.0, 0.0)]])})
	_put(breath, hp, 1.2)
	var flakes := _ps({"amount": 70, "life": 0.9, "once": true, "explo": 0.8, "shape": "sphere", "radius": 0.2, "dir": dir3, "spread": spread_deg,
		"vmin": v * 0.3, "vmax": v * 1.0, "smin": 0.1, "smax": 0.25, "grav": Vector3(0, -0.8, 0),
		"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.6, Color(0.8, 0.95, 1.0, 0.8)], [1.0, Color(0.8, 0.95, 1.0, 0.0)]])})
	_put(flakes, hp, 1.4)
	_light(Color("#8fd8ff"), 2.4, 9.0, 0.6, hp)
	var cnt := 10 + rank * 3
	for k in cnt:
		var d := rng_m * sqrt(rng.randf_range(0.08, 1.0))
		var a := ang + rng.randf_range(-half, half) * 0.9
		var cp := origin + Vector3(sin(a), 0.0, -cos(a)) * d
		var holder := Node3D.new()
		var delay := d / rng_m * 0.25
		_put(holder, cp, 1.6 + delay)
		_crystal(holder, Vector3.ZERO, rng.randf_range(1.0, 2.5) * (0.7 + 0.3 * float(rank) / 5.0), delay)
		var tw := holder.create_tween()
		tw.tween_interval(0.95 + delay)
		tw.tween_property(holder, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		if k % 3 == 0:
			var puff := _ps({"amount": 8, "life": 0.7, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.2, "dir": Vector3.UP, "spread": 60.0,
				"vmin": 0.8, "vmax": 2.2, "smin": 0.08, "smax": 0.18, "grav": Vector3(0, -1.5, 0),
				"ramp": _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.15, Color(0.9, 0.98, 1.0, 1.0)], [1.0, Color(0.7, 0.9, 1.0, 0.0)]])})
			var tw2 := puff.create_tween()
			puff.emitting = false
			tw2.tween_interval(delay)
			tw2.tween_callback(func(): puff.restart())
			_put(puff, cp + Vector3(0, 0.2, 0), 1.6 + delay)


# ---------------------------------------------------------------- Blitze
## Kettenblitz-Glied: gezackter Blitz mit Leuchten, Funken am Einschlag
func bolt(x1: float, y1: float, x2: float, y2: float, side: int, crit: bool, from_hand: bool = false) -> void:
	if g.test_mode:
		return
	var a := _w(x1, y1, side) + Vector3(0, HAND if from_hand else 1.1, 0)
	var b := _w(x2, y2, side) + Vector3(0, 1.0, 0)
	var core_col := Color(1.0, 0.97, 0.75, 1.0) if crit else Color(0.92, 0.97, 1.0, 1.0)
	var glow_col := Color(1.0, 0.82, 0.25, 0.8) if crit else Color(0.45, 0.7, 1.0, 0.8)
	for variant in 3:                                    # drei Zacken-Varianten, flackern kurz nacheinander
		var pts := _jagged(a, b, 9, 0.32 if not crit else 0.45)
		var life := 0.07 if variant < 2 else 0.12
		var delay := variant * 0.06
		var mid := (a + b) / 2.0
		var rel: Array = []
		for pt in pts:
			rel.append(pt - mid)
		var glow := _ribbon(rel, 0.34 if crit else 0.26, glow_col)
		var core := _ribbon(rel, 0.09 if crit else 0.07, core_col)
		var holder := Node3D.new()
		holder.add_child(glow)
		holder.add_child(core)
		holder.visible = variant == 0
		_put(holder, mid, delay + life + 0.05)
		if variant > 0:
			var tw := holder.create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func(): holder.visible = true)
		var tw2 := holder.create_tween()
		tw2.tween_interval(delay + life)
		tw2.tween_callback(func(): holder.visible = false)
		if variant == 0 and rng.randf() < 0.7:
			var fork_pts := _jagged(pts[rng.randi_range(3, 6)], pts[rng.randi_range(3, 6)] + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.3, 0.9), rng.randf_range(-1.6, 1.6)), 5, 0.25)
			var frel: Array = []
			for pt in fork_pts:
				frel.append(pt - mid)
			holder.add_child(_ribbon(frel, 0.05, glow_col))
	var spark := _ps({"amount": 16 if not crit else 28, "life": 0.4, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 120.0,
		"vmin": 3.0, "vmax": 8.0, "smin": 0.08, "smax": 0.2, "grav": Vector3(0, -8.0, 0), "dmin": 1.0, "dmax": 2.0,
		"ramp": _ramp([[0.0, Color(1, 1, 0.9, 1.0)], [0.4, glow_col], [1.0, Color(glow_col.r, glow_col.g, glow_col.b, 0.0)]])})
	_put(spark, b, 0.7)
	_glow_sprite(Color(core_col.r, core_col.g, core_col.b, 0.9), 2.6 if crit else 1.9, 0.22, b, 1.4)
	_light(Color(0.7, 0.85, 1.0) if not crit else Color(1.0, 0.9, 0.4), 3.0 if crit else 2.0, 8.0, 0.25, b + Vector3(0, 0.5, 0))
	if from_hand:
		_glow_sprite(Color(0.7, 0.85, 1.0, 0.9), 1.3, 0.25, a)


func _jagged(a: Vector3, b: Vector3, n: int, amp: float) -> Array:
	var pts: Array = [a]
	var dir := b - a
	var len := dir.length()
	var side_v := dir.cross(Vector3.UP).normalized()
	if side_v.length() < 0.1:
		side_v = Vector3.RIGHT
	for i in range(1, n):
		var f := float(i) / n
		var off := rng.randf_range(-1.0, 1.0) * amp * minf(1.0, len / 6.0 + 0.4) * sin(f * PI)
		var up := rng.randf_range(-1.0, 1.0) * amp * 0.6 * sin(f * PI)
		pts.append(a + dir * f + side_v * off + Vector3.UP * up)
	pts.append(b)
	return pts


## Band (immer zur Kamera gedreht) entlang der Punkte, Farbe über Vertexfarbe, leuchtend
func _ribbon(pts: Array, width: float, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var back: Vector3 = g.cam.global_transform.basis.z if g.cam != null else Vector3.BACK
	for i in pts.size():
		var p0: Vector3 = pts[maxi(0, i - 1)]
		var p1: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var d := (p1 - p0).normalized()
		var side_v := d.cross(back).normalized()
		var taper := 1.0
		st.set_color(col)
		st.add_vertex(pts[i] + side_v * width * 0.5 * taper)
		st.set_color(col)
		st.add_vertex(pts[i] - side_v * width * 0.5 * taper)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	return mi


## Kleines Geschoss (Angriff der Elementare): leuchtender Fleck mit Schweif
func projectile(from: Vector3, to: Vector3, col: Color, life: float, size: float) -> void:
	var node := Node3D.new()
	_put(node, from, life + 0.6)
	_glow_on(node, col, size)
	var trail := _ps({"amount": 24, "life": 0.3, "local": false, "shape": "sphere", "radius": 0.08, "vmin": 0.0, "vmax": 0.5, "spread": 180.0,
		"smin": size * 0.4, "smax": size * 0.7, "curve": _curve([1.0, 0.0]),
		"ramp": _ramp([[0.0, Color(1, 1, 1, 0.8)], [0.4, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
	node.add_child(trail)
	var tw := node.create_tween()
	tw.tween_method(func(f: float): node.position = from.lerp(to, f), 0.0, 1.0, life)
	tw.tween_callback(func():
		trail.emitting = false
		for c in node.get_children():
			if c is CPUParticles3D:
				(c as CPUParticles3D).emitting = false
		var hit := _ps({"amount": 10, "life": 0.35, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 150.0,
			"vmin": 1.5, "vmax": 4.0, "smin": 0.1, "smax": 0.25, "grav": Vector3(0, -4.0, 0),
			"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.4, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
		_put(hit, to, 0.6))


## Flammenstrahl (Feuer-Elementar): Flammen schießen im Kegel nach vorn
func flame_jet(x: float, y: float, side: int, ang: float, range_: float, half: float) -> void:
	if g.test_mode:
		return
	var o := _w(x, y, side) + Vector3(0, 1.2, 0)
	var dir3 := Vector3(sin(ang), 0.0, -cos(ang))
	var v := range_ * S / 0.5
	var jet := _ps({"amount": 120, "life": 0.6, "tex": tex_flame, "qsize": Vector2(1.0, 1.4), "ang": 40.0, "once": false, "shape": "sphere", "radius": 0.2, "dir": dir3, "spread": rad_to_deg(half) * 0.8,
		"vmin": v * 0.5, "vmax": v, "smin": 0.8, "smax": 1.8, "dmin": v * 0.3, "dmax": v * 0.8, "grav": Vector3(0, 1.0, 0), "curve": _curve([0.5, 1.0, 0.2]),
		"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 0.9)], [0.3, Color(1.0, 0.5, 0.1, 0.8)], [0.7, Color(0.6, 0.12, 0.02, 0.5)], [1.0, Color(0.1, 0.05, 0.03, 0.0)]])})
	_put(jet, o, 1.4)
	var tw := jet.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func(): jet.emitting = false)
	_light(Color("#ff7a2a"), 3.0, 10.0, 0.7, o + dir3 * 3.0)


# ---------------------------------------------------------------- Elementar (R)
func summon(x: float, y: float, side: int, type: String) -> void:
	if g.test_mode:
		return
	var pos := _w(x, y, side)
	var col := _elem_col(type)
	var circle := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	qm.orientation = PlaneMesh.FACE_Y
	circle.mesh = qm
	var cm := _flat_mat(tex_rune, Color(col.r, col.g, col.b, 0.0), true)
	circle.material_override = cm
	circle.scale = Vector3(5.0, 1.0, 5.0)
	_put(circle, pos + Vector3(0, 0.12, 0), 2.2)
	var tw := circle.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cm, "albedo_color:a", 0.95, 0.3)
	tw.tween_property(circle, "rotation:y", 2.2, 1.8)
	tw.chain().tween_property(cm, "albedo_color:a", 0.0, 0.5).set_delay(0.8)
	# Lichtsäule
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.2
	cyl.height = 9.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 16
	beam.mesh = cyl
	var bm := _flat_mat(tex_beam, Color(col.r, col.g, col.b, 0.0), true)
	beam.material_override = bm
	beam.position.y = 4.5
	var holder := Node3D.new()
	holder.add_child(beam)
	_put(holder, pos, 1.6)
	var tw2 := holder.create_tween()
	tw2.tween_property(bm, "albedo_color:a", 0.9, 0.25).set_delay(0.35)
	tw2.tween_property(bm, "albedo_color:a", 0.0, 0.7)
	# Funken, die zur Mitte hochwirbeln
	var spiral := _ps({"amount": 60, "life": 1.0, "once": false, "shape": "ring", "radius": 2.4, "inner": 2.0, "height": 0.1, "dir": Vector3.UP, "spread": 4.0,
		"vmin": 2.0, "vmax": 5.0, "smin": 0.1, "smax": 0.24,
		"ramp": _ramp([[0.0, Color(col.r, col.g, col.b, 0.0)], [0.2, Color(1, 1, 1, 0.9)], [0.7, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
	_put(spiral, pos + Vector3(0, 0.1, 0), 2.0)
	var tw3 := spiral.create_tween()
	tw3.tween_interval(1.0)
	tw3.tween_callback(func(): spiral.emitting = false)
	_light(col, 2.5, 10.0, 1.3, pos + Vector3(0, 2.0, 0))
	var tw4 := g.create_tween()                          # Abschluss: Druckwelle und Funkenfontäne
	tw4.tween_interval(0.85)
	tw4.tween_callback(func():
		_ring_wave(pos, col, 6.0, 0.6)
		_glow_sprite(Color(1, 1, 1, 0.9), 4.5, 0.3, pos + Vector3(0, 1.0, 0), 1.5)
		var pop := _ps({"amount": 40, "life": 0.9, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 70.0,
			"vmin": 3.0, "vmax": 8.0, "smin": 0.12, "smax": 0.28, "grav": Vector3(0, -6.0, 0),
			"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.4, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
		_put(pop, pos + Vector3(0, 0.5, 0), 1.3))


func elem_vanish(x: float, y: float, side: int, type: String) -> void:
	if g.test_mode:
		return
	var pos := _w(x, y, side) + Vector3(0, 1.0, 0)
	var col := _elem_col(type)
	var pop := _ps({"amount": 36, "life": 0.8, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.4, "dir": Vector3.UP, "spread": 180.0,
		"vmin": 1.5, "vmax": 5.0, "smin": 0.12, "smax": 0.34, "grav": Vector3(0, 0.5, 0), "dmin": 1.0, "dmax": 2.5,
		"ramp": _ramp([[0.0, Color(1, 1, 1, 0.9)], [0.35, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
	_put(pop, pos, 1.2)
	_ring_wave(pos - Vector3(0, 0.85, 0), col, 3.0, 0.5)
	_light(col, 1.5, 6.0, 0.4, pos)


func _elem_col(type: String) -> Color:
	return {"fire": Color("#ff7a2a"), "frost": Color("#8fd8ff"), "lightning": Color("#ffe066")}.get(type, Color.WHITE)


## Körper des Elementars: Feuer = flammende Wolke, Frost = schwebende Kristalle, Blitz = knisternde Energiekugel
func make_elemental(type: String) -> Node3D:
	var root := Node3D.new()
	if g.test_mode:
		return root
	var pivot := Node3D.new()
	pivot.position.y = 1.1
	root.add_child(pivot)
	var col := _elem_col(type)
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = 7.0
	light.position.y = 1.4
	root.add_child(light)
	if type == "fire":
		light.light_energy = 1.8
		flickers.append({"node": light, "base": 1.8, "ph": rng.randf() * 6.0})
		_glow_on(pivot, Color(1.0, 0.55, 0.15, 1.0), 2.4)
		pivot.add_child(_ps({"amount": 70, "life": 0.8, "tex": tex_flame, "qsize": Vector2(1.0, 1.6), "ang": 14.0, "local": false, "shape": "sphere", "radius": 0.45, "dir": Vector3.UP, "spread": 30.0,
			"vmin": 0.8, "vmax": 2.2, "smin": 1.0, "smax": 1.8, "grav": Vector3(0, 1.4, 0), "curve": _curve([0.7, 1.0, 0.0]),
			"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 0.0)], [0.15, Color(1.0, 0.75, 0.25, 0.9)], [0.55, Color(1.0, 0.4, 0.1, 0.6)], [1.0, Color(0.25, 0.04, 0.0, 0.0)]])}))
		pivot.add_child(_ps({"amount": 18, "life": 1.2, "local": false, "shape": "sphere", "radius": 0.5, "dir": Vector3.UP, "spread": 40.0,
			"vmin": 1.0, "vmax": 3.0, "smin": 0.08, "smax": 0.17, "grav": Vector3(0, 0.6, 0),
			"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.6, Color(1.0, 0.5, 0.1, 0.8)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])}))
		for k in 3:                                      # kreisende Glutbrocken
			var orb := Node3D.new()
			orb.position = Vector3(cos(TAU * k / 3.0), 0.2 * (k - 1), sin(TAU * k / 3.0)) * 0.95
			orb.add_child(_ps({"amount": 8, "life": 0.4, "local": false, "vmin": 0.0, "vmax": 0.3, "smin": 0.4, "smax": 0.7, "curve": _curve([1.0, 0.0]),
				"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 0.9)], [1.0, Color(1.0, 0.3, 0.0, 0.0)]])}))
			pivot.add_child(orb)
	elif type == "frost":
		light.light_energy = 1.3
		var core := MeshInstance3D.new()
		var up := CylinderMesh.new()
		up.top_radius = 0.0
		up.bottom_radius = 0.55
		up.height = 1.1
		up.radial_segments = 6
		core.mesh = up
		core.material_override = _ice_mat()
		core.position.y = 0.55
		pivot.add_child(core)
		var down := MeshInstance3D.new()
		down.mesh = up
		down.material_override = core.material_override
		down.rotation.x = PI
		down.position.y = -0.0
		pivot.add_child(down)
		var orbit := Node3D.new()
		orbit.name = "orbit"
		pivot.add_child(orbit)
		for k in 4:
			var sh := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.0
			sm.bottom_radius = 0.13
			sm.height = 0.55
			sm.radial_segments = 5
			sh.mesh = sm
			sh.material_override = core.material_override
			sh.position = Vector3(cos(TAU * k / 4.0), 0.2, sin(TAU * k / 4.0)) * 1.1
			sh.rotation = Vector3(0.4, k, 0.4)
			orbit.add_child(sh)
		_glow_on(pivot, Color(0.55, 0.85, 1.0, 0.7), 2.0)
		pivot.add_child(_ps({"amount": 40, "life": 1.4, "local": false, "shape": "sphere", "radius": 0.9, "dir": Vector3.DOWN, "spread": 60.0,
			"vmin": 0.1, "vmax": 0.6, "smin": 0.07, "smax": 0.16, "grav": Vector3(0, -0.5, 0),
			"ramp": _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.25, Color(0.9, 0.97, 1.0, 0.9)], [1.0, Color(0.7, 0.9, 1.0, 0.0)]])}))
		pivot.add_child(_ps({"amount": 10, "life": 2.0, "local": false, "add": false, "shape": "sphere", "radius": 0.6, "dir": Vector3.UP, "spread": 60.0,
			"vmin": 0.1, "vmax": 0.4, "smin": 1.2, "smax": 2.0,
			"ramp": _ramp([[0.0, Color(0.7, 0.88, 1.0, 0.0)], [0.3, Color(0.75, 0.9, 1.0, 0.3)], [1.0, Color(0.8, 0.92, 1.0, 0.0)]])}))
	else:
		light.light_energy = 2.2
		flickers.append({"node": light, "base": 2.2, "ph": rng.randf() * 6.0, "wild": true})
		_glow_on(pivot, Color(1.0, 0.9, 0.35, 1.0), 2.0)
		pivot.add_child(_ps({"amount": 22, "life": 0.5, "local": false, "shape": "sphere", "radius": 0.6, "dir": Vector3.UP, "spread": 180.0,
			"vmin": 1.0, "vmax": 3.5, "smin": 0.07, "smax": 0.16, "grav": Vector3(0, -2.0, 0),
			"ramp": _ramp([[0.0, Color(1, 1, 0.9, 1.0)], [0.5, Color(1.0, 0.85, 0.3, 0.8)], [1.0, Color(1.0, 0.7, 0.2, 0.0)]])}))
	elems.append({"node": root, "type": type, "pivot": pivot, "arc_t": 0.0, "age": 0.0})
	root.scale = Vector3(0.01, 0.01, 0.01)
	var tw := root.create_tween()
	tw.tween_interval(0.9)                               # erscheint, wenn der Zauberkreis aufleuchtet
	tw.tween_property(root, "scale", Vector3.ONE * 1.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


# ---------------------------------------------------------------- laufende Aktualisierung
func tick(delta: float, t: float) -> void:
	if g.test_mode:
		return
	for f in flickers.duplicate():
		if not is_instance_valid(f["node"]):
			flickers.erase(f)
			continue
		var n: float = sin(t * 13.0 + f["ph"]) * 0.5 + sin(t * 7.3 + f["ph"] * 2.0) * 0.5
		if f.get("wild", false):
			n = rng.randf_range(-1.0, 1.0)
		(f["node"] as OmniLight3D).light_energy = f["base"] * (0.85 + 0.2 * n)
	for e in elems.duplicate():
		if not is_instance_valid(e["node"]):
			elems.erase(e)
			continue
		e["age"] += delta
		var pv: Node3D = e["pivot"]
		pv.position.y = 1.1 + 0.12 * sin(e["age"] * 2.6)
		if e["type"] == "frost":
			pv.rotation.y += delta * 0.8
			var orbit := pv.get_node_or_null("orbit")
			if orbit != null:
				orbit.rotation.y -= delta * 2.2
		elif e["type"] == "fire":
			pv.rotation.y += delta * 1.5
		else:
			e["arc_t"] -= delta
			if e["arc_t"] <= 0.0:
				e["arc_t"] = rng.randf_range(0.08, 0.2)
				var o: Vector3 = (e["node"] as Node3D).global_position + Vector3(0, 1.2, 0)
				var a := rng.randf() * TAU
				var tgt := o + Vector3(cos(a), rng.randf_range(-0.4, 0.8), sin(a)) * rng.randf_range(0.9, 1.7)
				_mini_arc(o, tgt)


func _mini_arc(a: Vector3, b: Vector3) -> void:
	var pts := _jagged(a, b, 5, 0.18)
	var mid := (a + b) / 2.0
	var rel: Array = []
	for pt in pts:
		rel.append(pt - mid)
	var holder := Node3D.new()
	holder.add_child(_ribbon(rel, 0.16, Color(1.0, 0.85, 0.3, 0.7)))
	holder.add_child(_ribbon(rel, 0.05, Color(1, 1, 0.9, 1.0)))
	_put(holder, mid, 0.07)


func bolt_later(delay: float, x1: float, y1: float, x2: float, y2: float, side: int, crit: bool, from_hand: bool) -> void:
	## Kettenblitz: jedes Glied etwas später, damit man den Sprung von Ziel zu Ziel sieht
	if g.test_mode:
		return
	if delay <= 0.0:
		bolt(x1, y1, x2, y2, side, crit, from_hand)
	else:
		g.get_tree().create_timer(delay).timeout.connect(func(): bolt(x1, y1, x2, y2, side, crit, from_hand))


## Normalangriff eines Elementars
func elem_shot(type: String, x1: float, y1: float, x2: float, y2: float, side: int) -> void:
	if g.test_mode:
		return
	if type == "lightning":
		bolt(x1, y1, x2, y2, side, false)
		return
	var size := 0.7 if type == "fire" else 0.5
	projectile(_w(x1, y1, side) + Vector3(0, 1.3, 0), _w(x2, y2, side) + Vector3(0, 1.0, 0), _elem_col(type), 0.16, size)
