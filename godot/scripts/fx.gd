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
	p.amount = maxi(1, int(round(float(o.get("amount", 20)) * Data.user.particle_factor())))     # Grafikqualität: weniger Partikel
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
	l.light_energy = energy * Data.user.light_factor()               # Grafikqualität: Effektlichter schwächer oder aus
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


# ---------------------------------------------------------------- Level-Aufstieg (alle Helden)
## Goldener Runenkreis unter dem Helden, Funken spiralen hoch (ca. 2 s). Folgt dem Helden (Kind von p["node"]).
func level_up(p: Dictionary) -> void:
	if g.test_mode:
		return
	var node: Node3D = p["node"]
	var gold := Color(1.0, 0.82, 0.35)
	var holder := Node3D.new()
	holder.name = "LevelUpFx"
	node.add_child(holder)
	var pos := _w(p["x"], p["y"], p["side"]["idx"])
	var circle := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	qm.orientation = PlaneMesh.FACE_Y
	circle.mesh = qm
	var cm := _flat_mat(tex_rune, Color(gold.r, gold.g, gold.b, 0.0), true)
	circle.material_override = cm
	circle.scale = Vector3(3.6, 1.0, 3.6)
	circle.position.y = 0.12
	holder.add_child(circle)
	var tw := circle.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cm, "albedo_color:a", 0.95, 0.2)
	tw.tween_property(circle, "rotation:y", 2.6, 1.5)
	tw.chain().tween_property(cm, "albedo_color:a", 0.0, 0.5).set_delay(0.7)
	var spiral := _ps({"amount": 40, "life": 1.0, "local": true, "shape": "ring", "radius": 1.6, "inner": 1.3, "height": 0.1,
		"dir": Vector3.UP, "spread": 4.0, "vmin": 2.0, "vmax": 4.5, "smin": 0.08, "smax": 0.2,
		"ramp": _ramp([[0.0, Color(gold.r, gold.g, gold.b, 0.0)], [0.2, Color(1, 1, 1, 0.9)], [0.7, gold], [1.0, Color(gold.r, gold.g, gold.b, 0.0)]])})
	holder.add_child(spiral)
	var tw2 := spiral.create_tween()
	tw2.tween_interval(0.9)
	tw2.tween_callback(func(): spiral.emitting = false)
	_glow_sprite(Color(1.0, 0.9, 0.6, 0.8), 2.4, 0.3, pos + Vector3(0, 1.2, 0), 1.3)
	_light(gold, 2.0, 7.0, 1.4, pos + Vector3(0, 1.5, 0))
	var tw_end := holder.create_tween()
	tw_end.tween_interval(2.0)
	tw_end.tween_callback(holder.queue_free)


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


	elif kind == "poison":
		var ar := r * r
		node.add_child(_ps({"amount": int(clampf(10.0 + ar * 1.5, 12.0, 60.0)), "life": 2.2, "add": false, "shape": "ring", "radius": r * 0.85, "height": 0.1,
			"dir": Vector3.UP, "spread": 18.0, "vmin": 0.3, "vmax": 0.9, "smin": 1.4, "smax": 2.6, "grav": Vector3(0, 0.2, 0), "curve": _curve([0.5, 1.0]),
			"ramp": _ramp([[0.0, Color(0.45, 0.8, 0.3, 0.0)], [0.2, Color(0.4, 0.75, 0.3, 0.42)], [0.8, Color(0.3, 0.45, 0.35, 0.3)], [1.0, Color(0.25, 0.3, 0.3, 0.0)]])}))
		node.add_child(_ps({"amount": int(clampf(8.0 + ar, 10.0, 36.0)), "life": 1.6, "shape": "ring", "radius": r * 0.9, "height": 0.1,
			"dir": Vector3.UP, "spread": 10.0, "vmin": 0.4, "vmax": 1.2, "smin": 0.1, "smax": 0.22, "grav": Vector3(0, 0.3, 0),
			"ramp": _ramp([[0.0, Color(0.7, 1.0, 0.5, 0.0)], [0.25, Color(0.7, 1.0, 0.45, 1.0)], [1.0, Color(0.5, 0.9, 0.4, 0.0)]])}))
		node.add_child(_ps({"amount": 8, "life": 1.2, "shape": "ring", "radius": r * 0.8, "height": 0.1, "dir": Vector3.UP, "spread": 8.0,
			"vmin": 0.8, "vmax": 2.0, "smin": 0.14, "smax": 0.26, "grav": Vector3(0, -1.5, 0),
			"ramp": _ramp([[0.0, Color(0.6, 1.0, 0.4, 0.0)], [0.2, Color(0.6, 1.0, 0.4, 0.9)], [1.0, Color(0.4, 0.7, 0.3, 0.0)]])}))
		var lt3 := OmniLight3D.new()
		lt3.light_color = Color(0.5, 1.0, 0.4)
		lt3.light_energy = 0.9
		lt3.omni_range = r * 2.0 + 3.0
		lt3.position.y = 0.8
		node.add_child(lt3)
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


## Normalangriff des Casters: kleiner Feuerball mit Flammenschweif, kleiner Einschlag
func auto_fireball(p: Dictionary, tx: float, ty: float) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var from := _hand(p)
	var to := _w(tx, ty, side) + Vector3(0, 0.9, 0)
	var life := clampf(from.distance_to(to) / 28.0, 0.1, 0.4)
	var node := Node3D.new()
	_put(node, from, life + 0.8)
	_glow_on(node, Color(1.0, 0.6, 0.2, 1.0), 0.9)
	var trail := _ps({"amount": 36, "life": 0.28, "tex": tex_flame, "qsize": Vector2(1.0, 1.4), "ang": 20.0, "local": false, "shape": "sphere", "radius": 0.06,
		"vmin": 0.0, "vmax": 0.4, "spread": 180.0, "smin": 0.45, "smax": 0.75, "curve": _curve([1.0, 0.0]),
		"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 0.9)], [0.4, Color(1.0, 0.45, 0.1, 0.7)], [1.0, Color(0.3, 0.05, 0.0, 0.0)]])})
	node.add_child(trail)
	var lt := OmniLight3D.new()
	lt.light_color = Color("#ff8a3a")
	lt.light_energy = 0.9
	lt.omni_range = 4.0
	node.add_child(lt)
	var tw := node.create_tween()
	tw.tween_method(func(f: float): node.position = from.lerp(to, f), 0.0, 1.0, life)
	tw.tween_callback(func():
		trail.emitting = false
		lt.light_energy = 0.0
		for c in node.get_children():
			if c is MeshInstance3D:
				c.visible = false
		_glow_sprite(Color(1.0, 0.8, 0.45, 0.9), 1.6, 0.14, to, 1.4)
		var hit := _ps({"amount": 12, "life": 0.4, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 140.0,
			"vmin": 2.0, "vmax": 5.0, "smin": 0.1, "smax": 0.22, "grav": Vector3(0, -6.0, 0),
			"ramp": _ramp([[0.0, Color(1.0, 0.95, 0.6, 1.0)], [0.5, Color(1.0, 0.5, 0.1, 0.8)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])})
		_put(hit, to, 0.7)
		var puff := _ps({"amount": 5, "life": 0.5, "once": true, "explo": 1.0, "tex": tex_flame, "qsize": Vector2(1.0, 1.4), "ang": 25.0, "shape": "sphere", "radius": 0.15,
			"dir": Vector3.UP, "spread": 60.0, "vmin": 0.5, "vmax": 1.5, "smin": 0.7, "smax": 1.1, "grav": Vector3(0, 1.0, 0), "curve": _curve([0.6, 1.0, 0.0]),
			"ramp": _ramp([[0.0, Color(1.0, 0.8, 0.4, 0.8)], [1.0, Color(0.5, 0.1, 0.0, 0.0)]])})
		_put(puff, to, 0.8))


# ================================================================ Tank
## Schild (Turmschild mit Spikes)
func make_shield() -> Node3D:
	## Turmschild: hoher, schmaler Schild aus dunklem Eisen mit violetter Einfassung und Spikes auf der Vorderseite.
	## Vorderseite zeigt nach +Z, Oberkante nach +Y.
	var root := Node3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.24, 0.25, 0.3)
	iron.metallic = 0.7
	iron.roughness = 0.5
	var purple := StandardMaterial3D.new()
	purple.albedo_color = Color(0.42, 0.2, 0.62)
	purple.metallic = 0.5
	purple.roughness = 0.45
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.75, 0.82)
	steel.metallic = 0.95
	steel.roughness = 0.25
	var w := 0.66
	var h := 1.38
	var d := 0.09
	# Tafel (leicht gebogen: Mittelstreifen vorn, Seitenstreifen nach hinten gewinkelt)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(w * 0.5, h, d)
	plate.mesh = pm
	plate.material_override = iron
	root.add_child(plate)
	for s in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(w * 0.3, h, d)
		wing.mesh = wm
		wing.material_override = iron
		wing.position = Vector3(s * w * 0.38, 0.0, -0.025)
		wing.rotation_degrees = Vector3(0, -s * 14.0, 0)
		root.add_child(wing)
	# violette Einfassung: oben, unten, links, rechts
	for k in 4:
		var fr := MeshInstance3D.new()
		var fm := BoxMesh.new()
		var horiz := k < 2
		fm.size = Vector3(w * 1.02, 0.07, 0.05) if horiz else Vector3(0.06, h, 0.05)
		fr.mesh = fm
		fr.material_override = purple
		if horiz:
			fr.position = Vector3(0.0, (h / 2.0 - 0.02) * (1.0 if k == 0 else -1.0), 0.04)
		else:
			var sx := 1.0 if k == 2 else -1.0
			fr.position = Vector3(sx * (w / 2.0 - 0.02), 0.0, -0.01)
			fr.rotation_degrees = Vector3(0, -sx * 14.0, 0)
			fr.position.x = sx * (w * 0.38 + 0.12)
			fr.position.z = 0.02
		root.add_child(fr)
	# Querbänder
	for yy in [0.38, -0.38]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 0.96, 0.05, 0.03)
		band.mesh = bm
		band.material_override = purple
		band.position = Vector3(0.0, yy, 0.06)
		root.add_child(band)
	# Spikes vorne: Raster 3 x 5
	for ix in 3:
		for iy in 5:
			var spike := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.0
			sm.bottom_radius = 0.045
			sm.height = 0.2
			sm.radial_segments = 6
			spike.mesh = sm
			spike.material_override = steel
			spike.rotation_degrees = Vector3(90, 0, 0)
			spike.position = Vector3((ix - 1) * 0.19, (iy - 2) * 0.27, 0.13)
			root.add_child(spike)
	# großer Mittelspike
	var big := MeshInstance3D.new()
	var bgm := CylinderMesh.new()
	bgm.top_radius = 0.0
	bgm.bottom_radius = 0.08
	bgm.height = 0.34
	bgm.radial_segments = 6
	big.mesh = bgm
	big.material_override = steel
	big.rotation_degrees = Vector3(90, 0, 0)
	big.position = Vector3(0.0, 0.0, 0.2)
	root.add_child(big)
	return root


## Schild am linken Unterarm des Modells befestigen (Knochen "LowerArm.L"). Rückgabe in fig["shield"].
func attach_shield(fig: Dictionary) -> void:
	if g.test_mode:
		return
	var skel := (fig["inner"] as Node).find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "LowerArm.L"
	skel.add_child(ba)
	var holder := Node3D.new()
	holder.name = "ShieldHolder"
	var sh := make_shield()
	sh.rotation_degrees = Vector3(0, 0, 180)                # Spitze zeigt zur Hand
	holder.add_child(sh)
	holder.position = Vector3(0.0, 0.1, 0.22)             # Knochen: Y entlang des Unterarms (zur Hand), Z nach außen
	holder.scale = Vector3.ONE * 1.0
	holder.rotation_degrees = Vector3(0, 40, 0)           # Vorderseite schräg nach vorn-außen
	ba.add_child(holder)
	fig["shield"] = holder
	fig["shield_attach"] = ba


func _shield_hand_pos(p: Dictionary) -> Vector3:
	var fig: Dictionary = p.get("fig", {})
	if not fig.is_empty() and fig.has("shield"):
		var h: Node3D = fig["shield"]
		if h.is_inside_tree():
			return h.global_position
	return _hand(p) - Vector3(0, 0.3, 0)


func _shield_visible(p: Dictionary, v: bool) -> void:
	var fig: Dictionary = p.get("fig", {})
	if not fig.is_empty() and fig.has("shield"):
		(fig["shield"] as Node3D).visible = v


## Schildwurf: Schild verlässt die Hand, springt von Ziel zu Ziel (shield_to je Sprung) und kehrt zurück (shield_back)
func shield_to(p: Dictionary, tx: float, ty: float, dur: float) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var to := _w(tx, ty, side) + Vector3(0, 1.1, 0)
	var fly: Node3D = p.get("shield_fly", null)
	if fly == null or not is_instance_valid(fly):
		fly = _make_fly_shield()
		p["shield_fly"] = fly
		fly.position = _shield_hand_pos(p)
		_shield_visible(p, false)
	var from := fly.position
	var old_tw: Tween = p.get("shield_tw", null)
	if old_tw != null:
		old_tw.kill()
	var tw := fly.create_tween()
	p["shield_tw"] = tw
	tw.tween_method(func(f: float):
		var pos := from.lerp(to, f)
		pos.y += sin(f * PI) * 0.7
		fly.position = pos, 0.0, 1.0, maxf(0.05, dur))
	tw.tween_callback(func(): metal_hit(to, 1.0))


func shield_back(p: Dictionary, dur: float) -> void:
	if g.test_mode:
		return
	var fly: Node3D = p.get("shield_fly", null)
	if fly == null or not is_instance_valid(fly):
		return
	var from := fly.position
	var old_tw: Tween = p.get("shield_tw", null)
	if old_tw != null:
		old_tw.kill()
	var tw := fly.create_tween()
	p["shield_tw"] = tw
	tw.tween_method(func(f: float):
		var to := _shield_hand_pos(p)
		var pos := from.lerp(to, f)
		pos.y += sin(f * PI) * 0.5
		fly.position = pos, 0.0, 1.0, maxf(0.05, dur))
	tw.tween_callback(func():
		_shield_visible(p, true)
		p["shield_fly"] = null
		fly.queue_free()
		_glow_sprite(Color(0.7, 0.9, 1.0, 0.9), 1.5, 0.2, _shield_hand_pos(p), 1.4))


func _make_fly_shield() -> Node3D:
	var node := Node3D.new()
	g.add_child(node)
	var spin := Node3D.new()
	var sh := make_shield()
	sh.rotation.x = -PI / 2.0                    # flach, Vorderseite nach oben
	sh.scale = Vector3.ONE * 1.5
	spin.add_child(sh)
	node.add_child(spin)
	var tw := spin.create_tween()
	tw.set_loops()
	tw.tween_property(spin, "rotation:y", TAU, 0.28).from(0.0)
	var trail := _ps({"amount": 30, "life": 0.35, "local": false, "shape": "sphere", "radius": 0.15, "vmin": 0.0, "vmax": 0.3, "spread": 180.0,
		"smin": 0.3, "smax": 0.6, "curve": _curve([1.0, 0.0]),
		"ramp": _ramp([[0.0, Color(0.9, 0.97, 1.0, 0.7)], [0.5, Color(0.6, 0.8, 1.0, 0.4)], [1.0, Color(0.5, 0.7, 1.0, 0.0)]])})
	node.add_child(trail)
	g.fx_nodes.append({"node": node, "t": 6.0})
	return node


## Metall trifft Ziel: Funken, Lichtblitz, kleiner Ring
func metal_hit(pos: Vector3, size: float) -> void:
	var sp := _ps({"amount": int(18 * size), "life": 0.45, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 130.0,
		"vmin": 3.0, "vmax": 8.0, "smin": 0.07, "smax": 0.16, "grav": Vector3(0, -12.0, 0),
		"ramp": _ramp([[0.0, Color(1, 1, 0.9, 1.0)], [0.4, Color(1.0, 0.85, 0.5, 0.9)], [1.0, Color(1.0, 0.6, 0.2, 0.0)]])})
	_put(sp, pos, 0.8)
	_glow_sprite(Color(1.0, 0.95, 0.8, 0.9), 1.6 * size, 0.14, pos, 1.5)
	_light(Color(1.0, 0.9, 0.7), 1.6, 5.0, 0.18, pos)


## Eiserne Haut: kleine Funken, wenn der Tank getroffen wird
func iron_spark(p: Dictionary) -> void:
	if g.test_mode:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(p.get("iron_t", 0.0)) < 0.3:
		return
	p["iron_t"] = now
	var pos := _w(p["x"], p["y"], p["side"]["idx"]) + Vector3(0, 1.4, 0)
	var sp := _ps({"amount": 8, "life": 0.35, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 150.0,
		"vmin": 1.5, "vmax": 4.0, "smin": 0.05, "smax": 0.11, "grav": Vector3(0, -8.0, 0),
		"ramp": _ramp([[0.0, Color(0.9, 0.95, 1.0, 1.0)], [0.5, Color(0.7, 0.8, 1.0, 0.8)], [1.0, Color(0.6, 0.7, 1.0, 0.0)]])})
	_put(sp, pos, 0.6)


## flaches Band auf dem Boden entlang der Punkte (für Risse im Boden)
func _ground_ribbon(pts: Array, width: float, col: Color, additive: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p0: Vector3 = pts[maxi(0, i - 1)]
		var p1: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var d := (p1 - p0)
		d.y = 0.0
		d = d.normalized()
		var side_v := d.cross(Vector3.UP).normalized()
		var w := width * (1.0 - 0.75 * float(i) / maxf(1.0, pts.size() - 1.0))       # läuft spitz aus
		st.set_color(col)
		st.add_vertex(pts[i] + side_v * w * 0.5)
		st.set_color(col)
		st.add_vertex(pts[i] - side_v * w * 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	return mi


## Risse im Boden: strahlenförmig, dunkel mit goldenem Glühen, blenden nach `life` aus
func _cracks(center: Vector3, ang: float, half: float, len_m: float, count: int, life: float) -> void:
	for k in count:
		var a := ang + (rng.randf_range(-half, half) if half < PI else rng.randf() * TAU)
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var dist := len_m * rng.randf_range(0.55, 1.0)
		var pts: Array = []
		var steps := 7
		var side_v := dir.cross(Vector3.UP)
		for i in steps + 1:
			var f := float(i) / steps
			pts.append(dir * dist * f + side_v * rng.randf_range(-0.25, 0.25) * dist * 0.15 * sin(f * PI) + Vector3(0, 0.06, 0))
		var holder := Node3D.new()
		var dark := _ground_ribbon(pts, 0.55, Color(0.07, 0.05, 0.04, 0.9), false)
		holder.add_child(dark)
		var glow_pts: Array = []
		for pt in pts:
			glow_pts.append(pt + Vector3(0, 0.02, 0))
		var glow := _ground_ribbon(glow_pts, 0.24, Color(1.0, 0.75, 0.3, 0.8), true)
		holder.add_child(glow)
		_put(holder, center, life + 0.1)
		var gm := glow.material_override as StandardMaterial3D
		var dm := dark.material_override as StandardMaterial3D
		var tw := holder.create_tween()
		tw.tween_property(gm, "albedo_color:a", 0.0, life * 0.6)
		tw.tween_property(dm, "albedo_color:a", 0.0, life * 0.4)


## Flacher Bogen (Kegelstück) am Boden, wächst nach außen und blendet aus (Druckwelle)
func _arc_wave(origin: Vector3, ang: float, half: float, r_end: float, life: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	for i in segs:
		var a0 := ang - half + 2.0 * half * i / segs
		var a1 := ang - half + 2.0 * half * (i + 1) / segs
		var i0 := Vector3(sin(a0), 0.0, -cos(a0)) * 0.78
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var i1 := Vector3(sin(a1), 0.0, -cos(a1)) * 0.78
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		st.set_color(Color(col.r, col.g, col.b, 0.0))
		st.add_vertex(i0)
		st.set_color(col)
		st.add_vertex(o0)
		st.set_color(col)
		st.add_vertex(o1)
		st.set_color(Color(col.r, col.g, col.b, 0.0))
		st.add_vertex(i0)
		st.set_color(col)
		st.add_vertex(o1)
		st.set_color(Color(col.r, col.g, col.b, 0.0))
		st.add_vertex(i1)
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
	mi.scale = Vector3.ONE * 0.2
	_put(mi, origin + Vector3(0, 0.14, 0), life + 0.1)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r_end, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)


func _dust(pos: Vector3, dir: Vector3, spread: float, speed: float, amount: int, size: float, life: float = 0.9) -> void:
	var d := _ps({"amount": amount, "life": life, "once": true, "explo": 0.9, "add": false, "shape": "sphere", "radius": 0.3, "dir": dir, "spread": spread,
		"vmin": speed * 0.3, "vmax": speed, "dmin": 1.5, "dmax": 3.0, "smin": size * 0.6, "smax": size, "grav": Vector3(0, 0.3, 0), "curve": _curve([0.4, 1.0]),
		"ramp": _ramp([[0.0, Color(0.62, 0.55, 0.44, 0.0)], [0.12, Color(0.66, 0.58, 0.46, 0.55)], [1.0, Color(0.5, 0.46, 0.4, 0.0)]])})
	_put(d, pos, life + 0.3)


func _debris(pos: Vector3, dir: Vector3, spread: float, speed: float, amount: int, life: float = 1.1) -> void:
	var d := _ps({"amount": amount, "life": life, "once": true, "explo": 1.0, "add": false, "shape": "sphere", "radius": 0.3, "dir": dir, "spread": spread,
		"vmin": speed * 0.4, "vmax": speed, "smin": 0.12, "smax": 0.3, "grav": Vector3(0, -16.0, 0),
		"ramp": _ramp([[0.0, Color(0.32, 0.26, 0.2, 1.0)], [0.85, Color(0.24, 0.2, 0.16, 0.95)], [1.0, Color(0.2, 0.17, 0.14, 0.0)]])})
	_put(d, pos, life + 0.3)


## Schockwelle (Q): Bodenschlag, Staubwelle im Kegel, Risse, Steinbrocken, goldener Druckbogen
func tank_shockwave(p: Dictionary, ang: float, range_: float, half: float, rank: int) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var origin := _w(p["x"], p["y"], side)
	var dir3 := Vector3(sin(ang), 0.0, -cos(ang))
	var r_m := range_ * S
	var tip := origin + dir3 * 1.2
	var v := r_m / 0.45
	_glow_sprite(Color(1.0, 0.9, 0.6, 0.9), 3.4, 0.2, tip + Vector3(0, 0.8, 0), 1.5)
	_light(Color(1.0, 0.85, 0.5), 2.5, 9.0, 0.35, tip + Vector3(0, 1.2, 0))
	_dust(tip + Vector3(0, 0.3, 0), dir3 + Vector3(0, 0.15, 0), rad_to_deg(half) * 0.9, v, 130, 3.0)
	_dust(tip + Vector3(0, 0.2, 0), dir3, rad_to_deg(half), v * 0.6, 40, 2.8, 1.2)
	_debris(tip + Vector3(0, 0.3, 0), (dir3 + Vector3(0, 0.9, 0)).normalized(), 35.0, 9.0 + rank, 18 + rank * 3)
	_arc_wave(origin, ang, half, r_m * 1.05, 0.45, Color(1.0, 0.85, 0.5, 0.85))
	_cracks(origin + dir3 * 0.8, ang, half * 0.9, r_m, 4 + rank, 1.4)
	if rank >= 3:
		_ring_wave(tip, Color(1.0, 0.9, 0.7, 0.6), 3.5, 0.4)
	g.shake_near(origin, 4.0 + rank)


func titan_slam(p: Dictionary, range_units: float, half: float, ang: float) -> void:
	## Titanenstoß (R): Erdbeben-Kegel. Der Boden bricht fächerförmig nach vorn auf (länger und breiter als die Schockwelle):
	## Felsplatten schießen reihenweise schräg aus dem Boden, glühende Magma-Risse fächern sich auf, Erdfontänen, Funken, Beben.
	## Farben: Fels, Erde, Magma (rot-orange), bewusst nicht blau oder golden.
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var origin := _w(p["x"], p["y"], side)
	var r_m := range_units * S
	var dir := Vector3(sin(ang), 0.0, -cos(ang))
	var left := Vector3(-dir.z, 0.0, dir.x)
	var magma := Color(1.0, 0.36, 0.08)
	var earth := Color(0.55, 0.38, 0.24)
	var lane_cap: float = g.lane_half_g * S - 0.8      # Platten und Risse bleiben innerhalb der Lane
	var tip := origin + dir * 1.0
	_glow_sprite(Color(1.0, 0.55, 0.2, 1.0), 5.5, 0.22, tip + Vector3(0, 0.8, 0), 1.7)
	_light(magma, 4.0, 14.0, 0.7, tip + Vector3(0, 1.5, 0))
	_dust(origin + Vector3(0, 0.3, 0), dir + Vector3(0, 0.6, 0), 80.0, 4.0, 60, 2.6, 1.0)
	# glühender Kegelboden und zwei Druckbögen
	_cone_glow(origin, ang, half, r_m, 1.9, Color(1.0, 0.38, 0.08, 0.7))
	_arc_wave(origin, ang, half, r_m, 0.6, Color(earth.r, earth.g, earth.b, 0.8))
	var twa := g.create_tween()
	twa.tween_interval(0.2)
	twa.tween_callback(func(): _arc_wave(origin, ang, half, r_m * 0.8, 0.6, Color(1.0, 0.5, 0.15, 0.7)))
	# Magma-Risse: Fächer aus langen Rissen (Mitte bis Kegelrand)
	var crack_n := 7
	for k in crack_n:
		var off := (float(k) / (crack_n - 1) * 2.0 - 1.0) * half * 0.92
		var a := ang + off
		var cdir := Vector3(sin(a), 0.0, -cos(a))
		var cleft := Vector3(-cdir.z, 0.0, cdir.x)
		var dist := r_m * rng.randf_range(0.8, 1.0)
		if absf(off) > 0.05:
			dist = minf(dist, lane_cap / sin(absf(off)))
		var pts: Array = []
		var steps := 12
		for i in steps + 1:
			var f := float(i) / steps
			pts.append(cdir * (0.8 + (dist - 0.8) * f) + cleft * rng.randf_range(-0.25, 0.25) * (0.3 + f) + Vector3(0, 0.06, 0))
		var holder := Node3D.new()
		var dark := _ground_ribbon(pts, 0.9 if k == crack_n / 2 else 0.6, Color(0.05, 0.03, 0.02, 0.95), false)
		holder.add_child(dark)
		var glow_pts: Array = []
		for pt in pts:
			glow_pts.append(pt + Vector3(0, 0.03, 0))
		var glow := _ground_ribbon(glow_pts, 0.5 if k == crack_n / 2 else 0.32, Color(1.0, 0.42, 0.1, 0.9), true)
		holder.add_child(glow)
		var core := _ground_ribbon(glow_pts, 0.14, Color(1.0, 0.85, 0.5, 0.9), true)
		holder.add_child(core)
		_put(holder, origin, 2.8)
		var twc := holder.create_tween()
		twc.tween_interval(0.25 + 0.03 * k)
		twc.set_parallel(true)
		twc.tween_property(core.material_override, "albedo_color:a", 0.0, 0.5)
		twc.tween_property(glow.material_override, "albedo_color:a", 0.0, 1.0)
		twc.chain().tween_property(dark.material_override, "albedo_color:a", 0.0, 0.6)
	# Felsplatten: Reihen im Fächer, innen wenige, außen mehr
	var rows := 9
	var tan_h := tan(half)
	for i in rows:
		var f := float(i) / (rows - 1)
		var d := 1.6 + (r_m - 1.6) * f
		var wmax := minf(d * tan_h * 0.85, lane_cap)
		var cnt := clampi(int(wmax * 2.0 / 2.7) + 1, 1, 3)                 # höchstens 3 Platten je Reihe
		var delay := 0.05 + 0.5 * f
		for j in cnt:
			var lat := 0.0 if cnt == 1 else (float(j) / (cnt - 1) * 2.0 - 1.0) * wmax
			var pos := origin + dir * (d + rng.randf_range(-0.4, 0.4)) + left * (lat + rng.randf_range(-0.3, 0.3))
			var slab := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var sw := rng.randf_range(1.0, 1.6)
			var sh := rng.randf_range(1.2, 2.1) * (0.8 + 0.4 * f)
			bm.size = Vector3(sw, sh, 0.4)
			slab.mesh = bm
			slab.material_override = _mat_slab()
			_put(slab, pos, 2.0)
			slab.rotation = Vector3(0, atan2(dir.x, dir.z) + rng.randf_range(-0.3, 0.3), 0)
			slab.rotate_object_local(Vector3.RIGHT, deg_to_rad(rng.randf_range(20.0, 38.0)))
			slab.scale = Vector3(1.0, 0.01, 1.0)
			slab.position.y = -0.1
			var dl := delay + rng.randf_range(0.0, 0.06)
			var tws := slab.create_tween()
			tws.tween_interval(dl)
			tws.tween_method(func(t: float):
				slab.scale = Vector3(1.0, maxf(0.01, t), 1.0)
				slab.position.y = sh * 0.5 * t * 0.8, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tws.tween_interval(0.6)
			tws.tween_method(func(t: float):
				slab.scale = Vector3(1.0, maxf(0.01, 1.0 - t), 1.0)
				slab.position.y = sh * 0.5 * (1.0 - t) * 0.8, 0.0, 1.0, 0.45)
			if j % 2 == 0:                               # Erdfontäne und Funken (nicht an jeder Platte, spart Rechenzeit)
				var burst := Node3D.new()
				_put(burst, pos, 1.6 + dl)
				var dirt := _ps({"amount": 14, "life": 0.9, "once": true, "explo": 1.0, "add": false, "shape": "sphere", "radius": 0.4, "dir": Vector3.UP, "spread": 40.0,
					"vmin": 3.0, "vmax": 8.0, "smin": 0.35, "smax": 0.9, "grav": Vector3(0, -9.0, 0), "dmin": 0.5, "dmax": 1.5,
					"ramp": _ramp([[0.0, Color(0.5, 0.36, 0.24, 0.0)], [0.12, Color(0.52, 0.38, 0.26, 0.8)], [1.0, Color(0.34, 0.25, 0.18, 0.0)]])})
				dirt.emitting = false
				burst.add_child(dirt)
				var emb := _ps({"amount": 8, "life": 0.8, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 45.0,
					"vmin": 3.0, "vmax": 9.0, "smin": 0.08, "smax": 0.18, "grav": Vector3(0, -10.0, 0),
					"ramp": _ramp([[0.0, Color(1.0, 0.9, 0.5, 1.0)], [0.4, Color(1.0, 0.45, 0.1, 0.9)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])})
				emb.emitting = false
				burst.add_child(emb)
				var twb := burst.create_tween()
				twb.tween_interval(dl)
				twb.tween_callback(func():
					dirt.restart()
					emb.restart())
	# Staubfahne in der Mitte hinter der Welle
	var trail := _ps({"amount": 80, "life": 1.2, "once": true, "explo": 0.0, "add": false, "shape": "sphere", "radius": 0.8, "dir": Vector3.UP, "spread": 30.0,
		"vmin": 0.8, "vmax": 2.2, "smin": 2.0, "smax": 3.4, "grav": Vector3(0, 0.4, 0), "curve": _curve([0.5, 1.0]),
		"ramp": _ramp([[0.0, Color(0.5, 0.4, 0.3, 0.0)], [0.15, Color(0.52, 0.42, 0.32, 0.5)], [1.0, Color(0.4, 0.34, 0.28, 0.0)]])})
	trail.emitting = false
	_put(trail, origin, 2.4)
	var twt := trail.create_tween()
	twt.tween_callback(func(): trail.restart())
	twt.tween_method(func(f: float): trail.position = origin + dir * r_m * f * 0.9, 0.0, 1.0, 0.7)
	# Beben über die Dauer der Welle
	var tws2 := g.create_tween()
	for k in 8:
		tws2.tween_callback(func(): g.shake_near(origin, 11.0))
		tws2.tween_interval(0.09)


## Gefüllter, weich auslaufender Kegel am Boden (glühender Boden), blendet nach `life` aus
func _cone_glow(origin: Vector3, ang: float, half: float, r_m: float, life: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	for i in segs:
		var a0 := ang - half + 2.0 * half * i / segs
		var a1 := ang - half + 2.0 * half * (i + 1) / segs
		st.set_color(col)
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(col.r, col.g, col.b, col.a * 0.25))
		st.add_vertex(Vector3(sin(a0), 0.0, -cos(a0)) * r_m)
		st.set_color(Color(col.r, col.g, col.b, col.a * 0.25))
		st.add_vertex(Vector3(sin(a1), 0.0, -cos(a1)) * r_m)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	_put(mi, origin + Vector3(0, 0.1, 0), life + 0.1)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 1.0, 0.25)
	tw.tween_interval(0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, life - 0.75)


func _mat_slab() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.16, 0.13)
	m.roughness = 0.95
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.05)
	m.emission_energy_multiplier = 0.08
	return m


func _mat_rock() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.34, 0.28)
	m.roughness = 0.95
	return m


# ================================================================ Damage (Schurke)
## Zweiter Dolch in der linken Hand (Kopie des vorhandenen Dolchs, an der linken Faust befestigt)
func attach_offhand_dagger(fig: Dictionary) -> void:
	if g.test_mode:
		return
	var inner := fig["inner"] as Node
	var skel := inner.find_child("Skeleton3D", true, false) as Skeleton3D
	var src := inner.find_child("Rogue_Dagger", true, false) as MeshInstance3D
	if skel == null or src == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Fist.L"
	skel.add_child(ba)
	var d := MeshInstance3D.new()
	d.mesh = src.mesh
	d.material_override = src.material_override
	d.name = "OffhandDagger"
	var t_old := Transform3D(Basis.from_euler(src.rotation), src.position)
	var t_new := Transform3D(Basis(Vector3.UP, PI)) * t_old
	t_new.origin += Vector3(0.0, 0.11, 0.0)
	d.transform = t_new
	ba.add_child(d)
	fig["offhand"] = d


## Dolch als Effektobjekt: Kopie des Dolch-Meshes aus dem Schurken-Modell (Spitze zeigt nach -Z), um die Mitte zentriert
func _dagger_mesh(scale_f: float) -> Node3D:
	var holder := Node3D.new()
	var info: Variant = g.model_cache.get("rpg/Rogue.gltf", null)
	var src: MeshInstance3D = null
	if info != null and info["root"] != null:
		src = (info["root"] as Node).find_child("Rogue_Dagger", true, false) as MeshInstance3D
	var mi := MeshInstance3D.new()
	if src != null:
		mi.mesh = src.mesh
		mi.position = -src.mesh.get_aabb().get_center() * scale_f
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.03, 0.9)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.75, 0.85)
		m.metallic = 0.9
		m.roughness = 0.3
		mi.material_override = m
	mi.scale = Vector3.ONE * scale_f
	holder.add_child(mi)
	return holder


## Q Wirbel als Dolchfächer: der Schurke dreht sich, ein Kranz Dolche fächert nach allen Seiten bis zum Rand des Wirkungskreises
func dagger_fan(p: Dictionary, radius_units: float, rank: int) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var origin := _w(p["x"], p["y"], side)
	var r_m := radius_units * S
	var n := 8 + rank * 2
	var steel := Color(0.85, 0.92, 1.0)
	_ring_wave(origin, Color(steel.r, steel.g, steel.b, 0.85), r_m, 0.35, 0.12)
	var twr := g.create_tween()
	twr.tween_interval(0.1)
	twr.tween_callback(func(): _ring_wave(origin, Color(1.0, 1.0, 1.0, 0.5), r_m * 0.8, 0.3, 0.14))
	_glow_sprite(Color(1, 1, 1, 0.8), 3.0, 0.16, origin + Vector3(0, 1.2, 0), 1.5)
	_light(Color(0.8, 0.9, 1.0), 2.0, 9.0, 0.3, origin + Vector3(0, 1.5, 0))
	var fig: Dictionary = p.get("fig", {})
	if not fig.is_empty():
		fig["spin"] = 0.35
	for i in n:
		var a := TAU * i / n + 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		var d := _dagger_mesh(0.85)
		var start := origin + Vector3(0, 1.3, 0)
		_put(d, start, 1.6)
		d.basis = Basis.looking_at(dir, Vector3.UP)
		d.visible = false
		var trail := _ps({"amount": 14, "life": 0.22, "local": false, "shape": "sphere", "radius": 0.05, "vmin": 0.0, "vmax": 0.3, "spread": 180.0,
			"smin": 0.18, "smax": 0.32, "curve": _curve([1.0, 0.0]),
			"ramp": _ramp([[0.0, Color(1, 1, 1, 0.9)], [0.5, Color(0.7, 0.85, 1.0, 0.5)], [1.0, Color(0.6, 0.8, 1.0, 0.0)]])})
		trail.emitting = false
		d.add_child(trail)
		var land := origin + dir * r_m * 0.95 + Vector3(0, 0.35, 0)
		var delay := float(i) * 0.012
		var tw := d.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			d.visible = true
			trail.restart())
		tw.tween_method(func(f: float):
			d.position = start.lerp(land, f)
			d.rotate_object_local(Vector3.BACK, 0.5), 0.0, 1.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func():
			trail.emitting = false
			var sp := _ps({"amount": 6, "life": 0.3, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.05, "dir": Vector3.UP, "spread": 120.0,
				"vmin": 1.5, "vmax": 4.0, "smin": 0.05, "smax": 0.11, "grav": Vector3(0, -6.0, 0),
				"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [1.0, Color(0.7, 0.85, 1.0, 0.0)]])})
			_put(sp, land, 0.5))
		tw.tween_interval(0.45)
		tw.tween_property(d, "scale", Vector3.ONE * 0.01, 0.25)


## kleiner Schnitt am Ziel (Autoangriff des Schurken)
func slash_hit(p: Dictionary, tx: float, ty: float) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var pos := _w(tx, ty, side) + Vector3(0, 1.0, 0)
	_slash(pos, Color(1.0, 1.0, 1.0, 1.0), 1.5, rng.randf_range(-40.0, 40.0), 0.14)
	var sp := _ps({"amount": 5, "life": 0.25, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 90.0,
		"vmin": 1.5, "vmax": 4.0, "smin": 0.05, "smax": 0.1, "grav": Vector3(0, -6.0, 0),
		"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [1.0, Color(0.8, 0.9, 1.0, 0.0)]])})
	_put(sp, pos, 0.4)


## Schnittspur: dünner, kamerazugewandter Streifen mit Leuchten, blendet schnell aus. tilt in Grad (Neigung auf dem Bildschirm)
func _slash(pos: Vector3, col: Color, length: float, tilt_deg: float, life: float) -> void:
	var up: Vector3 = g.cam.global_transform.basis.y if g.cam != null else Vector3.UP
	var right: Vector3 = g.cam.global_transform.basis.x if g.cam != null else Vector3.RIGHT
	var dir := (right * cos(deg_to_rad(tilt_deg)) + up * sin(deg_to_rad(tilt_deg))).normalized()
	var pts: Array = []
	for i in 7:
		var f := float(i) / 6.0 - 0.5
		var bend := up * (0.25 * (f * f - 0.1)) * length * 0.3
		pts.append(dir * f * length + bend)
	var holder := Node3D.new()
	var glow := _ribbon(pts, 0.22, Color(col.r, col.g, col.b, 0.55))
	var core := _ribbon(pts, 0.07, Color(1, 1, 1, 1.0))
	holder.add_child(glow)
	holder.add_child(core)
	_put(holder, pos, life + 0.1)
	var tw := holder.create_tween()
	tw.tween_interval(life * 0.5)
	tw.tween_property(holder, "scale", Vector3(1.0, 0.05, 1.0), life * 0.5)


## Flächenschaden der Angriffe (Kampfrausch Rang 5 oder Splitteraxt): sichtbarer Schwung am Hauptziel und Schnitte an den Nebenzielen
func cleave_fx(p: Dictionary, tx: float, ty: float, others: Array, radius_units: float, col: Color) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var center := _w(tx, ty, side)
	_ring_wave(center, Color(col.r, col.g, col.b, 0.85), radius_units * S, 0.4, 0.12)
	for pos2 in others:
		var wp := _w(pos2.x, pos2.y, side) + Vector3(0, 1.0, 0)
		_slash(wp, col, 3.0, 35.0, 0.3)
		_slash(wp, col, 2.4, -35.0, 0.3)
		var sp := _ps({"amount": 6, "life": 0.3, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.1, "dir": Vector3.UP, "spread": 100.0,
			"vmin": 1.5, "vmax": 4.0, "smin": 0.06, "smax": 0.12, "grav": Vector3(0, -6.0, 0),
			"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.4, col], [1.0, Color(col.r, col.g, col.b, 0.0)]])})
		_put(sp, wp, 0.5)


## R Dolchhagel: Warnkreis am Boden (violett)
func dagger_warn(x: float, y: float, side: int, secs: float) -> void:
	if g.test_mode:
		return
	var pos := _w(x, y, side)
	var warn := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	qm.orientation = PlaneMesh.FACE_Y
	warn.mesh = qm
	var wm := _flat_mat(tex_rune, Color(0.7, 0.4, 1.0, 0.0), true)
	warn.material_override = wm
	warn.scale = Vector3(3.2, 1.0, 3.2)
	_put(warn, pos + Vector3(0, 0.12, 0), secs + 0.3)
	var tw := warn.create_tween()
	tw.set_parallel(true)
	tw.tween_property(wm, "albedo_color:a", 0.9, secs * 0.6)
	tw.tween_property(warn, "rotation:y", 2.5, secs + 0.2)
	tw.chain().tween_property(wm, "albedo_color:a", 0.0, 0.25)


## R Dolchhagel: ein Schwall Dolche fällt in einen engen Kreis, bleibt kurz im Boden stecken
func dagger_volley(x: float, y: float, side: int, radius_units: float) -> void:
	if g.test_mode:
		return
	var pos := _w(x, y, side)
	var r_m := radius_units * S
	var n := 9
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r_m * 0.9
		var land := pos + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var dg := _dagger_mesh(0.55)
		var from := land + Vector3(rng.randf_range(-1.0, 1.0), 14.0, rng.randf_range(-1.0, 1.0))
		_put(dg, from, 2.0)
		dg.rotation = Vector3(deg_to_rad(90.0 + rng.randf_range(-12.0, 12.0)), rng.randf() * TAU, 0)
		var delay := float(i) * 0.03
		var tw := dg.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(f: float): dg.position = from.lerp(land + Vector3(0, 0.5, 0), f * f), 0.0, 1.0, 0.16)
		tw.tween_callback(func():
			var sp := _ps({"amount": 5, "life": 0.3, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.08, "dir": Vector3.UP, "spread": 110.0,
				"vmin": 1.5, "vmax": 4.0, "smin": 0.05, "smax": 0.1, "grav": Vector3(0, -6.0, 0),
				"ramp": _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.4, Color(0.8, 0.6, 1.0, 0.8)], [1.0, Color(0.6, 0.4, 1.0, 0.0)]])})
			_put(sp, land, 0.5))
		tw.tween_interval(2.2)
		tw.tween_property(dg, "scale", Vector3.ONE * 0.01, 0.4)
	_ring_wave(pos, Color(0.7, 0.45, 1.0, 0.8), r_m * 1.3, 0.35, 0.12)
	_glow_sprite(Color(0.8, 0.6, 1.0, 0.9), 3.0, 0.18, pos + Vector3(0, 0.6, 0), 1.5)
	_light(Color(0.7, 0.5, 1.0), 2.0, 8.0, 0.3, pos + Vector3(0, 1.0, 0))
	g.shake_near(pos, 2.5)


## W Giftklingen: grüner Giftschein um den Schurken; ab Rang 3 (poison = true) tropfen die Dolche und leuchten grün
func rage_aura(p: Dictionary, secs: float, poison: bool = false) -> void:
	if g.test_mode:
		return
	var node: Node3D = p["node"]
	if node.has_node("RageFx"):
		node.get_node("RageFx").queue_free()
	var holder := Node3D.new()
	holder.name = "RageFx"
	node.add_child(holder)
	var flames := _ps({"amount": 22, "life": 0.9, "add": false, "local": false, "shape": "ring", "radius": 0.8, "height": 0.1,
		"dir": Vector3.UP, "spread": 14.0, "vmin": 0.6, "vmax": 1.6, "smin": 0.9, "smax": 1.6, "grav": Vector3(0, 0.5, 0), "curve": _curve([0.6, 1.0, 0.2]),
		"ramp": _ramp([[0.0, Color(0.45, 0.85, 0.3, 0.0)], [0.2, Color(0.4, 0.8, 0.3, 0.4)], [0.7, Color(0.3, 0.5, 0.3, 0.25)], [1.0, Color(0.2, 0.3, 0.2, 0.0)]])})
	holder.add_child(flames)
	var motes := _ps({"amount": 12, "life": 1.2, "local": false, "shape": "ring", "radius": 0.9, "height": 0.1, "dir": Vector3.UP, "spread": 20.0,
		"vmin": 0.8, "vmax": 2.2, "smin": 0.07, "smax": 0.15, "grav": Vector3(0, 0.3, 0),
		"ramp": _ramp([[0.0, Color(0.7, 1.0, 0.5, 0.0)], [0.2, Color(0.7, 1.0, 0.45, 1.0)], [1.0, Color(0.4, 0.8, 0.3, 0.0)]])})
	holder.add_child(motes)
	var lt := OmniLight3D.new()
	lt.light_color = Color(0.45, 1.0, 0.4)
	lt.light_energy = 1.1
	lt.omni_range = 6.0
	lt.position.y = 1.2
	holder.add_child(lt)
	flickers.append({"node": lt, "base": 1.1, "ph": rng.randf() * 6.0})
	var pos := _w(p["x"], p["y"], p["side"]["idx"])
	_ring_wave(pos, Color(0.45, 1.0, 0.4, 0.85), 4.2, 0.5)
	_glow_sprite(Color(0.5, 1.0, 0.4, 0.9), 3.2, 0.25, pos + Vector3(0, 1.2, 0), 1.5)
	var drips: Array = []
	var restore: Array = []
	if poison:
		var fig: Dictionary = p.get("fig", {})
		var blades: Array = []
		if not fig.is_empty():
			var right := (fig["inner"] as Node).find_child("Rogue_Dagger", true, false) as MeshInstance3D
			if right != null:
				blades.append(right)
			if fig.has("offhand"):
				blades.append(fig["offhand"])
		for b in blades:
			var mi := b as MeshInstance3D
			var drip := _ps({"amount": 10, "life": 0.7, "local": false, "shape": "sphere", "radius": 0.08, "dir": Vector3.DOWN, "spread": 25.0,
				"vmin": 0.2, "vmax": 0.8, "smin": 0.08, "smax": 0.16, "grav": Vector3(0, -6.0, 0),
				"ramp": _ramp([[0.0, Color(0.55, 1.0, 0.4, 0.0)], [0.15, Color(0.55, 1.0, 0.4, 1.0)], [1.0, Color(0.3, 0.7, 0.3, 0.0)]])})
			drip.position = Vector3(0, 0, -0.7)
			mi.add_child(drip)
			var glow := _ps({"amount": 2, "life": 0.35, "local": true, "vmin": 0.0, "vmax": 0.0, "smin": 0.9, "smax": 1.0,
				"ramp": _ramp([[0.0, Color(0.5, 1.0, 0.4, 0.0)], [0.3, Color(0.5, 1.0, 0.4, 0.7)], [1.0, Color(0.5, 1.0, 0.4, 0.0)]])})
			glow.position = Vector3(0, 0, -0.55)
			mi.add_child(glow)
			drips.append(drip)
			drips.append(glow)
			var mat := mi.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:                  # Klinge leuchtet grün, solange das Gift wirkt
				var gm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				gm.emission_enabled = true
				gm.emission = Color(0.3, 1.0, 0.3)
				gm.emission_energy_multiplier = 0.9
				mi.material_override = gm
				restore.append(mi)
	var tw := holder.create_tween()
	tw.tween_interval(maxf(0.2, secs - 0.5))
	tw.tween_callback(func():
		flames.emitting = false
		motes.emitting = false
		lt.light_energy = 0.0
		for dpart in drips:
			if is_instance_valid(dpart):
				(dpart as CPUParticles3D).emitting = false
		for m in restore:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_override = null)
	tw.tween_interval(0.8)
	tw.tween_callback(func():
		for dpart in drips:
			if is_instance_valid(dpart):
				dpart.queue_free()
		holder.queue_free())


## E Sprung: Absprung mit Rauchspur zum Ziel (giftgrüner Rauch entlang der Flugbahn)
func leap_start(p: Dictionary, sx: float, sy: float, tx: float, ty: float) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var a := _w(sx, sy, side)
	var b := _w(tx, ty, side)
	_dust(a + Vector3(0, 0.3, 0), Vector3.UP, 70.0, 3.0, 18, 1.4, 0.6)
	_ring_wave(a, Color(0.5, 0.9, 0.4, 0.6), 2.4, 0.3, 0.1)
	var n := 12
	for i in n:                                          # Rauchwolken entlang der Linie, nacheinander (der Schurke fliegt voraus)
		var f := float(i) / (n - 1)
		var pos := a.lerp(b, f)
		var puff := _ps({"amount": 7, "life": 1.3, "once": true, "explo": 1.0, "add": false, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 50.0,
			"vmin": 0.3, "vmax": 1.2, "smin": 1.2, "smax": 2.2, "grav": Vector3(0, 0.3, 0), "curve": _curve([0.5, 1.0]),
			"ramp": _ramp([[0.0, Color(0.4, 0.75, 0.35, 0.0)], [0.15, Color(0.38, 0.7, 0.33, 0.5)], [0.6, Color(0.28, 0.4, 0.3, 0.35)], [1.0, Color(0.22, 0.28, 0.25, 0.0)]])})
		puff.emitting = false
		_put(puff, pos + Vector3(0, 0.4, 0), 1.6 + f * 0.22)
		var tw := puff.create_tween()
		tw.tween_interval(f * 0.22)
		tw.tween_callback(func(): puff.restart())
	var node: Node3D = p["node"]
	var trail := _ps({"amount": 20, "life": 0.45, "local": false, "shape": "sphere", "radius": 0.3, "vmin": 0.0, "vmax": 0.4, "spread": 180.0,
		"smin": 0.6, "smax": 1.1, "add": false, "curve": _curve([1.0, 0.0]),
		"ramp": _ramp([[0.0, Color(0.35, 0.7, 0.3, 0.6)], [1.0, Color(0.2, 0.3, 0.2, 0.0)]])})
	trail.position.y = 1.2
	node.add_child(trail)
	var tw2 := trail.create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_callback(func(): trail.emitting = false)
	tw2.tween_interval(0.6)
	tw2.tween_callback(func(): trail.queue_free())


## E Sprung: Landung als Giftwolke: Gaspilz, Spritzer, Blasen (keine Risse, kein Feuer); Rang 5: klebrige Verlangsamung
func leap_land(p: Dictionary, radius_units: float, rank: int) -> void:
	if g.test_mode:
		return
	var side: int = p["side"]["idx"]
	var pos := _w(p["x"], p["y"], side)
	var r_m := radius_units * S
	_glow_sprite(Color(0.6, 1.0, 0.45, 1.0), 4.0, 0.2, pos + Vector3(0, 0.6, 0), 1.6)
	_light(Color(0.45, 1.0, 0.4), 2.5, 9.0, 0.4, pos + Vector3(0, 1.0, 0))
	_ring_wave(pos, Color(0.5, 1.0, 0.4, 0.85), r_m, 0.45, 0.12)
	var cloud := _ps({"amount": 46, "life": 1.3, "once": true, "explo": 0.8, "add": false, "shape": "sphere", "radius": 0.5, "dir": Vector3.UP, "spread": 70.0,
		"vmin": 1.5, "vmax": 5.0, "dmin": 1.0, "dmax": 2.5, "smin": 1.6, "smax": 3.0, "grav": Vector3(0, 0.4, 0), "curve": _curve([0.4, 1.0, 0.8]),
		"ramp": _ramp([[0.0, Color(0.45, 0.85, 0.3, 0.0)], [0.12, Color(0.4, 0.8, 0.3, 0.6)], [0.6, Color(0.3, 0.5, 0.3, 0.4)], [1.0, Color(0.2, 0.3, 0.2, 0.0)]])})
	_put(cloud, pos + Vector3(0, 0.3, 0), 1.7)
	var splash := _ps({"amount": 30, "life": 0.8, "once": true, "explo": 1.0, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 65.0,
		"vmin": 3.0, "vmax": 8.0, "smin": 0.12, "smax": 0.28, "grav": Vector3(0, -12.0, 0),
		"ramp": _ramp([[0.0, Color(0.75, 1.0, 0.55, 1.0)], [0.5, Color(0.45, 0.9, 0.35, 0.9)], [1.0, Color(0.3, 0.6, 0.25, 0.0)]])})
	_put(splash, pos + Vector3(0, 0.3, 0), 1.2)
	var bubbles := _ps({"amount": 12, "life": 1.2, "once": true, "explo": 0.6, "shape": "ring", "radius": r_m * 0.6, "height": 0.1, "dir": Vector3.UP, "spread": 10.0,
		"vmin": 0.6, "vmax": 1.6, "smin": 0.18, "smax": 0.34,
		"ramp": _ramp([[0.0, Color(0.7, 1.0, 0.5, 0.0)], [0.2, Color(0.7, 1.0, 0.5, 0.9)], [1.0, Color(0.5, 0.9, 0.4, 0.0)]])})
	_put(bubbles, pos + Vector3(0, 0.2, 0), 1.5)
	for k in 2:                                          # zwei Dolche stoßen links und rechts in den Boden
		var dd := _dagger_mesh(0.6)
		var off := Vector3((-0.7 if k == 0 else 0.7), 0.0, 0.2)
		_put(dd, pos + off + Vector3(0, 3.0, 0), 1.2)
		dd.rotation = Vector3(deg_to_rad(80.0), rng.randf_range(-0.3, 0.3), 0)
		var tw := dd.create_tween()
		tw.tween_property(dd, "position:y", 0.45, 0.1).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.5)
		tw.tween_property(dd, "scale", Vector3.ONE * 0.01, 0.25)
	if rank >= 5:                                        # Verlangsamung: zähe, dunkelgrüne Fäden steigen aus dem Boden
		_ring_wave(pos, Color(0.25, 0.6, 0.25, 0.7), r_m * 1.15, 0.7, 0.1)
	g.shake_near(pos, 3.0 + rank * 0.5)


## Vergiftete Monster: grüne Bläschen steigen auf, solange das Gift wirkt
func poison_mark(u: Dictionary, n: Node3D) -> void:
	var has := n.has_node("Pois")
	if u["pois"] > 0.0 and not has:
		var ps := _ps({"amount": 6, "life": 0.9, "local": true, "shape": "sphere", "radius": 0.35, "dir": Vector3.UP, "spread": 20.0,
			"vmin": 0.6, "vmax": 1.3, "smin": 0.1, "smax": 0.2,
			"ramp": _ramp([[0.0, Color(0.6, 1.0, 0.45, 0.0)], [0.25, Color(0.6, 1.0, 0.45, 0.95)], [1.0, Color(0.35, 0.75, 0.3, 0.0)]])})
		ps.name = "Pois"
		ps.position.y = float(u["r"]) * S * 1.2
		n.add_child(ps)
	elif u["pois"] <= 0.0 and has:
		n.get_node("Pois").queue_free()
