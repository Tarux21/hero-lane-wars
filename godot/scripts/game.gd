extends Node3D
## Hero Lane Wars, Godot-Version. Stand: erster spielbarer Ausschnitt (Meilenstein 1).
## Enthalten: Kamera von schräg oben, Held (Rechtsklick), automatische Angriffe, Monsterwellen, Level, Gold/Einkommen, Lebensverlust.
## Noch NICHT enthalten: Skills, Shop/Items, Gegner-Bot und seine Lane, Boss-Fähigkeiten, Sounds, echte 3D-Figuren.
## Alle Spielwerte stammen aus data/daten.json (Autoload "Data"). Spielkoordinaten (x = Lane entlang, y = quer) werden mit S in Meter umgerechnet.

const S := 0.05                      # Spielwert -> Meter (Lane 3000 -> 150 m)
const WALL := 3.2                    # Breite der Felswand zwischen/neben Lanes (Meter)
const TEAM_SPACE := 28.0             # Abstand zwischen den Lane-Rändern der beiden Teams (Felswand, Gras, Fluss, Felswand)
# Durchgänge in der Wand zwischen den beiden Lanes eines Teams (4v4): Weg-Bereiche [von, bis] in Spielwerten. Die Basis (x < 300) ist offen.
const WALL_GAPS := [[800.0, 960.0], [1500.0, 1660.0], [2200.0, 2360.0], [2800.0, 2960.0]]
const WALL_OPEN_BASE := 300.0
const CAM_PITCH := 58.0              # Kamerawinkel in Grad (wie Warcraft 3: schräg von oben)
var cam_dist := 28.0                 # Kamera-Abstand zum Helden (Mausrad)

var cfg: Dictionary
var t := 0.0
var gold: float
var income: float
var lives: int
var wave := 0
var wave_t: float
var income_t := 0.0
var over := false
var hero_key := "damage"
var hero: Dictionary = {}
var units: Array = []
var texts: Array = []                # schwebende Zahlen
var kills := 0
var autoplay := false
var cam_init := false

# Kartenaufbau je Spielerzahl pro Team (--team=1|2|4): bis 2 Spieler teilen sich eine breite Lane, ab 4 gibt es pro Team eine Doppel-Lane.
var team_size := 1
var lanes_per_team := 1
var lane_half_g := 90.0              # halbe Lane-Breite in Spielwerten
var lane_xs: Array[float] = []       # Mitte jeder Lane in Metern, von links nach rechts: erst Team A, dann Team B
var slot_ys: Array[float] = []       # Spieler-Plätze quer in der Lane (Spielwerte)
var lane_off_g: Array[float] = []    # Quer-Mitte jeder Lane deines Teams in Spielwerten (Lane 1 = 0, Lane 2 = Abstand)

var cam: Camera3D
var hud: Label
var msg: Label
var started := false
var trace := false
var menu_shot := ""
var menu_layer: CanvasLayer


func _ready() -> void:
	cfg = Data.cfg
	var sim_secs := 0.0
	var shot_path := ""
	var direct := false                  # Kommandozeile gibt Modus vor: Menü überspringen
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			hero_key = a.substr(7)
		elif a.begins_with("--sim="):
			sim_secs = float(a.substr(6))
			direct = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--team="):
			team_size = int(a.substr(7))
			direct = true
		elif a.begins_with("--zoom="):
			cam_dist = float(a.substr(7))
		elif a == "--autoplay":
			autoplay = true
		elif a == "--trace":
			trace = true
		elif a.begins_with("--menushot="):
			menu_shot = a.substr(11)
	if direct:
		_start_game()
		if sim_secs > 0.0:
			set_process(false)   # Testmodus: nur der Simulationslauf rechnet
			_run_simulation(sim_secs, shot_path)
	else:
		_show_menu()
		if menu_shot != "":               # Test: Menü-Bild speichern und beenden
			for i in 5:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(menu_shot)
			get_tree().quit()


## Startet eine Partie mit dem gewählten Modus (team_size) und Helden (hero_key).
func _start_game() -> void:
	gold = cfg["startGold"]
	income = cfg["baseIncome"]
	lives = int(cfg["startLives"])
	wave_t = cfg["firstWave"]
	_setup_layout()
	_build_world()
	_build_hud()
	_spawn_hero()
	started = true


## Startmenü: Spielmodus (1v1, 2v2, 4v4) und Held wählen.
func _show_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	var bg := ColorRect.new()
	bg.color = Color("#10131a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "HERO LANE WARS"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_menu_row("Spielmodus", [["1 gegen 1", 1], ["2 gegen 2", 2], ["4 gegen 4", 4]], team_size, func(v): team_size = v))
	var hero_opts := []
	for k in ["tank", "damage", "caster"]:
		hero_opts.append([str(Data.heroes[k]["name"]), k])
	box.add_child(_menu_row("Held", hero_opts, hero_key, func(v): hero_key = v))
	var info := Label.new()
	info.text = "1 gegen 1: je eine Lane pro Spieler   |   2 gegen 2: eine breite Lane pro Team\n4 gegen 4: Doppel-Lane pro Team (zwischen den Lanes könnt ihr wechseln und aushelfen)"
	info.modulate = Color("#9aa3b5")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var go := Button.new()
	go.text = "Spiel starten"
	go.custom_minimum_size = Vector2(260, 54)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(func():
		menu_layer.queue_free()
		_start_game())
	box.add_child(go)


## Eine Zeile mit Auswahl-Knöpfen (nur einer aktiv). opts = [[Beschriftung, Wert], ...]
func _menu_row(label: String, opts: Array, current: Variant, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var group := ButtonGroup.new()
	for o in opts:
		var b := Button.new()
		b.text = o[0]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(130, 44)
		b.button_pressed = (o[1] == current)
		var val: Variant = o[1]
		b.pressed.connect(func(): on_pick.call(val))
		row.add_child(b)
	return row


# ---------------------------------------------------------------- Koordinaten
## Spielkoordinaten -> Welt: Die Lane läuft senkrecht über den Bildschirm (Basis unten, Monster kommen von oben).
## x = Weg entlang der Lane (0 = Basis), y = quer über alle Lanes deines Teams (Lane 1 hat die Mitte y = 0).
func _wp(gx: float, gy: float) -> Vector3:
	return Vector3(gy * S + lane_xs[0], 0.0, -gx * S)


## Berechnet Lane-Breite, Lane-Mitten und Spieler-Plätze aus der Teamgröße.
func _setup_layout() -> void:
	team_size = clampi(team_size, 1, 4)
	lanes_per_team = 2 if team_size >= 4 else 1
	var per_lane := int(ceil(float(team_size) / lanes_per_team))
	lane_half_g = float(cfg["laneHalf"]) * (1.2 if per_lane <= 1 else 1.95)   # 2 Helden pro Lane brauchen eine breitere Lane
	var half := lane_half_g * S
	lane_xs.clear()
	var x := 0.0
	for team in 2:
		for k in lanes_per_team:
			lane_xs.append(x)
			if k < lanes_per_team - 1:
				x += half * 2.0 + WALL          # Lanes desselben Teams teilen sich eine Felswand
		x += half * 2.0 + TEAM_SPACE            # zwischen den Teams: Felswände, Gras, Fluss
	slot_ys.clear()
	for j in per_lane:
		slot_ys.append((j - (per_lane - 1) / 2.0) * (2.0 * lane_half_g / per_lane))
	lane_off_g.clear()
	for k in lanes_per_team:
		lane_off_g.append((lane_xs[k] - lane_xs[0]) / S)


func _cam_offset() -> Vector3:
	var p := deg_to_rad(CAM_PITCH)
	return Vector3(0.0, sin(p) * cam_dist, cos(p) * cam_dist)


# ---------------------------------------------------------------- Aufbau
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a3a22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9c2cc")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	_build_map()

	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 500
	add_child(cam)


## Karte im Stil von Warcraft-3-Hero-Line-Wars: zwei Lanes nebeneinander, dazwischen Felswände und ein Fluss,
## unten ein Platz mit magischem Kreis, Häusern (Monster senden) und Händlern. Alles noch aus einfachen Formen (Platzhalter).
func _build_map() -> void:
	var lane_len: float = cfg["laneLen"] * S
	var half: float = lane_half_g * S
	var n := lane_xs.size()
	var x_min: float = lane_xs[0] - half - WALL
	var x_max: float = lane_xs[n - 1] + half + WALL
	var mid_x := (lane_xs[0] + lane_xs[n - 1]) / 2.0
	var span := x_max - x_min
	var z_far := -lane_len - 10.0
	var z_mid := (z_far + 14.0) / 2.0
	var z_len := 14.0 - z_far
	_box(Vector3(mid_x, -0.5, z_mid), Vector3(span + 120.0, 1.0, z_len + 30.0), Color("#4b6b30"))            # Gras
	for i in n:
		var cx: float = lane_xs[i]
		var k := i % lanes_per_team
		_box(Vector3(cx, -0.04, z_mid + 4.0), Vector3(half * 2.0, 0.1, z_len - 8.0), Color("#a89462"))       # Lane (Sandweg)
		_box(Vector3(cx, 0.02, z_mid + 4.0), Vector3(half * 0.5, 0.06, z_len - 8.0), Color("#8d7d55"))       # Pflasterstreifen in der Mitte
		var sides: Array = [1.0] if k > 0 else [-1.0, 1.0]   # Lanes desselben Teams teilen sich eine Wand (nur rechts bauen)
		for side in sides:
			var wall_x: float = cx + side * (half + WALL / 2.0)
			if lanes_per_team == 2 and k == 0 and side > 0.0:
				_gapped_wall(wall_x)                                  # gemeinsame Wand mit Durchgängen (Helden können die Lane wechseln)
			else:
				_box(Vector3(wall_x, 1.1, z_mid - 6.0), Vector3(WALL, 2.4, lane_len + 2.0), Color("#4c4f55"))   # Felswand
				_box(Vector3(wall_x, 2.45, z_mid - 6.0), Vector3(WALL - 1.0, 0.5, lane_len + 2.0), Color("#5f636b"))
	var river_x: float = (lane_xs[lanes_per_team - 1] + lane_xs[lanes_per_team]) / 2.0
	_box(Vector3(river_x, -0.06, z_mid - 6.0), Vector3(5.0, 0.2, lane_len + 2.0), Color("#1f5fa8"))           # Fluss zwischen den Teams
	var spawn_z := -float(cfg["spawnX"]) * S
	for i in n:
		_box(Vector3(lane_xs[i], 0.03, spawn_z - 2.0), Vector3(half * 2.0, 0.06, 6.0), Color("#6e2a2a"))     # Monster-Spawn
	# Platz am unteren Ende (Basis): Pflaster, magischer Kreis, Feuerstellen
	var plaza_z := 7.0
	var plaza_r := span / 2.0 + 6.0
	var plaza := _cyl(Vector3(mid_x, -0.02, plaza_z), plaza_r, 0.1, Color("#8b8272"))
	plaza.scale = Vector3(1.0, 1.0, minf(1.0, 13.0 / plaza_r))
	_cyl(Vector3(mid_x, 0.06, plaza_z), 4.2, 0.05, Color("#2a3a7a"), Color("#4a7aff"))                         # magischer Kreis
	_cyl(Vector3(mid_x, 0.1, plaza_z), 2.4, 0.06, Color("#3b3f48"))
	for fx in [-1.0, 1.0]:
		var fire_x: float = mid_x + fx * (plaza_r * 0.5)
		_cyl(Vector3(fire_x, 0.1, plaza_z - 2.0), 1.3, 0.2, Color("#4c4f55"))
		_cyl(Vector3(fire_x, 0.5, plaza_z - 2.0), 0.5, 0.8, Color("#ff7a2a"), Color("#ff5a10"))               # Feuer
	# Je Spieler-Platz: 4 Häuser (Monster senden); je Lane zwei Händler-Sockel (Items)
	for i in n:
		for sy in slot_ys:
			var slot_x: float = lane_xs[i] + sy * S
			for h in 4:
				_house(Vector3(slot_x + (h - 1.5) * 2.5, 0.0, plaza_z + 5.0))
		for sx in [-1.0, 1.0]:
			_cyl(Vector3(lane_xs[i] + sx * (half - 1.5), 0.2, plaza_z - 1.0), 1.1, 0.4, Color("#6d6558"))     # Händler-Sockel
	# Bäume außerhalb der Lanes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var zz := 12.0
	while zz > z_far:
		for side in [-1.0, 1.0]:
			var tx: float = (x_min - 14.0 - rng.randf() * 12.0) if side < 0.0 else (x_max + 14.0 + rng.randf() * 12.0)
			_tree(Vector3(tx, 0.0, zz + rng.randf() * 4.0), 0.8 + rng.randf() * 0.7)
		zz -= 7.0


## Wand zwischen den beiden Lanes eines Teams: Stücke zwischen den Durchgängen (WALL_GAPS), an den Durchgängen Torpfosten.
## Die Basis (x < WALL_OPEN_BASE) ist offen.
func _gapped_wall(wall_x: float) -> void:
	var cursor := WALL_OPEN_BASE
	var end_x := float(cfg["laneLen"]) + 50.0
	_sand_piece(wall_x, -200.0, WALL_OPEN_BASE)                      # offene Basis: Sandweg statt Wand
	for g in WALL_GAPS:
		_sand_piece(wall_x, g[0], g[1])
		_wall_piece(wall_x, cursor, g[0])
		_box(Vector3(wall_x, 1.6, -g[0] * S), Vector3(WALL + 0.6, 3.2, 0.9), Color("#6a6e76"))       # Torpfosten
		_box(Vector3(wall_x, 1.6, -g[1] * S), Vector3(WALL + 0.6, 3.2, 0.9), Color("#6a6e76"))
		cursor = g[1]
	_wall_piece(wall_x, cursor, end_x)


func _sand_piece(wall_x: float, x0: float, x1: float) -> void:
	_box(Vector3(wall_x, -0.04, -(x0 + x1) / 2.0 * S), Vector3(WALL + 0.2, 0.1, (x1 - x0) * S), Color("#a89462"))


func _wall_piece(wall_x: float, x0: float, x1: float) -> void:
	if x1 <= x0:
		return
	var zc := -(x0 + x1) / 2.0 * S
	var len := (x1 - x0) * S
	_box(Vector3(wall_x, 1.1, zc), Vector3(WALL, 2.4, len), Color("#4c4f55"))
	_box(Vector3(wall_x, 2.45, zc), Vector3(WALL - 1.0, 0.5, len), Color("#5f636b"))


func _cyl(pos: Vector3, radius: float, height: float, col: Color, glow: Color = Color(0, 0, 0, 0)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	m.mesh = c
	m.position = pos
	var mat := _mat(col)
	if glow.a > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.2
	m.material_override = mat
	add_child(m)
	return m


func _house(pos: Vector3) -> void:
	_box(pos + Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 2.6), Color("#b9955a"))                       # Wände
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(3.2, 1.4, 3.0)
	roof.mesh = pm
	roof.position = pos + Vector3(0, 2.7, 0)
	roof.material_override = _mat(Color("#7a4a2a"))
	add_child(roof)


func _tree(pos: Vector3, s: float) -> void:
	_cyl(pos + Vector3(0, 0.8 * s, 0), 0.25 * s, 1.6 * s, Color("#5a3d22"))
	for k in 3:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = (1.7 - k * 0.4) * s
		cm.height = 2.0 * s
		cone.mesh = cm
		cone.position = pos + Vector3(0, (2.0 + k * 1.3) * s, 0)
		cone.material_override = _mat(Color("#23512a"))
		add_child(cone)


func _box(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = _mat(col)
	add_child(m)
	return m


func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(14, 10)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)
	msg = Label.new()
	msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg.position = Vector2(-120, 80)
	msg.add_theme_font_size_override("font_size", 40)
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	msg.add_theme_constant_override("outline_size", 8)
	layer.add_child(msg)


func _label3d(text: String, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


func _spawn_hero() -> void:
	var d: Dictionary = Data.heroes[hero_key]
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.6
	cap.height = 2.0
	body.mesh = cap
	body.position.y = 1.0
	body.material_override = _mat(Color.html(d["col"]))
	node.add_child(body)
	var lab := _label3d("", 36, Color("#7be07b"))
	lab.position.y = 2.7
	node.add_child(lab)
	add_child(node)
	hero = {"d": d, "x": 120.0, "y": slot_ys[0], "lvl": 1, "xp": 0.0, "hp": float(d["hp"]), "dead": 0.0,
		"atk_t": 0.0, "target": null, "move_to": null, "deaths": 0, "node": node, "label": lab}


# ---------------------------------------------------------------- Formeln (wie im Browser-Prototyp)
func _reduce(dmg: float, armor: float) -> float:
	return dmg * (1.0 - armor / (armor + float(cfg["armorK"])))


func _hero_max_hp() -> float:
	return float(hero["d"]["hp"]) + float(hero["d"]["hpl"]) * (hero["lvl"] - 1)


func _hero_dmg() -> float:
	return float(hero["d"]["dmg"]) + float(hero["d"]["dpl"]) * (hero["lvl"] - 1)


func _hero_armor() -> float:
	return float(hero["d"]["armor"]) + float(hero["d"]["armorl"]) * (hero["lvl"] - 1)


func _xp_need(l: int) -> float:
	return float(cfg["xpBase"]) + float(cfg["xpPer"]) * l


func _hp_mult() -> float:
	return 1.0 + (t / 60.0) * float(cfg["hpScalePerMin"])


func _in_base() -> bool:
	return hero["x"] < float(cfg["baseX"]) and hero["dead"] <= 0.0


# ---------------------------------------------------------------- Einheiten und Wellen
func _spawn_unit(type: String, off_x: float, spd_mul: float, lane: int = 0) -> void:
	var u: Dictionary = Data.units[type]
	var m := _hp_mult()
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = float(u["r"]) * S
	sph.height = sph.radius * 2.0
	body.mesh = sph
	body.position.y = sph.radius
	body.material_override = _mat(Color.html(u["col"]))
	node.add_child(body)
	add_child(node)
	var ly: float = lane_half_g - 16.0
	units.append({"type": type, "lane": lane, "x": float(cfg["spawnX"]) + off_x + randf() * 30.0, "y": lane_off_g[lane] + (randf() * 2.0 - 1.0) * ly,
		"hp": float(u["hp"]) * m, "max": float(u["hp"]) * m,
		"dmg": float(u["dmg"]) * (1.0 + float(cfg["unitDmgScale"]) * (m - 1.0)),
		"spd": float(u["spd"]) * spd_mul * float(cfg["speedMul"]), "range": float(u["range"]),
		"armor": float(u["armor"]), "r": float(u["r"]), "atk_t": 0.0, "node": node, "def": u})


func _spawn_wave() -> void:
	wave += 1
	var n := wave
	var count := int(round(float(cfg["waveBase"]) + float(cfg["wavePer"]) * n))
	var from_x: float = minf(float(cfg["spawnX"]), float(cfg["rampStart"]) + float(cfg["rampStep"]) * (n - 1))
	var base_off := from_x - float(cfg["spawnX"])
	for lane in lanes_per_team:          # jede Lane deines Teams bekommt die Welle
		for i in count:
			_spawn_unit("grunt", base_off + i * 4.0, float(cfg["waveSpeedMul"]), lane)
		if n % int(cfg["eliteEvery"]) == 0:
			for k in int(cfg["eliteCount"]):
				_spawn_unit("elite", base_off + count * 4.0 + 30.0 + k * 40.0, float(cfg["waveSpeedMul"]), lane)
		if n == int(cfg["bossWave"]):
			_spawn_unit("boss", base_off + count * 4.0 + 160.0, float(cfg["waveSpeedMul"]), lane)
	_flash_msg("Welle %d" % n)


func _flash_msg(text: String) -> void:
	msg.text = text
	get_tree().create_timer(1.5).timeout.connect(func(): if msg.text == text: msg.text = "")


func _kill_unit(u: Dictionary) -> void:
	units.erase(u)
	u["node"].queue_free()
	kills += 1
	var def: Dictionary = u["def"]
	gold += float(def["gold"]) if def.has("gold") else float(cfg["killGold"])
	_gain_xp(float(def["xp"]))


func _gain_xp(n: float) -> void:
	hero["xp"] += n
	while hero["lvl"] < int(cfg["maxLevel"]) and hero["xp"] >= _xp_need(hero["lvl"]):
		hero["xp"] -= _xp_need(hero["lvl"])
		hero["lvl"] += 1
		hero["hp"] += float(hero["d"]["hpl"])
		_float_text("LEVEL %d" % hero["lvl"], _wp(hero["x"], hero["y"]) + Vector3(0, 3.2, 0), Color("#ffd166"), 48, 1.2)


func _float_text(text: String, pos: Vector3, col: Color, size: int, life: float) -> void:
	var l := _label3d(text, size, col)
	l.position = pos
	add_child(l)
	texts.append({"node": l, "t": life})


func _hit_unit(u: Dictionary, dmg: float) -> void:
	var d := _reduce(dmg, u["armor"])
	u["hp"] -= d
	_float_text(str(int(round(d))), _wp(u["x"], u["y"]) + Vector3(0, 1.8, 0), Color.WHITE, 30, 0.5)
	if u["hp"] <= 0.0:
		_kill_unit(u)


func _damage_hero(dmg: float) -> void:
	if hero["dead"] > 0.0:
		return
	var eff := _reduce(dmg, _hero_armor())
	hero["hp"] -= eff
	_float_text("-" + str(int(round(eff))), _wp(hero["x"], hero["y"]) + Vector3(0, 3.0, 0), Color("#ff6b6b"), 30, 0.6)
	if hero["hp"] <= 0.0:
		hero["hp"] = 0.0
		hero["deaths"] += 1
		hero["dead"] = float(cfg["respawnBase"]) + float(cfg["respawnPerLevel"]) * hero["lvl"]
		hero["target"] = null
		hero["move_to"] = null


# ---------------------------------------------------------------- Spielschritt
func step(dt: float) -> void:
	if over:
		return
	t += dt
	# Einkommen und Wellen
	income_t += dt
	if income_t >= float(cfg["incomeTick"]):
		income_t -= float(cfg["incomeTick"])
		gold += income
	wave_t -= dt
	if wave_t <= 0.0:
		_spawn_wave()
		wave_t = float(cfg["earlyWaveEvery"]) if wave <= int(cfg["earlyWaves"]) else float(cfg["waveEvery"])
	_step_hero(dt)
	_step_units(dt)
	if lives <= 0:
		over = true
		msg.text = "NIEDERLAGE"


func _step_hero(dt: float) -> void:
	if hero["dead"] > 0.0:
		hero["dead"] -= dt
		if hero["dead"] <= 0.0:
			hero["dead"] = 0.0
			hero["hp"] = _hero_max_hp()
			hero["x"] = 120.0
			hero["y"] = slot_ys[0]
		return
	var mx := _hero_max_hp()
	var regen: float = mx * 0.12 if _in_base() else 1.5 + hero["lvl"] * 0.3
	hero["hp"] = minf(mx, hero["hp"] + regen * dt)
	if autoplay:
		_autoplay_choose()
	# Ziel gültig? Bewegungsziel bestimmen
	if hero["target"] != null and not units.has(hero["target"]):
		hero["target"] = null
	var goal: Variant = null
	var range_: float = float(hero["d"]["range"])
	if hero["target"] != null:
		var tg: Dictionary = hero["target"]
		if Vector2(tg["x"] - hero["x"], tg["y"] - hero["y"]).length() > range_ + tg["r"]:
			goal = Vector2(tg["x"], tg["y"])
	elif hero["move_to"] != null:
		goal = hero["move_to"]
	var old_y: float = hero["y"]
	if goal != null:
		goal = _route(goal)              # bei Doppel-Lane: über einen Durchgang zur anderen Lane laufen
		var dv: Vector2 = goal - Vector2(hero["x"], hero["y"])
		var d := dv.length()
		if d < 4.0:
			if hero["target"] == null:
				hero["move_to"] = null
		else:
			var step_len := minf(d, float(hero["d"]["spd"]) * dt)
			hero["x"] += dv.x / d * step_len
			hero["y"] += dv.y / d * step_len
	hero["x"] = clampf(hero["x"], 20.0, float(cfg["laneLen"]))
	hero["y"] = _clamp_y(hero["x"], hero["y"], old_y)
	# Auto-Angriff: auch im Laufen, sobald ein Gegner in Reichweite ist
	hero["atk_t"] -= dt
	var tgt: Variant = hero["target"]
	if tgt == null:
		var best := 1e9
		for u in units:
			var dd := Vector2(u["x"] - hero["x"], u["y"] - hero["y"]).length()
			if dd <= range_ + u["r"] and dd < best:
				best = dd
				tgt = u
	if tgt != null and Vector2(tgt["x"] - hero["x"], tgt["y"] - hero["y"]).length() <= range_ + tgt["r"] and hero["atk_t"] <= 0.0:
		hero["atk_t"] = 1.0 / float(hero["d"]["as"])
		_hit_unit(tgt, _hero_dmg())


## Doppel-Lane (4v4): Quer-Bereich, den der Held betreten darf. Die Wand zwischen den Lanes ist nur an den Durchgängen und in der Basis offen.
func _in_gap(x: float) -> bool:
	if x < WALL_OPEN_BASE:
		return true
	for g in WALL_GAPS:
		if x >= g[0] and x <= g[1]:
			return true
	return false


func _clamp_y(x: float, y: float, old_y: float) -> float:
	var ly := lane_half_g - 10.0
	y = clampf(y, -ly, lane_off_g[lanes_per_team - 1] + ly)
	if lanes_per_team == 2 and not _in_gap(x):
		var lo := lane_half_g - 10.0
		var hi: float = lane_off_g[1] - lane_half_g + 10.0
		if y > lo and y < hi:
			y = lo if old_y <= (lo + hi) / 2.0 else hi
	return y


## Liegt das Ziel auf der anderen Lane, läuft der Held zuerst zum nächsten Durchgang (oder durch die offene Basis).
func _route(goal: Vector2) -> Vector2:
	if lanes_per_team < 2:
		return goal
	var mid: float = (lane_off_g[0] + lane_off_g[1]) / 2.0
	if (hero["y"] < mid) == (goal.y < mid):
		return goal
	var best_x := 150.0
	var best_c: float = absf(hero["x"] - 150.0) + absf(goal.x - 150.0)
	for g in WALL_GAPS:
		var cx: float = (g[0] + g[1]) / 2.0
		var c: float = absf(hero["x"] - cx) + absf(goal.x - cx)
		if c < best_c:
			best_c = c
			best_x = cx
	if best_x > WALL_OPEN_BASE and absf(hero["x"] - best_x) > 40.0:
		return Vector2(best_x, hero["y"])      # erst in der eigenen Lane bis auf Höhe des Durchgangs laufen
	var lo := lane_half_g - 10.0               # Wandbereich quer
	var hi: float = lane_off_g[1] - lane_half_g + 10.0
	return Vector2(best_x, hi + 10.0 if goal.y >= mid else lo - 10.0)   # quer durch den Durchgang bis auf die andere Seite


func _autoplay_choose() -> void:
	# Nur für Tests (--autoplay): Held geht zum vordersten Monster, sonst nach vorn
	var best: Variant = null
	var bx := 1e9
	for u in units:
		if u["x"] < bx:
			bx = u["x"]
			best = u
	hero["target"] = best
	hero["move_to"] = null if best != null else Vector2(700, 0)


func _step_units(dt: float) -> void:
	for u in units.duplicate():
		if not units.has(u):
			continue
		u["atk_t"] -= dt
		var engaged := false
		if hero["dead"] <= 0.0 and Vector2(u["x"] - hero["x"], u["y"] - hero["y"]).length() <= u["range"] + 14.0:
			engaged = true
			if u["atk_t"] <= 0.0:
				u["atk_t"] = 1.0
				_damage_hero(u["dmg"])
		if not engaged:
			var step_len: float = u["spd"] * dt
			var dx := -1.0
			var dy := 0.0
			if hero["dead"] <= 0.0 and u["type"] != "fast":
				var hx: float = hero["x"] - u["x"]
				var hy: float = hero["y"] - u["y"]
				var dist := maxf(1.0, sqrt(hx * hx + hy * hy))
				if dist <= (float(cfg["aggroRange"]) if hx <= 40.0 else float(cfg["aggroBehind"])):
					dx = hx / dist
					dy = hy / dist
			u["x"] += dx * step_len
			var ly: float = lane_half_g - 16.0
			var off: float = lane_off_g[u["lane"]]
			u["y"] = clampf(u["y"] + dy * step_len, off - ly, off + ly)
		if u["x"] <= float(cfg["leakX"]):
			lives -= int(u["def"]["lives"])
			units.erase(u)
			u["node"].queue_free()


# ---------------------------------------------------------------- Darstellung und Eingabe
func _process(delta: float) -> void:
	if not started:
		return
	step(delta)
	_sync_visuals(delta)


func _sync_visuals(delta: float) -> void:
	var hn: Node3D = hero["node"]
	hn.visible = hero["dead"] <= 0.0
	hn.position = _wp(hero["x"], hero["y"])
	var lab: Label3D = hero["label"]
	lab.text = "%d / %d" % [int(hero["hp"]), int(_hero_max_hp())]
	for u in units:
		var n: Node3D = u["node"]
		n.position = _wp(u["x"], u["y"])
	for f in texts.duplicate():
		f["t"] -= delta
		f["node"].position.y += 1.5 * delta
		if f["t"] <= 0.0:
			f["node"].queue_free()
			texts.erase(f)
	var off := _cam_offset()
	var want := hn.position + off
	cam.position = want if not cam_init else cam.position.lerp(want, minf(1.0, delta * 6.0))
	cam_init = true
	cam.look_at(cam.position - off)
	var min_t := int(t) / 60
	hud.text = "Gold %d   Einkommen +%.0f / %ds   Leben %d   Welle %d   Zeit %d:%02d\nLevel %d   XP %d / %d   HP %d / %d   Kills %d   %s" % [
		int(gold), income, int(cfg["incomeTick"]), lives, wave, min_t, int(t) % 60,
		hero["lvl"], int(hero["xp"]), int(_xp_need(hero["lvl"])), int(hero["hp"]), int(_hero_max_hp()), kills,
		"[Held tot: %ds]" % int(ceil(hero["dead"])) if hero["dead"] > 0.0 else ("[in der Basis]" if _in_base() else "")]


func _ground_point(screen_pos: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return Vector3.ZERO
	return o + d * (-o.y / d.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:   # Mausrad: Kamera näher/weiter weg
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 2.0, 14.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 2.0, 14.0, 50.0)
	if not started or over or hero["dead"] > 0.0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var p := _ground_point(event.position)
		var gx := -p.z / S
		var gy := (p.x - lane_xs[0]) / S
		var hit: Variant = null
		var best := 1e9
		for u in units:
			var dd := Vector2(u["x"] - gx, u["y"] - gy).length()
			if dd <= u["r"] + 14.0 and dd < best:
				best = dd
				hit = u
		if hit != null:
			hero["target"] = hit
			hero["move_to"] = null
		else:
			hero["target"] = null
			var ly: float = lane_half_g - 10.0
			hero["move_to"] = Vector2(maxf(20.0, gx), clampf(gy, -ly, lane_off_g[lanes_per_team - 1] + ly))


# ---------------------------------------------------------------- Test-Simulation (Kommandozeile)
func _run_simulation(secs: float, shot_path: String) -> void:
	var steps := int(secs / 0.05)
	for i in steps:
		step(0.05)
		if trace and i % 100 == 0:   # alle 5 Sekunden: Position des Helden und Ziel (für Fehlersuche)
			var tg: Variant = hero["target"]
			print("t=%.0f Held x=%.0f y=%.0f | Ziel: %s | Einheiten %d" % [t, hero["x"], hero["y"],
				"-" if tg == null else "x=%.0f y=%.0f lane=%d" % [tg["x"], tg["y"], tg["lane"]], units.size()])
	print("SIM %.0f s | Welle %d | Leben %d | Gold %d | Level %d | Kills %d | Tode %d | Einheiten %d" % [
		secs, wave, lives, int(gold), hero["lvl"], kills, hero["deaths"], units.size()])
	if shot_path != "":
		_sync_visuals(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("Screenshot: ", shot_path)
	get_tree().quit()
