extends RefCounted
## Hauptmenü: links die Menüliste (Singleplayer, Multiplayer, Optionen, Beenden), dahinter später ein Hintergrundbild.
## Singleplayer: Spielmodus, Klasse, Schwierigkeit und Start; rechts erscheint die Vorschau der gewählten Klasse mit ihren vier Fähigkeiten.
## Das Menü nimmt die Farben der gewählten Klasse an (Tank Eisen, Schurke dunkel, Magier lila).

const HudStein := preload("res://scripts/hud_stein.gd")
const SkillIcon := preload("res://scripts/skill_icon.gd")

const MODES := [[1, "1 gegen 1", "Je eine Lane pro Spieler."], [2, "2 gegen 2", "Eine breite Lane pro Team."],
	[4, "4 gegen 4", "Doppel-Lane pro Team. Zur anderen Lane kommst du nur über die Basis (Backport)."]]
const ROLES := {"tank": "Frontkämpfer", "damage": "Nahkämpfer mit Gift", "caster": "Magier mit Feuer, Frost und Blitz"}
const ICONS := {"tank": ["shock", "ironskin", "shieldthrow", "quake"], "damage": ["daggerfan", "poisonblade", "leap", "daggerhail"],
	"caster": ["firefield", "frostcone", "chain", "elemental"]}
const KEYS := ["Q", "W", "E", "R"]

var g: Node
var root: Control
var pages: Dictionary = {}
var nav_btns: Dictionary = {}
var mode_info: Label
var preview: VBoxContainer
var go_btn: Button
var preview_panel: Control
var bg_rect: ColorRect
var panels: Array = []                      # alle Felder, werden mit der Klassenfarbe neu umrandet
var cards: Dictionary = {}


func build(layer: CanvasLayer) -> Button:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	bg_rect = ColorRect.new()                                  # Platzhalter für das spätere Hintergrundbild
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg_rect)
	root.add_child(_nav())
	var area := MarginContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_theme_constant_override("margin_left", 290)
	area.add_theme_constant_override("margin_right", 36)
	area.add_theme_constant_override("margin_top", 36)
	area.add_theme_constant_override("margin_bottom", 36)
	root.add_child(area)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE            # sonst fängt die Fläche die Klicks auf die Menüliste ab
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(stack)
	pages["single"] = _single_page()
	pages["multi"] = _note_page("Multiplayer", "Online-Spiele kommen später.")
	pages["options"] = _options_page()
	for k in pages:
		(pages[k] as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(pages[k])
	_show_page("")                                              # zuerst ist nur das Hintergrundbild mit der Menüliste zu sehen
	_style_all(HudStein.PALETTES["stone"])
	return go_btn


func _nav() -> Control:
	var pc := PanelContainer.new()
	panels.append(pc)
	pc.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pc.offset_right = 250.0
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var title := Label.new()
	title.text = "HERO\nLANE\nWARS"
	title.add_theme_font_size_override("font_size", 38)
	title.custom_minimum_size = Vector2(0, 150)
	vb.add_child(title)
	var group := ButtonGroup.new()
	group.allow_unpress = true                                 # nochmal klicken klappt das Fenster wieder zu
	for e in [["single", "Singleplayer"], ["multi", "Multiplayer"], ["options", "Optionen"]]:
		var b := Button.new()
		b.text = e[1]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		var pk: String = e[0]
		b.pressed.connect(func(): _show_page(pk if b.button_pressed else ""))
		if pk == "multi":
			b.tooltip_text = "Kommt später"
		vb.add_child(b)
		nav_btns[pk] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	var q := Button.new()
	q.text = "Beenden"
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q.custom_minimum_size = Vector2(0, 52)
	q.add_theme_font_size_override("font_size", 20)
	q.focus_mode = Control.FOCUS_NONE
	q.pressed.connect(func(): g.get_tree().quit())
	vb.add_child(q)
	return pc


func _show_page(k: String) -> void:
	for p in pages:
		(pages[p] as Control).visible = p == k
	if k != "":
		(nav_btns[k] as Button).button_pressed = true


func _label(txt: String, size: int = 14, dim: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.modulate = Color(1, 1, 1, 0.65)
	return l


func _single_page() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.add_child(_settings_panel())
	preview_panel = _preview_panel()
	preview_panel.visible = false                              # erscheint erst, wenn eine Klasse angeklickt wird
	hb.add_child(preview_panel)
	return hb


func _settings_panel() -> Control:
	var pc := PanelContainer.new()
	panels.append(pc)
	pc.custom_minimum_size = Vector2(420, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	vb.add_child(_label("Spielmodus", 15, true))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	var mg := ButtonGroup.new()
	for m in MODES:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_group = mg
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = m[0] == g.team_size
		var mv: int = m[0]
		var info: String = m[2]
		b.pressed.connect(func():
			g.team_size = mv
			mode_info.text = info)
		mrow.add_child(b)
	vb.add_child(mrow)
	mode_info = _label(str(MODES[[1, 2, 4].find(g.team_size)][2]) if [1, 2, 4].has(g.team_size) else "", 12, true)
	mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_info.custom_minimum_size = Vector2(0, 34)
	vb.add_child(mode_info)
	vb.add_child(_label("Klasse", 15, true))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	var cg := ButtonGroup.new()
	for k in ["tank", "damage", "caster"]:
		crow.add_child(_class_card(k, cg))
	vb.add_child(crow)
	vb.add_child(_label("Schwierigkeit", 15, true))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	var dg := ButtonGroup.new()
	for k in ["easy", "normal", "hard", "expert"]:
		var b := Button.new()
		b.text = str(Data.raw["diff"][k]["name"])
		b.toggle_mode = true
		b.button_group = dg
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = k == g.diff_key
		var dk: String = k
		b.pressed.connect(func(): g.diff_key = dk)
		drow.add_child(b)
	vb.add_child(drow)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	go_btn = Button.new()
	go_btn.text = "Spiel starten"
	go_btn.custom_minimum_size = Vector2(0, 58)
	go_btn.add_theme_font_size_override("font_size", 24)
	go_btn.focus_mode = Control.FOCUS_NONE
	go_btn.disabled = true                                      # erst nach der Klassenwahl
	go_btn.tooltip_text = "Wähle zuerst eine Klasse"
	vb.add_child(go_btn)
	return pc


func _class_card(key: String, group: ButtonGroup) -> Control:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.button_pressed = false
	cards[key] = b
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	var ic := SkillIcon.new()
	ic.kind = "class_" + key
	ic.round_look = true
	ic.plate = Color.html(str(Data.heroes[key]["col"])).darkened(0.6)
	ic.ring = HudStein.PALETTES[key]["border"]
	ic.custom_minimum_size = Vector2(64, 64)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var nm := _label(str(Data.heroes[key]["name"]), 16)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	b.add_child(vb)
	b.pressed.connect(func(): _apply_class(key))
	return b


func _preview_panel() -> Control:
	var pc := PanelContainer.new()
	panels.append(pc)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview = VBoxContainer.new()
	preview.add_theme_constant_override("separation", 12)
	pc.add_child(preview)
	return pc


## Klasse gewählt: Hauptmenü in die Klassenfarbe tauchen und die Vorschau neu aufbauen
func _style_all(pal: Dictionary) -> void:
	g.get_window().theme = HudStein.make_theme(pal)
	bg_rect.color = (pal["dark"] as Color).darkened(0.35)
	for pn in panels:
		(pn as PanelContainer).add_theme_stylebox_override("panel", HudStein.box(pal["bg"], pal["border"], 3, 4, 16))


func _apply_class(key: String) -> void:
	g.hero_key = key
	var pal: Dictionary = HudStein.PALETTES[key]
	_style_all(pal)
	preview_panel.visible = true
	go_btn.disabled = false
	go_btn.tooltip_text = ""
	for c in preview.get_children():
		c.queue_free()
	var h: Dictionary = Data.heroes[key]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var ic := SkillIcon.new()
	ic.kind = "class_" + key
	ic.round_look = true
	ic.plate = Color.html(str(h["col"])).darkened(0.6)
	ic.ring = pal["border"]
	ic.custom_minimum_size = Vector2(150, 150)                 # später: 3D-Modell des Helden
	top.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(str(h["name"]), 34)
	nm.add_theme_color_override("font_color", pal["hi"])
	tv.add_child(nm)
	tv.add_child(_label(str(ROLES.get(key, "")), 16, true))
	var stats := _label("Leben %d   Rüstung %s   Schaden %d   Lauftempo %d" % [int(h["hp"]), str(h["armor"]).replace(".", ","), int(h["dmg"]), int(h["spd"])], 13, true)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(stats)
	var desc := _label(str(h["desc"]), 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(desc)
	top.add_child(tv)
	preview.add_child(top)
	preview.add_child(_label("Fähigkeiten", 15, true))
	var defs: Array = Data.raw["skills"][key]
	for i in 4:
		var d: Dictionary = defs[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sic := SkillIcon.new()
		sic.kind = str(ICONS[key][i])
		sic.plate = pal["plate"]
		sic.custom_minimum_size = Vector2(54, 54)
		sic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", HudStein.box(pal["inset"], pal["border"], 3, 3, 3))
		frame.add_child(sic)
		row.add_child(frame)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var ttl := "%s   (%s)" % [str(d["name"]), KEYS[i]]
		if d.has("cd"):
			ttl += "   Abklingzeit %s s" % str(d["cd"]).replace(".", ",")
		var tl := _label(ttl, 15)
		tl.add_theme_color_override("font_color", pal["hi"])
		col.add_child(tl)
		var first := _label(str(d["info"][0]), 13)
		first.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		first.modulate = Color(1, 1, 1, 0.85)
		col.add_child(first)
		row.add_child(col)
		preview.add_child(row)


func _note_page(title: String, text: String) -> Control:
	var pc := PanelContainer.new()
	panels.append(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	vb.add_child(_label(title, 28))
	vb.add_child(_label(text, 16, true))
	return pc


func _options_page() -> Control:
	var pc := PanelContainer.new()
	panels.append(pc)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pc.custom_minimum_size = Vector2(520, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	vb.add_child(_label("Optionen", 28))
	vb.add_child(_label("Lautstärke", 15, true))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 100.0
	sl.step = 1.0
	sl.custom_minimum_size = Vector2(0, 26)
	sl.value = g._load_volume() * 100.0
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float): g._save_volume(v / 100.0))
	vb.add_child(sl)
	vb.add_child(_label("Anzeige", 15, true))
	var ob := OptionButton.new()
	ob.add_item("Fenster", 0)
	ob.add_item("Vollbild (randlos, empfohlen)", 1)
	ob.add_item("Exklusives Vollbild", 2)
	ob.select(ob.get_item_index(g.display_mode))
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(0, 36)
	ob.item_selected.connect(func(idx: int): g.set_display_mode(ob.get_item_id(idx)))
	vb.add_child(ob)
	var shake := CheckBox.new()
	shake.text = "Bildschirmwackeln"
	shake.button_pressed = g.shake_on
	shake.focus_mode = Control.FOCUS_NONE
	shake.toggled.connect(func(on: bool): g.set_shake_on(on))
	vb.add_child(shake)
	return pc


## Test: Knopf für einen Mausklick (Menüliste: single, multi, options; Klassenkarte: class_tank ...)
func target(key: String) -> Control:
	if key.begins_with("class_"):
		return cards[key.substr(6)]
	return nav_btns[key]
