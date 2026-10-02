extends ScrollContainer
## Optionen (gemeinsam für das Hauptmenü und das Spiel-Menü): Ton, Grafik, Anzeige, Kamera, Steuerung (Tasten ändern), Hinweise, Barrierefreiheit.
## Alles wird in Data.user gespeichert und sofort angewendet (game.apply_settings()).

var g: Node
var in_game := false
var capturing := ""                  # Aktion, deren neue Taste gerade abgefragt wird
var key_btns: Dictionary = {}
var head_col := Color("#e8c46a")


func build(game: Node, ingame: bool, head: Color) -> void:
	g = game
	in_game = ingame
	head_col = head
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var u = Data.user

	_head(vb, "Ton")
	var vrow := _row(vb, "Lautstärke")
	var vs := HSlider.new()
	vs.min_value = 0.0
	vs.max_value = 100.0
	vs.step = 1.0
	vs.value = u.volume * 100.0
	vs.custom_minimum_size = Vector2(220, 24)
	vs.focus_mode = Control.FOCUS_NONE
	vs.value_changed.connect(func(v: float):
		u.volume = v / 100.0
		_changed())
	vrow.add_child(vs)
	vb.add_child(_check("Ton aus (stumm)", u.mute, func(on: bool):
		u.mute = on
		_changed()))
	var mus := Label.new()
	mus.text = "Musik: kommt, sobald es Musik im Spiel gibt."
	mus.add_theme_font_size_override("font_size", 12)
	mus.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(mus)

	_head(vb, "Grafik")
	_option(vb, "Qualität", ["Niedrig", "Mittel", "Hoch"], u.gfx, func(i: int):
		u.gfx = i
		_changed())
	var gl := Label.new()
	gl.text = "Qualität ändert Schatten, Kantenglättung, Partikelmenge und Effektlichter."
	gl.add_theme_font_size_override("font_size", 12)
	gl.modulate = Color(1, 1, 1, 0.6)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(gl)
	var caps := [0, 30, 60, 120]
	_option(vb, "Bildrate", ["Unbegrenzt", "30", "60", "120"], maxi(0, caps.find(u.fps_cap)), func(i: int):
		u.fps_cap = caps[i]
		_changed())
	vb.add_child(_check("Vertikale Synchronisierung", u.vsync, func(on: bool):
		u.vsync = on
		_changed()))
	var scales := [0.85, 1.0, 1.2]
	var sidx := 1
	for k in scales.size():
		if absf(scales[k] - u.ui_scale) < 0.05:
			sidx = k
	_option(vb, "Oberflächengröße", ["Klein", "Normal", "Groß"], sidx, func(i: int):
		u.ui_scale = scales[i]
		_changed())

	_head(vb, "Anzeige")
	_option(vb, "Anzeigemodus", ["Fenster", "Vollbild (randlos, empfohlen)", "Exklusives Vollbild"], g.display_mode, func(i: int):
		g.set_display_mode(i))
	vb.add_child(_check("Bildrate (FPS) anzeigen", u.show_fps, func(on: bool):
		u.show_fps = on
		_changed()))
	vb.add_child(_check("Lebenszahl über deinem Helden", u.hp_numbers, func(on: bool):
		u.hp_numbers = on
		_changed()))
	vb.add_child(_check("Bildschirmwackeln", g.shake_on, func(on: bool): g.set_shake_on(on)))

	_head(vb, "Kamera")
	var crow := _row(vb, "Geschwindigkeit")
	var cs := HSlider.new()
	cs.min_value = 0.5
	cs.max_value = 2.0
	cs.step = 0.1
	cs.value = u.cam_speed
	cs.custom_minimum_size = Vector2(220, 24)
	cs.focus_mode = Control.FOCUS_NONE
	cs.value_changed.connect(func(v: float):
		u.cam_speed = v
		_changed())
	crow.add_child(cs)
	vb.add_child(_check("Randscrollen (Maus am Bildrand schiebt die Kamera)", u.edge_scroll, func(on: bool):
		u.edge_scroll = on
		_changed()))
	var cl := Label.new()
	cl.text = "Pfeiltasten schieben die Kamera immer, die Leertaste holt sie zurück zum Helden."
	cl.add_theme_font_size_override("font_size", 12)
	cl.modulate = Color(1, 1, 1, 0.6)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(cl)

	_head(vb, "Steuerung")
	for d in Data.UserSettings.KEY_DEFS:
		var row := _row(vb, str(d[1]))
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 30)
		b.focus_mode = Control.FOCUS_NONE
		var act: String = d[0]
		b.pressed.connect(func(): _start_capture(act))
		row.add_child(b)
		key_btns[act] = b
	var reset := Button.new()
	reset.text = "Tasten zurücksetzen"
	reset.custom_minimum_size = Vector2(0, 34)
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func():
		u.reset_keys()
		_changed()
		_refresh_keys())
	vb.add_child(reset)
	var kn := Label.new()
	kn.text = "Taste anklicken, dann die neue Taste drücken (Esc bricht ab)."
	kn.add_theme_font_size_override("font_size", 12)
	kn.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(kn)
	_refresh_keys()

	_head(vb, "Hinweise")
	vb.add_child(_check("Rang-Übersicht der Fähigkeiten immer zeigen (ohne Alt)", u.alt_always, func(on: bool):
		u.alt_always = on
		_changed()))
	if in_game:
		var tips := Button.new()
		tips.text = "Tipps erneut zeigen"
		tips.custom_minimum_size = Vector2(0, 34)
		tips.focus_mode = Control.FOCUS_NONE
		tips.pressed.connect(func():
			g.tips_seen = {}
			g._save_tips()
			g._flash_msg("Tipps werden wieder gezeigt"))
		vb.add_child(tips)

	_head(vb, "Barrierefreiheit")
	vb.add_child(_check("Farbenblind-Modus (Lebensbalken blau und orange statt grün und rot)", u.colorblind, func(on: bool):
		u.colorblind = on
		_changed()))
	var lang := Label.new()
	lang.text = "Sprache: Deutsch (weitere Sprachen noch nicht verfügbar)."
	lang.add_theme_font_size_override("font_size", 12)
	lang.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(lang)


func _changed() -> void:
	Data.user.save()
	g.apply_settings()


func _head(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", head_col)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)
	vb.add_child(l)


func _row(vb: VBoxContainer, label: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	hb.add_child(l)
	vb.add_child(hb)
	return hb


func _option(vb: VBoxContainer, label: String, items: Array, current: int, on_pick: Callable) -> OptionButton:
	var hb := _row(vb, label)
	var ob := OptionButton.new()
	for i in items.size():
		ob.add_item(str(items[i]), i)
	ob.select(clampi(current, 0, items.size() - 1))
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(240, 32)
	ob.item_selected.connect(func(idx: int): on_pick.call(ob.get_item_id(idx)))
	hb.add_child(ob)
	return ob


func _check(txt: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = txt
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	return c


func _refresh_keys() -> void:
	for act in key_btns:
		(key_btns[act] as Button).text = "Taste drücken …" if capturing == act else Data.user.key_name(act)


func _start_capture(act: String) -> void:
	capturing = act
	_refresh_keys()


## Neue Taste: Esc bricht ab; reservierte Tasten (F2, F11, Leertaste, Umschalten, Alt, Strg) und Zahlen 1-3 sind gesperrt;
## wird die Taste schon benutzt, tauschen die beiden Aktionen ihre Tasten.
func _input(event: InputEvent) -> void:
	if capturing == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.keycode
	if code == KEY_ESCAPE:
		capturing = ""
		_refresh_keys()
		return
	if [KEY_F2, KEY_F11, KEY_SPACE, KEY_SHIFT, KEY_ALT, KEY_CTRL, KEY_1, KEY_2, KEY_3, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN].has(code):
		if in_game:
			g._flash_msg("Diese Taste ist reserviert")
		return
	var u = Data.user
	var other: String = u.action_for_key(code)
	if other != "" and other != capturing:
		u.keys[other] = u.keys[capturing]
	u.keys[capturing] = code
	capturing = ""
	_changed()
	_refresh_keys()
