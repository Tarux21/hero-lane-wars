extends Control
## Fähigkeiten-Bildchen, im Code gezeichnet (keine Bilddateien): jede Fähigkeit hat ein kleines Symbol, das andeutet, was sie tut.
## kind: shock, ironskin, shieldthrow, quake, daggerfan, poisonblade, leap, daggerhail, firefield, frostcone, chain, elemental,
##       class_tank, class_damage, class_caster

var kind := "shock"
var plate := Color("#2b2a28")
var round_look := false              # rund (Heldenbild): Kreis statt Quadrat, Zeichnung etwas kleiner
var ring := Color("#b49a5c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * size


func _poly(pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for q in pts:
		v.append(_p(q[0], q[1]))
	draw_colored_polygon(v, col)


func _line(a: Array, b: Array, col: Color, w: float = 2.0) -> void:
	draw_line(_p(a[0], a[1]), _p(b[0], b[1]), col, w * size.x / 64.0, true)


func _circle(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(_p(x, y), r * size.x, col)


## ein Dolch von der Mitte (cx, cy) in Richtung ang (rad, 0 = nach oben), Länge len
func _dagger(cx: float, cy: float, ang: float, len: float, col: Color, handle: Color) -> void:
	var d := Vector2(sin(ang), -cos(ang))
	var n := Vector2(-d.y, d.x)
	var base := Vector2(cx, cy)
	var tip := base + d * len
	var w := 0.055
	_poly([[(base + n * w).x, (base + n * w).y], [(base - n * w).x, (base - n * w).y], [tip.x, tip.y]], col)
	var guard1 := base - d * 0.02 + n * 0.1
	var guard2 := base - d * 0.02 - n * 0.1
	_line([guard1.x, guard1.y], [guard2.x, guard2.y], handle, 3.0)
	var hend := base - d * 0.14
	_line([base.x, base.y], [hend.x, hend.y], handle, 4.0)


func _draw() -> void:
	if round_look:
		draw_circle(size / 2.0, size.x / 2.0, plate)
		draw_set_transform(size * 0.14, 0.0, Vector2(0.72, 0.72))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), plate)
	match kind:
		"shock":
			var gold := Color("#e8c46a")
			for k in 3:
				draw_arc(_p(0.5, 0.92), (0.28 + 0.2 * k) * size.x, deg_to_rad(-135.0), deg_to_rad(-45.0), 18, gold, (3.0 - k * 0.5) * size.x / 64.0, true)
			_poly([[0.42, 0.9], [0.58, 0.9], [0.55, 0.72], [0.45, 0.72]], Color("#c9ccd4"))
			_line([0.5, 0.5], [0.5, 0.64], Color("#f6e7b4"), 3.0)
		"ironskin":
			var steel := Color("#9fb0c8")
			_poly([[0.24, 0.2], [0.76, 0.2], [0.76, 0.55], [0.5, 0.88], [0.24, 0.55]], steel)
			_poly([[0.3, 0.26], [0.7, 0.26], [0.7, 0.52], [0.5, 0.78], [0.3, 0.52]], Color("#52627d"))
			_line([0.5, 0.26], [0.5, 0.78], steel, 2.0)
			_line([0.3, 0.46], [0.7, 0.46], steel, 2.0)
			for x in [0.3, 0.5, 0.7]:
				_poly([[x - 0.05, 0.2], [x + 0.05, 0.2], [x, 0.08]], Color("#dfe6f2"))
		"shieldthrow":
			_circle(0.62, 0.42, 0.22, Color("#8fa0bb"))
			_circle(0.62, 0.42, 0.15, Color("#46526b"))
			_line([0.62, 0.3], [0.62, 0.54], Color("#e8c46a"), 2.5)
			_line([0.5, 0.42], [0.74, 0.42], Color("#e8c46a"), 2.5)
			draw_arc(_p(0.35, 0.8), 0.4 * size.x, deg_to_rad(-150.0), deg_to_rad(-60.0), 14, Color("#e8c46a"), 2.0 * size.x / 64.0, true)
			_poly([[0.58, 0.58], [0.7, 0.55], [0.64, 0.68]], Color("#e8c46a"))
		"quake":
			var rock := Color("#a98b66")
			_line([0.1, 0.62], [0.3, 0.55], Color("#2a1f14"), 4.0)
			_line([0.3, 0.55], [0.42, 0.7], Color("#2a1f14"), 4.0)
			_line([0.42, 0.7], [0.58, 0.5], Color("#2a1f14"), 4.0)
			_line([0.58, 0.5], [0.72, 0.68], Color("#2a1f14"), 4.0)
			_line([0.72, 0.68], [0.9, 0.52], Color("#2a1f14"), 4.0)
			_line([0.3, 0.55], [0.42, 0.7], Color("#ff7a2a"), 1.5)
			_line([0.58, 0.5], [0.72, 0.68], Color("#ff7a2a"), 1.5)
			_poly([[0.2, 0.5], [0.3, 0.3], [0.4, 0.5]], rock)
			_poly([[0.44, 0.46], [0.56, 0.2], [0.68, 0.46]], rock)
			_poly([[0.7, 0.5], [0.8, 0.34], [0.9, 0.5]], rock)
		"daggerfan":
			for k in 5:
				_dagger(0.5, 0.84, deg_to_rad(-60.0 + 30.0 * k), 0.62, Color("#e4ecf7"), Color("#7a6240"))
		"poisonblade":
			_dagger(0.38, 0.8, deg_to_rad(28.0), 0.66, Color("#dfe8f4"), Color("#7a6240"))
			var gr := Color("#7ee05a")
			_circle(0.68, 0.46, 0.06, gr)
			_poly([[0.64, 0.46], [0.72, 0.46], [0.68, 0.34]], gr)
			_circle(0.76, 0.7, 0.05, gr)
			_poly([[0.72, 0.7], [0.8, 0.7], [0.76, 0.6]], gr)
			_circle(0.6, 0.84, 0.04, gr)
		"leap":
			draw_arc(_p(0.46, 0.86), 0.42 * size.x, deg_to_rad(-170.0), deg_to_rad(-20.0), 20, Color("#cfe9bf"), 3.0 * size.x / 64.0, true)
			_poly([[0.78, 0.5], [0.9, 0.62], [0.72, 0.66]], Color("#cfe9bf"))
			var sm := Color(0.45, 0.78, 0.4, 0.8)
			_circle(0.14, 0.84, 0.09, sm)
			_circle(0.26, 0.9, 0.08, sm)
			_circle(0.2, 0.74, 0.07, sm)
			_circle(0.1, 0.72, 0.05, sm)
		"daggerhail":
			for x in [0.24, 0.5, 0.76]:
				_dagger(x, 0.14, deg_to_rad(180.0), 0.5, Color("#e4ecf7"), Color("#7a6240"))
			draw_circle(_p(0.5, 0.88), 0.28 * size.x, Color(0.45, 0.78, 0.4, 0.55))
			_circle(0.38, 0.86, 0.05, Color("#a6f080"))
			_circle(0.6, 0.9, 0.04, Color("#a6f080"))
		"firefield":
			_poly([[0.5, 0.1], [0.68, 0.38], [0.8, 0.6], [0.7, 0.86], [0.3, 0.86], [0.2, 0.6], [0.34, 0.4], [0.42, 0.26]], Color("#ff7a2a"))
			_poly([[0.5, 0.36], [0.62, 0.58], [0.58, 0.82], [0.42, 0.82], [0.38, 0.6]], Color("#ffd166"))
			_poly([[0.5, 0.56], [0.55, 0.7], [0.5, 0.82], [0.45, 0.7]], Color("#fff3c4"))
		"frostcone":
			var ice := Color("#b8e8ff")
			for k in 3:
				var a := PI * k / 3.0
				var d := Vector2(cos(a), sin(a)) * 0.36
				_line([0.5 - d.x, 0.5 - d.y], [0.5 + d.x, 0.5 + d.y], ice, 3.0)
				for s in [-1.0, 1.0]:
					var pt: Vector2 = Vector2(0.5, 0.5) + d * 0.65 * float(s)
					var perp: Vector2 = Vector2(-sin(a), cos(a)) * 0.08
					_line([pt.x, pt.y], [pt.x + perp.x + d.x * 0.18 * s, pt.y + perp.y + d.y * 0.18 * s], ice, 2.0)
					_line([pt.x, pt.y], [pt.x - perp.x + d.x * 0.18 * s, pt.y - perp.y + d.y * 0.18 * s], ice, 2.0)
			_circle(0.5, 0.5, 0.05, Color("#ffffff"))
		"chain":
			_poly([[0.58, 0.06], [0.26, 0.52], [0.46, 0.52], [0.36, 0.94], [0.76, 0.4], [0.54, 0.4], [0.66, 0.06]], Color("#ffe066"))
			_poly([[0.58, 0.18], [0.4, 0.5], [0.52, 0.5], [0.46, 0.76], [0.64, 0.42], [0.5, 0.42], [0.6, 0.18]], Color("#fff8d0"))
		"elemental":
			draw_arc(_p(0.5, 0.5), 0.3 * size.x, 0.0, TAU, 28, Color("#c8c4ff"), 1.5 * size.x / 64.0, true)
			_circle(0.5, 0.2, 0.12, Color("#ff7a2a"))
			_circle(0.76, 0.66, 0.12, Color("#8fd8ff"))
			_circle(0.24, 0.66, 0.12, Color("#ffe066"))
			_circle(0.5, 0.2, 0.05, Color("#ffe9b0"))
			_circle(0.76, 0.66, 0.05, Color("#e8f8ff"))
			_circle(0.24, 0.66, 0.05, Color("#fffbd0"))
		"class_tank":
			_poly([[0.24, 0.16], [0.76, 0.16], [0.76, 0.56], [0.5, 0.9], [0.24, 0.56]], Color("#9fb0c8"))
			_poly([[0.32, 0.24], [0.68, 0.24], [0.68, 0.54], [0.5, 0.8], [0.32, 0.54]], Color("#5a3d8a"))
			_circle(0.5, 0.42, 0.07, Color("#8aff8a"))
		"class_damage":
			_dagger(0.3, 0.86, deg_to_rad(35.0), 0.7, Color("#e4ecf7"), Color("#7a6240"))
			_dagger(0.7, 0.86, deg_to_rad(-35.0), 0.7, Color("#e4ecf7"), Color("#7a6240"))
		"class_caster":
			_line([0.34, 0.9], [0.62, 0.28], Color("#8a6a3a"), 4.0)
			_circle(0.66, 0.2, 0.13, Color("#7fd6ff"))
			_circle(0.66, 0.2, 0.06, Color("#ffffff"))
			_circle(0.66, 0.2, 0.18, Color(0.5, 0.85, 1.0, 0.25))
	if round_look:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(size / 2.0, size.x / 2.0 - 2.0, 0.0, TAU, 40, ring, 4.0, true)
