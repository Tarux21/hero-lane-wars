extends RefCounted
## Einstellungen des Spielers (Optionen): Ton, Grafik, Kamera, Anzeige, Tastenbelegung, Hinweise, Barrierefreiheit.
## Liegt in user://settings.cfg (zusammen mit Anzeigemodus und Bildschirmwackeln, die game.gd verwaltet). Zugriff überall über Data.user.

const FILE := "user://settings.cfg"

## Tastenbelegung: [Aktion, Beschriftung, Standardtaste]
const KEY_DEFS := [
	["q", "Fähigkeit Q", KEY_Q], ["w", "Fähigkeit W", KEY_W], ["e", "Fähigkeit E", KEY_E], ["r", "Fähigkeit R", KEY_R],
	["backport", "Backport", KEY_B], ["potion", "Heiltrank", KEY_F], ["shop", "Shop öffnen", KEY_TAB], ["stop", "Stopp", KEY_S], ["pause", "Pause", KEY_P],
	["send_grunt", "Senden: Grunt", KEY_Z], ["send_tank", "Senden: Brocken", KEY_X], ["send_archer", "Senden: Schütze", KEY_C],
	["send_fast", "Senden: Läufer", KEY_V], ["send_elite", "Senden: Elite", KEY_N],
]

var volume := 0.4
var mute := false
var gfx := 2                       # 0 niedrig, 1 mittel, 2 hoch
var fps_cap := 0                   # 0 = unbegrenzt
var vsync := true
var ui_scale := 1.0
var show_fps := false
var hp_numbers := false
var cam_speed := 1.0
var edge_scroll := false
var alt_always := false
var colorblind := false
var keys: Dictionary = {}          # Aktion -> Tastencode


func _init() -> void:
	reset_keys()
	load_all()


func reset_keys() -> void:
	keys.clear()
	for d in KEY_DEFS:
		keys[d[0]] = int(d[2])


func key_of(action: String) -> int:
	return int(keys.get(action, 0))


## Name der Taste für Anzeigen ("Q", "Tab" ...)
func key_name(action: String) -> String:
	var k := key_of(action)
	return OS.get_keycode_string(k) if k != 0 else "–"


func action_for_key(code: int) -> String:
	for a in keys:
		if int(keys[a]) == code:
			return a
	return ""


func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(FILE) != OK:
		return
	volume = clampf(float(cf.get_value("sound", "volume", volume)), 0.0, 1.0)
	mute = bool(cf.get_value("sound", "mute", mute))
	gfx = clampi(int(cf.get_value("graphics", "quality", gfx)), 0, 2)
	fps_cap = int(cf.get_value("graphics", "fps_cap", fps_cap))
	vsync = bool(cf.get_value("graphics", "vsync", vsync))
	ui_scale = clampf(float(cf.get_value("display", "ui_scale", ui_scale)), 0.8, 1.4)
	show_fps = bool(cf.get_value("display", "show_fps", show_fps))
	hp_numbers = bool(cf.get_value("display", "hp_numbers", hp_numbers))
	cam_speed = clampf(float(cf.get_value("camera", "speed", cam_speed)), 0.4, 2.5)
	edge_scroll = bool(cf.get_value("camera", "edge_scroll", edge_scroll))
	alt_always = bool(cf.get_value("hints", "alt_always", alt_always))
	colorblind = bool(cf.get_value("access", "colorblind", colorblind))
	for d in KEY_DEFS:
		keys[d[0]] = int(cf.get_value("keys", d[0], d[2]))


func save() -> void:
	var cf := ConfigFile.new()
	cf.load(FILE)                      # Anzeigemodus und Wackeln stehen ebenfalls in dieser Datei: erhalten
	cf.set_value("sound", "volume", volume)
	cf.set_value("sound", "mute", mute)
	cf.set_value("graphics", "quality", gfx)
	cf.set_value("graphics", "fps_cap", fps_cap)
	cf.set_value("graphics", "vsync", vsync)
	cf.set_value("display", "ui_scale", ui_scale)
	cf.set_value("display", "show_fps", show_fps)
	cf.set_value("display", "hp_numbers", hp_numbers)
	cf.set_value("camera", "speed", cam_speed)
	cf.set_value("camera", "edge_scroll", edge_scroll)
	cf.set_value("hints", "alt_always", alt_always)
	cf.set_value("access", "colorblind", colorblind)
	for a in keys:
		cf.set_value("keys", a, int(keys[a]))
	cf.save(FILE)


## Faktoren der Grafikqualität (Partikelmenge, Effektlichter)
func particle_factor() -> float:
	return [0.35, 0.65, 1.0][gfx]


func light_factor() -> float:
	return [0.0, 0.6, 1.0][gfx]


## Farben der Lebensbalken (normal / Farbenblind-Modus: Blau und Orange statt Grün und Rot)
func hp_good() -> Color:
	return Color("#3fa0ff") if colorblind else Color("#4cd964")


func hp_bad() -> Color:
	return Color("#ffb020") if colorblind else Color("#ff4d3d")


func hp_enemy() -> Color:
	return Color("#ff9a1f") if colorblind else Color("#e0453a")
