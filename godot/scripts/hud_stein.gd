extends RefCounted
## Oberfläche im Steinrahmen-Stil (Warcraft-Look), alles im Code gezeichnet: Thema (Knöpfe, Felder, Hinweise), untere Leiste
## mit Heldenbild, Lebens- und Erfahrungsbalken, vier Fähigkeitsfeldern mit Bildchen, Rucksack, Knöpfen für Shop, Pause und Menü,
## sowie das Menü (Optionen mit Lautstärke, Speichern (folgt), Zurück zum Hauptmenü).

const SkillIcon := preload("res://scripts/skill_icon.gd")
const SkillSlot := preload("res://scripts/skill_slot.gd")

const STONE := Color("#3b3733")
const STONE_DARK := Color("#27241f")
const GOLD := Color("#b49a5c")
const GOLD_HI := Color("#e8c46a")
const TEXT := Color("#ecdfbd")
const TEXT_DIM := Color("#9a917c")

var g: Node
var slots: Array = []
var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var name_label: Label
var portrait: Control
var pause_btn: Button
var menu_root: Control
var menu_main: Control
var menu_options: Control
var menu_confirm: Control
var menu_open := false
var was_paused := false
var vol_slider: HSlider
var bar: PanelContainer
var mini_reserved := 270.0
var display_btn: OptionButton


func _init(game: Node) -> void:
	g = game


static func box(bg: Color, border: Color = GOLD, bw: int = 3, radius: int = 3, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## Gemeinsames Thema für das ganze Fenster: Steinfelder, Goldrand, Pergament-Schrift
static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(STONE, GOLD, 3, 3, 8))
	t.set_stylebox("panel", "Panel", box(STONE, GOLD, 3, 3, 8))
	t.set_stylebox("normal", "Button", box(STONE_DARK, Color("#7a6a46"), 2, 3, 6))
	t.set_stylebox("hover", "Button", box(Color("#4a443d"), GOLD_HI, 2, 3, 6))
	t.set_stylebox("pressed", "Button", box(Color("#1f1c18"), GOLD_HI, 2, 3, 6))
	t.set_stylebox("disabled", "Button", box(Color("#2a2825"), Color("#4d4636"), 2, 3, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("#fff3c4"))
	t.set_color("font_pressed_color", "Button", Color("#fff3c4"))
	t.set_color("font_disabled_color", "Button", Color("#7f7765"))
	t.set_stylebox("panel", "TooltipPanel", box(Color("#262321"), GOLD, 3, 3, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(Color("#262321"), GOLD, 2, 3, 6))
	t.set_stylebox("hover", "PopupMenu", box(Color("#4a443d"), GOLD_HI, 1, 2, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color("#fff3c4"))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color("#fff3c4"))
	return t


# ---------------------------------------------------------------- untere Leiste
func build_bar(layer: CanvasLayer, mini_w: float) -> void:
	mini_reserved = mini_w + 28.0
	bar = PanelContainer.new()                           # kompakter Block: so breit wie sein Inhalt, mittig unten (Position in update())
	bar.custom_minimum_size = Vector2(0, 152)
	bar.add_theme_stylebox_override("panel", box(STONE, GOLD, 4, 4, 10))
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	row.add_child(_portrait_block())
	row.add_child(_skills_block())
	row.add_child(_right_block())
	bar.reset_size()


func _portrait_block() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(Color("#1c1a17"), GOLD, 3, 3, 4))
	frame.custom_minimum_size = Vector2(84, 84)
	var ic := SkillIcon.new()
	ic.kind = "class_" + str(g.hero["key"])
	ic.plate = Color.html(str(g.hero["d"]["col"])).darkened(0.55)
	ic.custom_minimum_size = Vector2(72, 72)
	frame.add_child(ic)
	hb.add_child(frame)
	portrait = ic
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.custom_minimum_size = Vector2(176, 0)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(name_label)
	hp_bar = _bar(Color("#4cd964"), 24.0)
	hp_label = _bar_label(hp_bar)
	vb.add_child(hp_bar)
	xp_bar = _bar(Color("#6fa8ff"), 16.0)
	xp_label = _bar_label(xp_bar)
	xp_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(xp_bar)
	var hint := Label.new()
	hint.text = "Lebensbalken: auch über dem Helden"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.visible = false
	vb.add_child(hint)
	hb.add_child(vb)
	return hb


func _bar(fill: Color, h: float) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.add_theme_stylebox_override("background", box(Color("#15130f"), Color("#7a6a46"), 2, 2, 0))
	pb.add_theme_stylebox_override("fill", box(fill, fill, 0, 2, 0))
	return pb


func _bar_label(pb: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(l)
	return l


func _skills_block() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	slots.clear()
	var keys := ["Q", "W", "E", "R"]
	var icon_kinds: Dictionary = {
		"tank": ["shock", "ironskin", "shieldthrow", "quake"],
		"damage": ["daggerfan", "poisonblade", "leap", "daggerhail"],
		"caster": ["firefield", "frostcone", "chain", "elemental"]}
	for i in 4:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 24)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plus.focus_mode = Control.FOCUS_NONE
		plus.add_theme_color_override("font_color", GOLD_HI)
		plus.tooltip_text = "Fähigkeit verbessern (Skillpunkt einsetzen)"
		var idx: int = i
		plus.pressed.connect(func(): g.skills.learn(g.hero, idx))
		col.add_child(plus)
		var slot := SkillSlot.new()
		slot.add_theme_stylebox_override("panel", box(Color("#1c1a17"), GOLD, 3, 3, 4))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(64, 64)
		slot.add_child(holder)
		var ic := SkillIcon.new()
		ic.kind = str(icon_kinds[str(g.hero["key"])][i])
		ic.plate = Color("#2b2824")
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(ic)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.66)
		cd.anchor_left = 0.0
		cd.anchor_right = 1.0
		cd.anchor_top = 0.0
		cd.anchor_bottom = 0.0
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cd)
		var cdl := Label.new()
		cdl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cdl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cdl.add_theme_font_size_override("font_size", 20)
		cdl.add_theme_color_override("font_outline_color", Color.BLACK)
		cdl.add_theme_constant_override("outline_size", 6)
		cdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cdl)
		var kl := Label.new()
		kl.text = keys[i]
		kl.position = Vector2(4, 0)
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", GOLD_HI)
		kl.add_theme_color_override("font_outline_color", Color.BLACK)
		kl.add_theme_constant_override("outline_size", 4)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(kl)
		var lock := Label.new()
		lock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lock.offset_top = -18.0
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_outline_color", Color.BLACK)
		lock.add_theme_constant_override("outline_size", 4)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lock)
		col.add_child(slot)
		var pips := Label.new()
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pips.add_theme_font_size_override("font_size", 11)
		pips.add_theme_color_override("font_color", GOLD_HI)
		col.add_child(pips)
		hb.add_child(col)
		slots.append({"plus": plus, "slot": slot, "icon": ic, "cd": cd, "cdl": cdl, "lock": lock, "pips": pips, "key": keys[i], "h": 66.0})
	return hb


func _right_block() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	g.shop_btn = _small_button("Shop (Tab)")
	g.shop_btn.pressed.connect(g._toggle_shop)
	btns.add_child(g.shop_btn)
	pause_btn = _small_button("Pause (P)")
	pause_btn.pressed.connect(g._toggle_pause)
	btns.add_child(pause_btn)
	var menu_btn := _small_button("Menü (Esc)")
	menu_btn.pressed.connect(toggle_menu)
	btns.add_child(menu_btn)
	vb.add_child(btns)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 6)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	g.bag_btns.clear()
	for i in int(g.cfg["bagSize"]):
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 46)
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 11)
		b.focus_mode = Control.FOCUS_NONE
		var slot_i: int = i
		b.pressed.connect(func():
			if not g.items.sell(g.hero, slot_i):
				if slot_i < g.hero["bag"].size():
					g._flash_msg("Verkaufen nur in der Basis (Backport: B)"))
		grid.add_child(b)
		g.bag_btns.append(b)
	lower.add_child(grid)
	g.pot_btn = Button.new()
	g.pot_btn.custom_minimum_size = Vector2(62, 96)
	g.pot_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.pot_btn.add_theme_font_size_override("font_size", 12)
	g.pot_btn.focus_mode = Control.FOCUS_NONE
	g.pot_btn.pressed.connect(func(): g.items.drink_potion(g.hero))
	lower.add_child(g.pot_btn)
	vb.add_child(lower)
	return vb


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


# ---------------------------------------------------------------- Aktualisierung (jedes Bild)
func update() -> void:
	if slots.is_empty() or g.hero.is_empty():
		return
	_place_bar()
	var h: Dictionary = g.hero
	var sk = g.skills
	name_label.text = "%s   Level %d" % [str(h["d"]["name"]), h["lvl"]]
	var mx: float = sk.h_max_hp(h)
	hp_bar.max_value = mx
	hp_bar.value = clampf(h["hp"], 0.0, mx)
	hp_label.text = "Leben  %d / %d" % [int(h["hp"]), int(mx)] if h["dead"] <= 0.0 else "Gefallen: %ds" % int(ceil(h["dead"]))
	var frac: float = h["hp"] / maxf(1.0, mx)
	var fill: Color = Color("#4cd964").lerp(Color("#ff4d3d"), clampf(1.0 - frac * 1.6, 0.0, 1.0))
	hp_bar.add_theme_stylebox_override("fill", box(fill, fill, 0, 2, 0))
	var need: float = g._xp_need(h["lvl"])
	xp_bar.max_value = need
	xp_bar.value = minf(h["xp"], need)
	xp_label.text = "Erfahrung  %d / %d" % [int(h["xp"]), int(need)] if h["lvl"] < int(g.cfg["maxLevel"]) else "Höchste Stufe"
	for i in 4:
		var s: Dictionary = slots[i]
		var def: Dictionary = sk.skill_def(h, i)
		var r: int = h["ranks"][i]
		var rmax := int(def["max"])
		var unlock := int(g.cfg["unlock"][i])
		var passive: bool = def.get("passive", false)
		s["plus"].modulate.a = 1.0 if sk.can_learn(h, i) else 0.0
		s["plus"].mouse_filter = Control.MOUSE_FILTER_STOP if sk.can_learn(h, i) else Control.MOUSE_FILTER_IGNORE
		s["pips"].text = "●".repeat(r) + "○".repeat(rmax - r)
		var locked: bool = h["lvl"] < unlock and r == 0
		var lock_txt := ""
		var dim := false
		if locked:
			lock_txt = "ab Lv %d" % unlock
			dim = true
		elif r == 0:
			lock_txt = "nicht gelernt"
			dim = true
		elif passive:
			lock_txt = "passiv"
		s["lock"].text = lock_txt
		(s["icon"] as Control).modulate = Color(0.5, 0.5, 0.55) if dim else Color.WHITE
		var cd_left: float = h["cds"][i]
		var cd_total: float = maxf(0.1, float(def.get("cd", 1.0)) * (1.0 - float(h["cdr"])))
		var cdr_rect: ColorRect = s["cd"]
		if cd_left > 0.0 and r > 0 and not passive:
			cdr_rect.anchor_bottom = clampf(cd_left / cd_total, 0.0, 1.0)
			s["cdl"].text = str(int(ceil(cd_left))) if cd_left >= 1.0 else "%.1f" % cd_left
		else:
			cdr_rect.anchor_bottom = 0.0
			s["cdl"].text = ""
		(s["slot"] as Control).tooltip_text = _skill_tip(i, def, r, rmax, unlock)
	if pause_btn != null:
		pause_btn.text = "Weiter (P)" if g.paused else "Pause (P)"


## Leiste mittig unten, aber nie über die Minimap links
func _place_bar() -> void:
	if bar == null:
		return
	var vp: Vector2 = g.get_viewport().get_visible_rect().size
	var w: float = bar.get_combined_minimum_size().x
	var hgt: float = maxf(bar.get_combined_minimum_size().y, 152.0)
	bar.size = Vector2(w, hgt)
	var x: float = maxf((vp.x - w) / 2.0, mini_reserved)
	x = minf(x, maxf(0.0, vp.x - w - 6.0))
	bar.position = Vector2(x, vp.y - hgt - 8.0)


func _skill_tip(i: int, def: Dictionary, r: int, rmax: int, unlock: int) -> String:
	var sk = g.skills
	var h: Dictionary = g.hero
	var passive: bool = def.get("passive", false)
	var t := "[b][color=#e8c46a]%s[/color][/b]   [color=#b8b0a0](Taste %s)[/color]\n" % [str(def["name"]), str(slots[i]["key"])]
	var meta := "Rang %d von %d" % [r, rmax]
	if not passive:
		meta = "Abklingzeit %s s  ·  " % sk._f1(float(def["cd"]) * (1.0 - float(h["cdr"]))) + meta
	meta += "  ·  ab Level %d" % unlock
	t += "[color=#b8b0a0]%s[/color]\n\n" % meta
	for line in def["info"]:
		t += "• %s\n" % str(line)
	t += "\n"
	if r > 0:
		t += "[color=#9fe08a]Jetzt (Rang %d):[/color] %s\n" % [r, sk.tip(h, i, r)]
	if r < rmax:
		if r > 0:
			t += "[color=#8fd8ff]Nächster Rang (%d):[/color] %s" % [r + 1, sk.tip(h, i, r + 1)]
		else:
			t += "[color=#8fd8ff]Rang 1:[/color] %s" % sk.tip(h, i, 1)
	if int(h["sp"]) > 0 and sk.can_learn(h, i):
		t += "\n\n[color=#e8c46a]Klick auf das Plus verbessert diese Fähigkeit.[/color]"
	return t


# ---------------------------------------------------------------- Menü
func build_menu(layer: CanvasLayer) -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(menu_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(380, 400)
	center.add_child(stack)
	menu_main = _menu_panel("Menü", [["Weiter spielen", toggle_menu], ["Optionen", func(): _show_page(menu_options)], ["Speichern", Callable()],
		["Zurück zum Hauptmenü", func(): _show_page(menu_confirm)]])
	stack.add_child(menu_main)
	# Speichern ist noch nicht möglich: Knopf sperren und erklären
	for b in menu_main.find_children("*", "Button", true, false):
		if (b as Button).text == "Speichern":
			(b as Button).disabled = true
			(b as Button).tooltip_text = "Speichern kommt später (der Spielstand wird dann auf dem Rechner abgelegt)."
	menu_options = _build_options()
	stack.add_child(menu_options)
	menu_confirm = _menu_panel("Partie beenden?", [["Ja, zum Hauptmenü", func():
			Data.autostart = false
			g.get_tree().reload_current_scene()], ["Nein, weiterspielen", func(): _show_page(menu_main)]])
	var note := Label.new()
	note.text = "Der aktuelle Spielstand geht verloren."
	note.add_theme_font_size_override("font_size", 13)
	(menu_confirm.get_child(0) as VBoxContainer).add_child(note)
	(menu_confirm.get_child(0) as VBoxContainer).move_child(note, 1)
	stack.add_child(menu_confirm)
	_show_page(menu_main)


func _menu_panel(title: String, entries: Array) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pc.add_theme_stylebox_override("panel", box(STONE, GOLD, 4, 4, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", GOLD_HI)
	vb.add_child(tl)
	for e in entries:
		var b := Button.new()
		b.text = str(e[0])
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		if (e[1] as Callable).is_valid():
			b.pressed.connect(e[1])
		vb.add_child(b)
	return pc


func _build_options() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pc.add_theme_stylebox_override("panel", box(STONE, GOLD, 4, 4, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var tl := Label.new()
	tl.text = "Optionen"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", GOLD_HI)
	vb.add_child(tl)
	var vl := Label.new()
	vl.text = "Lautstärke"
	vb.add_child(vl)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.step = 1.0
	vol_slider.custom_minimum_size = Vector2(0, 26)
	vol_slider.focus_mode = Control.FOCUS_NONE
	vol_slider.value_changed.connect(func(v: float):
		if g.snd != null:
			g.snd.volume = v / 100.0
		g._save_volume(v / 100.0))
	vb.add_child(vol_slider)
	var dl := Label.new()
	dl.text = "Anzeige"
	vb.add_child(dl)
	display_btn = OptionButton.new()
	display_btn.add_item("Fenster", 0)
	display_btn.add_item("Vollbild (randlos, empfohlen)", 1)
	display_btn.add_item("Exklusives Vollbild", 2)
	display_btn.focus_mode = Control.FOCUS_NONE
	display_btn.custom_minimum_size = Vector2(0, 34)
	display_btn.item_selected.connect(func(idx: int): g.set_display_mode(display_btn.get_item_id(idx)))
	vb.add_child(display_btn)
	var shake := CheckBox.new()
	shake.text = "Bildschirmwackeln"
	shake.button_pressed = g.shake_on
	shake.focus_mode = Control.FOCUS_NONE
	shake.toggled.connect(func(on: bool): g.set_shake_on(on))
	vb.add_child(shake)
	var tips := Button.new()
	tips.text = "Tipps erneut zeigen"
	tips.custom_minimum_size = Vector2(0, 40)
	tips.focus_mode = Control.FOCUS_NONE
	tips.pressed.connect(func():
		g.tips_seen = {}
		g._save_tips()
		g._flash_msg("Tipps werden wieder gezeigt"))
	vb.add_child(tips)
	var back := Button.new()
	back.text = "Zurück"
	back.custom_minimum_size = Vector2(0, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): _show_page(menu_main))
	vb.add_child(back)
	return pc


func _show_page(page: Control) -> void:
	for p in [menu_main, menu_options, menu_confirm]:
		(p as Control).visible = p == page
	if page == menu_options and display_btn != null:
		display_btn.select(display_btn.get_item_index(g.display_mode))
	if page == menu_options and vol_slider != null:
		vol_slider.set_value_no_signal((g.snd.volume if g.snd != null else 0.4) * 100.0)


func toggle_menu() -> void:
	if g.over or not g.started:
		return
	if menu_open:
		menu_open = false
		menu_root.visible = false
		if not was_paused and g.paused:
			g._toggle_pause()
	else:
		menu_open = true
		was_paused = g.paused
		if not g.paused:
			g._toggle_pause()
		g.pause_label.visible = false
		_show_page(menu_main)
		menu_root.visible = true
