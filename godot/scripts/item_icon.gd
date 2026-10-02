extends Control
## Item-Bildchen, im Code gezeichnet (Prototyp; später durch Blender-Bilder ersetzbar: gibt es res://assets/items/<id>.png, wird die Datei gezeigt).
## id = Item-Kennung, tier = "basis" | "zwischen" | "fertig" (Zwischenstufen bekommen eine kleine Münze, fertige Items einen Funken)

const DRAWN := ["sword", "armor", "heart", "gloves", "staff", "bigSword", "rake", "critCloak", "bigStaff", "cloth", "thornArmor", "windCloak", "timeAmulet",
	"lifeStone", "regenBand", "ruby", "tome", "wand", "bloodGem", "dagger", "spellGem", "coinPouch", "hat"]

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


func _draw() -> void:
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	match id:
		"sword":
			_blade(0.5, 0.08, 0.62, 0.08, STEEL)
			_hilt(0.5, 0.64, 0.2, 0.2)
		"bigSword":
			_blade(0.5, 0.04, 0.6, 0.13, STEEL)
			_hilt(0.5, 0.62, 0.27, 0.22)
		"armor":
			_poly([[0.22, 0.16], [0.78, 0.16], [0.78, 0.55], [0.5, 0.88], [0.22, 0.55]], STEEL_D)
			_poly([[0.3, 0.24], [0.7, 0.24], [0.7, 0.52], [0.5, 0.78], [0.3, 0.52]], Color("#52627d"))
			_line([0.5, 0.24], [0.5, 0.78], STEEL_D, 1.5)
		"heart":
			_circle(0.37, 0.38, 0.19, RED)
			_circle(0.63, 0.38, 0.19, RED)
			_poly([[0.19, 0.46], [0.81, 0.46], [0.5, 0.86]], RED)
			_circle(0.33, 0.33, 0.05, Color(1, 1, 1, 0.55))
		"gloves":
			var gc := Color("#e0a63e")
			_poly([[0.28, 0.5], [0.72, 0.5], [0.7, 0.84], [0.3, 0.84]], gc)
			for k in 4:
				_poly([[0.28 + 0.11 * k, 0.52], [0.37 + 0.11 * k, 0.52], [0.37 + 0.11 * k, 0.22 + (0.0 if k in [1, 2] else 0.06)], [0.28 + 0.11 * k, 0.22 + (0.0 if k in [1, 2] else 0.06)]], gc.lightened(0.12))
			_poly([[0.7, 0.62], [0.88, 0.5], [0.9, 0.6], [0.72, 0.74]], gc.lightened(0.12))
			_line([0.3, 0.8], [0.7, 0.8], Color("#7a5a1a"), 3.0)
		"staff":
			_line([0.3, 0.9], [0.66, 0.26], WOOD, 4.0)
			_circle(0.7, 0.2, 0.12, PURPLE)
			_circle(0.7, 0.2, 0.05, Color.WHITE)
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
	if tier == "zwischen":
		_circle(0.86, 0.14, 0.09, GOLD)
		_circle(0.86, 0.14, 0.05, Color("#8a6a1a"))
	elif tier == "fertig":
		_star(0.85, 0.15, 0.13, Color("#ffe066"))
