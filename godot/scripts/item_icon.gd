extends Control
## Item-Bildchen, im Code gezeichnet (Prototyp; später durch Blender-Bilder ersetzbar: gibt es res://assets/items/<id>.png, wird die Datei gezeigt).
## id = Item-Kennung, tier = "basis" | "zwischen" | "fertig" (Zwischenstufen bekommen eine kleine Münze, fertige Items einen Funken)

const DRAWN := ["bigSword", "rake", "critCloak", "bigStaff", "cloth", "thornArmor", "windCloak", "timeAmulet", "lifeStone", "regenBand", "ruby", "tome", "wand",
	"bloodGem", "dagger", "spellGem", "coinPouch", "hat", "hatWind", "hatSage", "hatGuard", "hatBlood", "hatTravel", "strongArmor", "thornShirt", "guise", "cutlass",
	"mightyBlade", "arcaneCrown", "thornPlate", "stormBreaker", "timeStaff", "titanPlate", "tormentMask", "ruinBlade", "lifeSpring", "cleaver", "sparkBlade",
	"soulDrinker", "bulwark", "giantsMight", "moonstone", "merchantChain", "potion"]

const STEEL := Color("#cfd8e6")
const STEEL_D := Color("#8da4bf")
const GOLD := Color("#e8c46a")
const WOOD := Color("#8a6a3a")
const RED := Color("#d94a4a")
const GREEN := Color("#4fc36a")
const BLUE := Color("#7fd6ff")
const PURPLE := Color("#a67cff")

var id := ""
var tier := "basis"
var tex: Texture2D


static func has_icon(item_id: String) -> bool:
	return DRAWN.has(item_id) or ResourceLoader.exists("res://assets/items/%s.png" % item_id)


func set_item(item_id: String, item_tier: String) -> void:
	if item_id == id and item_tier == tier:
		return
	id = item_id
	tier = item_tier
	tex = null
	var path := "res://assets/items/%s.png" % id
	if ResourceLoader.exists(path):
		tex = load(path)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/items/%s.png" % id
	if ResourceLoader.exists(path):
		tex = load(path)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * size


func _poly(pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for q in pts:
		v.append(_p(q[0], q[1]))
	draw_colored_polygon(v, col)


func _line(a: Array, b: Array, col: Color, w: float = 2.0) -> void:
	draw_line(_p(a[0], a[1]), _p(b[0], b[1]), col, w * size.x / 56.0, true)


func _circle(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(_p(x, y), r * size.x, col)


func _arc(x: float, y: float, r: float, a0: float, a1: float, col: Color, w: float = 2.0) -> void:
	draw_arc(_p(x, y), r * size.x, deg_to_rad(a0), deg_to_rad(a1), 20, col, w * size.x / 56.0, true)


func _star(x: float, y: float, r: float, col: Color) -> void:
	_poly([[x, y - r], [x + r * 0.28, y - r * 0.28], [x + r, y], [x + r * 0.28, y + r * 0.28], [x, y + r], [x - r * 0.28, y + r * 0.28], [x - r, y], [x - r * 0.28, y - r * 0.28]], col)


func _gem(x: float, y: float, r: float, col: Color) -> void:
	_poly([[x, y - r], [x + r * 0.85, y - r * 0.2], [x + r * 0.5, y + r], [x - r * 0.5, y + r], [x - r * 0.85, y - r * 0.2]], col)
	_poly([[x, y - r], [x + r * 0.85, y - r * 0.2], [x, y - r * 0.1], [x - r * 0.85, y - r * 0.2]], col.lightened(0.35))
	_line([x - r * 0.3, y - r * 0.5], [x - r * 0.1, y - r * 0.7], Color(1, 1, 1, 0.8), 1.5)


func _blade(cx: float, top: float, bottom: float, w: float, col: Color) -> void:
	_poly([[cx, top], [cx + w, bottom - 0.08], [cx, bottom], [cx - w, bottom - 0.08]], col)
	_poly([[cx, top], [cx + w, bottom - 0.08], [cx, bottom]], col.darkened(0.15))
	_line([cx, top + 0.1], [cx, bottom - 0.06], Color(1, 1, 1, 0.55), 1.0)


func _hilt(cx: float, y: float, w: float, len: float) -> void:
	_line([cx - w, y], [cx + w, y], GOLD, 3.5)
	_line([cx, y], [cx, y + len], WOOD, 4.0)
	_circle(cx, y + len + 0.02, 0.035, GOLD)


func _hat_shape(body: Color, brim: Color) -> void:
	_poly([[0.22, 0.58], [0.32, 0.26], [0.5, 0.14], [0.68, 0.26], [0.78, 0.58]], body)
	_poly([[0.5, 0.14], [0.68, 0.26], [0.78, 0.58], [0.5, 0.58]], body.darkened(0.15))
	_poly([[0.08, 0.64], [0.2, 0.56], [0.8, 0.56], [0.92, 0.64], [0.8, 0.72], [0.2, 0.72]], brim)
	_line([0.24, 0.57], [0.76, 0.57], GOLD, 2.5)


func _drop(x: float, y: float, r: float, col: Color) -> void:
	_circle(x, y + r * 0.6, r, col)
	_poly([[x - r * 0.9, y + r * 0.4], [x + r * 0.9, y + r * 0.4], [x, y - r * 1.6]], col)


func _crescent(x: float, y: float, r: float, col: Color) -> void:
	var prev_o := Vector2.ZERO
	var prev_i := Vector2.ZERO
	for k in 25:
		var t := float(k) / 24.0
		var an := deg_to_rad(110.0 + 140.0 * t)
		var po := _p(x + r * cos(an), y + r * sin(an))
		var pin := _p(x + r * 0.35 + r * 0.72 * cos(an), y + r * 0.72 * sin(an))
		var pi_f: Vector2 = po.lerp(pin, sin(PI * t))
		if k > 0:
			draw_colored_polygon(PackedVector2Array([prev_o, po, pi_f, prev_i]), col)
		prev_o = po
		prev_i = pi_f


func _draw() -> void:
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	match id:
		"bigSword":
			_blade(0.5, 0.04, 0.6, 0.13, STEEL)
			_hilt(0.5, 0.62, 0.27, 0.22)
		"bigStaff":
			_line([0.26, 0.92], [0.64, 0.3], WOOD, 5.0)
			_circle(0.7, 0.2, 0.17, PURPLE)
			_circle(0.7, 0.2, 0.08, Color.WHITE)
			_arc(0.7, 0.2, 0.23, 0, 360, BLUE, 1.5)
		"rake":
			_line([0.5, 0.18], [0.5, 0.92], WOOD, 4.0)
			_line([0.22, 0.22], [0.78, 0.22], STEEL, 4.0)
			for x in [0.22, 0.4, 0.6, 0.78]:
				_line([x, 0.22], [x, 0.42], STEEL, 3.0)
		"critCloak":
			_poly([[0.28, 0.14], [0.72, 0.14], [0.84, 0.86], [0.5, 0.72], [0.16, 0.86]], Color("#8f2f3a"))
			_poly([[0.28, 0.14], [0.72, 0.14], [0.66, 0.26], [0.34, 0.26]], Color("#5e1c25"))
			_star(0.5, 0.5, 0.15, GOLD)
		"cloth":
			var cc := Color("#a9b4c6")
			_poly([[0.3, 0.2], [0.42, 0.14], [0.58, 0.14], [0.7, 0.2], [0.88, 0.36], [0.74, 0.48], [0.7, 0.42], [0.7, 0.86], [0.3, 0.86], [0.3, 0.42], [0.26, 0.48], [0.12, 0.36]], cc)
			_line([0.5, 0.14], [0.5, 0.86], cc.darkened(0.25), 1.5)
		"thornArmor":
			_poly([[0.26, 0.2], [0.74, 0.2], [0.74, 0.56], [0.5, 0.86], [0.26, 0.56]], STEEL_D)
			_line([0.5, 0.2], [0.5, 0.86], Color("#5a6f8a"), 1.5)
			for k in [[0.22, 0.2, 0.08, 0.1], [0.78, 0.2, 0.92, 0.1], [0.74, 0.42, 0.92, 0.42], [0.26, 0.42, 0.08, 0.42]]:
				_line([k[0], k[1]], [k[2], k[3]], Color("#dfe6f2"), 3.0)
		"windCloak":
			_poly([[0.28, 0.14], [0.72, 0.14], [0.84, 0.86], [0.5, 0.72], [0.16, 0.86]], Color("#2f7f8f"))
			for k in 3:
				_arc(0.5, 0.36 + 0.14 * k, 0.17 - 0.02 * k, 200, 340, Color("#c8f3ff"), 2.0)
		"timeAmulet":
			_arc(0.5, 0.3, 0.26, 200, 340, GOLD, 2.0)
			_circle(0.5, 0.6, 0.24, GOLD)
			_circle(0.5, 0.6, 0.18, Color("#3b3320"))
			_poly([[0.4, 0.5], [0.6, 0.5], [0.5, 0.6]], BLUE)
			_poly([[0.4, 0.7], [0.6, 0.7], [0.5, 0.6]], BLUE)
		"lifeStone":
			_poly([[0.5, 0.08], [0.82, 0.4], [0.5, 0.92], [0.18, 0.4]], RED)
			_poly([[0.5, 0.08], [0.82, 0.4], [0.5, 0.45], [0.18, 0.4]], RED.lightened(0.3))
			_line([0.34, 0.3], [0.44, 0.2], Color(1, 1, 1, 0.8), 2.0)
		"regenBand":
			_arc(0.5, 0.52, 0.3, 0, 360, GREEN, 6.0)
			_arc(0.5, 0.52, 0.3, 200, 300, GREEN.lightened(0.4), 3.0)
			_line([0.5, 0.4], [0.5, 0.64], Color.WHITE, 3.0)
			_line([0.38, 0.52], [0.62, 0.52], Color.WHITE, 3.0)
		"ruby":
			_gem(0.5, 0.5, 0.3, RED)
		"tome":
			_poly([[0.22, 0.16], [0.78, 0.16], [0.78, 0.82], [0.22, 0.82]], Color("#4a4f9a"))
			_poly([[0.28, 0.2], [0.78, 0.2], [0.78, 0.78], [0.28, 0.78]], Color("#e8e0c8"))
			_poly([[0.22, 0.16], [0.3, 0.16], [0.3, 0.82], [0.22, 0.82]], Color("#35397a"))
			_star(0.54, 0.48, 0.12, PURPLE)
		"wand":
			_line([0.3, 0.86], [0.62, 0.34], Color("#e8e0f0"), 4.0)
			_star(0.66, 0.26, 0.15, GOLD)
		"bloodGem":
			_circle(0.5, 0.58, 0.24, RED)
			_poly([[0.3, 0.52], [0.7, 0.52], [0.5, 0.1]], RED)
			_circle(0.42, 0.52, 0.06, Color(1, 1, 1, 0.6))
		"dagger":
			_blade(0.5, 0.1, 0.62, 0.07, STEEL)
			_hilt(0.5, 0.64, 0.16, 0.18)
		"spellGem":
			_gem(0.5, 0.46, 0.27, PURPLE)
			_circle(0.5, 0.82, 0.07, RED)
			_poly([[0.45, 0.82], [0.55, 0.82], [0.5, 0.72]], RED)
		"coinPouch":
			_poly([[0.34, 0.3], [0.66, 0.3], [0.8, 0.82], [0.2, 0.82]], Color("#8a5a2a"))
			_line([0.34, 0.3], [0.66, 0.3], Color("#5a3a1a"), 3.0)
			_circle(0.5, 0.58, 0.12, GOLD)
			_line([0.5, 0.5], [0.5, 0.66], Color("#8a6a1a"), 2.0)
		"hat":
			_poly([[0.2, 0.58], [0.32, 0.26], [0.5, 0.14], [0.68, 0.26], [0.8, 0.58]], Color("#8a5a2a"))
			_poly([[0.08, 0.62], [0.2, 0.54], [0.8, 0.54], [0.92, 0.62], [0.8, 0.7], [0.2, 0.7]], Color("#a8733a"))
			_line([0.22, 0.56], [0.78, 0.56], GOLD, 2.5)
		"hatWind":
			_hat_shape(Color("#3f8a8f"), Color("#5fb0b4"))
			_poly([[0.66, 0.3], [0.86, 0.06], [0.78, 0.34]], Color("#f2fbff"))
			_arc(0.5, 0.82, 0.3, 200, 340, Color("#c8f3ff"), 2.0)
			_arc(0.5, 0.9, 0.22, 200, 340, Color("#c8f3ff"), 1.5)
		"hatSage":
			_poly([[0.5, 0.04], [0.72, 0.58], [0.28, 0.58]], Color("#5a3f94"))
			_poly([[0.5, 0.04], [0.72, 0.58], [0.5, 0.58]], Color("#473178"))
			_poly([[0.08, 0.64], [0.2, 0.55], [0.8, 0.55], [0.92, 0.64], [0.8, 0.72], [0.2, 0.72]], Color("#7a5ac0"))
			_line([0.3, 0.56], [0.7, 0.56], GOLD, 3.0)
			_star(0.5, 0.34, 0.1, GOLD)
			_star(0.38, 0.46, 0.05, BLUE)
		"hatGuard":
			_poly([[0.2, 0.7], [0.2, 0.42], [0.3, 0.22], [0.5, 0.14], [0.7, 0.22], [0.8, 0.42], [0.8, 0.7]], STEEL_D)
			_poly([[0.5, 0.14], [0.7, 0.22], [0.8, 0.42], [0.8, 0.7], [0.5, 0.7]], Color("#6f86a3"))
			_poly([[0.44, 0.4], [0.56, 0.4], [0.56, 0.78], [0.44, 0.78]], STEEL)
			_poly([[0.26, 0.46], [0.74, 0.46], [0.74, 0.54], [0.26, 0.54]], Color("#1a1d22"))
			_poly([[0.46, 0.12], [0.54, 0.12], [0.6, 0.02], [0.4, 0.02]], RED)
			_line([0.5, 0.16], [0.5, 0.4], Color(1, 1, 1, 0.5), 1.0)
		"hatBlood":
			_hat_shape(Color("#8f2f3a"), Color("#b04050"))
			_drop(0.5, 0.34, 0.07, Color("#ff7a7a"))
		"hatTravel":
			_hat_shape(Color("#5a7a3a"), Color("#7a9a52"))
			_poly([[0.64, 0.3], [0.9, 0.08], [0.82, 0.38]], Color("#f0e6c8"))
			_circle(0.5, 0.42, 0.09, GOLD)
			_line([0.5, 0.34], [0.5, 0.5], Color("#3a2a10"), 1.5)
			_line([0.42, 0.42], [0.58, 0.42], Color("#3a2a10"), 1.5)
		"strongArmor":
			_poly([[0.2, 0.2], [0.8, 0.2], [0.8, 0.58], [0.5, 0.9], [0.2, 0.58]], STEEL_D)
			_poly([[0.5, 0.2], [0.8, 0.2], [0.8, 0.58], [0.5, 0.9]], Color("#6f86a3"))
			_poly([[0.28, 0.28], [0.72, 0.28], [0.72, 0.54], [0.5, 0.78], [0.28, 0.54]], Color("#52627d"))
			_line([0.5, 0.2], [0.5, 0.82], Color(1, 1, 1, 0.4), 1.5)
			for q in [[0.28, 0.26], [0.72, 0.26], [0.5, 0.78]]:
				_circle(q[0], q[1], 0.03, GOLD)
		"thornShirt":
			var tc := Color("#a9b4c6")
			_poly([[0.3, 0.22], [0.42, 0.16], [0.58, 0.16], [0.7, 0.22], [0.86, 0.38], [0.74, 0.48], [0.7, 0.42], [0.7, 0.86], [0.3, 0.86], [0.3, 0.42], [0.26, 0.48], [0.14, 0.38]], tc)
			_line([0.5, 0.16], [0.5, 0.86], tc.darkened(0.25), 1.5)
			for q in [[0.22, 0.34, 0.08, 0.2], [0.78, 0.34, 0.92, 0.2], [0.18, 0.46, 0.04, 0.5], [0.82, 0.46, 0.96, 0.5]]:
				_line([q[0], q[1]], [q[2], q[3]], Color("#eef2f8"), 3.0)
		"guise":
			_poly([[0.2, 0.22], [0.8, 0.22], [0.76, 0.6], [0.5, 0.9], [0.24, 0.6]], Color("#d8d0e8"))
			_poly([[0.5, 0.22], [0.8, 0.22], [0.76, 0.6], [0.5, 0.9]], Color("#b3a8cc"))
			_poly([[0.28, 0.4], [0.44, 0.44], [0.4, 0.54], [0.28, 0.5]], Color("#2a1f40"))
			_poly([[0.72, 0.4], [0.56, 0.44], [0.6, 0.54], [0.72, 0.5]], Color("#2a1f40"))
			_gem(0.5, 0.2, 0.1, RED)
			_line([0.4, 0.72], [0.6, 0.72], Color("#7a6aa0"), 2.0)
		"cutlass":
			_poly([[0.8, 0.08], [0.86, 0.3], [0.74, 0.58], [0.52, 0.74], [0.46, 0.66], [0.64, 0.5], [0.74, 0.28]], STEEL)
			_poly([[0.8, 0.08], [0.86, 0.3], [0.74, 0.58], [0.52, 0.74], [0.64, 0.46]], Color("#aab8cc"))
			_line([0.34, 0.72], [0.56, 0.84], GOLD, 4.0)
			_line([0.46, 0.78], [0.22, 0.92], WOOD, 4.0)
			_drop(0.7, 0.72, 0.05, RED)
		"mightyBlade":
			_blade(0.5, 0.03, 0.62, 0.14, STEEL)
			_poly([[0.5, 0.14], [0.56, 0.3], [0.5, 0.46], [0.44, 0.3]], Color("#e8c46a"))
			_line([0.18, 0.62], [0.82, 0.62], GOLD, 5.0)
			_poly([[0.18, 0.62], [0.1, 0.5], [0.26, 0.6]], GOLD)
			_poly([[0.82, 0.62], [0.9, 0.5], [0.74, 0.6]], GOLD)
			_gem(0.5, 0.64, 0.06, RED)
			_line([0.5, 0.7], [0.5, 0.9], WOOD, 5.0)
			_circle(0.5, 0.93, 0.04, GOLD)
		"arcaneCrown":
			_poly([[0.1, 0.7], [0.1, 0.3], [0.28, 0.5], [0.5, 0.2], [0.72, 0.5], [0.9, 0.3], [0.9, 0.7]], GOLD)
			_poly([[0.1, 0.7], [0.1, 0.3], [0.28, 0.5], [0.5, 0.2], [0.5, 0.7]], GOLD.darkened(0.12))
			_poly([[0.1, 0.7], [0.9, 0.7], [0.9, 0.82], [0.1, 0.82]], Color("#b8892a"))
			_gem(0.5, 0.5, 0.11, PURPLE)
			_circle(0.1, 0.28, 0.05, BLUE)
			_circle(0.9, 0.28, 0.05, BLUE)
			_circle(0.5, 0.17, 0.05, BLUE)
			_line([0.14, 0.76], [0.86, 0.76], Color("#fff3c4"), 1.2)
		"thornPlate":
			_poly([[0.22, 0.2], [0.78, 0.2], [0.82, 0.6], [0.5, 0.92], [0.18, 0.6]], STEEL_D)
			_poly([[0.5, 0.2], [0.78, 0.2], [0.82, 0.6], [0.5, 0.92]], Color("#6f86a3"))
			_poly([[0.3, 0.3], [0.7, 0.3], [0.7, 0.56], [0.5, 0.8], [0.3, 0.56]], Color("#52627d"))
			_poly([[0.5, 0.36], [0.58, 0.54], [0.5, 0.7], [0.42, 0.54]], GOLD)
			for q in [[0.2, 0.22, 0.04, 0.08], [0.8, 0.22, 0.96, 0.08], [0.16, 0.44, 0.0, 0.46], [0.84, 0.44, 1.0, 0.46], [0.2, 0.62, 0.06, 0.74], [0.8, 0.62, 0.94, 0.74]]:
				_line([q[0], q[1]], [q[2], q[3]], Color("#eef2f8"), 3.5)
		"stormBreaker":
			_poly([[0.58, 0.04], [0.28, 0.5], [0.48, 0.5], [0.36, 0.96], [0.82, 0.38], [0.58, 0.38], [0.72, 0.04]], Color("#ffe066"))
			_poly([[0.58, 0.14], [0.4, 0.48], [0.52, 0.48], [0.46, 0.76], [0.66, 0.42], [0.54, 0.42], [0.62, 0.14]], Color("#fff8d0"))
			_poly([[0.12, 0.88], [0.2, 0.36], [0.5, 0.06], [0.34, 0.5], [0.32, 0.84]], STEEL)
			_line([0.08, 0.84], [0.34, 0.9], GOLD, 4.0)
		"timeStaff":
			_line([0.3, 0.94], [0.62, 0.36], WOOD, 5.0)
			_circle(0.68, 0.26, 0.2, Color("#2a2060"))
			_arc(0.68, 0.26, 0.2, 0, 360, PURPLE, 2.0)
			_poly([[0.58, 0.14], [0.78, 0.14], [0.68, 0.26]], BLUE)
			_poly([[0.58, 0.38], [0.78, 0.38], [0.68, 0.26]], BLUE)
			_line([0.56, 0.14], [0.8, 0.14], GOLD, 2.0)
			_line([0.56, 0.38], [0.8, 0.38], GOLD, 2.0)
		"titanPlate":
			_poly([[0.14, 0.26], [0.34, 0.14], [0.66, 0.14], [0.86, 0.26], [0.84, 0.5], [0.7, 0.46], [0.7, 0.9], [0.3, 0.9], [0.3, 0.46], [0.16, 0.5]], STEEL_D)
			_poly([[0.5, 0.14], [0.66, 0.14], [0.86, 0.26], [0.84, 0.5], [0.7, 0.46], [0.7, 0.9], [0.5, 0.9]], Color("#6f86a3"))
			_circle(0.5, 0.5, 0.11, GREEN)
			_circle(0.5, 0.5, 0.05, Color("#d8ffe0"))
			_line([0.3, 0.74], [0.7, 0.74], GOLD, 3.0)
			_arc(0.5, 0.5, 0.2, 0, 360, Color(0.4, 0.9, 0.5, 0.6), 1.5)
		"tormentMask":
			_poly([[0.2, 0.2], [0.8, 0.2], [0.78, 0.6], [0.5, 0.9], [0.22, 0.6]], Color("#3a2f5a"))
			_poly([[0.5, 0.2], [0.8, 0.2], [0.78, 0.6], [0.5, 0.9]], Color("#2a2144"))
			_poly([[0.28, 0.4], [0.44, 0.46], [0.38, 0.56], [0.28, 0.5]], Color("#ff9a3a"))
			_poly([[0.72, 0.4], [0.56, 0.46], [0.62, 0.56], [0.72, 0.5]], Color("#ff9a3a"))
			_poly([[0.28, 0.4], [0.3, 0.18], [0.36, 0.34]], Color("#ff6a2a"))
			_poly([[0.72, 0.4], [0.7, 0.18], [0.64, 0.34]], Color("#ff6a2a"))
			_line([0.4, 0.74], [0.6, 0.74], Color("#8a6ac0"), 2.0)
			_poly([[0.2, 0.2], [0.14, 0.04], [0.32, 0.2]], Color("#8a6ac0"))
			_poly([[0.8, 0.2], [0.86, 0.04], [0.68, 0.2]], Color("#8a6ac0"))
		"ruinBlade":
			_blade(0.5, 0.03, 0.6, 0.12, Color("#6a2a38"))
			_line([0.5, 0.12], [0.5, 0.56], Color("#ff5a6a"), 1.5)
			_poly([[0.2, 0.62], [0.3, 0.52], [0.4, 0.62], [0.5, 0.5], [0.6, 0.62], [0.7, 0.52], [0.8, 0.62], [0.8, 0.7], [0.2, 0.7]], GOLD)
			_gem(0.5, 0.58, 0.05, RED)
			_line([0.5, 0.72], [0.5, 0.92], WOOD, 5.0)
			_drop(0.82, 0.34, 0.06, RED)
		"lifeSpring":
			_poly([[0.22, 0.2], [0.78, 0.2], [0.82, 0.6], [0.5, 0.92], [0.18, 0.6]], Color("#4a9a5a"))
			_poly([[0.5, 0.2], [0.78, 0.2], [0.82, 0.6], [0.5, 0.92]], Color("#357a44"))
			_circle(0.43, 0.44, 0.09, RED)
			_circle(0.57, 0.44, 0.09, RED)
			_poly([[0.34, 0.48], [0.66, 0.48], [0.5, 0.72]], RED)
			_arc(0.5, 0.5, 0.36, 0, 360, Color(0.6, 1.0, 0.7, 0.55), 1.5)
			_line([0.18, 0.2], [0.82, 0.2], GOLD, 3.0)
		"cleaver":
			_line([0.5, 0.12], [0.5, 0.94], WOOD, 5.0)
			_poly([[0.5, 0.14], [0.86, 0.1], [0.92, 0.3], [0.86, 0.5], [0.5, 0.46]], STEEL)
			_poly([[0.5, 0.14], [0.14, 0.1], [0.08, 0.3], [0.14, 0.5], [0.5, 0.46]], STEEL_D)
			_line([0.54, 0.2], [0.84, 0.2], Color(1, 1, 1, 0.6), 1.5)
			_circle(0.5, 0.3, 0.05, GOLD)
		"sparkBlade":
			_blade(0.44, 0.06, 0.64, 0.09, STEEL)
			_hilt(0.44, 0.66, 0.17, 0.2)
			_poly([[0.78, 0.1], [0.62, 0.42], [0.74, 0.42], [0.66, 0.74], [0.9, 0.34], [0.76, 0.34], [0.86, 0.1]], Color("#7fd6ff"))
			_star(0.2, 0.26, 0.07, Color("#e8f8ff"))
			_star(0.88, 0.6, 0.06, Color("#e8f8ff"))
		"soulDrinker":
			_poly([[0.24, 0.2], [0.76, 0.2], [0.7, 0.5], [0.58, 0.64], [0.42, 0.64], [0.3, 0.5]], Color("#c9a24a"))
			_poly([[0.28, 0.24], [0.72, 0.24], [0.68, 0.44], [0.32, 0.44]], Color("#b3263a"))
			_line([0.5, 0.64], [0.5, 0.82], Color("#c9a24a"), 4.0)
			_poly([[0.3, 0.86], [0.7, 0.86], [0.64, 0.78], [0.36, 0.78]], Color("#c9a24a"))
			_arc(0.5, 0.1, 0.12, 200, 340, Color("#d8c8ff"), 2.0)
			_circle(0.38, 0.08, 0.03, Color("#d8c8ff"))
			_circle(0.62, 0.08, 0.03, Color("#d8c8ff"))
		"bulwark":
			_circle(0.5, 0.5, 0.4, STEEL_D)
			_circle(0.5, 0.5, 0.33, Color("#52627d"))
			_arc(0.5, 0.5, 0.4, 0, 360, GOLD, 3.0)
			_line([0.5, 0.18], [0.5, 0.82], STEEL, 4.0)
			_line([0.18, 0.5], [0.82, 0.5], STEEL, 4.0)
			_circle(0.5, 0.5, 0.1, GOLD)
			_circle(0.5, 0.5, 0.05, Color("#fff3c4"))
		"giantsMight":
			_poly([[0.26, 0.5], [0.74, 0.5], [0.72, 0.88], [0.28, 0.88]], Color("#c98a5a"))
			for k in 4:
				_circle(0.31 + 0.13 * k, 0.4, 0.07, Color("#e0a672"))
			_poly([[0.7, 0.58], [0.9, 0.42], [0.94, 0.54], [0.72, 0.72]], Color("#e0a672"))
			_line([0.26, 0.82], [0.74, 0.82], GOLD, 4.0)
			_poly([[0.5, 0.08], [0.58, 0.24], [0.42, 0.24]], RED)
			_arc(0.5, 0.5, 0.42, 200, 340, Color(1.0, 0.6, 0.4, 0.6), 2.0)
		"moonstone":
			_crescent(0.5, 0.48, 0.34, Color("#e8f0ff"))
			_gem(0.64, 0.62, 0.15, Color("#6fe0a0"))
			_circle(0.2, 0.2, 0.03, Color("#fff3c4"))
			_circle(0.84, 0.2, 0.025, Color("#fff3c4"))
		"merchantChain":
			for k in 8:
				var an := PI * (0.15 + 0.7 * k / 7.0)
				_circle(0.5 + 0.34 * cos(an), 0.16 + 0.42 * sin(an), 0.06, GOLD)
				_circle(0.5 + 0.34 * cos(an), 0.16 + 0.42 * sin(an), 0.03, Color("#4a3a10"))
			_circle(0.5, 0.74, 0.17, GOLD)
			_circle(0.5, 0.74, 0.12, Color("#c9a24a"))
			_line([0.5, 0.65], [0.5, 0.83], Color("#8a6a1a"), 2.5)
			_line([0.43, 0.7], [0.57, 0.7], Color("#8a6a1a"), 2.0)
		"potion":
			_circle(0.5, 0.64, 0.27, RED)
			_poly([[0.42, 0.2], [0.58, 0.2], [0.6, 0.48], [0.4, 0.48]], Color("#cfe8f0"))
			_poly([[0.4, 0.46], [0.6, 0.46], [0.5, 0.6]], RED)
			_poly([[0.4, 0.1], [0.6, 0.1], [0.58, 0.22], [0.42, 0.22]], WOOD)
			_circle(0.4, 0.58, 0.06, Color(1, 1, 1, 0.55))
	if tier == "zwischen":
		_circle(0.86, 0.14, 0.09, GOLD)
		_circle(0.86, 0.14, 0.05, Color("#8a6a1a"))
	elif tier == "fertig":
		_star(0.85, 0.15, 0.13, Color("#ffe066"))
