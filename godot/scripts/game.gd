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
const ItemsLib := preload("res://scripts/items.gd")
const BotLib := preload("res://scripts/bot.gd")
const SfxLib := preload("res://scripts/sfx.gd")
const FxLib := preload("res://scripts/fx.gd")
const HudStein := preload("res://scripts/hud_stein.gd")
const MainMenuLib := preload("res://scripts/main_menu.gd")
const NachtLib := preload("res://scripts/map_nachtwald.gd")
const ShopLib := preload("res://scripts/shop_stein.gd")
const GoldenRunner := preload("res://scripts/golden_runner.gd")
const GoldenEconomyRunner := preload("res://scripts/golden_economy_runner.gd")
const GoldenBossRunner := preload("res://scripts/golden_boss_runner.gd")
const MINI_W := 250.0                # Größe der Minimap (Pixel)
const MINI_H := 270.0
const ENEMY_LANE_VIEW := 700.0       # Gegner-Lane auf der Minimap: nur dieser Abschnitt (Spielwerte) bei deren Basis
var cam_pitch := 58.0             # Kamerawinkel in Grad (wie Warcraft 3: schräg von oben)
var cam_dist := 28.0                 # Kamera-Abstand zum Helden (Mausrad)

var cfg: Dictionary
var t := 0.0
var team_lives: Array = [20, 20]    # Leben je Team (gemeinsam): [dein Team, Gegner-Team]
var income_t := 0.0
var over := false
var hero_key := "damage"
var hero: Dictionary = {}            # der Spieler am Computer (players[0])
var players: Array = []                # alle Spieler (Helden): du, deine Mitspieler (Bots) und die Gegner (Bots)
var sides: Array = []                  # 2 Seiten (Teams): [0] = dein Team, [1] = Gegner-Team. Jede hat Monster, Leben, Wellen, Spieler
var cur_side := 0                      # Seite, für die gerade gerechnet/gezeichnet wird (für Effekte aus skills.gd)
var units: Array = []                 # Monster auf den Lanes DEINER Seite (gleiches Array wie sides[0]["units"])
var texts: Array = []                # schwebende Zahlen
var kills := 0
var autoplay := false
var autoplay_skills := false          # Test: Der Test-Held nutzt Skills (--skills)
var test_mode := false                # Tests ohne Grafik: keine Knoten für Effekte, Zahlen und Monster
var rand_fixed := -1.0                 # Tests: fester Zufallswert (>= 0)
var deterministic := false            # Tests: kein Zufall (keine Krits, feste Auswahl, feste Startpositionen)
var items: ItemsLib                 # Items, Rucksack, Shop-Regeln (items.gd)
var skills: SkillsLib                # Skill-Logik (skills.gd)
var zones: Array = []                 # Schadensfelder am Boden
var timers: Array = []                # zeitverzögerte Skill-Effekte
var elems: Array = []                 # Caster-Elementare
var fx_list: Array = []               # Skill-Effekte (Ringe, Kegel, Linien), blenden aus
var fx_nodes: Array = []              # Partikel-/Licht-Effekte (fx.gd): {node, t}
var vfx: FxLib                        # Fähigkeiten-Effekte
var skillbar: Array = []              # Oberfläche: die 4 Skill-Plätze
var ui: HudStein                       # Oberfläche im Steinrahmen-Stil (hud_stein.gd)
var shake_on := true                  # Bildschirmwackeln an/aus (Optionen)
var display_mode := 0                    # 0 Fenster, 1 Vollbild (randlos), 2 exklusives Vollbild
var alerts_box: VBoxContainer         # Meldungen oben in der Mitte
var tips_seen: Dictionary = {}         # schon gezeigte Einsteiger-Tipps (gespeichert)
var ui_t_base := 0.0
var ui_t_sp := 0.0
var ui_t_coach := 0.0
var ui_lives := -1
var ui_warn_wave := 0
var boss_bar: ProgressBar
var boss_label: Label
var paused := false
var game_speed := 1
var acc := 0.0                         # Zeit-Sammler für feste Spielschritte
var end_shown := false
var end_layer: CanvasLayer
var pause_label: Label
var test_panel: PanelContainer         # Testfenster (F2): Level, Ränge, Gold, Monster usw. zum schnellen Ausprobieren
var test_vals: Dictionary = {}
var send_btns: Array = []              # Knöpfe zum Monster-Senden
var bot: BotLib                               # Bot-Steuerung der Computer-Spieler (bot.gd)
var snd: SfxLib                        # Sounds (sfx.gd)
var shake_amt := 0.0                   # Bildschirmwackeln (Pixelwert, klingt ab)
var flash_a := 0.0                     # roter Blitz über dem Bild (Lebensverlust, Tod)
var vignette: TextureRect
var no_bots := false                   # Tests: keine Computer-Spieler
var bot_diff: Dictionary = {}          # gewählte Schwierigkeit der Gegner
var bot_style := "random"              # gewählter Spielstil der Gegner
var diff_key := "normal"               # gewählte Schwierigkeit (leicht/normal/schwer/experte)
var winner := -1                       # nach Spielende: 0 = dein Team, 1 = Gegner
var shop: ShopLib                       # Shop-Fenster (shop_stein.gd)
var shop_btn: Button
var pot_btn: Button
var bag_btns: Array = []               # Rucksack-Plätze
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
var merchant: Dictionary = {}          # Goblin-Händler an der Basis (map_nachtwald.gd): Positionen und Beschriftungen
var map_theme := "nachtwald"            # Karte: nachtwald (giftiger Nachtwald) oder gras (alte Wiese), Test: --map=gras
var decor                              # Dekoration der Karte (map_nachtwald.gd)
var mc: Dictionary = {}                # Farben der Karte
var sun: DirectionalLight3D            # Sonne (Schatten je nach Grafikqualität)
var fps_ema := 60.0
var hud_mid: Label
var hud_right: Label
var msg: Label
var started := false
var trace := false
var selftest := false
var selftest_items := false
var shopshot := false                 # Test: Shop offen, Gold und ein paar Items fürs Screenshot
var itemcat := false                   # Test: Katalog aller Items mit Bildchen
var dbgshot := false                 # Test: Testfenster offen fürs Bild
var uimenu := false                   # Test: Menü offen fürs Bild
var uioptions := false
var uitip := false                    # Test: Hinweistexte der Fähigkeiten ausgeben
var golden := false                   # Szenario-Runner (Vergleich mit dem Prototyp)
var golden_filter := ""
var golden_eco := false
var golden_boss := false
var botplay := false                  # Test: auch dein Held wird vom Bot gesteuert (ganze Partien Bot gegen Bot)
var golden_eco_filter := ""
var menu_shot := ""
var menu_click := ""                  # Test: Menü per echten Mausklicks bedienen, z. B. --menuclick=options oder single,class_tank
var cam_test_x := -1.0                 # Test: Kamera frei auf Lane-Position x (Spielwert), --camx=1500
var merchant_test := false              # Test: Klick auf den Händler per Skript
var menu_obj
var fxtest := ""                     # Test: Effekt einer Fähigkeit zeigen (q, w, e, rfire, rfrost, rlightning) und Bilder speichern
var fx_rank := 3
var menu_test := false                # Test: Menü per Skript bedienen (Spiel starten drücken)
var menu_go: Button
var mini: Control                    # Minimap
var life_labels: Array[Label3D] = [] # Lebensanzeige über den Team-Kristallen
var team_mid_y := 0.0                # Quer-Mitte deines Teams (Spielwerte); bei 4v4 laufen die Lanes hier zusammen
var cam_free := false                # Kamera vom Helden gelöst (nach Klick auf die Minimap), Leertaste = zurück zum Helden
var cam_focus := Vector3.ZERO
var menu_layer: CanvasLayer


func _ready() -> void:
	get_window().theme = HudStein.make_theme()      # Steinrahmen-Stil für alle Felder, Knöpfe und Hinweise
	_apply_saved_display()
	cfg = Data.cfg
	skills = SkillsLib.new(self)
	items = ItemsLib.new(self)
	bot = BotLib.new(self)
	bot_diff = Data.raw["diff"]["normal"]
	var sim_secs := 0.0
	var shot_path := ""
	var direct := false                  # Kommandozeile gibt Modus vor: Menü überspringen
	team_size = Data.sel_team
	hero_key = Data.sel_hero
	diff_key = Data.sel_diff
	bot_style = Data.sel_style
	if Data.autostart:                   # Revanche: gleiche Auswahl, ohne Menü
		direct = true
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
		elif a == "--itemcatalog":
			itemcat = true
		elif a == "--shopshot":
			shopshot = true
		elif a == "--dbgshot":
			dbgshot = true
		elif a == "--uimenu":
			uimenu = true
		elif a == "--uioptions":
			uimenu = true
			uioptions = true
		elif a == "--uitip":
			uitip = true
		elif a == "--selftest-items":
			selftest_items = true
			no_bots = true
			direct = true
		elif a.begins_with("--golden-boss="):
			golden_boss = true
			golden_filter = a.substr(14)
			no_bots = true
			direct = true
		elif a == "--golden-boss":
			golden_boss = true
			no_bots = true
			direct = true
		elif a == "--golden-eco":
			golden_eco = true
			no_bots = true
			direct = true
		elif a.begins_with("--golden-eco="):
			golden_eco = true
			golden_eco_filter = a.substr(13)
			no_bots = true
			direct = true
		elif a == "--golden":
			golden = true
			no_bots = true
			direct = true
		elif a.begins_with("--golden="):
			golden = true
			no_bots = true
			golden_filter = a.substr(9)
			direct = true
		elif a.begins_with("--diff="):
			diff_key = a.substr(7)
		elif a.begins_with("--map="):
			map_theme = a.substr(6)
		elif a == "--merchanttest":
			merchant_test = true
		elif a.begins_with("--camx="):
			cam_test_x = float(a.substr(7))
		elif a.begins_with("--uiscale="):
			Data.user.ui_scale = float(a.substr(10))                  # Test: Oberflächengröße ohne zu speichern
		elif a == "--colorblind":
			Data.user.colorblind = true
		elif a == "--gfxlow":
			Data.user.gfx = 0
		elif a.begins_with("--style="):
			bot_style = a.substr(8)
		elif a == "--botplay":
			botplay = true
		elif a == "--no-bots":
			no_bots = true
		elif a == "--selftest":
			selftest = true
			no_bots = true
			direct = true
		elif a == "--menu-test":
			menu_test = true
		elif a.begins_with("--fxtest="):
			fxtest = a.substr(9)
			no_bots = true
			direct = true
		elif a.begins_with("--rank="):
			fx_rank = int(a.substr(7))
		elif a.begins_with("--menuclick="):
			menu_click = a.substr(12)
		elif a.begins_with("--menushot="):
			menu_shot = a.substr(11)
	if direct:
		_start_game()
		if fxtest != "":
			_fxtest(fxtest, shot_path)
			return
		if selftest:
			set_process(false)
			_selftest()
			return
		if selftest_items:
			set_process(false)
			for s in sides:
				s["wave_t"] = 1e9
			_selftest_items()
			return
		if golden_boss:
			set_process(false)
			var boss_runner := GoldenBossRunner.new(self)
			boss_runner.run_boss(golden_filter)
			get_tree().quit()
			return
		if golden_eco:
			set_process(false)
			var eco_runner := GoldenEconomyRunner.new(self)
			eco_runner.run(golden_eco_filter)
			get_tree().quit()
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
		if menu_test:                     # Test: Moduswahl per Skript, "Spiel starten" drücken, 8 s spielen lassen, Bild speichern
			for i in 3:
				await get_tree().process_frame
			menu_go.pressed.emit()
			for i in 480:
				await get_tree().process_frame
			print("MENUTEST gestartet=%s Zeit=%.1f Gold=%d Level=%d Spieler=%d" % [started, t, int(hero["gold"]), hero["lvl"], players.size()])
			if menu_shot != "":
				get_viewport().get_texture().get_image().save_png(menu_shot)
			get_tree().quit()
			return
		if menu_click != "":              # Test: echte Mausklicks auf Menü-Knöpfe
			for key in menu_click.split(","):
				for i in 4:
					await get_tree().process_frame
				var tgt: Control = menu_obj.target(key)
				var pos: Vector2 = tgt.get_global_rect().get_center()
				var mv := InputEventMouseMotion.new()
				mv.position = pos
				mv.global_position = pos
				Input.parse_input_event(mv)
				for down in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = down
					ev.position = pos
					ev.global_position = pos
					Input.parse_input_event(ev)
					await get_tree().process_frame
		if menu_shot != "":               # Test: Menü-Bild speichern und beenden
			for i in 5:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(menu_shot)
			get_tree().quit()


## Startet eine Partie mit dem gewählten Modus (team_size) und Helden (hero_key).
func _start_game() -> void:
	bot_diff = Data.raw["diff"][diff_key]
	Data.sel_team = team_size
	Data.sel_hero = hero_key
	Data.sel_diff = diff_key
	Data.sel_style = bot_style
	team_lives = [int(cfg["startLives"]), int(cfg["startLives"])]
	_setup_layout()
	_setup_sides()
	_build_world()
	vfx = FxLib.new(self)
	_spawn_hero()
	if not no_bots and snd == null:
		snd = SfxLib.new(self)               # Sounds nur im echten Spiel (nicht in Tests)
		snd.volume = _load_volume()
		_load_tips()
	apply_settings()
	if not no_bots:
		_spawn_others()
	if botplay:                          # Test: dein Held spielt auch als Bot (gleiche Schwierigkeit wie der Gegner)
		hero["bot"] = true
		hero["gold_mul"] = float(bot_diff["goldMul"])
		hero["mul"] = float(bot_diff["heroMul"])
		bot.setup(hero, bot_diff, bot_style)
	_build_hud()
	started = true
	if dbgshot and test_panel != null:
		test_panel.visible = true
	if shopshot:                         # Test: Shop zeigen
		hero["gold"] = 1500.0
		for id in ["bigSword", "rake", "hat", "ruby", "bigStaff", "mightyBlade"]:
			items.buy(hero, id)
		items.buy(hero, "potion")
		shop.toggle()
		if OS.get_cmdline_user_args().has("--shoptab"):
			shop._set_tab(1)
			shop._select("arcaneCrown")
			shop._select("bigStaff", false)


## Zwei Seiten (Teams): Monster, Spieler, Wellen und Leben getrennt
func _setup_sides() -> void:
	sides.clear()
	for i in 2:
		sides.append({"idx": i, "units": [], "players": [], "wave": 0, "wave_t": float(cfg["firstWave"]), "boss_spawned": false, "leak": {}})
	units = sides[0]["units"]


## Mitspieler (Seite 0) und Gegner (Seite 1) als Bots
func _spawn_others() -> void:
	var keys: Array = Data.heroes.keys()
	for s in 2:
		for slot in team_size:
			if s == 0 and slot == 0:
				continue                 # das bist du
			var key: String = keys[randi() % keys.size()]
			var p := _make_player(key, s, slot, true)
			var diff: Dictionary = bot_diff if s == 1 else Data.raw["diff"]["normal"]
			p["gold_mul"] = float(diff["goldMul"]) if s == 1 else 1.0
			p["mul"] = float(diff["heroMul"]) if s == 1 else 1.0
			players.append(p)
			sides[s]["players"].append(p)
			bot.setup(p, diff, bot_style)


## Startmenü: Spielmodus (1v1, 2v2, 4v4) und Held wählen.
func _show_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	bot_style = "random"                  # Gegner-Stil und Build werden je Gegner zufällig gemischt (kein Menüpunkt)
	var mm := MainMenuLib.new()
	mm.g = self
	menu_obj = mm
	menu_go = mm.build(menu_layer)
	menu_go.pressed.connect(func():
		menu_layer.queue_free()
		_start_game())


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
func _wp(gx: float, gy: float, side_idx: int = -1) -> Vector3:
	var si := cur_side if side_idx < 0 else side_idx
	return Vector3(gy * S + lane_xs[si * lanes_per_team], 0.0, -gx * S)


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
	var p := deg_to_rad(cam_pitch)
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

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	mc = NachtLib.COLORS if map_theme == "nachtwald" else {"ground": Color("#4b6b30"), "lane": Color("#a89462"), "strip": Color("#8d7d55"), "wall": Color("#4c4f55"), "wall_top": Color("#5f636b"), "river": Color("#1f5fa8"), "plaza": Color("#8b8272"), "fog": Color(0.62, 0.68, 0.78, 0.72)}
	decor = NachtLib.new(self)
	if map_theme == "nachtwald":
		decor.setup_environment(env, sun)
	_build_map()
	_build_fog()

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
	_box(Vector3(mid_x, -0.5, z_mid), Vector3(span + 120.0, 1.0, z_len + 30.0), mc["ground"])            # Boden (Gras bzw. dunkle Erde)
	var wall_list: Array = []
	for i in n:
		var cx: float = lane_xs[i]
		var k := i % lanes_per_team
		_box(Vector3(cx, -0.04, z_mid + 4.0), Vector3(half * 2.0, 0.1, z_len - 8.0), mc["lane"])       # Lane (Weg)
		_box(Vector3(cx, 0.02, z_mid + 4.0), Vector3(half * 0.5, 0.06, z_len - 8.0), mc["strip"])       # Pflasterstreifen in der Mitte
		var sides: Array = [1.0] if k > 0 else [-1.0, 1.0]   # Lanes desselben Teams teilen sich eine Wand (nur rechts bauen)
		for side in sides:
			var wall_x: float = cx + side * (half + WALL / 2.0)
			wall_list.append({"x": wall_x, "gapped": lanes_per_team == 2 and k == 0 and side > 0.0})
			if lanes_per_team == 2 and k == 0 and side > 0.0:
				_gapped_wall(wall_x)                                  # gemeinsame Wand mit Durchgängen (Helden können die Lane wechseln)
			elif map_theme != "nachtwald":                       # im Nachtwald stehen Bäume statt der Wand (map_nachtwald.gd)
				_box(Vector3(wall_x, 1.1, z_mid - 6.0), Vector3(WALL, 2.4, lane_len + 2.0), mc["wall"])   # Wand (Fels bzw. dunkles Unterholz)
				_box(Vector3(wall_x, 2.45, z_mid - 6.0), Vector3(WALL - 1.0, 0.5, lane_len + 2.0), mc["wall_top"])
	var river_x: float = (lane_xs[lanes_per_team - 1] + lane_xs[lanes_per_team]) / 2.0
	var river_box := _box(Vector3(river_x, -0.06, z_mid - 6.0), Vector3(5.0, 0.2, lane_len + 2.0), mc["river"])           # Fluss (Wasser bzw. Lava) zwischen den Teams
	if map_theme == "nachtwald":
		var lm := river_box.material_override as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission = Color("#ff4a14")
		lm.emission_energy_multiplier = 1.8
	var spawn_z := -float(cfg["spawnX"]) * S
	for i in n:
		_box(Vector3(lane_xs[i], 0.03, spawn_z - 2.0), Vector3(half * 2.0, 0.06, 6.0), Color("#6e2a2a"))     # Monster-Spawn
	# Platz am unteren Ende (Basis): Pflaster, magischer Kreis, Feuerstellen
	var plaza_z := 7.0
	var plaza_r := span / 2.0 + 6.0
	var plaza := _cyl(Vector3(mid_x, -0.02, plaza_z), plaza_r, 0.1, mc["plaza"])
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
		sm.radius = 0.7
		sm.height = 2.2
		crystal.mesh = sm
		crystal.position = Vector3(cx, 1.9, 0.8)
		var cmat := _mat(col)
		cmat.emission_enabled = true
		cmat.emission = col
		cmat.emission_energy_multiplier = 1.4
		crystal.material_override = cmat
		add_child(crystal)
		var ll := _label3d("", 44, col)
		ll.position = Vector3(cx, 3.8, 0.8)
		add_child(ll)
		life_labels.append(ll)
	if map_theme == "nachtwald":
		if not test_mode:
			decor.decorate(wall_list, river_x, lane_xs, half, x_min, x_max)
		return
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
	_box(Vector3(wall_x, -0.04, -(x0 + x1) / 2.0 * S), Vector3(WALL + 0.2, 0.1, (x1 - x0) * S), mc["lane"])


func _wall_piece(wall_x: float, x0: float, x1: float) -> void:
	if x1 <= x0 or map_theme == "nachtwald":
		return
	var zc := -(x0 + x1) / 2.0 * S
	var len := (x1 - x0) * S
	_box(Vector3(wall_x, 1.1, zc), Vector3(WALL, 2.4, len), mc["wall"])
	_box(Vector3(wall_x, 2.45, zc), Vector3(WALL - 1.0, 0.5, len), mc["wall_top"])


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


## Gegner-Seite ist in der 3D-Ansicht verdeckt (Nebelwand hinter dem Fluss): Infos dazu gibt nur die Minimap.
func _build_fog() -> void:
	if test_mode:
		return
	var river_x: float = (lane_xs[lanes_per_team - 1] + lane_xs[lanes_per_team]) / 2.0 + 2.5
	var lane_len: float = cfg["laneLen"] * S
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(200.0, 14.0, lane_len + 160.0)
	box.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = mc["fog"]      # Nebel: Gelände schimmert durch, Gegner bleiben unsichtbar
	box.material_override = mat
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.position = Vector3(river_x + 100.0, 7.0, -lane_len / 2.0)
	add_child(box)


## Lebensbalken (blickt immer zur Kamera). Gibt {node, fill, w} zurück; Füllung mit set_bar() ändern.
func _make_bar(w: float, h: float, y: float) -> Dictionary:
	var node := Node3D.new()
	node.position.y = y
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(w + 0.1, h + 0.1)
	back.mesh = bq
	back.material_override = _bar_mat(Color(0.05, 0.05, 0.05, 0.85), 0)
	node.add_child(back)
	var holder := Node3D.new()
	holder.position.x = -w / 2.0
	node.add_child(holder)
	var fill := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, h)
	fq.center_offset = Vector3(0.5, 0, 0)
	fill.mesh = fq
	fill.scale.x = w
	fill.material_override = _bar_mat(Color("#4cd964"), 1)
	holder.add_child(fill)
	return {"node": node, "fill": fill, "w": w}


func _bar_mat(col: Color, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	m.albedo_color = col
	return m


func _set_bar(fill: MeshInstance3D, w: float, frac: float, ally: bool) -> void:
	frac = clampf(frac, 0.0, 1.0)
	fill.scale.x = maxf(0.001, w * frac)
	var c: Color = Data.user.hp_good().lerp(Data.user.hp_bad(), 1.0 - frac) if ally else Data.user.hp_enemy()
	(fill.material_override as StandardMaterial3D).albedo_color = c


func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat


## Testfenster (F2), wie im Browser-Prototyp: Werte des eigenen Helden und der Partie verstellen, ohne lange zu spielen.
func _build_test_panel(layer: CanvasLayer) -> void:
	test_panel = PanelContainer.new()
	test_panel.anchor_left = 1.0
	test_panel.anchor_right = 1.0
	test_panel.offset_left = -352.0
	test_panel.offset_right = -12.0
	test_panel.custom_minimum_size = Vector2(340, 0)
	test_panel.offset_top = 10.0
	test_panel.add_theme_stylebox_override("panel", _flat(Color(0.1, 0.12, 0.17, 0.92)))
	test_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	test_panel.add_child(box)
	var head := Label.new()
	head.text = "Testfenster (F2)"
	head.add_theme_color_override("font_color", Color("#ffd166"))
	box.add_child(head)
	for row in [["Level", "lvl", -1], ["Freie Skillpunkte", "sp", -1], ["Rang Q", "rank0", 0], ["Rang W", "rank1", 1], ["Rang E", "rank2", 2], ["Rang R", "rank3", 3]]:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = row[0]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var key: String = row[1]
		for d in [-1, 1]:
			var b := Button.new()
			b.text = "−" if d < 0 else "+"
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(30, 0)
			var dd: int = d
			b.pressed.connect(func(): _dbg(key, dd))
			h.add_child(b)
			if d < 0:
				var v := Label.new()
				v.custom_minimum_size = Vector2(34, 0)
				v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				test_vals[key] = v
				h.add_child(v)
		box.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 2
	for bt in [["Alles max", "allmax"], ["Skills zurücksetzen", "reset"], ["Cooldowns 0", "cd"], ["+1000 Gold", "gold"], ["Welle jetzt", "wave"], ["Monster löschen", "clear"],
			["Übungspuppen", "dummies"], ["Unsterblich: aus", "god"], ["Gegner-Leben ∞: aus", "inf"], ["Held heilen", "heal"]]:
		var b2 := Button.new()
		b2.text = bt[0]
		b2.focus_mode = Control.FOCUS_NONE
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var act: String = bt[1]
		b2.pressed.connect(func(): _dbg(act, 0))
		grid.add_child(b2)
		test_vals[act] = b2
	box.add_child(grid)
	var note := Label.new()
	note.text = "Ränge ohne Level-Sperre.
Puppen: stehende Monster zum Ausprobieren."
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)
	layer.add_child(test_panel)


## Aktion des Testfensters
func _dbg(a: String, d: int) -> void:
	if hero.is_empty():
		return
	var mx := int(cfg["maxLevel"])
	if a == "lvl":
		hero["lvl"] = clampi(hero["lvl"] + d, 1, mx)
		hero["xp"] = 0.0
		hero["hp"] = minf(maxf(hero["hp"], 1.0), skills.h_max_hp(hero))
	elif a == "sp":
		hero["sp"] = maxi(0, hero["sp"] + d)
	elif a.begins_with("rank"):
		var i := int(a.substr(4))
		hero["ranks"][i] = clampi(hero["ranks"][i] + d, 0, int(skills.skill_def(hero, i)["max"]))
	elif a == "allmax":
		hero["lvl"] = mx
		for i in 4:
			hero["ranks"][i] = int(skills.skill_def(hero, i)["max"])
		hero["sp"] = 0
		hero["hp"] = skills.h_max_hp(hero)
	elif a == "reset":
		hero["ranks"] = [0, 0, 0, 0]
		hero["sp"] = hero["lvl"]
	elif a == "cd":
		hero["cds"] = [0.0, 0.0, 0.0, 0.0]
		hero["bp_cd"] = 0.0
		hero["pot_cd"] = 0.0
	elif a == "gold":
		hero["gold"] += 1000.0
	elif a == "wave":
		cur_side = 0
		_spawn_wave(sides[0])
	elif a == "clear":
		for u in units.duplicate():
			_free(u["node"])
		units.clear()
	elif a == "dummies":                  # 9 stehende, sehr zähe Monster vor dem Helden
		for i in 9:
			_spawn_unit("grunt", 0.0, 1.0, hero["lane"], 0)
			var u: Dictionary = units[units.size() - 1]
			u["x"] = hero["x"] + 170.0 + (i % 3) * 55.0 + (i / 3) * 40.0
			u["y"] = hero["y"] - 70.0 + (i / 3) * 70.0 + (i % 3) * 20.0
			u["hp"] = 1e6
			u["max"] = 1e6
			u["stun"] = 1e7
	elif a == "god":
		hero["god"] = not hero.get("god", false)
	elif a == "inf":
		team_lives[1] = int(cfg["startLives"]) if team_lives[1] > 100000000 else 1000000000
	elif a == "heal":
		hero["hp"] = skills.h_max_hp(hero)
		hero["dead"] = 0.0


func _update_test_panel() -> void:
	if test_panel == null or not test_panel.visible or hero.is_empty():
		return
	(test_vals["lvl"] as Label).text = str(hero["lvl"])
	(test_vals["sp"] as Label).text = str(hero["sp"])
	for i in 4:
		(test_vals["rank%d" % i] as Label).text = str(hero["ranks"][i])
	(test_vals["god"] as Button).text = "Unsterblich: " + ("an" if hero.get("god", false) else "aus")
	(test_vals["inf"] as Button).text = "Gegner-Leben ∞: " + ("an" if team_lives[1] > 100000000 else "aus")


## Lautstärkeregler oben rechts (wird gespeichert). 0 = stumm.
func _build_volume_slider(layer: CanvasLayer) -> void:
	if snd == null:
		return
	var box := HBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -230.0
	box.offset_right = -12.0
	box.offset_top = 8.0
	box.offset_bottom = 34.0
	box.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = "Ton"
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 6)
	box.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 100.0
	sl.step = 1.0
	sl.value = snd.volume * 100.0
	sl.custom_minimum_size = Vector2(150, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float):
		snd.volume = v / 100.0
		_save_volume(v / 100.0))
	box.add_child(sl)
	layer.add_child(box)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_test_panel(layer)
	vignette = TextureRect.new()         # roter Rand: Lebensverlust, Tod, wenig Leben
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.1, 0.1, 0.0), Color(1, 0.1, 0.1, 0.9)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	vignette.texture = gtex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	layer.add_child(vignette)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 15)
	var hud_panel := PanelContainer.new()                # Schild oben links (Gold, Einkommen, Leben, Welle, Zeit)
	hud_panel.position = Vector2(8, 8)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(hud)
	layer.add_child(hud_panel)
	hud_mid = Label.new()                                # Plakette oben in der Mitte: Welle und Zeit
	hud_mid.add_theme_font_size_override("font_size", 17)
	hud_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid_panel := PanelContainer.new()
	mid_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mid_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mid_panel.position.y = 8.0
	mid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_panel.add_child(hud_mid)
	layer.add_child(mid_panel)
	hud_right = Label.new()                              # rechts oben: Kills
	hud_right.add_theme_font_size_override("font_size", 15)
	var right_panel := PanelContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.position = Vector2(-8, 8)
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel.add_child(hud_right)
	layer.add_child(right_panel)
	msg = Label.new()
	msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg.position = Vector2(-120, 80)
	msg.add_theme_font_size_override("font_size", 40)
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	msg.add_theme_constant_override("outline_size", 8)
	layer.add_child(msg)
	pause_label = Label.new()
	pause_label.text = "PAUSE  (P oder Esc: weiter)"
	pause_label.set_anchors_preset(Control.PRESET_CENTER)
	pause_label.position = Vector2(-150, -40)
	pause_label.add_theme_font_size_override("font_size", 36)
	pause_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_label.add_theme_constant_override("outline_size", 8)
	pause_label.visible = false
	layer.add_child(pause_label)
	alerts_box = VBoxContainer.new()     # Meldungen oben in der Mitte
	alerts_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alerts_box.offset_left = -320.0
	alerts_box.offset_right = 320.0
	alerts_box.offset_top = 150.0
	alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(alerts_box)
	boss_bar = ProgressBar.new()         # Boss-Lebensleiste
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.offset_left = -190.0
	boss_bar.offset_right = 190.0
	boss_bar.offset_top = 46.0
	boss_bar.offset_bottom = 70.0
	boss_bar.show_percentage = false
	boss_bar.visible = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_theme_stylebox_override("fill", _flat(Color("#ff4d4d")))
	boss_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.6)))
	layer.add_child(boss_bar)
	boss_label = Label.new()
	boss_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 14)
	boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_label.add_theme_constant_override("outline_size", 4)
	boss_bar.add_child(boss_label)
	mini = Control.new()                 # Minimap unten links
	mini.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mini.offset_left = 14.0
	mini.offset_right = 14.0 + MINI_W
	mini.offset_bottom = -14.0
	mini.offset_top = -14.0 - MINI_H
	_build_skillbar(layer)
	_build_shop(layer)
	_build_send_panel(layer)
	mini.clip_contents = true
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.draw.connect(_draw_minimap)
	mini.gui_input.connect(_mini_input)
	layer.add_child(mini)


func send(p: Dictionary, type: String) -> bool:
	var ud: Dictionary = Data.units[type]
	if over or ud.get("noSend", false) or p["gold"] < float(ud["cost"]):
		return false
	p["gold"] -= float(ud["cost"])
	p["income"] += float(ud["inc"]) * float(cfg["incMul"])              # Senden erhöht dein Einkommen
	p["sent"][type] = p["sent"].get(type, 0) + 1
	if p == hero:
		sfx("send")
	var es: int = 1 - int(p["side"]["idx"])
	for lane in lanes_per_team:                                         # das Monster erscheint auf allen Lanes des Gegner-Teams
		_spawn_unit(type, 0.0, 1.0, lane, es, int(p["side"]["idx"]))
	return true


func _update_send() -> void:
	for e in send_btns:
		var ud: Dictionary = Data.units[e["type"]]
		e["btn"].disabled = hero["gold"] < float(ud["cost"]) or over
		e["btn"].text = "%s  %s  %d g  (+%s)" % [Data.user.key_name("send_" + str(e["type"])), str(ud["name"]), int(ud["cost"]), str(ud["inc"])]


## Monster-Senden-Leiste (links): Taste, Name, Kosten und Einkommen. Senden kostet Gold und erhöht dein Einkommen.
func _build_send_panel(layer: CanvasLayer) -> void:
	var frame := PanelContainer.new()                    # Steintafel links
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)                  # unter der Anzeige oben links, bleibt auch bei großer Oberfläche über der Minimap
	frame.offset_left = 8.0
	frame.offset_right = 262.0
	frame.offset_top = 72.0
	frame.offset_bottom = 302.0
	layer.add_child(frame)
	var box := VBoxContainer.new()
	frame.add_child(box)
	var head := Label.new()
	head.text = "Monster senden"
	head.add_theme_color_override("font_color", Color("#ffd166"))
	head.add_theme_font_size_override("font_size", 14)
	box.add_child(head)
	send_btns.clear()
	var keys := {"grunt": "Z", "tank": "X", "archer": "C", "fast": "V", "elite": "N"}
	for type in ["grunt", "tank", "archer", "fast", "elite"]:
		var ud: Dictionary = Data.units[type]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  %s  %d g  (+%s)" % [keys[type], str(ud["name"]), int(ud["cost"]), str(ud["inc"])]
		b.tooltip_text = "%s\nKosten %d Gold, Einkommen +%s pro %d s\nLeben %d, Schaden %d, Rüstung %d\nKommt auf allen Lanes des Gegner-Teams an.\nDer Gegner bekommt XP und Gold, wenn er es besiegt." % [
			str(ud["name"]), int(ud["cost"]), str(ud["inc"]), int(cfg["incomeTick"]), int(ud["hp"]), int(ud["dmg"]), int(ud["armor"])]
		var tp: String = type
		b.pressed.connect(func(): send(hero, tp))
		box.add_child(b)
		send_btns.append({"type": type, "btn": b})


## Shop (Taste Tab oder Knopf) und Rucksack (immer sichtbar, unten rechts). Kaufen geht nur in der Basis.
func _build_shop(layer: CanvasLayer) -> void:
	# Rucksack, Heiltrank und Knöpfe sitzen in der unteren Leiste (hud_stein.gd), das Shop-Fenster steht in shop_stein.gd
	shop = ShopLib.new(self)
	shop.build(layer)

func _item_tip(id: String) -> String:
	var it: Dictionary = items.item[id]
	var tip := "%s\n%s" % [str(it["name"]), str(it["desc"])]
	if it.has("parts"):
		var names: Array = []
		for part in it["parts"]:
			names.append(str(items.item[part]["name"]))
		tip += "\n\nRezept: %s\nRezeptgeld %d, Gesamtpreis %d" % [" + ".join(names), int(it["cost"]), items.total_cost(id)]
	if it["group"] != "verbrauch":
		tip += "\nVerkauf: %d Gold" % int(floor(items.total_cost(id) * float(cfg["sellRatio"])))
	return tip


func _toggle_shop() -> void:
	if shop != null:
		shop.toggle()
		if OS.get_cmdline_user_args().has("--shoptab"):
			shop._set_tab(1)
			shop._select("arcaneCrown")
			shop._select("bigStaff", false)


func _update_shop() -> void:
	if shop_btn == null or hero.is_empty():
		return
	var in_base := _in_base()
	pot_btn.text = "Trank\n(%s)  x%d%s" % [Data.user.key_name("potion"), hero["cons"]["potion"], ("\n%ds" % int(ceil(hero["pot_cd"]))) if hero["pot_cd"] > 0.0 else ""]
	for i in bag_btns.size():
		var b: Button = bag_btns[i]
		if i < hero["bag"].size():
			var id: String = hero["bag"][i]
			var bic: Control = b.get_meta("icon")
			b.text = ""
			bic.visible = true
			bic.set_item(id, shop._tier(id))
			b.tooltip_text = _item_tip(id) + "\n(Klick: verkaufen, nur in der Basis)"
		else:
			(b.get_meta("icon") as Control).visible = false
			b.text = ""
			b.tooltip_text = "leerer Platz"
	if shop != null:
		shop.update()


## Skill-Leiste unten in der Mitte: 4 Plätze (Q W E R) mit Rang, Abklingzeit und "+" zum Lernen.
func _build_skillbar(layer: CanvasLayer) -> void:
	ui = HudStein.new(self)
	get_window().theme = HudStein.make_theme(ui.pal)     # Farben der Klasse (Tank Eisen, Schurke dunkel, Magier lila)
	ui.build_bar(layer, MINI_W)
	if shop != null:
		layer.move_child(shop.root, -1)                        # Shop liegt über Leiste, Minimap und Senden-Feld
	ui.build_menu(layer)


func _update_skillbar() -> void:
	if ui != null:
		ui.update()


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
	var own_x_max: float = lane_xs[lanes_per_team - 1] + lane_half_g * S      # Gegner-Seite ist nicht einsehbar
	cam_focus = Vector3(minf(wx, own_x_max), 0.0, clampf(wz, m["z_top"], m["z_bot"]))
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
	if ui != null:
		mini.draw_rect(Rect2(1.5, 1.5, MINI_W - 3.0, MINI_H - 3.0), ui.pal["border"], false, 3.0)     # Rahmen in den Farben der Klasse
	var river_x: float = (lane_xs[lanes_per_team - 1] + lane_xs[lanes_per_team]) / 2.0
	var rp := _mini_pt(m, river_x - 2.5, z_top)
	mini.draw_rect(Rect2(rp.x, rp.y, 5.0 * m["sx"], (z_bot - z_top) * m["sy"]), mc["river"])
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
	for u in units:                       # Monster auf deinen Lanes: rot
		var d: Dictionary = u["def"]
		var r := 2.5 + clampf(float(d["r"]) / 9.0, 0.0, 4.0) * 0.8
		var w := _wp(u["x"], u["y"], 0)
		mini.draw_circle(_mini_pt(m, w.x, w.z), r, Color("#ff3030"))
	for u in sides[1]["units"]:           # Gegner-Lane: nur deine gesendeten Monster im sichtbaren Abschnitt (orange)
		if u["from_side"] == 0 and u["x"] <= float(ENEMY_LANE_VIEW):
			var w2 := _wp(u["x"], u["y"], 1)
			mini.draw_circle(_mini_pt(m, w2.x, w2.z), 3.0, Color("#ffb040"))
	for p in sides[0]["players"]:         # Helden deines Teams
		if p["dead"] <= 0.0:
			var hw := _wp(p["x"], p["y"], 0)
			var hp := _mini_pt(m, hw.x, hw.z)
			mini.draw_circle(hp, 5.5 if p == hero else 4.0, Color.WHITE)
			mini.draw_circle(hp, 4.0 if p == hero else 2.8, Color.html(p["d"]["col"]))
	if cam != null and cam_init:          # Sichtfeld der Kamera
		var sz := get_viewport().get_visible_rect().size
		var pts := PackedVector2Array()
		for c in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y), Vector2(0, 0)]:
			var g := _ground_point(c)
			pts.append(_mini_pt(m, g.x, g.z))
		mini.draw_polyline(pts, Color(1, 1, 1, 0.75), 1.5)
	mini.draw_rect(Rect2(0, 0, MINI_W, MINI_H), Color("#b49a5c"), false, 4.0)


func _flat(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	return sb


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


## Erzeugt den Spieler am Computer (Seite 0, Platz 0).
func _spawn_hero() -> void:
	players.clear()
	for s in sides:
		s["players"].clear()
	hero = _make_player(hero_key, 0, 0, false)
	players.append(hero)
	sides[0]["players"].append(hero)


## Erzeugt einen Spieler (Held) auf einer Seite. Gold, Einkommen, Rucksack, Skills usw. hat jeder Spieler selbst.
func _make_player(key: String, side_idx: int, slot: int, bot: bool) -> Dictionary:
	var d: Dictionary = Data.heroes[key]
	var per_lane := int(ceil(float(team_size) / lanes_per_team))
	var lane_k := slot / per_lane
	var home_y: float = lane_off_g[lane_k] + slot_ys[slot % per_lane]
	var node := Node3D.new()
	var fig: Dictionary = {}
	if not test_mode and HERO_MODEL.has(key):
		fig = _make_figure(HERO_MODEL[key][0], float(HERO_MODEL[key][4]))
		if not fig.is_empty() and key == "tank":          # Tank: breiter und mit Schild am linken Arm
			(fig["inner"] as Node3D).scale *= Vector3(1.12, 1.0, 1.12)
			vfx.attach_shield(fig)
		if not fig.is_empty() and key == "damage":          # Schurke: zweiter Dolch in der linken Hand
			vfx.attach_offhand_dagger(fig)
	if fig.is_empty():
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.6
		cap.height = 2.0
		body.mesh = cap
		body.position.y = 1.0
		body.material_override = _mat(Color.html(d["col"]))
		node.add_child(body)
	else:
		node.add_child(fig["model"])
	var team_col := Color("#4fd8ff") if side_idx == 0 else Color("#ff6a4a")      # Teamfarbe unter dem Helden
	var team_ring := _cyl(Vector3(0, 0.05, 0), 1.0, 0.04, team_col, team_col)
	remove_child(team_ring)
	node.add_child(team_ring)
	var lab := _label3d("", 30, Color("#e8e8e8"))
	lab.position.y = 4.0
	node.add_child(lab)
	var hbar := _make_bar(2.2, 0.22, 3.4)
	node.add_child(hbar["node"])
	add_child(node)
	var ring := _cyl(Vector3(0, 0.08, 0), 1.6, 0.04, Color("#7fd6ff"), Color("#7fd6ff"))   # Backport-Anzeige am Boden
	ring.visible = false
	remove_child(ring)                   # _cyl hängt es an die Szene, hier gehört es an den Helden
	node.add_child(ring)
	return {"key": key, "d": d, "side": sides[side_idx], "bot": bot, "slot": slot, "home_y": home_y, "lane": lane_k,
		"x": 120.0, "y": home_y, "lvl": 1, "xp": 0.0, "hp": float(d["hp"]), "dead": 0.0, "mul": 1.0,
		"atk_t": 0.0, "target": null, "move_to": null, "deaths": 0, "node": node, "label": lab, "bar": hbar["fill"], "bar_w": hbar["w"], "fig": fig, "px": 0.0, "py": 0.0,
		"bp": 0.0, "bp_cd": 0.0, "ring": ring,
		"gold": float(cfg["startGold"]), "income": float(cfg["baseIncome"]),     # jeder Spieler hat eigenes Gold und Einkommen
		"ranks": [0, 0, 0, 0], "cds": [0.0, 0.0, 0.0, 0.0], "sp": 1, "buffs": {}, "leap": null,
		"last_elem": "", "combo_t": 0.0, "amp_now": false,
		"bonus_hp": 0.0, "bonus_dmg": 0.0, "bonus_armor": 0.0, "bonus_as": 0.0, "bonus_sp": 0.0, "bonus_spd": 0.0,
		"uniq": {}, "spell_vamp": 0.0, "cdr": 0.0, "bonus_regen": 0.0, "dr": 0.0,
		"bag": [], "cons": {"potion": 0}, "pot_cd": 0.0, "crit_ch": 0.0, "lifesteal": 0.0, "gps": 0.0, "bp_red": 0.0, "dmg_t": 99.0, "bp_max": 0.0,
		"boss_income": 0.0, "sent": {}, "kills": 0, "gold_mul": 1.0, "stat_gold": 0.0}


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


func _in_base(p: Dictionary = {}) -> bool:
	var q: Dictionary = p if not p.is_empty() else hero
	return q["x"] < float(cfg["baseX"]) and q["dead"] <= 0.0


## Monster auf der Seite des Spielers `p` (seine Gegner)
func units_of(p: Dictionary) -> Array:
	return p["side"]["units"]


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
		timers.append({"t": delay, "fn": fn, "side": cur_side})   # Seite merken: Effekte werden später für dieselbe Seite gezeichnet


func cancel_backport(p: Dictionary) -> void:
	p["bp"] = 0.0


func clamp_lane_y(y: float) -> float:
	var ly := lane_half_g - 10.0
	return clampf(y, -ly, lane_off_g[lanes_per_team - 1] + ly)


## Quälende Maske: Fähigkeitstreffer starten einen Schaden-über-Zeit-Effekt (pro Ziel mit Abklingzeit)
func apply_torment(p: Dictionary, u: Dictionary) -> void:
	if not p["uniq"].has("torment") or not units_of(p).has(u) or u["torm_cd"] > 0.0:
		return
	u["torm_t"] = float(cfg["tormentTime"])
	u["torm_tick"] = float(cfg["tormentEvery"])
	u["torm_dmg"] = float(cfg["tormentFlat"]) + float(cfg["tormentAp"]) * skills.h_sp(p) + float(cfg["tormentPct"]) * u["max"]
	u["torm_cd"] = float(cfg["tormentCd"])


## Sound abspielen (nur im echten Spiel; nur für Ereignisse deines Helden/Teams, damit es nicht zu laut wird)
func sfx(name: String) -> void:
	if snd != null and not test_mode:
		snd.play(name)


func sfx_cast(p: Dictionary, i: int) -> void:
	if p == hero and p["key"] != "caster" and not (p["key"] in ["tank", "damage"] and snd != null and snd.streams.has(str(p["key"]) + "_" + "qwer"[i])):      # Caster und Tank haben eigene Klänge je Fähigkeit (sfx_p)
		sfx("cast%d" % i)


## Klang einer Fähigkeit: nur für deine Seite hörbar (Mitspieler leiser). vol 0..1, pitch 1 = normal.
const HEAR_NEAR := 20.0              # m: bis zu dieser Entfernung vom Zuhörer (Held bzw. Kamera) volle Lautstärke
const HEAR_FAR := 60.0               # m: ab hier unhörbar


## Lautstärke (0..1) eines Geräuschs an Spielposition (x, y) auf Seite side_idx, abhängig vom Abstand zum Zuhörer
func hear_gain(x: float, y: float, side_idx: int) -> float:
	var lp: Vector3 = cam_focus if cam_free else (hero["node"] as Node3D).position
	var sp := _wp(x, y, side_idx)
	var d := Vector2(lp.x - sp.x, lp.z - sp.z).length()
	var f := clampf(1.0 - (d - HEAR_NEAR) / (HEAR_FAR - HEAR_NEAR), 0.0, 1.0)
	return f * f


func sfx_p(p: Dictionary, name: String, vol: float = 1.0, pitch: float = 1.0, at: Variant = null) -> void:
	if snd == null or test_mode or hero.is_empty() or p["side"]["idx"] != hero["side"]["idx"]:
		return
	var pos := Vector2(p["x"], p["y"]) if at == null else (at as Vector2)
	var gain := hear_gain(pos.x, pos.y, p["side"]["idx"])      # weit weg = leiser, sehr weit = gar nicht
	if gain < 0.03:
		return
	snd.play(name, vol * (1.0 if p == hero else 0.45) * gain, pitch, p == hero)


## Wie sfx_p, aber nach `delay` Sekunden (Echtzeit, nur Optik/Ton)
func sfx_after(p: Dictionary, name: String, delay: float, vol: float = 1.0, pitch: float = 1.0, at: Variant = null) -> void:
	if test_mode or snd == null:
		return
	get_tree().create_timer(delay).timeout.connect(func(): sfx_p(p, name, vol, pitch, at))


## Bildschirmwackeln, wenn ein Einschlag nahe beim Helden liegt
func shake_near(pos: Vector3, px: float) -> void:
	if test_mode or hero.is_empty():
		return
	var d: float = pos.distance_to((hero["node"] as Node3D).position)
	shake(px * clampf(1.0 - d / 40.0, 0.0, 1.0))


## Zauberpose: Figur dreht sich zum Ziel und spielt die Angriffsanimation neu ab
func cast_pose(p: Dictionary, tx: float, ty: float, anim: String = "", secs: float = 0.55, speed: float = 1.0) -> void:
	var fig: Dictionary = p.get("fig", {})
	if fig.is_empty():
		return
	fig["force"] = secs
	fig["force_speed"] = speed
	fig["force_anim"] = anim
	fig["face"] = Vector2(tx, ty)
	fig["cur"] = ""


## Bildschirmwackeln (px) und roter Blitz (0..1); nur für deine Seite
func shake(px: float) -> void:
	if not test_mode and shake_on:
		shake_amt = maxf(shake_amt, px)


func flash(a: float) -> void:
	if not test_mode:
		flash_a = maxf(flash_a, a)


func _free(n: Variant) -> void:
	if n != null:
		n.queue_free()


func add_zone(z: Dictionary) -> void:
	z["side"] = cur_side
	if test_mode:
		z["node"] = null
		zones.append(z)
		return
	var node := MeshInstance3D.new()
	var col := Color.html(z["c"])
	var mat := _fx_mat(col)
	if z.has("kind"):                    # Feld mit Partikeln (Feuer, Frost): weiche Bodenfläche statt Scheibe
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * float(z["r"]) * S * 2.0
		qm.orientation = PlaneMesh.FACE_Y
		node.mesh = qm
		mat = vfx._flat_mat(vfx.tex_disc, col, true)
		z["a0"] = float(z.get("a0", 0.3))
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = float(z["r"]) * S
		cm.bottom_radius = cm.top_radius
		cm.height = 0.04
		node.mesh = cm
	node.material_override = mat
	z["node"] = node
	z["mat"] = mat
	z["col"] = col
	add_child(node)
	node.position = _wp(z["x"], z["y"]) + Vector3(0, 0.1, 0)
	zones.append(z)
	if z.has("kind"):
		vfx.zone_attach(z)


func set_elementar(e: Dictionary) -> void:
	for old in elems:
		_free(old["node"])
	elems.clear()
	if test_mode:
		e["node"] = null
		elems.append(e)
		return
	var col := Color.html(skills.ELEM_COL[e["type"]])
	var node: Node3D = vfx.make_elemental(str(e["type"]))
	var lab := _label3d("", 28, col)
	lab.position.y = 3.0
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


func fx_cone(x: float, y: float, ang: float, r: float, half: float, life: float, col: String, alpha0: float = 0.5) -> void:
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
	_fx_add(node, mat, life, c, alpha0)


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
	var fog_x: float = lane_xs[lanes_per_team - 1] + lane_half_g * S + WALL
	for n in fx_nodes.duplicate():       # Partikel und Lichter: nach Ablauf entfernen, auf der Gegner-Seite ausblenden
		if not is_instance_valid(n["node"]):
			fx_nodes.erase(n)
			continue
		n["t"] -= delta
		if n["t"] <= 0.0:
			n["node"].queue_free()
			fx_nodes.erase(n)
		else:
			n["node"].visible = n["node"].position.x < fog_x
	for z in zones:
		var c: Color = z["col"]
		c.a = float(z.get("a0", 0.22)) + 0.1 * sin(t * 6.0)
		z["mat"].albedo_color = c
		z["node"].position = _wp(z["x"], z["y"], z["side"]) + Vector3(0, 0.1, 0)
		z["node"].visible = z["node"].position.x < fog_x
	vfx.tick(delta, t)
	for e in elems:
		e["node"].position = _wp(e["x"], e["y"], e["p"]["side"]["idx"])
		e["node"].visible = e["node"].position.x < fog_x
		e["label"].text = "%s  %d  (%ds)" % [str(e["type"]).capitalize(), int(e["hp"]), int(e["t"])]


# ---------------------------------------------------------------- Einheiten und Wellen
## Erzeugt ein Monster auf einer Lane der Seite `side_idx`. from_side: Seite, die es geschickt hat (-1 = Welle).
## Figuren (Quaternius, CC0, als Platzhalter): werden zur Laufzeit aus den glTF-Dateien geladen und gemerkt.
const MODEL_DIR := "res://assets/quaternius/"
## Held-Modelle: [Datei, Angriffsanimation, Laufanimation, Ruheanimation, Höhe in m]
const HERO_MODEL := {"tank": ["rpg/Warrior.gltf", "Sword_Attack", "Run_Weapon", "Idle_Weapon", 3.0], "damage": ["rpg/Rogue.gltf", "Dagger_Attack", "Run", "Idle", 2.8], "caster": ["rpg/Wizard.gltf", "Staff_Attack", "Run", "Idle", 2.8]}
const UNIT_MODEL := {"grunt": "GreenDemon", "tank": "Cyclops", "archer": "Skull", "fast": "Bat", "elite": "Demon", "boss": "YellowDragon"}
const LOOP_ANIMS := ["Idle", "Walk", "Run", "Flying", "Attacking_Idle", "Run_Weapon", "Idle_Weapon"]
var model_cache: Dictionary = {}


## Lädt ein Modell und skaliert es auf die Höhe `height` (m). Gibt {} zurück, wenn es nicht geladen werden kann.
## Ergebnis: {"model": Node3D, "anim": AnimationPlayer, "cur": "", "yaw": 0.0}
func _make_figure(path: String, height: float) -> Dictionary:
	if not model_cache.has(path):
		var root: Node = null
		var st := GLTFState.new()
		var doc := GLTFDocument.new()
		if doc.append_from_file(MODEL_DIR + path, st) == OK:
			root = doc.generate_scene(st)
		var info := {"root": root, "h": 1.0}
		if root != null:
			var top := 0.0
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				top = maxf(top, (mi as MeshInstance3D).get_aabb().end.y * (mi as MeshInstance3D).scale.y)
			info["h"] = maxf(0.1, top)
			var ap0 := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap0 != null:
				for an in ap0.get_animation_list():
					ap0.get_animation(an).loop_mode = Animation.LOOP_LINEAR if an in LOOP_ANIMS else Animation.LOOP_NONE
		model_cache[path] = info
	var ci: Dictionary = model_cache[path]
	if ci["root"] == null:
		return {}
	var model := (ci["root"] as Node).duplicate() as Node3D
	var holder := Node3D.new()
	holder.add_child(model)
	model.scale = Vector3.ONE * (height / float(ci["h"]))
	return {"model": holder, "inner": model, "anim": model.find_child("AnimationPlayer", true, false), "cur": "", "yaw": 0.0}


## Spielt eine Animation, wenn sie sich ändert (weich übergeblendet).
func _play_anim(fig: Dictionary, name: String) -> void:
	var ap: AnimationPlayer = fig["anim"]
	if ap == null or fig["cur"] == name or not ap.has_animation(name):
		return
	fig["cur"] = name
	ap.play(name, 0.15)


func _spawn_unit(type: String, off_x: float, spd_mul: float, lane: int = 0, side_idx: int = 0, from_side: int = -1) -> void:
	var u: Dictionary = Data.units[type]
	var m := _hp_mult()
	var node: Node3D = null
	var bar: Dictionary = {}
	if not test_mode:
		node = Node3D.new()
		var mh := float(u["r"]) * S * 2.8                    # Figurhöhe in Metern
		var fig := _make_figure("monsters/%s.gltf" % UNIT_MODEL[type], mh)
		if fig.is_empty():                                   # Ersatz, falls das Modell fehlt
			var body := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = float(u["r"]) * S
			sph.height = sph.radius * 2.0
			body.mesh = sph
			body.position.y = sph.radius
			body.material_override = _mat(Color.html(u["col"]))
			node.add_child(body)
		else:
			node.add_child(fig["model"])
			fig["flies"] = type == "fast" or type == "boss"
			bar["fig"] = fig
		var bw := maxf(0.9, float(u["r"]) * S * 2.4)
		var b2 := _make_bar(bw, 0.14 if type != "boss" else 0.28, mh + 0.3)
		bar["node"] = b2["node"]
		bar["fill"] = b2["fill"]
		bar["w"] = b2["w"]
		node.add_child(bar["node"])
		add_child(node)
	var ly: float = lane_half_g - 16.0
	sides[side_idx]["units"].append({"type": type, "lane": lane, "side_idx": side_idx, "from_side": from_side,
		"x": float(cfg["spawnX"]) + off_x + rand_pos() * 30.0, "y": lane_off_g[lane] + (rand_pos() * 2.0 - 1.0) * ly,
		"hp": float(u["hp"]) * m, "max": float(u["hp"]) * m,
		"dmg": float(u["dmg"]) * (1.0 + float(cfg["unitDmgScale"]) * (m - 1.0)),
		"spd": float(u["spd"]) * spd_mul * float(cfg["speedMul"]), "range": float(u["range"]),
		"armor": float(u["armor"]), "r": float(u["r"]), "atk_t": 0.0, "node": node, "def": u, "bar": bar.get("fill"), "bar_w": bar.get("w", 1.0), "fig": bar.get("fig", {}), "px": 0.0, "py": 0.0,
		"stun": 0.0, "slow": 0.0, "burn": 0.0, "burn_dps": 0.0, "burn_t": 0.0, "pois": 0.0, "pois_dps": 0.0, "pois_t": 0.0, "bleed": 0.0, "bleed_pct": 0.0, "bleed_t": 0.0,
		"torm_t": 0.0, "torm_tick": 0.0, "torm_dmg": 0.0, "torm_cd": 0.0, "last_p": {},
		"boss": type == "boss", "phase": 1, "base": float(u["spd"]) * spd_mul * float(cfg["speedMul"]), "stomp_t": 5.0, "summon_t": 12.0})


## Zufallswert für Startpositionen (in Tests fest, damit Läufe vergleichbar sind)
func rand_pos() -> float:
	return 0.5 if deterministic else randf()


func _spawn_wave(side: Dictionary) -> void:
	side["wave"] += 1
	var n: int = side["wave"]
	var count := int(round(float(cfg["waveBase"]) + float(cfg["wavePer"]) * n))
	var from_x: float = minf(float(cfg["spawnX"]), float(cfg["rampStart"]) + float(cfg["rampStep"]) * (n - 1))
	var base_off := from_x - float(cfg["spawnX"])
	var si: int = side["idx"]
	for pl in side["players"]:                # Boss besiegt: dauerhaft Gold pro Welle (wie im Prototyp beim Spawn)
		if pl["boss_income"] > 0.0:
			pl["gold"] += pl["boss_income"]
	var boss_due_done: bool = side["boss_spawned"]      # Merker vor der Schleife: alle Lanes bekommen ihren Boss
	for lane in lanes_per_team:          # jede Lane des Teams bekommt die Welle (gleich groß, egal wie viele Spieler)
		for i in count:
			_spawn_unit("grunt", base_off + i * 4.0, float(cfg["waveSpeedMul"]), lane, si)
		if n % int(cfg["eliteEvery"]) == 0:
			for k in int(cfg["eliteCount"]):
				_spawn_unit("elite", base_off + count * 4.0 + 30.0 + k * 40.0, float(cfg["waveSpeedMul"]), lane, si)
		if n == int(cfg["bossWave"]) and not boss_due_done:                     # ein Boss je Lane (einmalig pro Spiel)
			_spawn_unit("boss", base_off + count * 4.0 + 160.0, float(cfg["waveSpeedMul"]), lane, si)
	if n == int(cfg["bossWave"]):
		side["boss_spawned"] = true
	if si == 0:
		var wk := _wave_kind_after(n, side)
		_flash_msg(("BOSSWELLE %d" if wk == "boss" else ("ELITE-WELLE %d" if wk == "elite" else "Welle %d")) % n, Color("#ff7a7a") if wk == "boss" else (Color("#d9b3ff") if wk == "elite" else Color("#ffd166")))
		sfx("boss" if n == int(cfg["bossWave"]) else "wave")


func _flash_msg(text: String, col: Color = Color.WHITE) -> void:
	if msg == null:
		return
	msg.text = text
	msg.add_theme_color_override("font_color", col)
	get_tree().create_timer(1.5).timeout.connect(func(): if msg.text == text: msg.text = "")


func _kill_unit(u: Dictionary, p: Dictionary = {}) -> void:
	var side: Dictionary = sides[u["side_idx"]]
	side["units"].erase(u)
	_free(u["node"])
	var killer: Dictionary = p
	if killer.is_empty():
		killer = side["players"][0] if not side["players"].is_empty() else hero
	if killer == hero:
		sfx("kill")
	if killer["side"]["idx"] == 0:
		kills += 1
	killer["kills"] += 1
	if u["type"] == "boss":                                           # Boss besiegt: dauerhaft Gold pro Welle für den Töter
		killer["boss_income"] += float(cfg["bossIncome"])
		if killer["side"]["idx"] == 0:
			_flash_msg("BOSS BESIEGT! +%d Gold pro Welle" % int(killer["boss_income"]))
	var def: Dictionary = u["def"]
	var kg: float = float(def["gold"]) if def.has("gold") else float(cfg["killGold"])
	killer["gold"] += kg
	killer["stat_gold"] += kg
	_gain_xp(float(def["xp"]), killer)


func _gain_xp(n: float, p: Dictionary = {}) -> void:
	var pl: Dictionary = p if not p.is_empty() else hero
	pl["xp"] += n
	while pl["lvl"] < int(cfg["maxLevel"]) and pl["xp"] >= _xp_need(pl["lvl"]):
		pl["xp"] -= _xp_need(pl["lvl"])
		pl["lvl"] += 1
		pl["sp"] += 1                                                     # 1 Skillpunkt pro Level, frei verteilbar
		if pl == hero:
			sfx("level")
			ui_alert("LEVEL %d! Skillpunkte frei: %d" % [pl["lvl"], pl["sp"]], "good")
		pl["hp"] += float(pl["d"]["hpl"])
		_float_text("LEVEL %d" % pl["lvl"], _wp(pl["x"], pl["y"], pl["side"]["idx"]) + Vector3(0, 3.2, 0), Color("#ffd166"), 48, 1.2)


func _float_text(text: String, pos: Vector3, col: Color, size: int, life: float) -> void:
	if test_mode:
		return
	var l := _label3d(text, size, col)
	l.position = pos
	add_child(l)
	texts.append({"node": l, "t": life})


## Schaden an einem Monster (Rüstung wird abgezogen). Gibt den tatsächlichen Schaden zurück.
func hit_unit(u: Dictionary, dmg: float, p: Dictionary = {}, crit: bool = false) -> float:
	if not sides[u["side_idx"]]["units"].has(u):
		return 0.0
	var d := _reduce(dmg, u["armor"])
	u["hp"] -= d
	if not p.is_empty():
		u["last_p"] = p                  # wem Kills durch Brennen/Blutung/Qual gutgeschrieben werden
	_float_text(str(int(round(d))), _wp(u["x"], u["y"], u["side_idx"]) + Vector3(0, 1.8, 0), Color("#ffe066") if crit else Color.WHITE, 38 if crit else 30, 0.8 if crit else 0.5)
	if p == hero:
		sfx("crit" if crit else "hit")
	if u["hp"] <= 0.0:
		_kill_unit(u, p)
	return d


func _hit_unit(u: Dictionary, dmg: float) -> float:
	return hit_unit(u, dmg, hero)


func _damage_hero(p: Dictionary, dmg: float, src: Variant = null) -> void:
	if p["dead"] > 0.0:
		return
	if p.get("god", false):
		return                           # Testfenster: unsterblich
	var my_units: Array = units_of(p)
	var raw := dmg                       # Dornen/Reflexion rechnen mit dem ungekürzten Schaden
	dmg *= (1.0 - float(p["dr"]))        # verringerter Schaden durch Items
	var eff := _reduce(dmg, skills.h_armor(p))
	p["bp"] = 0.0                        # Schaden unterbricht den Backport
	p["hp"] -= eff
	p["dmg_t"] = 0.0                     # Lebensquell-Harnisch: Zeit seit dem letzten Schaden
	_float_text("-" + str(int(round(eff))), _wp(p["x"], p["y"], p["side"]["idx"]) + Vector3(0, 3.0, 0), Color("#ff6b6b"), 30, 0.6)
	if p == hero:
		sfx("hurt")
		if eff > 0.08 * skills.h_max_hp(p):
			shake(minf(8.0, 2.0 + eff / skills.h_max_hp(p) * 20.0))
	var ir := skills.iron_passive(p)     # Tank: Dornen geben einen Anteil des Schadens an den Angreifer zurück
	if p["key"] == "tank" and p["ranks"][1] > 0 and not test_mode:
		vfx.iron_spark(p)
	if ir["reflect"] > 0.0 and src != null and my_units.has(src):
		hit_unit(src, raw * float(ir["reflect"]) * float(cfg["reflectMul"]), p)
	if src != null and my_units.has(src) and p["uniq"].has("thorns"):   # Dornen-Items: fester Schaden + Anteil der Item-Rüstung
		hit_unit(src, (float(cfg["thornFlat"]) + float(cfg["thornArmorPct"]) * p["bonus_armor"]) * float(cfg["reflectMul"]), p)
	if p["hp"] <= 0.0:
		p["hp"] = 0.0
		p["deaths"] += 1
		if p == hero:
			sfx("die")
			shake(10.0)
			flash(0.5)
		p["dead"] = float(cfg["respawnBase"]) + float(cfg["respawnPerLevel"]) * p["lvl"]
		p["target"] = null
		p["move_to"] = null
		p["buffs"] = {}
		p["leap"] = null


# ---------------------------------------------------------------- Hinweise im Spiel (Meldungen, Tipps, Boss-Leiste)
const TIPS := [
	{"id": "move", "text": "Ziel: Halte die Monsterwellen auf. Rechtsklick = Held läuft und greift an."},
	{"id": "mini", "text": "Minimap: Klick = Kamera dorthin, Leertaste = zurück zum Helden. Über den Lanes steht, wie viele Monster dort sind."},
	{"id": "skill", "text": "Skills: Q W E R wirken auf den Mauszeiger. Skillpunkte vergibst du mit Shift+Taste oder „+“."},
	{"id": "shop", "text": "Gold ausgeben: Im Shop (Tab) kaufst du Items. Kaufen geht nur in der Basis (unten, B = Backport)."},
	{"id": "send", "text": "Monster senden (Z X C V N): kostet Gold, erhöht dein Einkommen. Der Gegner bekommt dafür XP."},
	{"id": "lives", "text": "Jedes Monster, das durchkommt, kostet Team-Leben. Wer zuerst 0 Leben hat, verliert."},
	{"id": "lanes", "text": "Doppel-Lane: Zur anderen Lane kommst du nur über die Basis. Backport (B) nutzen und im Team absprechen!"},
]


## Meldung oben in der Mitte (max. 4 gleichzeitig). kind: info, good, danger, enemy
func ui_alert(text: String, kind: String = "info", secs: float = 3.2) -> void:
	if alerts_box == null or test_mode:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_color", {"info": Color("#e6e6e6"), "good": Color("#9af0a8"), "danger": Color("#ff9a9a"), "enemy": Color("#d9b3ff")}.get(kind, Color.WHITE))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alerts_box.add_child(l)
	while alerts_box.get_child_count() > 4:
		alerts_box.get_child(0).queue_free()
		alerts_box.remove_child(alerts_box.get_child(0))
	get_tree().create_timer(secs).timeout.connect(func(): if is_instance_valid(l): l.queue_free())


func _load_tips() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		var seen: Variant = cf.get_value("tips", "seen", {})
		if seen is Dictionary:
			tips_seen = seen


## Lautstärke (0..1) aus den Einstellungen, Standard 0,4
func _load_volume() -> float:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		shake_on = bool(cf.get_value("sound", "shake", true))
		display_mode = clampi(int(cf.get_value("display", "mode", 0)), 0, 2)
	return Data.user.volume


## Beim Start: gespeicherte Anzeige anwenden, aber nicht in Tests und Bild-Läufen (feste Auflösung)
func _apply_saved_display() -> void:
	for a in OS.get_cmdline_user_args():
		for t in ["--sim", "--shot", "--selftest", "--golden", "--fxtest", "--menushot", "--menuclick", "--menu-test", "--shopshot", "--merchanttest", "--camx", "--map", "--uiscale", "--colorblind", "--gfxlow", "--itemcatalog", "--dbgshot", "--uimenu", "--uitip", "--botplay", "--autoplay"]:
			if a.begins_with(t):
				return
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		display_mode = clampi(int(cf.get_value("display", "mode", 0)), 0, 2)
		set_display_mode(display_mode, false)


## Anzeige: Fenster, Vollbild (randlos) oder exklusives Vollbild; wird gespeichert (F11 wechselt zwischen Fenster und Vollbild)
func set_display_mode(m: int, save: bool = true) -> void:
	display_mode = m
	if DisplayServer.get_name() != "headless":
		match m:
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if save:
		var cf := ConfigFile.new()
		cf.load("user://settings.cfg")
		cf.set_value("display", "mode", m)
		cf.save("user://settings.cfg")


func set_shake_on(on: bool) -> void:
	shake_on = on
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("sound", "shake", on)
	cf.save("user://settings.cfg")


func _save_volume(v: float) -> void:
	Data.user.volume = v
	Data.user.save()
	apply_settings()


func _on_window_resized() -> void:
	get_window().content_scale_size = get_window().size



## Alle Optionen auf das laufende Spiel anwenden (Ton, Grafikqualität, Bildrate, Oberflächengröße). Darf auch im Menü aufgerufen werden.
func apply_settings() -> void:
	var u = Data.user
	if snd != null:
		snd.volume = 0.0 if u.mute else u.volume
	if sun != null:
		sun.shadow_enabled = u.gfx >= 1
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][u.gfx]
	Engine.max_fps = u.fps_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if u.vsync else DisplayServer.VSYNC_DISABLED)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS      # Texte und Rahmen werden in der neuen Größe scharf gezeichnet (nicht nur gestreckt)
	var win := get_window()
	win.content_scale_size = win.size                                            # Basisgröße = aktuelle Fenstergröße: Faktor 1,0 bleibt exakt 1:1 (scharf), nur die Einstellung skaliert
	if not win.size_changed.is_connected(_on_window_resized):
		win.size_changed.connect(_on_window_resized)
	get_window().content_scale_factor = u.ui_scale


func _save_tips() -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("tips", "seen", tips_seen)
	cf.save("user://settings.cfg")


## Wird pro Spielschritt aufgerufen (nur im echten Spiel)
func _ui_tick(dt: float) -> void:
	if test_mode:
		return
	ui_t_base -= dt
	ui_t_sp -= dt
	ui_t_coach -= dt
	var side: Dictionary = sides[0]
	if ui_lives < 0:
		ui_lives = team_lives[0]
	if team_lives[0] < ui_lives:
		ui_alert("−%d Leben! Noch %d" % [ui_lives - team_lives[0], maxi(0, team_lives[0])], "danger")
	ui_lives = team_lives[0]
	if ui_t_base <= 0.0:
		var near := 0
		for u in units:
			if u["x"] < float(cfg["baseX"]) + 320.0:
				near += 1
		if near > 0:
			ui_alert("⚠ %d Monster nahe eurer Basis!" % near, "danger", 2.6)
			ui_t_base = 6.0
	var nxt: int = side["wave"] + 1                                      # Vorschau: besondere Welle in 10 Sekunden
	var kind := _wave_kind(side, nxt)
	if kind != "normal" and side["wave_t"] <= 10.0 and side["wave_t"] > 0.0 and ui_warn_wave != nxt:
		ui_warn_wave = nxt
		ui_alert("In %d s: %s!" % [int(ceil(side["wave_t"])), "BOSSWELLE" if kind == "boss" else "ELITE-WELLE"], "danger", 4.5)
	if ui_t_sp <= 0.0:
		for i in 4:
			if skills.can_learn(hero, i):
				ui_alert("Skillpunkt frei – Shift+Taste oder „+“ in der Skill-Leiste", "info", 3.0)
				break
		ui_t_sp = 30.0
	if ui_t_coach <= 0.0:                                                # Einsteiger-Tipps: je einmal zum passenden Zeitpunkt
		ui_t_coach = 2.0
		var sent_n := 0
		for k in hero["sent"].keys():
			sent_n += int(hero["sent"][k])
		var conds := {"move": t > 2.0, "mini": t > 20.0, "skill": t > 12.0, "shop": t > 30.0 and hero["gold"] >= 80.0 and hero["bag"].is_empty(),
			"send": t > 50.0 and hero["gold"] >= 90.0 and sent_n == 0, "lives": team_lives[0] < int(cfg["startLives"]), "lanes": lanes_per_team == 2 and t > 60.0}
		for tp in TIPS:
			if not tips_seen.get(tp["id"], false) and conds.get(tp["id"], false):
				tips_seen[tp["id"]] = true
				_save_tips()
				ui_alert("💡 " + tp["text"], "good", 8.0)
				break
	# Boss-Leiste: solange ein Boss auf deinen Lanes lebt
	var boss: Variant = null
	for u in units:
		if u["boss"]:
			boss = u
			break
	boss_bar.visible = boss != null
	if boss != null:
		boss_bar.value = 100.0 * boss["hp"] / boss["max"]
		boss_label.text = "BOSS · Phase %d · %d %%" % [boss["phase"], int(ceil(100.0 * boss["hp"] / boss["max"]))]


func _wave_kind(side: Dictionary, n: int) -> String:
	if n == int(cfg["bossWave"]) and not side["boss_spawned"]:
		return "boss"
	return "elite" if n % int(cfg["eliteEvery"]) == 0 else "normal"


## Meldung, wenn der Gegner ein großes Item baut
func on_item_built(p: Dictionary, it: Dictionary) -> void:
	if p["side"]["idx"] != 0 and p["bot"]:
		ui_alert("Gegner hat %s gebaut" % str(it["name"]), "enemy", 4.0)


# ---------------------------------------------------------------- Spielschritt
func step(dt: float) -> void:
	if over:
		return
	t += dt
	# Einkommen: alle Spieler gleichzeitig alle incomeTick Sekunden (jeder sein eigenes Gold)
	income_t += dt
	var income_now := false
	if income_t >= float(cfg["incomeTick"]):
		income_t -= float(cfg["incomeTick"])
		income_now = true
	for p in players:
		p["gold"] += p["gps"] * dt                                        # Gold-Items: zusätzliches Einkommen pro Sekunde
		if income_now:
			var inc: float = p["income"] * p["gold_mul"] * (1.0 + comeback_bonus(p))
			p["gold"] += inc
			p["stat_gold"] += inc
	# Wellen: jede Seite hat ihre eigene
	for side in sides:
		side["wave_t"] -= dt
		if side["wave_t"] <= 0.0:
			cur_side = side["idx"]
			_spawn_wave(side)
			side["wave_t"] = float(cfg["earlyWaveEvery"]) if side["wave"] <= int(cfg["earlyWaves"]) else float(cfg["waveEvery"])
	# Zeitverzögerte Skill-Effekte
	for tm in timers.duplicate():
		tm["t"] -= dt
		if tm["t"] <= 0.0:
			timers.erase(tm)
			cur_side = tm["side"]
			tm["fn"].call()
	_step_zones(dt)
	for p in players:
		if p["bot"]:
			bot.think(p, dt)
		_step_hero(p, dt)
	for e in elems.duplicate():
		cur_side = e["p"]["side"]["idx"]
		if not skills.update_elem(e, dt):
			_free(e["node"])
			elems.erase(e)
	for side in sides:
		_step_units(side, dt)
	# Ende: Team ohne Leben verliert
	for i in 2:
		if team_lives[i] <= 0 and not over:
			over = true
			winner = 1 - i
			if msg != null:
				msg.text = "SIEG!" if winner == 0 else "NIEDERLAGE"


## Boss: Phasen bei 66 % und 33 % Leben (schneller), Stampfen im Umkreis und Verstärkung rufen.
func _boss_think(side: Dictionary, u: Dictionary, dt: float) -> void:
	var f: float = u["hp"] / u["max"]
	var ph := 1 if f > 0.66 else (2 if f > 0.33 else 3)
	if ph != u["phase"]:
		u["phase"] = ph
		u["summon_t"] = minf(u["summon_t"], 2.0)
		if side["idx"] == 0:
			_flash_msg("Der Boss wird schneller!" if ph == 2 else "BOSS-RASEREI: noch schneller, ruft öfter Verstärkung!")
	u["spd"] = u["base"] * float(cfg["bossSpeedMul"][ph - 1])
	u["stomp_t"] -= dt
	if u["stomp_t"] <= 0.0:                                              # Stampfen: Schaden an allem im Umkreis
		u["stomp_t"] = float(cfg["bossStompEvery"][ph - 1])
		fx_ring(u["x"], u["y"], float(cfg["bossStompR"]), 0.5, "#ff4d4d")
		if side["idx"] == 0:
			sfx("boss")
			shake(4.0)
		for q in side["players"]:
			if q["dead"] <= 0.0 and Vector2(q["x"] - u["x"], q["y"] - u["y"]).length() <= float(cfg["bossStompR"]) + 14.0:
				_damage_hero(q, u["dmg"] * float(cfg["bossStompMul"]), u)
	u["summon_t"] -= dt
	if u["summon_t"] <= 0.0:                                             # Verstärkung rufen
		u["summon_t"] = float(cfg["bossSummonEvery"][ph - 1])
		var n := 2 + ph
		var ly: float = lane_half_g - 16.0
		for i in n:
			_spawn_unit("grunt", 0.0, 1.0, u["lane"], side["idx"])
			var gu: Dictionary = side["units"][side["units"].size() - 1]
			gu["x"] = u["x"] + 30.0 + i * 14.0
			gu["y"] = lane_off_g[u["lane"]] + (rand_pos() * 2.0 - 1.0) * ly
		fx_text(u["x"] - 30.0, u["y"] - 40.0, "Verstärkung!", "#ff9a9a", 1.2, 30)


## Aufholhilfe: Wer deutlich weniger Team-Leben hat als der Gegner, bekommt mehr Einkommen (wie im Prototyp).
func comeback_bonus(p: Dictionary) -> float:
	var si: int = p["side"]["idx"]
	var mine: int = team_lives[si]
	var theirs: int = team_lives[1 - si]
	if theirs > 100000000 or mine >= theirs:                              # Gegner "unendlich" (Testmodus): keine Hilfe
		return 0.0
	var behind := theirs - mine
	if behind < int(cfg["comebackDiff"]):
		return 0.0
	return minf(float(cfg["comebackCap"]), float(cfg["comebackPerLife"]) * (behind - int(cfg["comebackDiff"]) + 1))


## Schadensfelder (Feuerfeld, Sprung-Landung, Schwertregen, Frost-Elementar)
func _step_zones(dt: float) -> void:
	for z in zones.duplicate():
		cur_side = z["side"]
		var zunits: Array = sides[z["side"]]["units"]
		z["t"] -= dt
		z["tick"] -= dt
		if z.get("follow", "") == "enemy":                               # Feld jagt den nächsten Gegner
			var best: Variant = null
			var bd := 1e9
			for u in zunits:
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
			for u in zunits.duplicate():
				if zunits.has(u) and Vector2(u["x"] - z["x"], u["y"] - z["y"]).length() <= z["r"] + u["r"]:
					skills.affect(z["p"], u, z["dmg"], z.get("o", {}))
		if z["t"] <= 0.0:
			vfx.zone_end(z)
			zones.erase(z)


func _step_hero(p: Dictionary, dt: float) -> void:
	cur_side = p["side"]["idx"]
	var my_units: Array = p["side"]["units"]
	for i in 4:
		p["cds"][i] = maxf(0.0, p["cds"][i] - dt)
	p["bp_cd"] = maxf(0.0, p["bp_cd"] - dt)
	p["pot_cd"] = maxf(0.0, p["pot_cd"] - dt)
	p["combo_t"] = maxf(0.0, p["combo_t"] - dt)
	for k in p["buffs"].keys():
		p["buffs"][k]["t"] -= dt
		if p["buffs"][k]["t"] <= 0.0:
			p["buffs"].erase(k)
	if p["dead"] > 0.0:
		p["dead"] -= dt
		if p["dead"] <= 0.0:
			p["dead"] = 0.0
			p["hp"] = skills.h_max_hp(p)
			p["x"] = 120.0
			p["y"] = p["home_y"]
		return
	var mx := skills.h_max_hp(p)
	var ir := skills.iron_passive(p)
	var regen: float = mx * 0.12 if _in_base(p) else 1.5 + p["lvl"] * 0.3
	p["dmg_t"] += dt
	if p["uniq"].has("lifeflow") and p["dmg_t"] >= float(cfg["lifeflowDelay"]):   # Lebensquell-Harnisch: Heilung, wenn lange kein Schaden
		p["hp"] = minf(mx, p["hp"] + mx * float(cfg["lifeflowPct"]) * dt)
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
			p["y"] = p["home_y"]
			p["move_to"] = null
			p["target"] = null
			_float_text("Zurück in der Basis", _wp(p["x"], p["y"]) + Vector3(0, 3.2, 0), Color("#7fd6ff"), 36, 1.0)
		return
	if autoplay and p == hero:
		_autoplay_choose()
	# Ziel gültig? Bewegungsziel bestimmen
	if p["target"] != null and not my_units.has(p["target"]):
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
		goal = _route(p, goal)              # bei Doppel-Lane: nur in der Basis zur anderen Lane
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
		for u in my_units:
			var dd := Vector2(u["x"] - p["x"], u["y"] - p["y"]).length()
			if dd <= range_ + u["r"] and dd < best:
				best = dd
				tgt = u
	if tgt != null and Vector2(tgt["x"] - p["x"], tgt["y"] - p["y"]).length() <= range_ + tgt["r"] and p["atk_t"] <= 0.0:
		p["atk_t"] = 1.0 / skills.h_as(p)
		var dmg := skills.h_dmg(p)
		var tx: float = tgt["x"]
		var ty: float = tgt["y"]
		var is_crit := false
		if p["crit_ch"] > 0.0 and rand() < p["crit_ch"]:                  # kritischer Treffer (Crit-Mantel / Mächtige Klinge)
			is_crit = true
			dmg *= float(cfg["critDmgBase"]) + (float(cfg["critDmgBonus"]) if p["uniq"].has("critDmg") else 0.0)
			fx_text(tx, ty - 28.0, "KRIT!", "#ffe066", 0.6, 34)
			if p["uniq"].has("stormCrit"):                                # Sturmbrecher: kurz mehr Angriffstempo
				p["buffs"]["critAs"] = {"t": float(cfg["stormCritTime"]), "as": float(cfg["stormCritAs"])}
		var dealt := hit_unit(tgt, dmg, p, is_crit)
		var rg0: Variant = skills.buff(p, "rage")                          # Giftklingen: Treffer vergiften das Ziel
		if rg0 != null and float(rg0.get("pois", 0.0)) > 0.0 and units_of(p).has(tgt):
			tgt["pois"] = maxf(tgt["pois"], float(cfg["poisonTime"]))
			tgt["pois_dps"] = maxf(tgt["pois_dps"], float(rg0["pois"]))
		if p["lifesteal"] > 0.0:                                          # Lebensraub (inkl. Rachsucht)
			var vf := 2.0 if p["uniq"].has("vengeance") and p["hp"] < 0.4 * skills.h_max_hp(p) else 1.0
			p["hp"] = minf(skills.h_max_hp(p), p["hp"] + dealt * p["lifesteal"] * vf)
		if p["uniq"].has("onHitMagic") and my_units.has(tgt):                # Funkenklinge: magischer Zusatzschaden, ignoriert Rüstung
			var md: float = float(cfg["sparkFlat"]) + float(cfg["sparkAp"]) * skills.h_sp(p)
			tgt["hp"] -= md
			fx_text(tx, ty - 14.0, str(int(round(md))), "#9fe0ff", 0.4, 28)
			if tgt["hp"] <= 0.0:
				_kill_unit(tgt, p)
		if p["uniq"].has("giants") and my_units.has(tgt):                    # Gigantenschlag: % deines max. Lebens
			hit_unit(tgt, float(cfg["giantsPct"]) * skills.h_max_hp(p), p)
		if p["uniq"].has("cleave"):                                       # Splitteraxt: die nächsten Gegner im Umkreis (höchstens cleaveMax)
			var near: Array = []
			for u in my_units:
				if u != tgt and Vector2(u["x"] - tx, u["y"] - ty).length() <= 80.0:
					near.append(u)
			near.sort_custom(func(a, b): return Vector2(a["x"] - tx, a["y"] - ty).length() < Vector2(b["x"] - tx, b["y"] - ty).length())
			var item_others: Array = []
			for u in near.slice(0, int(cfg["cleaveMax"])):
				item_others.append(Vector2(u["x"], u["y"]))
				hit_unit(u, dmg * float(cfg["cleaveItemPct"]), p)
			vfx.cleave_fx(p, tx, ty, item_others, 80.0, Color(1.0, 0.8, 0.4))
		if p["uniq"].has("ruin") and my_units.has(tgt):                      # Schneide des gefallenen Monarchen: % des aktuellen Lebens
			hit_unit(tgt, minf(float(cfg["ruinMax"]), maxf(float(cfg["ruinMin"]), float(cfg["ruinPct"]) * tgt["hp"])), p)
		var rg: Variant = skills.buff(p, "rage")
		if rg != null and rg["cleave"]:                                   # Kampfrausch Rang 5: Angriffe treffen Gegner im Umkreis
			var others: Array = []
			for u in my_units.duplicate():
				if u != tgt and my_units.has(u) and Vector2(u["x"] - tx, u["y"] - ty).length() <= 75.0:
					others.append(Vector2(u["x"], u["y"]))
					hit_unit(u, dmg * 0.5, p)
					if float(rg.get("pois", 0.0)) > 0.0 and my_units.has(u):
						u["pois"] = maxf(u["pois"], float(cfg["poisonTime"]))
						u["pois_dps"] = maxf(u["pois_dps"], float(rg["pois"]))
			vfx.cleave_fx(p, tx, ty, others, 75.0, Color(0.55, 1.0, 0.35) if float(rg.get("pois", 0.0)) > 0.0 else Color(1.0, 0.3, 0.25))
		if range_ > 100.0:
			if p["key"] == "caster":
				vfx.auto_fireball(p, tx, ty)
				sfx_p(p, "caster_shot", 0.55)
			else:
				fx_line(p["x"], p["y"], tx, ty, 0.12, str(p["d"]["col"]), 2.0)
		elif p["key"] == "tank":
			sfx_p(p, "tank_shot", 0.7)                 # Nahkampf-Schlag des Tanks
		elif p["key"] == "damage":
			vfx.slash_hit(p, tx, ty)
			sfx_p(p, "damage_shot", 0.7)                # Doppelter Dolchhieb des Schurken




## Backport (Taste B): Zauberzeit, danach zurück in die Basis; nicht in der Basis, nicht während der Abklingzeit.
func _start_backport(p: Dictionary) -> void:
	if p["dead"] > 0.0 or p["bp"] > 0.0 or p["bp_cd"] > 0.0 or _in_base(p):
		return
	p["bp_max"] = float(cfg["backportCast"]) * (1.0 - float(p["bp_red"]))   # Hut des Reisenden verkürzt den Cast
	p["bp"] = p["bp_max"]
	p["move_to"] = null
	p["target"] = null


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
func _route(p: Dictionary, goal: Vector2) -> Vector2:
	if lanes_per_team < 2:
		return goal
	var mid: float = (lane_off_g[0] + lane_off_g[1]) / 2.0
	if (p["y"] < mid) == (goal.y < mid):
		return goal
	if p["x"] < WALL_OPEN_BASE:
		return Vector2(minf(p["x"], WALL_OPEN_BASE - 50.0), goal.y)   # quer durch die Basis
	var lo := lane_half_g - 10.0               # Wandbereich quer
	var hi: float = lane_off_g[1] - lane_half_g + 10.0
	return Vector2(goal.x, lo if p["y"] < mid else hi)


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


func _step_units(side: Dictionary, dt: float) -> void:
	cur_side = side["idx"]
	var sunits: Array = side["units"]
	var heroes: Array = side["players"]
	for u in sunits.duplicate():
		if not sunits.has(u):
			continue
		# Statuseffekte
		if u["slow"] > 0.0:
			u["slow"] -= dt
		if u["burn"] > 0.0:
			u["burn"] -= dt
			u["burn_t"] += dt
			if u["burn_t"] >= 1.0:
				u["burn_t"] -= 1.0
				hit_unit(u, u["burn_dps"], u["last_p"])
				if not sunits.has(u):
					continue
		if u["pois"] > 0.0:                                               # Gift (Giftklingen, Giftpfütze): jede Sekunde fester Schaden
			u["pois"] -= dt
			u["pois_t"] += dt
			if u["pois_t"] >= 1.0:
				u["pois_t"] -= 1.0
				hit_unit(u, u["pois_dps"], u["last_p"])
				if not sunits.has(u):
					continue
		if u["torm_cd"] > 0.0:
			u["torm_cd"] -= dt
		if u["torm_t"] > 0.0:                                             # Qual (Quälende Maske): alle 0,5 s Schaden, ignoriert Rüstung
			u["torm_t"] -= dt
			u["torm_tick"] -= dt
			if u["torm_tick"] <= 0.0:
				u["torm_tick"] += float(cfg["tormentEvery"])
				u["hp"] -= u["torm_dmg"]
				_float_text(str(int(round(u["torm_dmg"]))), _wp(u["x"], u["y"]) + Vector3(0, 1.8, 0), Color("#c77dff"), 26, 0.4)
				if u["hp"] <= 0.0:
					_kill_unit(u, u["last_p"])
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
					_kill_unit(u, u["last_p"])
					continue
		if u["stun"] > 0.0:
			u["stun"] -= dt
			continue
		if u["boss"]:
			_boss_think(side, u, dt)
		u["atk_t"] -= dt
		# Ziel: der nächste lebende Held in Reichweite, sonst ein Elementar
		var engaged := false
		var target_hero: Dictionary = {}
		var th_d := 1e9
		for q in heroes:
			if q["dead"] <= 0.0:
				var dq := sqrt(pow(u["x"] - q["x"], 2.0) + pow(u["y"] - q["y"], 2.0))   # 64-Bit wie im Prototyp (Vector2 rechnet in 32-Bit)
				if dq <= u["range"] + 14.0 and dq < th_d:
					th_d = dq
					target_hero = q
		var el: Variant = null
		if target_hero.is_empty():
			for e in elems:
				if e["p"]["side"] == side and Vector2(u["x"] - e["x"], u["y"] - e["y"]).length() <= u["range"] + 18.0:
					el = e
					break
		if not target_hero.is_empty() or el != null:
			engaged = true
			if u["atk_t"] <= 0.0:
				u["atk_t"] = 1.0
				if not target_hero.is_empty():
					_damage_hero(target_hero, u["dmg"], u)
				else:
					el["hp"] -= _reduce(u["dmg"], 10.0)
		if not engaged:
			# der nächste lebende Held bestimmt, ob das Monster ihn jagt
			var near_hero: Dictionary = {}
			var nh_d := 1e9
			for q in heroes:
				if q["dead"] <= 0.0:
					var dn := Vector2(u["x"] - q["x"], u["y"] - q["y"]).length()
					if dn < nh_d:
						nh_d = dn
						near_hero = q
			# Titanenpanzer-Aura: Gegner nahe an einem Helden mit Aura sind langsamer
			var aura := 1.0
			for q in heroes:
				if q["dead"] <= 0.0 and q["uniq"].has("slowAura") and Vector2(u["x"] - q["x"], u["y"] - q["y"]).length() <= float(cfg["auraRadius"]):
					aura = 1.0 - float(cfg["auraSlow"])
					break
			var step_len: float = u["spd"] * (0.5 if u["slow"] > 0.0 else 1.0) * aura * dt
			var dx := -1.0
			var dy := 0.0
			var chasing := false
			if not near_hero.is_empty() and u["type"] != "fast":
				var hx: float = near_hero["x"] - u["x"]
				var hy: float = near_hero["y"] - u["y"]
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
		if u["x"] <= float(cfg["leakX"]):          # durchgebrochen: kostet Team-Leben
			var l := int(u["def"]["lives"])
			team_lives[side["idx"]] -= l
			side["leak"][u["type"]] = side["leak"].get(u["type"], 0) + l
			if side["idx"] == 0:
				sfx("leak")
				shake(5.0)
				flash(0.35)
			sunits.erase(u)
			_free(u["node"])


# ---------------------------------------------------------------- Darstellung und Eingabe
func _process(delta: float) -> void:
	if not started:
		return
	if not paused:
		acc = minf(acc + delta * float(game_speed), 0.5)                # feste Schritte von 0,05 s (bei Tempo x2/x3 mehrere pro Bild)
		while acc >= 0.05:
			step(0.05)
			_ui_tick(0.05)
			acc -= 0.05
	_sync_visuals(delta)
	if over and not end_shown:
		end_shown = true
		get_tree().create_timer(1.1).timeout.connect(_show_end)


## Pause (P oder Esc). Shop und Skillpunkte bleiben bedienbar.
func _toggle_pause() -> void:
	if not started or over:
		return
	paused = not paused
	pause_label.visible = paused


func _show_end() -> void:
	if end_layer != null:
		return
	sfx("win" if winner == 0 else "lose")
	end_layer = CanvasLayer.new()
	end_layer.layer = 10
	add_child(end_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "SIEG!" if winner == 0 else "NIEDERLAGE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#7be07b") if winner == 0 else Color("#ff6b6b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := Label.new()
	info.text = "Dauer %d:%02d   Team-Leben: du %d, Gegner %d" % [int(t) / 60, int(t) % 60, maxi(0, team_lives[0]), maxi(0, team_lives[1])]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	box.add_child(grid)
	for h in ["Team", "Held", "Level", "Kills", "Tode", "Monster gesendet", "Einkommen"]:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", Color("#9aa3b5"))
		grid.add_child(l)
	for p in players:
		var sent_total := 0
		for k in p["sent"].keys():
			sent_total += int(p["sent"][k])
		var cells := ["Du" if p == hero else ("Team A" if p["side"]["idx"] == 0 else "Gegner"), str(p["d"]["name"]), str(p["lvl"]), str(p["kills"]),
			str(p["deaths"]), str(sent_total), "%.1f" % float(p["income"])]
		for c in cells:
			var l := Label.new()
			l.text = c
			grid.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var again := Button.new()
	again.text = "Revanche"
	again.custom_minimum_size = Vector2(160, 46)
	again.pressed.connect(func():
		Data.autostart = true
		get_tree().reload_current_scene())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Zurück zum Menü"
	menu.custom_minimum_size = Vector2(160, 46)
	menu.pressed.connect(func():
		Data.autostart = false
		get_tree().reload_current_scene())
	row.add_child(menu)


## Sichtbare Position und Figur: Die Spiellogik rechnet in Schritten von 0,05 s, die Anzeige gleitet weich zur
## aktuellen Position (kein Ruckeln). Figur dreht sich schnell in Laufrichtung bzw. zum Ziel, Animation passt zum Tempo.
## e: Held oder Monster (x, y, fig, target). ref: Lauftempo (m/s), bei dem die Laufanimation normal schnell läuft.
func _animate(e: Dictionary, node: Node3D, side_idx: int, delta: float, attack_anim: String, move_anim: String, idle_anim: String, ref: float) -> void:
	var tgt := Vector2(e["x"], e["y"])
	var vis: Vector2 = e.get("vis", tgt)
	var old := vis
	if vis.distance_to(tgt) > 150.0:
		vis = tgt                                       # Sprung (Backport, Wiederbelebung): sofort
	else:
		vis = vis.lerp(tgt, 1.0 - exp(-delta * 22.0))
	e["vis"] = vis
	node.position = _wp(vis.x, vis.y, side_idx)
	var fig: Dictionary = e["fig"]
	if fig.is_empty() or delta <= 0.0:
		return
	var vx: float = (vis.y - old.y) * S / delta         # Weltgeschwindigkeit (m/s), x = quer, z = längs
	var vz: float = -(vis.x - old.x) * S / delta
	var speed := sqrt(vx * vx + vz * vz)
	var hold: float = fig.get("hold", 0.0)
	hold = 0.18 if speed > 0.5 else maxf(0.0, hold - delta)       # kurzes Nachhalten: kein Flackern zwischen Laufen und Stehen
	fig["hold"] = hold
	var moving := hold > 0.0
	var want_yaw: float = fig["yaw"]
	var force: float = fig.get("force", 0.0)
	var mt: Variant = e.get("move_to")
	var tg: Variant = e.get("target")
	if mt is Dictionary and mt.has("x"):
		want_yaw = atan2((mt["y"] - vis.y), -(mt["x"] - vis.x))
	elif mt is Vector2:
		want_yaw = atan2(mt.y - vis.y, -(mt.x - vis.x))
	elif speed > 0.5:
		want_yaw = atan2(vx, vz)
	elif tg is Dictionary and tg.has("x"):
		want_yaw = atan2((tg["y"] - vis.y), -(tg["x"] - vis.x))
	if force > 0.0:                                     # Zauberpose: zum Ziel drehen und Angriff zeigen
		fig["force"] = force - delta
		var fc: Vector2 = fig["face"]
		want_yaw = atan2(fc.y - vis.y, -(fc.x - vis.x))
	fig["yaw"] = lerp_angle(fig["yaw"], want_yaw, 1.0 - exp(-delta * 30.0))
	(fig["inner"] as Node3D).rotation.y = fig["yaw"]
	var anim := move_anim if moving else (attack_anim if (tg != null or e.get("type") != null) else idle_anim)
	if force > 0.0:
		anim = str(fig.get("force_anim", "")) if str(fig.get("force_anim", "")) != "" else attack_anim
	_play_anim(fig, anim)
	var ap: AnimationPlayer = fig["anim"]
	if ap != null:
		ap.speed_scale = clampf(speed / ref, 0.7, 2.0) if moving and anim == move_anim else (float(fig.get("force_speed", 1.0)) if force > 0.0 else 1.0)
	var spin: float = fig.get("spin", 0.0)
	if spin > 0.0:                                      # Drehung (Dolchfächer): einmal im Kreis
		fig["spin"] = spin - delta
		fig["yaw"] += TAU * delta / 0.35
		(fig["inner"] as Node3D).rotation.y = fig["yaw"]
	var lp: Variant = e.get("leap", null)
	if fig.has("model"):                                # Sprung: die Figur steigt im Bogen (der Boden-Ring bleibt unten)
		var hgt := 0.0
		if lp is Dictionary:
			var kk: float = 1.0 - maxf(0.0, float(lp["t"])) / float(lp["T"])
			hgt = 3.4 * sin(kk * PI)
		(fig["model"] as Node3D).position.y = hgt


func _sync_visuals(delta: float) -> void:
	var hn: Node3D = hero["node"]
	for p in players:                    # alle Helden: Position, Sichtbarkeit, Lebensanzeige
		var pn: Node3D = p["node"]
		pn.visible = p["dead"] <= 0.0 and p["side"]["idx"] == hero["side"]["idx"]      # Gegner-Seite bleibt verdeckt
		var hm: Array = HERO_MODEL.get(p["key"], ["", "", "Run", "Idle", 2.8])
		_animate(p, pn, p["side"]["idx"], delta, str(hm[1]), str(hm[2]), str(hm[3]), 5.0)
		p["label"].text = ("Lv %d   %d" % [p["lvl"], int(p["hp"])]) if Data.user.hp_numbers else ("Lv %d" % p["lvl"])
		_set_bar(p["bar"], p["bar_w"], p["hp"] / skills.h_max_hp(p), p["side"]["idx"] == hero["side"]["idx"])
	for s in sides:                      # alle Monster beider Seiten
		for u in s["units"]:
			var n: Node3D = u["node"]
			n.visible = s["idx"] == hero["side"]["idx"]
			if n.visible:
				vfx.poison_mark(u, n)
			if n.visible:
				_animate(u, n, s["idx"], delta, "Bite_InPlace" if u["fig"]["anim"] != null and u["fig"]["anim"].has_animation("Bite_InPlace") else "Bite_Front",
					"Flying" if u["fig"].get("flies", false) else "Walk", "Flying" if u["fig"].get("flies", false) else "Idle", 2.5)
			_set_bar(u["bar"], u["bar_w"], u["hp"] / u["max"], true)
	var fog_x: float = lane_xs[lanes_per_team - 1] + lane_half_g * S + WALL
	for fx in fx_list:                   # Effekte und Zahlen auf der Gegner-Seite ausblenden
		var fnode: Node3D = fx["node"]
		fnode.visible = fnode.position.x < fog_x
	for f in texts.duplicate():
		f["node"].visible = f["node"].position.x < fog_x
		f["t"] -= delta
		f["node"].position.y += 1.5 * delta
		if f["t"] <= 0.0:
			f["node"].queue_free()
			texts.erase(f)
	_update_fx(delta)
	_update_merchant(delta)
	_cam_input(delta)
	var off := _cam_offset()
	var want := (cam_focus if cam_free else hn.position) + off
	cam.position = want if not cam_init else cam.position.lerp(want, minf(1.0, delta * 6.0))
	for i in life_labels.size():
		life_labels[i].text = "Leben %d" % maxi(0, team_lives[i])
	cam_init = true
	flash_a = maxf(0.0, flash_a - 1.2 * delta)                          # Bildschirmeffekte klingen ab
	shake_amt = 0.0 if shake_amt < 0.2 else shake_amt * exp(-10.0 * delta)
	cam.h_offset = randf_range(-1.0, 1.0) * shake_amt * 0.02
	cam.v_offset = randf_range(-1.0, 1.0) * shake_amt * 0.02
	var low_hp: bool = hero["dead"] <= 0.0 and hero["hp"] / skills.h_max_hp(hero) < 0.3
	vignette.modulate.a = clampf(maxf(flash_a, (0.25 + 0.15 * sin(t * 6.0)) if low_hp else 0.0), 0.0, 1.0)
	cam.look_at(cam.position - off)
	var ring: MeshInstance3D = hero["ring"]
	ring.visible = hero["bp"] > 0.0
	var prog: float = hero["bp"] / maxf(0.01, hero["bp_max"])
	ring.scale = Vector3(0.4 + 0.6 * prog, 1.0, 0.4 + 0.6 * prog)
	var min_t := int(t) / 60
	hud.text = "Team-Leben  %d   (Gegner %d)\nEinkommen  +%.0f alle %d s" % [team_lives[0], team_lives[1], hero["income"], int(cfg["incomeTick"])]
	hud_mid.text = "Welle %d\nZeit %d:%02d" % [sides[0]["wave"], min_t, int(t) % 60]
	fps_ema = lerpf(fps_ema, 1.0 / maxf(delta, 0.0001), 0.05)
	hud_right.text = "Kills  %d" % kills + ("\nHeld tot: %d s" % int(ceil(hero["dead"])) if hero["dead"] > 0.0 else "") + ("\nFPS %d" % int(round(fps_ema)) if Data.user.show_fps else "")
	if mini != null:
		mini.queue_redraw()
	_update_skillbar()
	_update_shop()
	_update_send()
	_update_test_panel()


func _ground_point(screen_pos: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return Vector3.ZERO
	return o + d * (-o.y / d.y)


## Zeigt die Maus auf den Händler (Goblin oder Wagen)?
func _over_merchant(screen_pos: Vector2) -> bool:
	var p := _ground_point(screen_pos)
	var gp: Vector3 = merchant["goblin"]
	var wp: Vector3 = merchant["wagon"]
	var cp: Vector3 = merchant["counter"]
	var ap: Vector3 = merchant["armor"]
	return (Vector2(p.x - gp.x, p.z - gp.z).length() < 2.0 or Vector2(p.x - wp.x, p.z - wp.z).length() < 3.2
		or Vector2(p.x - cp.x, p.z - cp.z).length() < 2.0 or Vector2(p.x - ap.x, p.z - ap.z).length() < 1.4)


## Händler: Hinweis beim Darüberfahren, Mauszeiger, und ein kleines "Pst!", wenn der Held herankommt
func _update_merchant(delta: float) -> void:
	if merchant.is_empty() or hero.is_empty():
		return
	var mp := get_viewport().get_mouse_position()
	var ui_hit := get_viewport().gui_get_hovered_control() != null
	var hover := not ui_hit and not paused and _over_merchant(mp)
	merchant["hover"] = hover
	var tag: Label3D = merchant["tag"]
	var pst: Label3D = merchant["pst"]
	tag.text = "Händler – Klick: Shop (%s)" % Data.user.key_name("shop") if hover else "Händler"
	var want_a: float = 1.0 if hover else 0.0
	tag.modulate.a = lerpf(tag.modulate.a, want_a, minf(1.0, delta * 8.0))
	tag.outline_modulate.a = tag.modulate.a
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover else Input.CURSOR_ARROW)
	var gp: Vector3 = merchant["goblin"]
	var hp: Vector3 = (hero["node"] as Node3D).position
	var dist := Vector2(hp.x - gp.x, hp.z - gp.z).length()
	var near: bool = dist < 9.0 and hero["dead"] <= 0.0
	if near and not merchant["near"]:
		merchant["pst_t"] = 0.0                                             # neu herangekommen: "Pst!" von vorn
	merchant["near"] = near
	var t: float = merchant["pst_t"] + delta
	merchant["pst_t"] = t
	var a := 0.0
	if near and t < 4.0 and not (shop != null and shop.visible()):
		a = clampf(minf(t * 4.0, (4.0 - t) * 2.0), 0.0, 1.0)
	pst.modulate.a = a
	pst.outline_modulate.a = a
	pst.position.y = gp.y + 3.1 + sin(t * 6.0) * 0.08 * a
	pst.scale = Vector3.ONE * (1.0 + 0.1 * sin(t * 9.0) * a)


## Maus relativ zum Helden in Spielkoordinaten (Richtung und Zielpunkt für Skills).
func _mouse_info() -> Dictionary:
	var p := _ground_point(get_viewport().get_mouse_position())
	var gx := -p.z / S
	var gy := (p.x - lane_xs[0]) / S
	var dx: float = gx - hero["x"]
	var dy: float = gy - hero["y"]
	return {"dx": dx, "dy": dy, "dist": maxf(1.0, Vector2(dx, dy).length()), "ang": atan2(dy, dx), "wx": gx, "wy": gy}


## Fähigkeit (0..3) zu einer Taste laut Tastenbelegung, sonst -1
func _slot_for_key(code: int) -> int:
	return ["q", "w", "e", "r"].find(Data.user.action_for_key(code))


## Kamera: Pfeiltasten und (wenn aktiviert) Mauszeiger am Bildrand schieben die Kamera; Leertaste holt sie zum Helden zurück
func _cam_input(delta: float) -> void:
	if not started or over:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Data.user.edge_scroll and get_window().has_focus():
		var vp := get_viewport()
		var mp := vp.get_mouse_position()
		var sz := vp.get_visible_rect().size
		if mp.x >= 0.0 and mp.y >= 0.0 and mp.x <= sz.x and mp.y <= sz.y:
			if mp.x <= 6.0:
				dir.x -= 1.0
			if mp.x >= sz.x - 6.0:
				dir.x += 1.0
			if mp.y <= 6.0:
				dir.y -= 1.0
			if mp.y >= sz.y - 6.0:
				dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	if not cam_free:
		cam_free = true
		cam_focus = (hero["node"] as Node3D).position
	var m := _mini_map()
	var own_x_max: float = lane_xs[lanes_per_team - 1] + lane_half_g * S      # Gegner-Seite ist nicht einsehbar
	var step_len: float = 45.0 * float(Data.user.cam_speed) * delta
	cam_focus.x = clampf(cam_focus.x + dir.x * step_len, lane_xs[0] - lane_half_g * S, own_x_max)
	cam_focus.z = clampf(cam_focus.z + dir.y * step_len, m["z_top"], m["z_bot"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_display_mode(0 if display_mode != 0 else 1)           # F11: Fenster <-> Vollbild
		return
	if started and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2 and test_panel != null:
		test_panel.visible = not test_panel.visible
		return
	if started and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		cam_free = false                  # Leertaste: Kamera zurück zum Helden
	if event is InputEventMouseButton and event.pressed:   # Mausrad: Kamera näher/weiter weg
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 2.0, 14.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 2.0, 14.0, 50.0)
	if not started or over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not merchant.is_empty() and _over_merchant(event.position):
		_toggle_shop()                    # Klick auf den Händler öffnet den Shop
		return
	if event is InputEventKey and event.pressed and not event.echo and event.shift_pressed:
		var lslot := _slot_for_key(event.keycode)
		if lslot >= 0:
			skills.learn(hero, lslot)     # Skillpunkte lassen sich auch als toter Held vergeben
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if shop != null and shop.visible():
				shop.close()                           # Esc schließt zuerst den Shop
				return
			if ui != null:
				ui.toggle_menu()                       # Esc öffnet/schließt das Menü (pausiert das Spiel)
			return
		if event.keycode == Data.user.key_of("pause"):
			if ui == null or not ui.menu_open:
				_toggle_pause()
			return
		var spd := [KEY_1, KEY_2, KEY_3].find(event.keycode)
		if spd >= 0:
			game_speed = spd + 1
			return
	if paused:
		return                            # in der Pause nur noch Shop und Skillpunkte
	if event is InputEventKey and event.pressed and not event.echo:
		var act0: String = Data.user.action_for_key(event.keycode)
		var stype: String = act0.substr(5) if act0.begins_with("send_") else ""
		if stype != "":
			send(hero, stype)             # Monster senden geht auch als toter Held
			return
	if hero["dead"] > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var act: String = Data.user.action_for_key(event.keycode)
		if act == "backport":
			_start_backport(hero)
		elif act == "stop":               # Stopp
			hero["move_to"] = null
			hero["target"] = null
		elif act == "shop":               # Shop ein-/ausblenden
			_toggle_shop()
		elif act == "potion":             # Heiltrank
			items.drink_potion(hero)
		else:
			var slot := _slot_for_key(event.keycode)
			if slot >= 0 and not event.shift_pressed:
				skills.cast_slot(hero, slot, _mouse_info())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_backport(hero)             # Rechtsklick bricht den Backport ab
		var p := _ground_point(event.position)
		var gx := -p.z / S
		var gy := (p.x - lane_xs[0]) / S
		var hit: Variant = null
		var best := 1e9
		for u in units:
			var dd := Vector2(u["x"] - gx, u["y"] - gy).length()
			if dd < u["r"] + 8.0 and dd < best:             # Klickfläche wie im Prototyp (Radius + 8)
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
	for s in sides:
		s["wave"] = 0
		s["wave_t"] = 1e9
		s["units"].clear()
		s["boss_spawned"] = false
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
	p["crit_ch"] = float(inp.get("critCh", 0.0))
	p["lifesteal"] = float(inp.get("lifesteal", 0.0))
	p["bonus_regen"] = float(inp.get("regen", 0.0))
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


# ---------------------------------------------------------------- Selbsttest Shop (--selftest-items)
func _selftest_items() -> void:
	var ok := true
	var check := func(name: String, cond: bool) -> void:
		print(("PASS  " if cond else "FAIL  ") + name)
		if not cond:
			ok = false
	var p := hero
	p["gold"] = 10000.0
	p["x"] = 1000.0
	check.call("Kaufen nur in der Basis", items.buy_reason(p, "rake") != "" and not items.buy(p, "rake"))
	p["x"] = 100.0
	check.call("Harke kaufen (200 g, +30 Schaden)", items.buy(p, "rake") and p["gold"] == 9800.0 and p["bonus_dmg"] == 30.0 and p["bag"] == ["rake"])
	var g0: float = p["gold"]
	check.call("Verkaufen: 70 % von 200 = 140 g", items.sell(p, 0) and p["gold"] == g0 + 140.0 and p["bag"].is_empty() and p["bonus_dmg"] == 0.0)
	# Rezept: Mächtige Klinge = Großes Schwert + Harke + Crit-Mantel + 300 Rezeptgeld
	items.buy(p, "bigSword")
	check.call("Teil im Rucksack senkt den Rezeptpreis (700 statt 1000)", items.resolve_buy("mightyBlade", p["bag"])["cost"] == 700)
	g0 = p["gold"]
	check.call("Mächtige Klinge kaufen: Teil verbraucht, fehlende Teile mitgekauft", items.buy(p, "mightyBlade") and g0 - p["gold"] == 700.0 and p["bag"] == ["mightyBlade"])
	check.call("Werte: +80 Schaden, 25 % Krit, Effekt critDmg", p["bonus_dmg"] == 80.0 and absf(p["crit_ch"] - 0.25) < 1e-9 and p["uniq"].has("critDmg"))
	g0 = p["gold"]
	check.call("Verkauf Mächtige Klinge: 70 % von 1000 = 700 g", items.sell(p, 0) and p["gold"] == g0 + 700.0)
	# Hut-Regel
	items.buy(p, "hat")
	check.call("Zweiter Lederhut wird abgelehnt (nur ein Hut)", items.buy_reason(p, "hat") == "du trägst schon einen Hut")
	g0 = p["gold"]
	check.call("Spezialhut verbraucht den Lederhut, kostet 450", items.buy(p, "hatWind") and g0 - p["gold"] == 450.0 and p["bag"] == ["hatWind"])
	check.call("Hutwerte: +50 Lauftempo, +0,35 Angriffstempo", p["bonus_spd"] == 50.0 and absf(p["bonus_as"] - 0.35) < 1e-9)
	check.call("Zweiter Hut blockiert", items.buy_reason(p, "hatSage") == "du trägst schon einen Hut")
	# Rucksack voll
	p["bag"] = []
	items.recalc(p)
	for i in 6:
		items.buy(p, "rake")
	check.call("Rucksack hat 6 Plätze", p["bag"].size() == 6 and items.buy_reason(p, "rake").begins_with("Rucksack voll"))
	# Leben beim Kauf: aktuelles Leben steigt mit dem max. Leben
	p["bag"] = []
	items.recalc(p)
	p["hp"] = 100.0
	items.buy(p, "ruby")
	check.call("Rubinkristall: +150 max. Leben und aktuelles Leben steigt mit (100 -> 250)", p["bonus_hp"] == 150.0 and absf(p["hp"] - 250.0) < 1e-6)
	# Heiltrank
	p["bag"] = []
	items.recalc(p)
	p["hp"] = skills.h_max_hp(p)
	items.buy(p, "potion")
	check.call("Heiltrank gekauft", p["cons"]["potion"] == 1)
	check.call("Trinken bei vollem Leben geht nicht", not items.drink_potion(p))
	p["hp"] = 100.0
	var mx: float = skills.h_max_hp(p)
	check.call("Trinken heilt 40 %% des max. Lebens (%.0f)" % (mx * 0.4), items.drink_potion(p) and absf(p["hp"] - (100.0 + mx * 0.4)) < 1e-6 and p["pot_cd"] == 15.0)
	items.buy(p, "potion")
	p["hp"] = 100.0
	check.call("Abklingzeit 15 s blockiert den nächsten Trank", not items.drink_potion(p))
	for i in 10:
		items.buy(p, "potion")
	check.call("Vorrat höchstens 5", p["cons"]["potion"] <= int(cfg["consMax"]))
	# Gold pro Sekunde
	p["bag"] = ["coinPouch", "coinPouch"]
	items.recalc(p)
	g0 = p["gold"]
	for i in 20:
		step(0.05)
	check.call("Münzbeutel: 0,8 Gold/s -> +0,8 in 1 s", absf(p["gold"] - g0 - 0.8) < 1e-6)
	# Backport-Verkürzung (Hut des Reisenden: -40 %)
	p["bag"] = ["hatTravel"]
	items.recalc(p)
	p["x"] = 1000.0
	_start_backport(hero)
	check.call("Hut des Reisenden: Backport 2,7 s statt 4,5 s", absf(p["bp"] - 2.7) < 1e-9)
	print("SELFTEST-ITEMS " + ("OK" if ok else "FEHLER"))
	get_tree().quit()


# ---------------------------------------------------------------- Selbsttest (--selftest, nur 4v4)
func _selftest() -> void:
	var ok := true
	var check := func(name: String, cond: bool) -> void:
		print(("PASS  " if cond else "FAIL  ") + name)
		if not cond:
			ok = false
	var run := func(secs: float) -> void:
		for i in int(secs / 0.05):
			for s in sides:
				s["wave_t"] = 1e9
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
	_start_backport(hero)
	check.call("Backport startet in der Lane", hero["bp"] > 0.0)
	run.call(2.0)
	check.call("Backport noch nicht fertig nach 2 s", hero["x"] > 900.0)
	run.call(3.0)
	check.call("Backport fertig nach 5 s (x=%.0f)" % hero["x"], absf(hero["x"] - 120.0) < 1.0 and hero["bp_cd"] > 60.0)
	_start_backport(hero)
	check.call("Kein Backport in der Basis", hero["bp"] == 0.0)
	# 4. Aus der Basis in Lane 1 laufen
	hero["move_to"] = Vector2(1000.0, lane_off_g[0])
	run.call(40.0)
	check.call("Aus der Basis in Lane 1 gelaufen (x=%.0f, y=%.0f)" % [hero["x"], hero["y"]], hero["x"] > 900.0 and hero["y"] < mid)
	# 5. Schaden unterbricht den Backport
	hero["bp_cd"] = 0.0
	hero["move_to"] = null
	_start_backport(hero)
	_damage_hero(hero, 10.0)
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
	# 7. Testfenster
	_dbg("allmax", 0)
	check.call("Testfenster: Alles max (Level %d, Rang Q %d)" % [hero["lvl"], hero["ranks"][0]], hero["lvl"] == int(cfg["maxLevel"]) and hero["ranks"][0] == int(skills.skill_def(hero, 0)["max"]))
	_dbg("reset", 0)
	check.call("Testfenster: Skills zurücksetzen", hero["ranks"][0] == 0 and hero["sp"] == hero["lvl"])
	_dbg("dummies", 0)
	var n_before := units.size()
	_dbg("clear", 0)
	check.call("Testfenster: Puppen und Löschen (%d -> %d)" % [n_before, units.size()], n_before >= 9 and units.size() == 0)
	# 8. Lautstärke nach Entfernung
	var hnode: Node3D = hero["node"]
	hnode.position = _wp(hero["x"], hero["y"], 0)
	cam_free = false
	var g_near := hear_gain(hero["x"] + 100.0, hero["y"], 0)
	var g_mid := hear_gain(hero["x"] + 800.0, hero["y"], 0)
	var g_far := hear_gain(hero["x"] + 1600.0, hero["y"], 0)
	check.call("Ton nach Entfernung: nah %.2f > mittel %.2f > weit %.2f (Basis hört Lane-Ende nicht)" % [g_near, g_mid, g_far], g_near == 1.0 and g_mid < g_near and g_mid > 0.0 and g_far == 0.0)
	# 9. Oberfläche (Steinrahmen): Menü pausiert, Plus-Knopf, Hinweis
	hero["sp"] = 1
	hero["lvl"] = 5
	hero["ranks"] = [0, 0, 0, 0]
	ui.update()
	check.call("Oberfläche: Plus-Knopf bei Q sichtbar", ui.slots[0]["plus"].modulate.a > 0.5)
	ui.toggle_menu()
	check.call("Oberfläche: Menü öffnet und pausiert", ui.menu_open and paused)
	ui.toggle_menu()
	check.call("Oberfläche: Menü schließt und setzt fort", not ui.menu_open and not paused)
	set_display_mode(1, false)
	check.call("Anzeige: Vollbild-Modus wird gemerkt", display_mode == 1)
	set_display_mode(0, false)
	check.call("Anzeige: Fenster-Modus wird gemerkt", display_mode == 0)
	var tip_txt: String = ui._skill_tip(0, skills.skill_def(hero, 0), 0, 5, 1)
	# Optionen: Tastenbelegung
	var uk = Data.user
	var old_q: int = uk.keys["q"]
	uk.keys["q"] = KEY_A
	check.call("Tastenbelegung: A löst Fähigkeit 1 aus, Q nicht mehr", _slot_for_key(KEY_A) == 0 and _slot_for_key(KEY_Q) == -1 and uk.key_name("q") == "A")
	uk.keys["q"] = old_q
	uk.reset_keys()
	check.call("Tastenbelegung: Standard Q W E R B F Tab S P", _slot_for_key(KEY_E) == 2 and uk.action_for_key(KEY_B) == "backport" and uk.action_for_key(KEY_TAB) == "shop" and uk.action_for_key(KEY_Z) == "send_grunt")
	check.call("Oberfläche: Hinweis enthält Name und Rang-1-Zahlen", tip_txt.contains(str(skills.skill_def(hero, 0)["name"])) and tip_txt.contains("Schaden"))
	# Shop: Doppelklick kauft fehlende Teile soweit das Gold reicht (Sturmbrecher mit 400 Gold: Harke + Crit-Mantel)
	var sv_bag: Array = (hero["bag"] as Array).duplicate()
	var sv_gold: float = hero["gold"]
	var sv_x: float = hero["x"]
	hero["bag"] = []
	hero["gold"] = 400.0
	hero["x"] = 100.0
	shop._auto_buy_item("stormBreaker")
	check.call("Shop: Doppelklick mit 400 Gold kauft Harke und Crit-Mantel", hero["bag"] == ["rake", "critCloak"] and absf(hero["gold"]) < 0.01)
	hero["gold"] = 2000.0
	shop._auto_buy_item("stormBreaker")
	check.call("Shop: Doppelklick kauft den Rest (Windumhang) und baut den Sturmbrecher", hero["bag"] == ["stormBreaker"] and absf(hero["gold"] - 1400.0) < 0.01)
	hero["bag"] = sv_bag
	hero["gold"] = sv_gold
	hero["x"] = sv_x
	items.recalc(hero)
	_dbg("god", 0)
	var hp0: float = hero["hp"]
	_damage_hero(hero, 50.0)
	check.call("Testfenster: Unsterblich", hero["hp"] == hp0)
	_dbg("god", 0)
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
		_step_units(sides[0], 0.05)
		if units.is_empty():
			break
	check.call("Monster aus Lane 2 erreichen den Kristall in der Mitte (y=%.0f, Mitte=%.0f)" % [gr["y"], team_mid_y], units.is_empty() or absf(gr["y"] - team_mid_y) < absf(lane_off_g[1] - team_mid_y))
	print("SELFTEST " + ("OK" if ok else "FEHLER"))
	get_tree().quit()


# ---------------------------------------------------------------- Effekt-Test (--fxtest=q|w|e|rfire|rfrost|rlightning --hero=caster --shot=Prefix)
## Stellt den Helden vor eine Gruppe stehender Monster, wirkt die Fähigkeit und speichert Bilder (Echtzeit) in Abständen.
func _fxtest(which: String, prefix: String) -> void:
	for s in sides:
		s["wave_t"] = 1e9
	hero["bonus_hp"] = 1e6
	hero["hp"] = skills.h_max_hp(hero)
	hero["lvl"] = 12
	hero["ranks"] = [fx_rank, fx_rank, fx_rank, 1]
	hero["x"] = 1000.0
	hero["y"] = 0.0
	for i in 9:
		_spawn_unit("grunt", 0.0, 1.0, 0)
		var u: Dictionary = units[units.size() - 1]
		u["x"] = 1000.0 + 170.0 + (i % 3) * 55.0 + (i / 3) * 40.0
		u["y"] = -90.0 + (i / 3) * 70.0 + (i % 3) * 20.0
		u["stun"] = 1e6
	cam_dist = 26.0
	cam_free = true
	cam_focus = _wp(1130.0, 0.0, 0)
	if which.begins_with("look"):                       # Figur aus der Nähe: Kamera folgt dem Helden, der losläuft
		cam_free = false
		cam_dist = 9.0
		cam_pitch = 18.0
	for i in 40:
		await get_tree().process_frame
	var m := {"dx": 300.0, "dy": 0.0, "dist": 300.0, "ang": 0.0, "wx": 1250.0, "wy": 0.0}
	if which.begins_with("r"):
		hero["last_elem"] = which.substr(1)
		m["wx"] = 1000.0
	var slot: int = {"q": 0, "w": 1, "e": 2}.get(which, 3)
	if which == "q" and fx_rank >= 5:
		m["wx"] = 1280.0
	if which == "lookside" and not hero["fig"].is_empty():
		hero["fig"]["yaw"] = -PI / 2.0
	if which == "wauto":                              # Kampfrausch Rang 5: Angriff mit Flächenschaden zeigen
		skills.cast_slot(hero, 1, m)
		for i in 6:
			units[i]["x"] = 1060.0 + (i % 3) * 38.0
			units[i]["y"] = -30.0 + (i / 3) * 45.0
			units[i]["hp"] = 1e9
			units[i]["max"] = 1e9
		hero["target"] = units[0]
	if which == "auto":                               # Normalangriff zeigen
		units[0]["x"] = 1220.0
		units[0]["y"] = 0.0
		hero["target"] = units[0]
		units[0]["hp"] = 1e9
		units[0]["max"] = 1e9
	elif not which.begins_with("look") and which != "wauto":
		skills.cast_slot(hero, slot, m)
	var t0 := Time.get_ticks_msec()
	var k := 0
	var marks := [0.12, 0.3, 0.55, 0.9, 1.4, 2.2, 3.2]
	if which == "wauto" or which == "auto":
		marks = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0]
	while k < marks.size():
		await get_tree().process_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 >= marks[k]:
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
			k += 1
	if which.begins_with("r"):                        # Elementar: Fähigkeit auslösen
		for e in elems:
			e["ab_t"] = 0.0
			e["atk_t"] = 0.0
		t0 = Time.get_ticks_msec()
		k = 0
		while k < 4:
			await get_tree().process_frame
			if (Time.get_ticks_msec() - t0) / 1000.0 >= [0.15, 0.4, 0.8, 1.3][k]:
				get_viewport().get_texture().get_image().save_png("%s_b%d.png" % [prefix, k])
				k += 1
	print("FXTEST fertig")
	get_tree().quit()


# ---------------------------------------------------------------- Test-Simulation (Kommandozeile)
func _run_simulation(secs: float, shot_path: String) -> void:
	var steps := int(secs / 0.05)
	for i in steps:
		step(0.05)
		if shot_path != "":
			_ui_tick(0.05)               # fürs Bild: Meldungen und Tipps mitlaufen lassen
		if trace and i % 100 == 0:   # alle 5 Sekunden: Position des Helden und Ziel (für Fehlersuche)
			var tg: Variant = hero["target"]
			print("t=%.0f Held x=%.0f y=%.0f | Ziel: %s | Einheiten %d" % [t, hero["x"], hero["y"],
				"-" if tg == null else "x=%.0f y=%.0f lane=%d" % [tg["x"], tg["y"], tg["lane"]], units.size()])
	print("SIM %.0f s (Ende bei %.0f s, Sieger %s) | Welle %d | Team-Leben %d : %d | Gold %d | Level %d | Kills %d | Tode %d | Einheiten %d" % [
		secs, t, ("keiner" if winner < 0 else ("A" if winner == 0 else "B")), sides[0]["wave"], team_lives[0], team_lives[1], int(hero["gold"]), hero["lvl"], kills, hero["deaths"], units.size()])
	for p in players:                    # je Spieler: Seite, Held, Level, Kills, Tode, gesendet, Einkommen, Rucksack
		var sent_n := 0
		for k in p["sent"].keys():
			sent_n += int(p["sent"][k])
		print("   %s %s %-6s Lv%2d  Kills %3d  Tode %d  gesendet %3d  Einkommen %5.1f  Gold %5d  Rucksack %s%s" % ["A" if p["side"]["idx"] == 0 else "B", "(du)" if p == hero else "bot", p["key"], p["lvl"], p["kills"], p["deaths"], sent_n, p["income"], int(p["gold"]), str(p["bag"]), ("  Stil " + str(p["bot_state"]["style"])) if p.has("bot_state") else ""])
	if uitip:
		ui.update()
		for sl in ui.slots:
			print("TIP ", (sl["slot"] as Control).tooltip_text)
	if uitip and shot_path != "" and ui != null:                 # Test: Hinweis der Fähigkeit E als Bild zeigen
		ui.update()
		ui._show_tip(0)                                          # Hinweis an der festen Stelle, mit Alt-Erweiterung
		ui.tip.forced = false
		ui.tip.extra.visible = false
		ui.tip.hint.visible = true
	if itemcat and shop != null:
		var cat_root := Control.new()
		cat_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.menu_root.get_parent().add_child(cat_root)
		shop.build_catalog(cat_root)
	if uimenu and ui != null:
		ui.toggle_menu()
		if uioptions:
			ui._show_page(ui.menu_options)
	if merchant_test and not merchant.is_empty():
		_sync_visuals(1.0)
		cam.position = cam.position
		var sp: Vector2 = cam.unproject_position(merchant["goblin"] + Vector3(0, 1.0, 0))
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = sp
		print("MERCHANT Klick auf den Goblin bei ", sp, ": Maus darueber=", _over_merchant(sp))
		_unhandled_input(ev)
		print("MERCHANT Shop offen: ", shop.visible())
		_unhandled_input(ev)
		print("MERCHANT zweiter Klick, Shop offen: ", shop.visible())
		hero["x"] = 30.0                         # Held nah an den Goblin: "Pst!" erscheint
		hero["y"] = -100.0
		_sync_visuals(0.4)
		_sync_visuals(0.2)
	if cam_test_x >= 0.0:
		cam_free = true
		cam_focus = _wp(cam_test_x, 0.0, 0) + Vector3(-9.0, 0.0, 0.0)
	if shot_path != "":
		_sync_visuals(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("Screenshot: ", shot_path)
	get_tree().quit()


## Art der gerade gespawnten Welle (für die Anzeige)
func _wave_kind_after(n: int, side: Dictionary) -> String:
	if n == int(cfg["bossWave"]):
		return "boss"
	return "elite" if n % int(cfg["eliteEvery"]) == 0 else "normal"


func _exit_tree() -> void:
	for k in model_cache:
		if model_cache[k]["root"] != null:
			(model_cache[k]["root"] as Node).free()
