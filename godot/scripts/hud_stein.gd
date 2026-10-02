extends RefCounted
## Oberfläche (Stein-/Metall-Stil, Anordnung nach dem League-of-Legends-Vorbild), alles im Code gezeichnet: Thema (Knöpfe, Felder, Hinweise),
## untere Leiste mit rundem Heldenbild, Fähigkeiten (Bildchen, Plus-Knöpfe, Rang-Punkte), Leben und Erfahrung, Rucksack mit Gold (Klick = Shop),
## Trank und Backport, sowie das Menü (Esc: Optionen mit Lautstärke und Anzeige, Speichern (folgt), Zurück zum Hauptmenü).
## Das Aussehen ändert sich mit der Klasse: Tank = Eisen, Schurke = dunkel, Magier = lila.

const SkillIcon := preload("res://scripts/skill_icon.gd")
const SkillSlot := preload("res://scripts/skill_slot.gd")
const ItemIcon := preload("res://scripts/item_icon.gd")
const OptionsPanel := preload("res://scripts/options_panel.gd")

const PALETTES := {
	"stone": {"bg": Color("#3b3733"), "dark": Color("#27241f"), "border": Color("#b49a5c"), "hi": Color("#e8c46a"), "text": Color("#ecdfbd"), "dim": Color("#9a917c"), "plate": Color("#2b2824"), "inset": Color("#1c1a17")},
	"tank": {"bg": Color("#3b4048"), "dark": Color("#23272d"), "border": Color("#8d99a8"), "hi": Color("#d3dbe6"), "text": Color("#e4e9f0"), "dim": Color("#8e97a3"), "plate": Color("#2a2e35"), "inset": Color("#1a1d22")},
	"damage": {"bg": Color("#1d1b1e"), "dark": Color("#101012"), "border": Color("#8a3030"), "hi": Color("#d05555"), "text": Color("#ddd4d4"), "dim": Color("#8a7f7f"), "plate": Color("#18171a"), "inset": Color("#0b0b0d")},
	"caster": {"bg": Color("#35264d"), "dark": Color("#1f1530"), "border": Color("#a384d8"), "hi": Color("#d6c1ff"), "text": Color("#efe4ff"), "dim": Color("#9d8cbd"), "plate": Color("#271a3a"), "inset": Color("#170f24")},
}

var g: Node
var pal: Dictionary = PALETTES["stone"]
var slots: Array = []
var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label
var portrait_wrap: Control
var gold_btn: Button
var bp_btn: Button
var menu_root: Control
var menu_main: Control
var menu_options: Control
var menu_confirm: Control
var menu_open := false
var was_paused := false
var bar: HBoxContainer
var mini_reserved := 270.0
var options_panel: ScrollContainer
var menu_stack: Control
var tip: Control                     # Hinweis der Fähigkeit unter der Maus (steht immer an derselben Stelle über der Leiste)
var tip_idx := -1
var tip_text := ""


func _init(game: Node) -> void:
	g = game
	if not g.hero.is_empty():
		pal = PALETTES.get(str(g.hero["key"]), PALETTES["stone"])


static func box(bg: Color, border: Color, bw: int = 3, radius: int = 3, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## Gemeinsames Thema für das ganze Fenster in den Farben der Klasse
static func make_theme(p: Dictionary = {}) -> Theme:
	if p.is_empty():
		p = PALETTES["stone"]
	var t := Theme.new()
	t.set_color("font_color", "Label", p["text"])
	t.set_stylebox("panel", "PanelContainer", box(p["bg"], p["border"], 3, 3, 8))
	t.set_stylebox("panel", "Panel", box(p["bg"], p["border"], 3, 3, 8))
	t.set_stylebox("normal", "Button", box(p["dark"], p["border"].darkened(0.3), 2, 3, 6))
	t.set_stylebox("hover", "Button", box(p["bg"].lightened(0.1), p["hi"], 2, 3, 6))
	t.set_stylebox("pressed", "Button", box(p["inset"], p["hi"], 2, 3, 6))
	t.set_stylebox("disabled", "Button", box(p["dark"].lightened(0.04), p["border"].darkened(0.6), 2, 3, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", p["text"])
	t.set_color("font_hover_color", "Button", p["hi"].lightened(0.3))
	t.set_color("font_pressed_color", "Button", p["hi"].lightened(0.3))
	t.set_color("font_disabled_color", "Button", p["dim"].darkened(0.2))
	t.set_stylebox("panel", "TooltipPanel", box(p["dark"], p["border"], 3, 3, 8))
	t.set_color("font_color", "TooltipLabel", p["text"])
	t.set_color("font_color", "CheckBox", p["text"])
	t.set_color("font_hover_color", "CheckBox", p["hi"])
	t.set_stylebox("panel", "PopupMenu", box(p["dark"], p["border"], 2, 3, 6))
	t.set_stylebox("hover", "PopupMenu", box(p["bg"].lightened(0.1), p["hi"], 1, 2, 4))
	t.set_color("font_color", "PopupMenu", p["text"])
	t.set_color("font_hover_color", "PopupMenu", p["hi"])
	return t


# ---------------------------------------------------------------- untere Leiste
func build_bar(layer: CanvasLayer, mini_w: float) -> void:
	mini_reserved = mini_w + 28.0
	bar = HBoxContainer.new()                            # Block: Heldenbild, Fähigkeiten und Balken, Rucksack; mittig unten (Position in update())
	bar.add_theme_constant_override("separation", 6)
	layer.add_child(bar)
	bar.add_child(_portrait())
	bar.add_child(_center_panel())
	bar.add_child(_items_panel())
	bar.reset_size()


func _portrait() -> Control:
	portrait_wrap = Control.new()
	portrait_wrap.custom_minimum_size = Vector2(60, 86)      # ragt nach oben über die Leiste hinaus
	portrait_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	portrait_wrap.z_index = 3
	portrait_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic := SkillIcon.new()
	ic.kind = "class_" + str(g.hero["key"])
	ic.round_look = true
	ic.plate = Color.html(str(g.hero["d"]["col"])).darkened(0.6)
	ic.ring = pal["border"]
	ic.position = Vector2(-4, 6)
	ic.size = Vector2(76, 76)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_wrap.add_child(ic)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", box(pal["dark"], pal["border"], 2, 14, 2))
	badge.position = Vector2(42, 62)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", pal["hi"])
	level_label.custom_minimum_size = Vector2(22, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(level_label)
	portrait_wrap.add_child(badge)
	return portrait_wrap


func _center_panel() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(pal["bg"], pal["border"], 3, 4, 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	vb.add_child(_skills_block())
	hp_bar = _bar(Color("#4cd964"), 18.0)
	hp_label = _bar_label(hp_bar)
	vb.add_child(hp_bar)
	xp_bar = _bar(Color("#6fa8ff"), 14.0)
	xp_label = _bar_label(xp_bar)
	xp_label.add_theme_font_size_override("font_size", 10)
	vb.add_child(xp_bar)
	return pc


func _bar(fill: Color, h: float) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.add_theme_stylebox_override("background", box(pal["inset"], pal["border"].darkened(0.3), 2, 2, 0))
	pb.add_theme_stylebox_override("fill", box(fill, fill, 0, 2, 0))
	return pb


func _bar_label(pb: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(l)
	return l


func _skills_block() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 44)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.clear()
	var keys := ["Q", "W", "E", "R"]
	var icon_kinds: Dictionary = {
		"tank": ["shock", "ironskin", "shieldthrow", "quake"],
		"damage": ["daggerfan", "poisonblade", "leap", "daggerhail"],
		"caster": ["firefield", "frostcone", "chain", "elemental"]}
	for i in 4:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 20)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plus.focus_mode = Control.FOCUS_NONE
		plus.add_theme_color_override("font_color", pal["hi"])
		plus.tooltip_text = "Fähigkeit verbessern (Skillpunkt einsetzen)"
		var idx: int = i
		plus.pressed.connect(func(): g.skills.learn(g.hero, idx))
		col.add_child(plus)
		var slot := SkillSlot.new()
		slot.set_meta("pal", pal)
		slot.mouse_entered.connect(func(): _show_tip(idx))
		slot.mouse_exited.connect(func(): _hide_tip(idx))
		slot.add_theme_stylebox_override("panel", box(pal["inset"], pal["border"], 3, 3, 3))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(52, 52)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE            # sonst schluckt das Feld den Hinweis
		slot.add_child(holder)
		var ic := SkillIcon.new()
		ic.kind = str(icon_kinds[str(g.hero["key"])][i])
		ic.plate = pal["plate"]
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
		cdl.add_theme_font_size_override("font_size", 17)
		cdl.add_theme_color_override("font_outline_color", Color.BLACK)
		cdl.add_theme_constant_override("outline_size", 6)
		cdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cdl)
		var kl := Label.new()
		kl.text = keys[i]
		kl.position = Vector2(4, 0)
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", pal["hi"])
		kl.add_theme_color_override("font_outline_color", Color.BLACK)
		kl.add_theme_constant_override("outline_size", 4)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(kl)
		var lock := Label.new()
		lock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lock.offset_top = -17.0
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 9)
		lock.add_theme_color_override("font_outline_color", Color.BLACK)
		lock.add_theme_constant_override("outline_size", 4)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lock)
		col.add_child(slot)
		var pips := Label.new()
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pips.add_theme_font_size_override("font_size", 10)
		pips.add_theme_color_override("font_color", pal["hi"])
		col.add_child(pips)
		hb.add_child(col)
		slots.append({"plus": plus, "slot": slot, "icon": ic, "cd": cd, "cdl": cdl, "lock": lock, "pips": pips, "key": keys[i], "kl": kl, "h": 66.0})
	return hb


func _items_panel() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(pal["bg"], pal["border"], 3, 4, 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	g.bag_btns.clear()
	for i in int(g.cfg["bagSize"]):
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 44)
		var bic := ItemIcon.new()                         # Bildchen des Items im Rucksack (Name steht im Hinweis)
		bic.set_anchors_preset(Control.PRESET_FULL_RECT)
		bic.offset_left = 2.0
		bic.offset_top = 2.0
		bic.offset_right = -2.0
		bic.offset_bottom = -2.0
		bic.visible = false
		b.add_child(bic)
		b.set_meta("icon", bic)
		b.focus_mode = Control.FOCUS_NONE
		var slot_i: int = i
		b.pressed.connect(func():
			if not g.items.sell(g.hero, slot_i):
				if slot_i < g.hero["bag"].size():
					g._flash_msg("Verkaufen nur in der Basis (Backport: B)"))
		grid.add_child(b)
		g.bag_btns.append(b)
	vb.add_child(grid)
	gold_btn = Button.new()                              # Klick auf das Gold öffnet den Shop
	gold_btn.custom_minimum_size = Vector2(0, 28)
	gold_btn.focus_mode = Control.FOCUS_NONE
	gold_btn.add_theme_color_override("font_color", Color("#f2c94c"))
	gold_btn.add_theme_color_override("font_hover_color", Color("#ffe48a"))
	gold_btn.tooltip_text = "Klick: Shop öffnen oder schließen (Taste Tab)"
	gold_btn.pressed.connect(g._toggle_shop)
	g.shop_btn = gold_btn
	vb.add_child(gold_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	g.pot_btn = Button.new()
	g.pot_btn.custom_minimum_size = Vector2(100, 40)
	g.pot_btn.add_theme_font_size_override("font_size", 11)
	g.pot_btn.focus_mode = Control.FOCUS_NONE
	g.pot_btn.tooltip_text = "Heiltrank trinken (Taste F)"
	g.pot_btn.pressed.connect(func(): g.items.drink_potion(g.hero))
	row.add_child(g.pot_btn)
	bp_btn = Button.new()
	bp_btn.custom_minimum_size = Vector2(100, 40)
	bp_btn.add_theme_font_size_override("font_size", 11)
	bp_btn.focus_mode = Control.FOCUS_NONE
	bp_btn.tooltip_text = "Backport: zurück in die Basis (Taste B), Schaden unterbricht"
	bp_btn.pressed.connect(func(): g._start_backport(g.hero))
	row.add_child(bp_btn)
	vb.add_child(row)
	return pc


# ---------------------------------------------------------------- Aktualisierung (jedes Bild)
func update() -> void:
	if slots.is_empty() or g.hero.is_empty():
		return
	_place_bar()
	_update_tip()
	var h: Dictionary = g.hero
	var sk = g.skills
	level_label.text = str(h["lvl"])
	var mx: float = sk.h_max_hp(h)
	hp_bar.max_value = mx
	hp_bar.value = clampf(h["hp"], 0.0, mx)
	hp_label.text = "%d / %d" % [int(h["hp"]), int(mx)] if h["dead"] <= 0.0 else "Gefallen: %ds" % int(ceil(h["dead"]))
	var frac: float = h["hp"] / maxf(1.0, mx)
	var fill: Color = Data.user.hp_good().lerp(Data.user.hp_bad(), clampf(1.0 - frac * 1.6, 0.0, 1.0))
	hp_bar.add_theme_stylebox_override("fill", box(fill, fill, 0, 2, 0))
	var need: float = g._xp_need(h["lvl"])
	xp_bar.max_value = need
	xp_bar.value = minf(h["xp"], need)
	xp_label.text = "Erfahrung  %d / %d" % [int(h["xp"]), int(need)] if h["lvl"] < int(g.cfg["maxLevel"]) else "Höchste Stufe"
	for i in 4:
		var s: Dictionary = slots[i]
		(s["kl"] as Label).text = Data.user.key_name(["q", "w", "e", "r"][i])      # Taste laut Tastenbelegung
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
			lock_txt = "ungelernt"
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
	gold_btn.text = "Gold  %d" % int(h["gold"])
	gold_btn.tooltip_text = "Klick: Shop öffnen oder schließen (Taste %s)" % Data.user.key_name("shop")
	g.pot_btn.tooltip_text = "Heiltrank trinken (Taste %s)" % Data.user.key_name("potion")
	bp_btn.tooltip_text = "Backport: zurück in die Basis (Taste %s), Schaden unterbricht" % Data.user.key_name("backport")
	var bpk: String = Data.user.key_name("backport")
	if h["bp"] > 0.0:
		bp_btn.text = "Backport (%s)\n%.1fs" % [bpk, h["bp"]]
	elif g._in_base():
		bp_btn.text = "Backport (%s)\nin der Basis" % bpk
	elif h["bp_cd"] > 0.0:
		bp_btn.text = "Backport (%s)\nCD %ds" % [bpk, int(ceil(h["bp_cd"]))]
	else:
		bp_btn.text = "Backport (%s)\nbereit" % bpk
	portrait_wrap.tooltip_text = "%s  ·  Level %d\nAngriff %d  ·  Rüstung %d\nAngriffstempo %.2f  ·  Lauftempo %d\nZauberkraft %d\n\nEsc: Menü  ·  P: Pause" % [
		str(h["d"]["name"]), h["lvl"], int(sk.h_dmg(h)), int(sk.h_armor(h)), sk.h_as(h), int(sk.h_spd(h)), int(sk.h_sp(h))]


## Block mittig unten, aber nie über die Minimap links
func _place_bar() -> void:
	if bar == null:
		return
	var vp: Vector2 = g.get_viewport().get_visible_rect().size
	var ms := bar.get_combined_minimum_size()
	var w: float = ms.x
	bar.size = Vector2(w, ms.y)
	var x: float = maxf((vp.x - w) / 2.0, mini_reserved)
	x = minf(x, maxf(0.0, vp.x - w - 6.0))
	bar.position = Vector2(x, vp.y - ms.y - 8.0)


func _skill_tip(i: int, def: Dictionary, r: int, rmax: int, unlock: int) -> String:
	var sk = g.skills
	var h: Dictionary = g.hero
	var passive: bool = def.get("passive", false)
	var hi: String = "#" + (pal["hi"] as Color).to_html(false)
	var t := "[b][color=%s]%s[/color][/b]   [color=#b8b0a0](Taste %s)[/color]\n" % [hi, str(def["name"]), Data.user.key_name(["q", "w", "e", "r"][i])]
	var meta := "Rang %d von %d" % [r, rmax]
	if not passive:
		meta = "Abklingzeit %s s  ·  " % sk._f1(float(def["cd"]) * (1.0 - float(h["cdr"]))) + meta
	meta += "  ·  ab Level %d" % unlock
	t += "[color=#b8b0a0]%s[/color]\n\n" % meta
	for line in def["info"]:
		if str(line).begins_with("Rang ") or str(line).begins_with("Ab Rang"):       # Rang-Texte erst mit Alt (Erweiterung)
			continue
		t += "• %s\n" % str(line)
	t += "\n"
	if r > 0:
		t += "[color=#9fe08a]Jetzt (Rang %d):[/color] %s" % [r, sk.tip(h, i, r)]
	else:
		t += "[color=#8fd8ff]Rang 1 (noch nicht gelernt):[/color] %s" % sk.tip(h, i, 1)
	if int(h["sp"]) > 0 and sk.can_learn(h, i):
		t += "\n\n[color=%s]Klick auf das Plus verbessert diese Fähigkeit.[/color]" % hi
	if r + 1 <= rmax and r >= 1 or r == 0 and rmax >= 2:       # Erweiterung (nur mit Alt): was jeder weitere Rang ändert
		var alt := ""
		for rr in range(maxi(r + 1, 2), rmax + 1):
			alt += "[color=#8fd8ff]Rang %d:[/color] %s\n" % [rr, _rank_diff(sk.tip(h, i, rr - 1), sk.tip(h, i, rr))]
		if alt != "":
			t += "@@ALT@@" + alt.strip_edges()
	return t


## Unterschied zweier Rang-Texte (Teile durch " · " getrennt): geänderte Werte als "alt → neu", neue Teile als "neu: …"
func _rank_diff(prev: String, cur: String) -> String:
	var prev_by_key := {}
	for part in prev.split(" · "):
		prev_by_key[_part_key(part)] = part
	var out: Array = []
	for part in cur.split(" · "):
		var k := _part_key(part)
		if not prev_by_key.has(k):
			out.append("[color=#9fe08a]neu:[/color] " + part)
		elif prev_by_key[k] != part:
			out.append(_value_change(prev_by_key[k], part))
	return " · ".join(out) if not out.is_empty() else "keine Änderung"


## Schlüssel eines Teils: der Text ohne Ziffern, Kommas und Punkte (gleiche Größe, anderer Wert = gleicher Schlüssel)
func _part_key(part: String) -> String:
	var k := ""
	for ch in part:
		if not "0123456789,.".contains(ch):
			k += ch
	return k


## "Schaden 25" und "Schaden 40" -> "Schaden 25 → 40": gemeinsame Wörter bleiben, nur die Zahlen werden gezeigt
func _value_change(a: String, b: String) -> String:
	var re := RegEx.new()
	re.compile("[0-9]+(?:,[0-9]+)?")
	var ma := re.search_all(a)
	var mb := re.search_all(b)
	if ma.size() != mb.size() or mb.is_empty():
		return "[color=#9fe08a]" + b + "[/color]"
	var out := ""
	var pos := 0
	for k in mb.size():
		out += b.substr(pos, mb[k].get_start() - pos)
		var va := ma[k].get_string()
		var vb := mb[k].get_string()
		out += vb if va == vb else "[color=#9fe08a]%s → %s[/color]" % [va, vb]
		pos = mb[k].get_end()
	return out + b.substr(pos)



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
	stack.custom_minimum_size = Vector2(620, 620)
	menu_stack = stack
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
	pc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pc.offset_left = -190.0
	pc.offset_right = 190.0
	pc.add_theme_stylebox_override("panel", box(pal["bg"], pal["border"], 4, 4, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", pal["hi"])
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
	pc.add_theme_stylebox_override("panel", box(pal["bg"], pal["border"], 4, 4, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var tl := Label.new()
	tl.text = "Optionen"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", pal["hi"])
	vb.add_child(tl)
	options_panel = OptionsPanel.new()
	options_panel.custom_minimum_size = Vector2(0, 470)
	options_panel.build(g, true, pal["hi"])
	vb.add_child(options_panel)
	var back := Button.new()
	back.text = "Zurück"
	back.custom_minimum_size = Vector2(0, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): _show_page(menu_main))
	vb.add_child(back)
	return pc


func _show_page(page: Control) -> void:
	var vh: float = g.get_viewport().get_visible_rect().size.y                   # bei großer Oberfläche ist weniger Platz: Fenster passt sich an
	menu_stack.custom_minimum_size = Vector2(620, minf(620.0, vh - 30.0))
	options_panel.custom_minimum_size.y = clampf(vh - 200.0, 200.0, 470.0)
	for p in [menu_main, menu_options, menu_confirm]:
		(p as Control).visible = p == page


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


# ---------------------------------------------------------------- Hinweis der Fähigkeiten (feste Stelle)
func _show_tip(i: int) -> void:
	tip_idx = i
	_rebuild_tip()


func _hide_tip(i: int) -> void:
	if tip_idx != i:
		return
	tip_idx = -1
	if tip != null and is_instance_valid(tip):
		tip.queue_free()
	tip = null


func _rebuild_tip() -> void:
	if tip != null and is_instance_valid(tip):
		tip.queue_free()
	var slot: Control = slots[tip_idx]["slot"]
	tip_text = slot.tooltip_text
	tip = slot.build_tip(tip_text)
	bar.get_parent().add_child(tip)
	_update_tip()


func _update_tip() -> void:
	if tip == null or not is_instance_valid(tip) or tip_idx < 0:
		return
	if (slots[tip_idx]["slot"] as Control).tooltip_text != tip_text:       # Rang geändert: Text neu aufbauen
		_rebuild_tip()
		return
	tip.left_x = bar.position.x
	tip.bottom_y = bar.position.y - 14.0
