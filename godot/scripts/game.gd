extends Node3D
## Hero Lane Wars, Godot-Version. Stand: erster spielbarer Ausschnitt (Meilenstein 1).
## Enthalten: Kamera von schräg oben, Held (Rechtsklick), automatische Angriffe, Monsterwellen, Level, Gold/Einkommen, Lebensverlust.
## Noch NICHT enthalten: Skills, Shop/Items, Gegner-Bot und seine Lane, Boss-Fähigkeiten, Sounds, echte 3D-Figuren.
## Alle Spielwerte stammen aus data/daten.json (Autoload "Data"). Spielkoordinaten (x = Lane entlang, y = quer) werden mit S in Meter umgerechnet.

const S := 0.05                      # Spielwert -> Meter (Lane 3000 -> 150 m)
const WALL := 3.2                    # Breite der Felswand zwischen/neben Lanes (Meter)
const TEAM_SPACE := 28.0             # Abstand zwischen den Lane-Rändern der beiden Teams (Felswand, Gras, Fluss, Felswand)
const WALL_OPEN_BASE := 300.0        # bis hierhin (Spielwerte) ist die Basis offen: nur dort kommt man zur anderen Lane des Teams
const SkillsLib := preload("res://scripts/skills.gd")
const GoldenRunner := preload("res://scripts/golden_runner.gd")
const MINI_W := 290.0                # Größe der Minimap (Pixel)
const MINI_H := 270.0
const ENEMY_LANE_VIEW := 700.0       # Gegner-Lane auf der Minimap: nur dieser Abschnitt (Spielwerte) bei deren Basis
const CAM_PITCH := 58.0             # Kamerawinkel in Grad (wie Warcraft 3: schräg von oben)
var cam_dist := 28.0                 # Kamera-Abstand zum Helden (Mausrad)

var cfg: Dictionary
var t := 0.0
var team_lives: Array[int] = [20, 20]    # Leben je Team (gemeinsam): [dein Team, Gegner-Team]
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
var autoplay_skills := false          # Test: Der Test-Held nutzt Skills (--skills)
var test_mode := false                # Tests ohne Grafik: keine Knoten für Effekte, Zahlen und Monster
var rand_fixed := -1.0                 # Tests: fester Zufallswert (>= 0)
var deterministic := false            # Tests: kein Zufall (keine Krits, feste Auswahl, feste Startpositionen)
var skills: SkillsLib                # Skill-Logik (skills.gd)
var zones: Array = []                 # Schadensfelder am Boden
var timers: Array = []                # zeitverzögerte Skill-Effekte
var elems: Array = []                 # Caster-Elementare
var fx_list: Array = []               # Skill-Effekte (Ringe, Kegel, Linien), blenden aus
var skillbar: Array = []              # Oberfläche: die 4 Skill-Plätze
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
var selftest := false
var golden := false                   # Szenario-Runner (Vergleich mit dem Prototyp)
var golden_filter := ""
var menu_shot := ""
var mini: Control                    # Minimap
var life_labels: Array[Label3D] = [] # Lebensanzeige über den Team-Kristallen
var team_mid_y := 0.0                # Quer-Mitte deines Teams (Spielwerte); bei 4v4 laufen die Lanes hier zusammen
var cam_free := false                # Kamera vom Helden gelöst (nach Klick auf die Minimap), Leertaste = zurück zum Helden
var cam_focus := Vector3.ZERO
var menu_layer: CanvasLayer


func _ready() -> void:
	cfg = Data.cfg
	skills = SkillsLib.new(self)
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
		elif a == "--skills":
			autoplay_skills = true
		elif a == "--golden":
			golden = true
			direct = true
		elif a.begins_with("--golden="):
			golden = true
			golden_filter = a.substr(9)
			direct = true
		elif a == "--selftest":
			selftest = true
			direct = true
		elif a.begins_with("--menushot="):
			menu_shot = a.substr(11)
	if direct:
		_start_game()
		if selftest:
			set_process(false)
			_selftest()
			return
		if golden:
			set_process(false)
			var runner := GoldenRunner.new(self)
			runner.run(golden_filter)
			get_tree().quit()
			return
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
	team_lives = [int(cfg["startLives"]), int(cfg["startLives"])]
	wave_t = cfg["firstWave"]
	_setup_layout()
	_build_world()
	_spawn_hero()
	_build_hud()
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
	team_mid_y = (lane_off_g[0] + lane_off_g[lanes_per_team - 1]) / 2.0


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
	# Team-Lebenspunkt: ein Kristall am Ende der Lanes. Bei 4v4 laufen beide Lanes eines Teams hier zusammen.
	life_labels.clear()
	for team in 2:
		var first := team * lanes_per_team
		var cx: float = (lane_xs[first] + lane_xs[first + lanes_per_team - 1]) / 2.0
		var col := Color("#4fd8ff") if team == 0 else Color("#ff9a3a")
		_cyl(Vector3(cx, 0.25, 0.8), 1.6, 0.5, Color("#6d6558"))                                  # Sockel
		var crystal := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 3.2
		crystal.mesh = sm
		crystal.position = Vector3(cx, 2.3, 0.8)
		var cmat := _mat(col)
		cmat.emission_enabled = true
		cmat.emission = col
		cmat.emission_energy_multiplier = 1.4
		crystal.material_override = cmat
		add_child(crystal)
		var ll := _label3d("", 44, col)
		ll.position = Vector3(cx, 5.2, 0.8)
		add_child(ll)
		life_labels.append(ll)
	# Bäume außerhalb der Lanes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var zz := 12.0
	while zz > z_far:
		for side in [-1.0, 1.0]:
			var tx: float = (x_min - 14.0 - rng.randf() * 12.0) if side < 0.0 else (x_max + 14.0 + rng.randf() * 12.0)
			_tree(Vector3(tx, 0.0, zz + rng.randf() * 4.0), 0.8 + rng.randf() * 0.7)
		zz -= 7.0


## Wand zwischen den beiden Lanes eines Teams (4v4): durchgehend, nur die Basis (x < WALL_OPEN_BASE) ist offen.
## Zur anderen Lane kommt man also nur über die Basis (Backport nutzen oder zurücklaufen), man muss sich im Team absprechen.
func _gapped_wall(wall_x: float) -> void:
	_sand_piece(wall_x, -200.0, WALL_OPEN_BASE)                      # offene Basis: Sandweg statt Wand
	_wall_piece(wall_x, WALL_OPEN_BASE, float(cfg["laneLen"]) + 50.0)


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
	mini = Control.new()                 # Minimap unten links
	mini.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mini.offset_left = 14.0
	mini.offset_right = 14.0 + MINI_W
	mini.offset_bottom = -14.0
	mini.offset_top = -14.0 - MINI_H
	_build_skillbar(layer)
	mini.clip_contents = true
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.draw.connect(_draw_minimap)
	mini.gui_input.connect(_mini_input)
	layer.add_child(mini)


## Skill-Leiste unten in der Mitte: 4 Plätze (Q W E R) mit Rang, Abklingzeit und "+" zum Lernen.
func _build_skillbar(layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -300.0
	bar.offset_right = 300.0
	bar.offset_bottom = -14.0
	bar.offset_top = -100.0
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	skillbar.clear()
	var keys := ["Q", "W", "E", "R"]
	for i in 4:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(140, 86)
		pc.mouse_filter = Control.MOUSE_FILTER_PASS
		var vb := VBoxContainer.new()
		pc.add_child(vb)
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 15)
		vb.add_child(title)
		var pips := Label.new()
		pips.add_theme_color_override("font_color", Color("#ffd166"))
		vb.add_child(pips)
		var state := Label.new()
		state.add_theme_font_size_override("font_size", 13)
		vb.add_child(state)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(26, 22)
		plus.pressed.connect(func(): skills.learn(hero, i))
		plus.focus_mode = Control.FOCUS_NONE
		vb.add_child(plus)
		bar.add_child(pc)
		var def: Dictionary = skills.skill_def(hero, i)
		var tip := "%s [%s]\n" % [str(def["name"]), keys[i]]
		if not def.get("passive", false):
			tip += "Abklingzeit %.1f s\n" % float(def["cd"])
		tip += "Freigeschaltet ab Level %d, max. Rang %d\n" % [int(cfg["unlock"][i]), int(def["max"])]
		for line in def["info"]:
			tip += "• " + str(line) + "\n"
		pc.tooltip_text = tip
		skillbar.append({"title": title, "pips": pips, "state": state, "plus": plus, "key": keys[i]})


func _update_skillbar() -> void:
	if skillbar.is_empty() or hero.is_empty():
		return
	for i in 4:
		var s: Dictionary = skillbar[i]
		var def: Dictionary = skills.skill_def(hero, i)
		var r: int = hero["ranks"][i]
		var mx := int(def["max"])
		s["title"].text = "%s  %s" % [s["key"], str(def["name"])]
		s["pips"].text = "●".repeat(r) + "○".repeat(mx - r)
		var txt := ""
		if hero["lvl"] < int(cfg["unlock"][i]) and r == 0:
			txt = "ab Level %d" % int(cfg["unlock"][i])
		elif r == 0:
			txt = "nicht gelernt"
		elif def.get("passive", false):
			txt = "passiv"
		elif hero["cds"][i] > 0.0:
			txt = "CD %.1fs" % hero["cds"][i]
		else:
			txt = "bereit"
		s["state"].text = txt
		s["plus"].visible = skills.can_learn(hero, i)


## Minimap-Abbildung: Welt-Koordinaten (Meter) <-> Pixel der Minimap. Wird zum Zeichnen und für Klicks genutzt.
func _mini_map() -> Dictionary:
	var n := lane_xs.size()
	var half := lane_half_g * S
	var x_min: float = lane_xs[0] - half - WALL
	var x_max: float = lane_xs[n - 1] + half + WALL
	var lane_len: float = cfg["laneLen"] * S
	var z_top := -(lane_len + 8.0)
	var z_bot := 8.0
	var top := 18.0                       # oben Platz für die Monster-Zahlen
	return {"x_min": x_min, "z_top": z_top, "z_bot": z_bot, "top": top,
		"sx": MINI_W / (x_max - x_min), "sy": (MINI_H - top) / (z_bot - z_top)}


func _mini_pt(m: Dictionary, wx: float, wz: float) -> Vector2:
	return Vector2((wx - m["x_min"]) * m["sx"], m["top"] + (wz - m["z_top"]) * m["sy"])


## Klick oder Ziehen auf der Minimap: Kamera springt dorthin (Leertaste: zurück zum Helden).
func _mini_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pressed = true
		pos = event.position
	if not pressed or not started:
		return
	var m := _mini_map()
	var wx: float = m["x_min"] + pos.x / m["sx"]
	var wz: float = m["z_top"] + (pos.y - m["top"]) / m["sy"]
	cam_focus = Vector3(wx, 0.0, clampf(wz, m["z_top"], m["z_bot"]))
	cam_free = true
	mini.accept_event()


## Minimap: alle Lanes von oben. Monster sind rot (Elite/Boss größer), dein Held in Heldenfarbe.
## Über jeder Lane deines Teams steht die Zahl der Monster (wo ist mehr los?). Von der Gegner-Seite sieht man nur
## den unteren Abschnitt jeder Lane (bei deren Basis), damit man abschätzen kann, ob Druck sinnvoll ist, aber keine Gegner.
func _draw_minimap() -> void:
	var n := lane_xs.size()
	var half := lane_half_g * S
	var m := _mini_map()
	var z_top: float = m["z_top"]
	var z_bot: float = m["z_bot"]
	mini.draw_rect(Rect2(0, 0, MINI_W, MINI_H), Color(0.05, 0.06, 0.08, 0.82))
	var river_x: float = (lane_xs[lanes_per_team - 1] + lane_xs[lanes_per_team]) / 2.0
	var rp := _mini_pt(m, river_x - 2.5, z_top)
	mini.draw_rect(Rect2(rp.x, rp.y, 5.0 * m["sx"], (z_bot - z_top) * m["sy"]), Color("#1f5fa8"))
	var base_z := -float(cfg["baseX"]) * S
	var enemy_view_z := -float(ENEMY_LANE_VIEW) * S      # Gegner-Lane: nur bis hierhin (vom Ende her) sichtbar
	var counts: Array[int] = []
	counts.resize(lanes_per_team)
	counts.fill(0)
	for u in units:
		counts[u["lane"]] += 1
	for i in n:
		var mine := i < lanes_per_team
		var a := _mini_pt(m, lane_xs[i] - half, z_top if mine else enemy_view_z)
		var b := _mini_pt(m, lane_xs[i] + half, z_bot)
		mini.draw_rect(Rect2(a, b - a), Color("#6b5f3e") if mine else Color("#4a4a52"))
		var ba := _mini_pt(m, lane_xs[i] - half, base_z)
		mini.draw_rect(Rect2(ba, b - ba), Color("#2d4f7a") if mine else Color("#6a3a3a"))           # Basis
		if mine:
			var c: int = counts[i]
			var col := Color("#ff5a5a") if c > 0 else Color("#9aa3b5")
			mini.draw_string(ThemeDB.fallback_font, Vector2(a.x + 2.0, 14.0), str(c), HORIZONTAL_ALIGNMENT_LEFT, b.x - a.x, 14, col)
		else:
			mini.draw_line(a, Vector2(b.x, a.y), Color("#9aa3b5"), 1.0)                              # Grenze des sichtbaren Abschnitts
	if lanes_per_team == 2:               # gemeinsame Wand, offen in der Basis
		var wa := _mini_pt(m, (lane_xs[0] + lane_xs[1]) / 2.0, z_top)
		var wb := _mini_pt(m, (lane_xs[0] + lane_xs[1]) / 2.0, -float(WALL_OPEN_BASE) * S)
		mini.draw_line(wa, wb, Color("#9aa3b5"), 2.0)
	for u in units:
		var d: Dictionary = u["def"]
		var r := 2.5 + clampf(float(d["r"]) / 9.0, 0.0, 4.0) * 0.8
		var w := _wp(u["x"], u["y"])
		mini.draw_circle(_mini_pt(m, w.x, w.z), r, Color("#ff3030"))
	if hero["dead"] <= 0.0:
		var hw := _wp(hero["x"], hero["y"])
		var hp := _mini_pt(m, hw.x, hw.z)
		mini.draw_circle(hp, 5.5, Color.WHITE)
		mini.draw_circle(hp, 4.0, Color.html(hero["d"]["col"]))
	if cam != null and cam_init:          # Sichtfeld der Kamera
		var sz := get_viewport().get_visible_rect().size
		var pts := PackedVector2Array()
		for c in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y), Vector2(0, 0)]:
			var g := _ground_point(c)
			pts.append(_mini_pt(m, g.x, g.z))
		mini.draw_polyline(pts, Color(1, 1, 1, 0.75), 1.5)
	mini.draw_rect(Rect2(0, 0, MINI_W, MINI_H), Color("#8d7d55"), false, 2.0)


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
	var ring := _cyl(Vector3(0, 0.08, 0), 1.6, 0.04, Color("#7fd6ff"), Color("#7fd6ff"))   # Backport-Anzeige am Boden
	ring.visible = false
	remove_child(ring)                   # _cyl hängt es an die Szene, hier gehört es an den Helden
	node.add_child(ring)
	hero = {"key": hero_key, "d": d, "x": 120.0, "y": slot_ys[0], "lvl": 1, "xp": 0.0, "hp": float(d["hp"]), "dead": 0.0, "mul": 1.0,
		"atk_t": 0.0, "target": null, "move_to": null, "deaths": 0, "node": node, "label": lab,
		"bp": 0.0, "bp_cd": 0.0, "ring": ring,
		"gold": float(cfg["startGold"]), "income": float(cfg["baseIncome"]),     # jeder Spieler hat eigenes Gold und Einkommen
		"ranks": [0, 0, 0, 0], "cds": [0.0, 0.0, 0.0, 0.0], "sp": 1, "buffs": {}, "leap": null,
		"last_elem": "", "combo_t": 0.0, "amp_now": false,
		"bonus_hp": 0.0, "bonus_dmg": 0.0, "bonus_armor": 0.0, "bonus_as": 0.0, "bonus_sp": 0.0, "bonus_spd": 0.0,   # kommen später aus Items
		"uniq": {}, "spell_vamp": 0.0, "cdr": 0.0, "bonus_regen": 0.0, "dr": 0.0}


# ---------------------------------------------------------------- Formeln (wie im Browser-Prototyp)
func _reduce(dmg: float, armor: float) -> float:
	return dmg * (1.0 - armor / (armor + float(cfg["armorK"])))


func _hero_max_hp() -> float:
	return skills.h_max_hp(hero)


func _hero_dmg() -> float:
	return skills.h_dmg(hero)


func _hero_armor() -> float:
	return skills.h_armor(hero)


func _xp_need(l: int) -> float:
	return float(cfg["xpBase"]) + float(cfg["xpPer"]) * l


func _hp_mult() -> float:
	return 1.0 + (t / 60.0) * float(cfg["hpScalePerMin"])


func _in_base() -> bool:
	return hero["x"] < float(cfg["baseX"]) and hero["dead"] <= 0.0


# ---------------------------------------------------------------- Schnittstelle für skills.gd (Zufall, Zeitgeber, Felder, Effekte)
## Tests (--selftest, Szenario-Runner): keine Zufallsauswahl und keine Krits, damit Ergebnisse vergleichbar sind.
func rand() -> float:
	if rand_fixed >= 0.0:
		return rand_fixed
	return 0.999 if deterministic else randf()


func pick_random(list: Array, n: int) -> Array:
	var l := list.duplicate()
	if not deterministic and rand_fixed < 0.0:
		l.shuffle()
	return l.slice(0, n)


func later(delay: float, fn: Callable) -> void:
	if delay <= 0.0:
		fn.call()
	else:
		timers.append({"t": delay, "fn": fn})


func cancel_backport(p: Dictionary) -> void:
	p["bp"] = 0.0


func clamp_lane_y(y: float) -> float:
	var ly := lane_half_g - 10.0
	return clampf(y, -ly, lane_off_g[lanes_per_team - 1] + ly)


func apply_torment(_p: Dictionary, _u: Dictionary) -> void:
	pass                                  # Quälende Maske (Item): kommt mit den Items


func sfx_cast(_i: int) -> void:
	pass                                  # Sounds kommen später


func _free(n: Variant) -> void:
	if n != null:
		n.queue_free()


func add_zone(z: Dictionary) -> void:
	if test_mode:
		z["node"] = null
		zones.append(z)
		return
	var node := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = float(z["r"]) * S
	cm.bottom_radius = cm.top_radius
	cm.height = 0.04
	node.mesh = cm
	var col := Color.html(z["c"])
	var mat := _fx_mat(col)
	node.material_override = mat
	z["node"] = node
	z["mat"] = mat
	z["col"] = col
	add_child(node)
	node.position = _wp(z["x"], z["y"]) + Vector3(0, 0.1, 0)
	zones.append(z)


func set_elementar(e: Dictionary) -> void:
	for old in elems:
		_free(old["node"])
	elems.clear()
	if test_mode:
		e["node"] = null
		elems.append(e)
		return
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	body.mesh = sm
	body.position.y = 1.0
	var col := Color.html(skills.ELEM_COL[e["type"]])
	var mat := _mat(col)
	mat.emission_enabled = true
	mat.emission = col
	body.material_override = mat
	node.add_child(body)
	var lab := _label3d("", 28, col)
	lab.position.y = 2.4
	node.add_child(lab)
	add_child(node)
	e["node"] = node
	e["label"] = lab
	elems.append(e)


func _fx_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	return m


func _fx_add(node: Node3D, mat: StandardMaterial3D, life: float, col: Color, a0: float) -> void:
	add_child(node)
	fx_list.append({"node": node, "mat": mat, "t": life, "t0": maxf(0.01, life), "col": col, "a0": a0})


func fx_text(x: float, y: float, text: String, col: String, life: float, size: int) -> void:
	_float_text(text, _wp(x, y) + Vector3(0, 2.2, 0), Color.html(col), size, life)


func fx_ring(x: float, y: float, r: float, life: float, col: String) -> void:
	if test_mode:
		return
	var node := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * S
	cm.bottom_radius = cm.top_radius
	cm.height = 0.05
	node.mesh = cm
	var c := Color.html(col)
	var mat := _fx_mat(c)
	node.material_override = mat
	node.position = _wp(x, y) + Vector3(0, 0.12, 0)
	_fx_add(node, mat, life, c, 0.5)


func fx_cone(x: float, y: float, ang: float, r: float, half: float, life: float, col: String) -> void:
	if test_mode:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	for i in segs:
		var a0 := ang - half + 2.0 * half * i / segs
		var a1 := ang - half + 2.0 * half * (i + 1) / segs
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0.0, -cos(a0)) * r * S)
		st.add_vertex(Vector3(sin(a1), 0.0, -cos(a1)) * r * S)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var c := Color.html(col)
	var mat := _fx_mat(c)
	node.material_override = mat
	node.position = _wp(x, y) + Vector3(0, 0.14, 0)
	_fx_add(node, mat, life, c, 0.5)


func fx_line(x: float, y: float, x2: float, y2: float, life: float, col: String, w: float) -> void:
	if test_mode:
		return
	var a := _wp(x, y) + Vector3(0, 1.0, 0)
	var b := _wp(x2, y2) + Vector3(0, 1.0, 0)
	if a.distance_to(b) < 0.05:
		return
	var node := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(maxf(0.1, w * 0.05), maxf(0.1, w * 0.05), a.distance_to(b))
	node.mesh = bm
	var c := Color.html(col)
	var mat := _fx_mat(c)
	node.material_override = mat
	add_child(node)
	node.global_position = (a + b) / 2.0
	node.look_at(b, Vector3.UP)
	fx_list.append({"node": node, "mat": mat, "t": life, "t0": maxf(0.01, life), "col": c, "a0": 0.9})


func _update_fx(delta: float) -> void:
	for f in fx_list.duplicate():
		f["t"] -= delta
		if f["t"] <= 0.0:
			f["node"].queue_free()
			fx_list.erase(f)
		else:
			var c: Color = f["col"]
			c.a = f["a0"] * f["t"] / f["t0"]
			f["mat"].albedo_color = c
	for z in zones:
		var c: Color = z["col"]
		c.a = 0.22 + 0.1 * sin(t * 6.0)
		z["mat"].albedo_color = c
		z["node"].position = _wp(z["x"], z["y"]) + Vector3(0, 0.1, 0)
	for e in elems:
		e["node"].position = _wp(e["x"], e["y"])
		e["label"].text = "%s  %d  (%ds)" % [str(e["type"]).capitalize(), int(e["hp"]), int(e["t"])]


# ---------------------------------------------------------------- Einheiten und Wellen
func _spawn_unit(type: String, off_x: float, spd_mul: float, lane: int = 0) -> void:
	var u: Dictionary = Data.units[type]
	var m := _hp_mult()
	var node: Node3D = null
	if not test_mode:
		node = Node3D.new()
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
	units.append({"type": type, "lane": lane, "x": float(cfg["spawnX"]) + off_x + rand_pos() * 30.0, "y": lane_off_g[lane] + (rand_pos() * 2.0 - 1.0) * ly,
		"hp": float(u["hp"]) * m, "max": float(u["hp"]) * m,
		"dmg": float(u["dmg"]) * (1.0 + float(cfg["unitDmgScale"]) * (m - 1.0)),
		"spd": float(u["spd"]) * spd_mul * float(cfg["speedMul"]), "range": float(u["range"]),
		"armor": float(u["armor"]), "r": float(u["r"]), "atk_t": 0.0, "node": node, "def": u,
		"stun": 0.0, "slow": 0.0, "burn": 0.0, "burn_dps": 0.0, "burn_t": 0.0, "bleed": 0.0, "bleed_pct": 0.0, "bleed_t": 0.0})


## Zufallswert für Startpositionen (in Tests fest, damit Läufe vergleichbar sind)
func rand_pos() -> float:
	return 0.5 if deterministic else randf()


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
	if msg == null:
		return
	msg.text = text
	get_tree().create_timer(1.5).timeout.connect(func(): if msg.text == text: msg.text = "")


func _kill_unit(u: Dictionary, p: Dictionary = {}) -> void:
	units.erase(u)
	_free(u["node"])
	kills += 1
	var killer: Dictionary = p if not p.is_empty() else hero
	var def: Dictionary = u["def"]
	killer["gold"] += float(def["gold"]) if def.has("gold") else float(cfg["killGold"])
	_gain_xp(float(def["xp"]), killer)


func _gain_xp(n: float, p: Dictionary = {}) -> void:
	var pl: Dictionary = p if not p.is_empty() else hero
	pl["xp"] += n
	while pl["lvl"] < int(cfg["maxLevel"]) and pl["xp"] >= _xp_need(pl["lvl"]):
		pl["xp"] -= _xp_need(pl["lvl"])
		pl["lvl"] += 1
		pl["sp"] += 1                                                     # 1 Skillpunkt pro Level, frei verteilbar
		pl["hp"] += float(pl["d"]["hpl"])
		_float_text("LEVEL %d" % pl["lvl"], _wp(pl["x"], pl["y"]) + Vector3(0, 3.2, 0), Color("#ffd166"), 48, 1.2)


func _float_text(text: String, pos: Vector3, col: Color, size: int, life: float) -> void:
	if test_mode:
		return
	var l := _label3d(text, size, col)
	l.position = pos
	add_child(l)
	texts.append({"node": l, "t": life})


## Schaden an einem Monster (Rüstung wird abgezogen). Gibt den tatsächlichen Schaden zurück.
func hit_unit(u: Dictionary, dmg: float, p: Dictionary = {}) -> float:
	if not units.has(u):
		return 0.0
	var d := _reduce(dmg, u["armor"])
	u["hp"] -= d
	_float_text(str(int(round(d))), _wp(u["x"], u["y"]) + Vector3(0, 1.8, 0), Color.WHITE, 30, 0.5)
	if u["hp"] <= 0.0:
		_kill_unit(u, p)
	return d


func _hit_unit(u: Dictionary, dmg: float) -> float:
	return hit_unit(u, dmg, hero)


func _damage_hero(dmg: float, src: Variant = null) -> void:
	if hero["dead"] > 0.0:
		return
	var raw := dmg                       # Dornen/Reflexion rechnen mit dem ungekürzten Schaden
	dmg *= (1.0 - float(hero["dr"]))     # verringerter Schaden durch Items
	var eff := _reduce(dmg, _hero_armor())
	hero["bp"] = 0.0                     # Schaden unterbricht den Backport
	hero["hp"] -= eff
	_float_text("-" + str(int(round(eff))), _wp(hero["x"], hero["y"]) + Vector3(0, 3.0, 0), Color("#ff6b6b"), 30, 0.6)
	var ir := skills.iron_passive(hero)  # Tank: Dornen geben einen Anteil des Schadens an den Angreifer zurück
	if ir["reflect"] > 0.0 and src != null and units.has(src):
		hit_unit(src, raw * float(ir["reflect"]) * float(cfg["reflectMul"]), hero)
	if hero["hp"] <= 0.0:
		hero["hp"] = 0.0
		hero["deaths"] += 1
		hero["dead"] = float(cfg["respawnBase"]) + float(cfg["respawnPerLevel"]) * hero["lvl"]
		hero["target"] = null
		hero["move_to"] = null
		hero["buffs"] = {}
		hero["leap"] = null


# ---------------------------------------------------------------- Spielschritt
func step(dt: float) -> void:
	if over:
		return
	t += dt
	# Einkommen und Wellen
	income_t += dt
	if income_t >= float(cfg["incomeTick"]):
		income_t -= float(cfg["incomeTick"])
		hero["gold"] += hero["income"]
	wave_t -= dt
	if wave_t <= 0.0:
		_spawn_wave()
		wave_t = float(cfg["earlyWaveEvery"]) if wave <= int(cfg["earlyWaves"]) else float(cfg["waveEvery"])
	# Zeitverzögerte Skill-Effekte
	for tm in timers.duplicate():
		tm["t"] -= dt
		if tm["t"] <= 0.0:
			timers.erase(tm)
			tm["fn"].call()
	_step_zones(dt)
	_step_hero(dt)
	for e in elems.duplicate():
		if not skills.update_elem(e, dt):
			_free(e["node"])
			elems.erase(e)
	_step_units(dt)
	if team_lives[0] <= 0:
		over = true
		if msg != null:
			msg.text = "NIEDERLAGE"


## Schadensfelder (Feuerfeld, Sprung-Landung, Schwertregen, Frost-Elementar)
func _step_zones(dt: float) -> void:
	for z in zones.duplicate():
		z["t"] -= dt
		z["tick"] -= dt
		if z.get("follow", "") == "enemy":                               # Feld jagt den nächsten Gegner
			var best: Variant = null
			var bd := 1e9
			for u in units:
				var d := Vector2(u["x"] - z["x"], u["y"] - z["y"]).length()
				if d < bd:
					bd = d
					best = u
			if best != null and bd > 4.0:
				var st := minf(bd, 75.0 * dt)
				z["x"] += (best["x"] - z["x"]) / bd * st
				z["y"] += (best["y"] - z["y"]) / bd * st
			z["y"] = clamp_lane_y(z["y"])
		if z["tick"] <= 0.0:
			z["tick"] += z["every"]
			for u in units.duplicate():
				if units.has(u) and Vector2(u["x"] - z["x"], u["y"] - z["y"]).length() <= z["r"] + u["r"]:
					skills.affect(z["p"], u, z["dmg"], z.get("o", {}))
		if z["t"] <= 0.0:
			_free(z["node"])
			zones.erase(z)


func _step_hero(dt: float) -> void:
	var p := hero
	for i in 4:
		p["cds"][i] = maxf(0.0, p["cds"][i] - dt)
	p["bp_cd"] = maxf(0.0, p["bp_cd"] - dt)
	p["combo_t"] = maxf(0.0, p["combo_t"] - dt)
	for k in p["buffs"].keys():
		p["buffs"][k]["t"] -= dt
		if p["buffs"][k]["t"] <= 0.0:
			p["buffs"].erase(k)
	if p["dead"] > 0.0:
		p["dead"] -= dt
		if p["dead"] <= 0.0:
			p["dead"] = 0.0
			p["hp"] = _hero_max_hp()
			p["x"] = 120.0
			p["y"] = slot_ys[0]
		return
	var mx := _hero_max_hp()
	var ir := skills.iron_passive(p)
	var regen: float = mx * 0.12 if _in_base() else 1.5 + p["lvl"] * 0.3
	p["hp"] = minf(mx, p["hp"] + (regen + mx * float(ir["regen"]) + mx * float(p["bonus_regen"])) * dt)
	if p["leap"] != null:                # Sprung (Damage): Held fliegt zum Ziel und landet mit Schaden
		var L: Dictionary = p["leap"]
		L["t"] -= dt
		var k: float = 1.0 - maxf(0.0, L["t"]) / L["T"]
		p["x"] = L["sx"] + (L["tx"] - L["sx"]) * k
		p["y"] = L["sy"] + (L["ty"] - L["sy"]) * k
		if L["t"] <= 0.0:
			skills.leap_land(p)
			p["leap"] = null
		if p["leap"] != null:
			return
	if p["bp"] > 0.0:                    # Backport wird gewirkt: der Held steht still und greift nicht an
		p["bp"] -= dt
		if p["bp"] <= 0.0:
			p["bp"] = 0.0
			p["bp_cd"] = float(cfg["backportCd"])
			p["x"] = 120.0
			p["y"] = slot_ys[0]
			p["move_to"] = null
			p["target"] = null
			_float_text("Zurück in der Basis", _wp(p["x"], p["y"]) + Vector3(0, 3.2, 0), Color("#7fd6ff"), 36, 1.0)
		return
	if autoplay:
		_autoplay_choose()
	# Ziel gültig? Bewegungsziel bestimmen
	if p["target"] != null and not units.has(p["target"]):
		p["target"] = null
	var goal: Variant = null
	var range_: float = float(p["d"]["range"])
	if p["target"] != null:
		var tg: Dictionary = p["target"]
		if Vector2(tg["x"] - p["x"], tg["y"] - p["y"]).length() > range_ + tg["r"]:
			goal = Vector2(tg["x"], tg["y"])
	elif p["move_to"] != null:
		goal = p["move_to"]
	var old_y: float = p["y"]
	if goal != null:
		goal = _route(goal)              # bei Doppel-Lane: nur in der Basis zur anderen Lane
		var dv: Vector2 = goal - Vector2(p["x"], p["y"])
		var d := dv.length()
		if d < 4.0:
			if p["target"] == null:
				p["move_to"] = null
		else:
			var step_len := minf(d, skills.h_spd(p) * dt)
			p["x"] += dv.x / d * step_len
			p["y"] += dv.y / d * step_len
	p["x"] = clampf(p["x"], 20.0, float(cfg["laneLen"]))
	p["y"] = _clamp_y(p["x"], p["y"], old_y)
	# Auto-Angriff: auch im Laufen, sobald ein Gegner in Reichweite ist
	p["atk_t"] -= dt
	var tgt: Variant = p["target"]
	if tgt == null:
		var best := 1e9
		for u in units:
			var dd := Vector2(u["x"] - p["x"], u["y"] - p["y"]).length()
			if dd <= range_ + u["r"] and dd < best:
				best = dd
				tgt = u
	if tgt != null and Vector2(tgt["x"] - p["x"], tgt["y"] - p["y"]).length() <= range_ + tgt["r"] and p["atk_t"] <= 0.0:
		p["atk_t"] = 1.0 / skills.h_as(p)
		var dmg := _hero_dmg()
		var tx: float = tgt["x"]
		var ty: float = tgt["y"]
		hit_unit(tgt, dmg, p)
		var rg: Variant = skills.buff(p, "rage")
		if rg != null and rg["cleave"]:                                   # Kampfrausch Rang 5: Angriffe treffen Gegner im Umkreis
			for u in units.duplicate():
				if u != tgt and units.has(u) and Vector2(u["x"] - tx, u["y"] - ty).length() <= 75.0:
					hit_unit(u, dmg * 0.5, p)
		if range_ > 100.0:
			fx_line(p["x"], p["y"], tx, ty, 0.12, str(p["d"]["col"]), 2.0)


## Backport (Taste B): Zauberzeit, danach zurück in die Basis; nicht in der Basis, nicht während der Abklingzeit.
func _start_backport() -> void:
	if hero["dead"] > 0.0 or hero["bp"] > 0.0 or hero["bp_cd"] > 0.0 or _in_base():
		return
	hero["bp"] = float(cfg["backportCast"])
	hero["move_to"] = null
	hero["target"] = null


## Doppel-Lane (4v4): Die Wand zwischen den Lanes ist nur in der Basis offen.
func _clamp_y(x: float, y: float, old_y: float) -> float:
	var ly := lane_half_g - 10.0
	y = clampf(y, -ly, lane_off_g[lanes_per_team - 1] + ly)
	if lanes_per_team == 2 and x >= WALL_OPEN_BASE:
		var lo := lane_half_g - 10.0
		var hi: float = lane_off_g[1] - lane_half_g + 10.0
		if y > lo and y < hi:
			y = lo if old_y <= (lo + hi) / 2.0 else hi
	return y


## Liegt das Ziel auf der anderen Lane: In der Basis läuft der Held quer hinüber. In der Lane ist die Wand zu,
## er läuft nur bis an die Wand (zur anderen Lane kommt man über die Basis, z. B. mit dem Backport).
func _route(goal: Vector2) -> Vector2:
	if lanes_per_team < 2:
		return goal
	var mid: float = (lane_off_g[0] + lane_off_g[1]) / 2.0
	if (hero["y"] < mid) == (goal.y < mid):
		return goal
	if hero["x"] < WALL_OPEN_BASE:
		return Vector2(minf(hero["x"], WALL_OPEN_BASE - 50.0), goal.y)   # quer durch die Basis
	var lo := lane_half_g - 10.0               # Wandbereich quer
	var hi: float = lane_off_g[1] - lane_half_g + 10.0
	return Vector2(goal.x, lo if hero["y"] < mid else hi)


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
	if autoplay_skills:                  # Test: Skills benutzen, sobald sie bereit sind
		for i in 4:
			while skills.can_learn(hero, i) and i < 3:
				skills.learn(hero, i)
			if skills.can_learn(hero, 3):
				skills.learn(hero, 3)
		if best != null:
			var m := {"dx": best["x"] - hero["x"], "dy": best["y"] - hero["y"], "wx": best["x"], "wy": best["y"]}
			m["dist"] = maxf(1.0, Vector2(m["dx"], m["dy"]).length())
			m["ang"] = atan2(m["dy"], m["dx"])
			for i in 4:
				skills.cast_slot(hero, i, m)


func _step_units(dt: float) -> void:
	for u in units.duplicate():
		if not units.has(u):
			continue
		# Statuseffekte
		if u["slow"] > 0.0:
			u["slow"] -= dt
		if u["burn"] > 0.0:
			u["burn"] -= dt
			u["burn_t"] += dt
			if u["burn_t"] >= 1.0:
				u["burn_t"] -= 1.0
				hit_unit(u, u["burn_dps"], hero)
				if not units.has(u):
					continue
		if u["bleed"] > 0.0:                                              # Blutung: % des Lebens pro Sekunde, ignoriert Rüstung
			u["bleed"] -= dt
			u["bleed_t"] += dt
			if u["bleed_t"] >= 1.0:
				u["bleed_t"] -= 1.0
				var bd: float = u["max"] * u["bleed_pct"]
				u["hp"] -= bd
				_float_text(str(int(round(bd))), _wp(u["x"], u["y"]) + Vector3(0, 1.8, 0), Color("#ff6b6b"), 28, 0.5)
				if u["hp"] <= 0.0:
					_kill_unit(u, hero)
					continue
		if u["stun"] > 0.0:
			u["stun"] -= dt
			continue
		u["atk_t"] -= dt
		var engaged := false
		var hero_in: bool = hero["dead"] <= 0.0 and Vector2(u["x"] - hero["x"], u["y"] - hero["y"]).length() <= u["range"] + 14.0
		var el: Variant = null
		if not hero_in:
			for e in elems:
				if Vector2(u["x"] - e["x"], u["y"] - e["y"]).length() <= u["range"] + 18.0:
					el = e
					break
		if hero_in or el != null:
			engaged = true
			if u["atk_t"] <= 0.0:
				u["atk_t"] = 1.0
				if hero_in:
					_damage_hero(u["dmg"], u)
				else:
					el["hp"] -= _reduce(u["dmg"], 10.0)
		if not engaged:
			var step_len: float = u["spd"] * (0.5 if u["slow"] > 0.0 else 1.0) * dt
			var dx := -1.0
			var dy := 0.0
			var chasing := false
			if hero["dead"] <= 0.0 and u["type"] != "fast":
				var hx: float = hero["x"] - u["x"]
				var hy: float = hero["y"] - u["y"]
				var dist := maxf(1.0, sqrt(hx * hx + hy * hy))
				if dist <= (float(cfg["aggroRange"]) if hx <= 40.0 else float(cfg["aggroBehind"])):
					dx = hx / dist
					dy = hy / dist
					chasing = true
			var in_base_zone: bool = lanes_per_team == 2 and u["x"] < WALL_OPEN_BASE
			if in_base_zone and not chasing:     # 4v4: beide Lanes laufen am Ende auf den gemeinsamen Team-Kristall zu
				var dv := Vector2(float(cfg["leakX"]) - u["x"], team_mid_y - u["y"])
				var dl := maxf(1.0, dv.length())
				dx = dv.x / dl
				dy = dv.y / dl
			u["x"] += dx * step_len
			var ly: float = lane_half_g - 16.0
			var off: float = lane_off_g[u["lane"]]
			if in_base_zone:                     # in der offenen Basis gilt der Quer-Bereich beider Lanes
				u["y"] = clampf(u["y"] + dy * step_len, lane_off_g[0] - ly, lane_off_g[lanes_per_team - 1] + ly)
			else:
				u["y"] = clampf(u["y"] + dy * step_len, off - ly, off + ly)
		if u["x"] <= float(cfg["leakX"]):
			team_lives[0] -= int(u["def"]["lives"])
			units.erase(u)
			_free(u["node"])


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
	_update_fx(delta)
	var off := _cam_offset()
	var want := (cam_focus if cam_free else hn.position) + off
	cam.position = want if not cam_init else cam.position.lerp(want, minf(1.0, delta * 6.0))
	for i in life_labels.size():
		life_labels[i].text = "Leben %d" % maxi(0, team_lives[i])
	cam_init = true
	cam.look_at(cam.position - off)
	var ring: MeshInstance3D = hero["ring"]
	ring.visible = hero["bp"] > 0.0
	var prog: float = hero["bp"] / float(cfg["backportCast"])
	ring.scale = Vector3(0.4 + 0.6 * prog, 1.0, 0.4 + 0.6 * prog)
	var bp_txt := "in der Basis"
	if hero["dead"] > 0.0:
		bp_txt = "Held tot: %ds" % int(ceil(hero["dead"]))
	elif hero["bp"] > 0.0:
		bp_txt = "Cast %.1fs (Schaden unterbricht)" % hero["bp"]
	elif not _in_base():
		bp_txt = "CD %ds" % int(ceil(hero["bp_cd"])) if hero["bp_cd"] > 0.0 else "bereit"
	var min_t := int(t) / 60
	hud.text = "Gold %d   Einkommen +%.0f / %ds   Team-Leben %d  (Gegner %d)   Welle %d   Zeit %d:%02d\nLevel %d   XP %d / %d   HP %d / %d   Kills %d   [B] Backport: %s" % [
		int(hero["gold"]), hero["income"], int(cfg["incomeTick"]), team_lives[0], team_lives[1], wave, min_t, int(t) % 60,
		hero["lvl"], int(hero["xp"]), int(_xp_need(hero["lvl"])), int(hero["hp"]), int(_hero_max_hp()), kills, bp_txt]
	if mini != null:
		mini.queue_redraw()
	_update_skillbar()


func _ground_point(screen_pos: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return Vector3.ZERO
	return o + d * (-o.y / d.y)


## Maus relativ zum Helden in Spielkoordinaten (Richtung und Zielpunkt für Skills).
func _mouse_info() -> Dictionary:
	var p := _ground_point(get_viewport().get_mouse_position())
	var gx := -p.z / S
	var gy := (p.x - lane_xs[0]) / S
	var dx: float = gx - hero["x"]
	var dy: float = gy - hero["y"]
	return {"dx": dx, "dy": dy, "dist": maxf(1.0, Vector2(dx, dy).length()), "ang": atan2(dy, dx), "wx": gx, "wy": gy}


func _unhandled_input(event: InputEvent) -> void:
	if started and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		cam_free = false                  # Leertaste: Kamera zurück zum Helden
	if event is InputEventMouseButton and event.pressed:   # Mausrad: Kamera näher/weiter weg
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 2.0, 14.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 2.0, 14.0, 50.0)
	if not started or over or hero["dead"] > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_start_backport()
		elif event.keycode == KEY_S:      # Stopp
			hero["move_to"] = null
			hero["target"] = null
		elif event.keycode == KEY_F:      # Heiltrank: kommt mit den Items
			pass
		else:
			var slot := [KEY_Q, KEY_W, KEY_E, KEY_R].find(event.keycode)
			if slot >= 0:
				if event.shift_pressed:   # Shift + Taste: Skillpunkt vergeben
					skills.learn(hero, slot)
				else:
					skills.cast_slot(hero, slot, _mouse_info())
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


# ---------------------------------------------------------------- Szenario-Runner (--golden): Vergleich mit dem Prototyp
## Setzt Spielzustand und Held für ein Vergleichs-Szenario zurück (Eingaben siehe regelwerk/golden-skills.json).
func reset_test(inp: Dictionary, heldpos: Array, layouts: Dictionary) -> void:
	test_mode = true
	units.clear()
	zones.clear()
	timers.clear()
	elems.clear()
	t = 0.0
	wave = 0
	wave_t = 1e9
	income_t = 0.0
	over = false
	team_lives = [int(cfg["startLives"]), int(cfg["startLives"])]
	lane_half_g = float(cfg["laneHalf"])   # Prototyp-Lane-Breite, damit Klammern/Grenzen wie im Prototyp wirken
	if not hero.is_empty():
		_free(hero["node"])
	hero_key = str(inp["hero"])
	_spawn_hero()
	var p := hero
	p["lvl"] = int(inp["lvl"])
	for i in 4:
		p["ranks"][i] = int(inp["ranks"][i])
	p["sp"] = 0
	var b: Dictionary = inp.get("bonus", {})
	p["bonus_sp"] = float(b.get("sp", 0.0))
	p["bonus_dmg"] = float(b.get("dmg", 0.0))
	p["bonus_hp"] = float(b.get("hp", 0.0))
	p["bonus_armor"] = float(b.get("armor", 0.0))
	p["bonus_as"] = float(b.get("as", 0.0))
	p["uniq"] = {}
	for k in inp.get("uniq", []):
		p["uniq"][str(k)] = true
	p["cdr"] = float(inp.get("cdr", 0.0))
	p["spell_vamp"] = float(inp.get("spellVamp", 0.0))
	p["dr"] = float(inp.get("dr", 0.0))
	p["x"] = float(heldpos[0])
	p["y"] = float(heldpos[1])
	p["hp"] = skills.h_max_hp(p) * float(inp.get("hpFrac", 0.5))
	p["atk_t"] = 0.0 if inp.get("auto", false) else 1e9
	rand_fixed = float(inp.get("rand", 0.5))
	var dhp := float(inp.get("dummyHp", 100000))
	for off in layouts[str(inp["layout"])]:
		_spawn_unit("grunt", 0.0, 1.0, 0)
		var u: Dictionary = units[units.size() - 1]
		u["x"] = p["x"] + float(off[0])
		u["y"] = p["y"] + float(off[1])
		u["hp"] = dhp
		u["max"] = dhp
		u["armor"] = float(inp.get("dummyArmor", 0.0))
		u["dmg"] = 0.0
		u["spd"] = float(inp.get("dummySpd", 0.0))
		u["atk_t"] = 1e9
		u["r"] = 9.0
		u["range"] = 0.0                       # Prototyp-Dummys haben Reichweite 0 (laufen dicht an den Helden heran)


# ---------------------------------------------------------------- Selbsttest (--selftest, nur 4v4)
func _selftest() -> void:
	var ok := true
	var check := func(name: String, cond: bool) -> void:
		print(("PASS  " if cond else "FAIL  ") + name)
		if not cond:
			ok = false
	var run := func(secs: float) -> void:
		for i in int(secs / 0.05):
			wave_t = 1e9
			units.clear()
			hero["hp"] = _hero_max_hp()
			step(0.05)
	var mid: float = (lane_off_g[0] + lane_off_g[1]) / 2.0
	# 1. Aus der Basis quer in die andere Lane laufen ist erlaubt
	hero["move_to"] = Vector2(1000.0, lane_off_g[1])
	run.call(40.0)
	check.call("Aus der Basis in Lane 2 gelaufen (x=%.0f, y=%.0f)" % [hero["x"], hero["y"]], hero["x"] > 900.0 and hero["y"] > mid)
	# 2. In der Lane ist die Wand zu: Ziel in Lane 1 -> Held bleibt auf seiner Seite
	hero["move_to"] = Vector2(1500.0, lane_off_g[0])
	run.call(30.0)
	check.call("Wand blockiert den Wechsel (y=%.0f bleibt über %.0f)" % [hero["y"], mid], hero["y"] > mid)
	# 3. Backport: zurück in die Basis, Abklingzeit läuft
	hero["move_to"] = null
	_start_backport()
	check.call("Backport startet in der Lane", hero["bp"] > 0.0)
	run.call(2.0)
	check.call("Backport noch nicht fertig nach 2 s", hero["x"] > 900.0)
	run.call(3.0)
	check.call("Backport fertig nach 5 s (x=%.0f)" % hero["x"], absf(hero["x"] - 120.0) < 1.0 and hero["bp_cd"] > 60.0)
	_start_backport()
	check.call("Kein Backport in der Basis", hero["bp"] == 0.0)
	# 4. Aus der Basis in Lane 1 laufen
	hero["move_to"] = Vector2(1000.0, lane_off_g[0])
	run.call(40.0)
	check.call("Aus der Basis in Lane 1 gelaufen (x=%.0f, y=%.0f)" % [hero["x"], hero["y"]], hero["x"] > 900.0 and hero["y"] < mid)
	# 5. Schaden unterbricht den Backport
	hero["bp_cd"] = 0.0
	hero["move_to"] = null
	_start_backport()
	_damage_hero(10.0)
	check.call("Schaden unterbricht den Backport", hero["bp"] == 0.0)
	# 6. Minimap: Klick setzt die Kamera dorthin, Leertaste zurück zum Helden
	var mp := _mini_map()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _mini_pt(mp, lane_xs[1], -75.0)          # Mitte der 2. Lane, ca. 75 m vor der Basis
	_mini_input(click)
	check.call("Minimap-Klick löst die Kamera (frei=%s, Ziel x=%.1f z=%.1f)" % [cam_free, cam_focus.x, cam_focus.z], cam_free and absf(cam_focus.x - lane_xs[1]) < 1.0 and absf(cam_focus.z + 75.0) < 1.0)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	_unhandled_input(space)
	check.call("Leertaste: Kamera wieder am Helden", not cam_free)
	# 7. Monster der 2. Lane laufen am Ende auf den gemeinsamen Team-Kristall zu
	units.clear()
	hero["x"] = 2000.0
	hero["y"] = lane_off_g[0]
	_spawn_unit("grunt", 0.0, 1.0, 1)
	var gr: Dictionary = units[0]
	gr["x"] = 280.0
	gr["y"] = lane_off_g[1]
	hero["dead"] = 99.0                                         # Held aus dem Weg
	for i in 80:
		_step_units(0.05)
		if units.is_empty():
			break
	check.call("Monster aus Lane 2 erreichen den Kristall in der Mitte (y=%.0f, Mitte=%.0f)" % [gr["y"], team_mid_y], units.is_empty() or absf(gr["y"] - team_mid_y) < absf(lane_off_g[1] - team_mid_y))
	print("SELFTEST " + ("OK" if ok else "FEHLER"))
	get_tree().quit()


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
		secs, wave, team_lives[0], int(hero["gold"]), hero["lvl"], kills, hero["deaths"], units.size()])
	if shot_path != "":
		_sync_visuals(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("Screenshot: ", shot_path)
	get_tree().quit()
