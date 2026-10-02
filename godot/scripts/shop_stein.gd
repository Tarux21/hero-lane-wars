extends RefCounted
## Shop-Fenster im Stil der Oberfläche (Aufbau nach dem League-of-Legends-Vorbild):
## Reiter "Empfohlen" (Vorschläge je Klasse mit Preisen) und "Alle Items" (Suche, Filter, Gruppen Starter / Basis / Hüte / Zwischenstufen / Fertige / Verbrauch),
## rechts "Baut zu", der Rezeptbaum des gewählten Items, Beschreibung, Preis und Kaufen-Knopf.
## Kaufen: Knopf "Kaufen" oder Rechtsklick auf ein Item. Verkaufen: Feld im Rucksack anklicken (unten in der Leiste). Alles nur in der Basis.

const HudStein := preload("res://scripts/hud_stein.gd")

## Vorschläge je Klasse (Schätzung, wird später abgestimmt): {id, Hinweis}
const RECOMMENDED := {
	"tank": [["bulwark", "Rüstung und Leben, weniger Schaden"], ["thornPlate", "Dornen gegen viele kleine Gegner"], ["lifeSpring", "sehr viel Leben und Regeneration"],
		["titanPlate", "Gegner in der Nähe werden langsamer"], ["hatGuard", "Lauftempo, Rüstung, weniger Schaden"], ["giantsMight", "Leben und Schaden aus dem Leben"]],
	"damage": [["mightyBlade", "Schaden und kritische Treffer"], ["stormBreaker", "Angriffstempo und Krit"], ["cleaver", "trifft mehrere Gegner mit"],
		["ruinBlade", "Lebensraub, viel gegen Starke"], ["hatWind", "Lauf- und Angriffstempo"], ["soulDrinker", "Raub und Werte für alles"]],
	"caster": [["arcaneCrown", "viel Zauberkraft, 30 % mehr"], ["timeStaff", "Abklingzeit und Zauberkraft"], ["tormentMask", "Qual: Schaden über Zeit"],
		["moonstone", "Leben, Zauberkraft, Regeneration"], ["hatSage", "Lauftempo und Abklingzeit"], ["sparkBlade", "Angriffe mit Zauberschaden"]],
}

var g: Node
var pal: Dictionary
var root: PanelContainer
var sel := ""
var tree_root := ""
var tab := 0                                # 0 Empfohlen, 1 Alle Items
var filter := "all"
var search := ""
var tab_btns: Array = []
var gold_label: Label
var left_stack: Control
var tiles: Array = []                       # [{id, btn, box, frame}]
var rec_page: Control
var all_page: Control
var grid_holder: VBoxContainer
var rec_cards: VBoxContainer
var builds_row: HBoxContainer
var tree_box: VBoxContainer
var name_label: Label
var desc: RichTextLabel
var buy_btn: Button
var note_label: Label


func _init(game: Node) -> void:
	g = game
	pal = HudStein.PALETTES.get(str(g.hero_key), HudStein.PALETTES["stone"])


func visible() -> bool:
	return root != null and root.visible


func toggle() -> void:
	root.visible = not root.visible
	if root.visible:
		root.get_parent().move_child(root, -1)                  # über allen anderen Feldern
	if root.visible:
		refresh_all()


func close() -> void:
	if root != null:
		root.visible = false


# ---------------------------------------------------------------- Aufbau
func build(layer: CanvasLayer) -> void:
	root = PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.offset_left = -470.0
	root.offset_right = 470.0
	root.offset_top = -335.0
	root.offset_bottom = 250.0
	root.visible = false
	root.add_theme_stylebox_override("panel", HudStein.box(pal["bg"], pal["border"], 4, 4, 10))
	layer.add_child(root)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	root.add_child(vb)
	vb.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	vb.add_child(body)
	body.add_child(_left())
	body.add_child(_right())
	sel = RECOMMENDED[str(g.hero_key)][0][0] if RECOMMENDED.has(str(g.hero_key)) else "sword"
	_select(sel)
	_set_tab(0)


func _header() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	for i in 2:
		var b := Button.new()
		b.text = ["Empfohlen", "Alle Items"][i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 34)
		b.focus_mode = Control.FOCUS_NONE
		var ti: int = i
		b.pressed.connect(func(): _set_tab(ti))
		hb.add_child(b)
		tab_btns.append(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color("#f2c94c"))
	hb.add_child(gold_label)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(34, 34)
	x.focus_mode = Control.FOCUS_NONE
	x.tooltip_text = "Schließen (Tab)"
	x.pressed.connect(close)
	hb.add_child(x)
	return hb


func _left() -> Control:
	left_stack = Control.new()
	left_stack.custom_minimum_size = Vector2(540, 0)
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_page = _build_rec_page()
	all_page = _build_all_page()
	rec_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	all_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_stack.add_child(rec_page)
	left_stack.add_child(all_page)
	return left_stack


func _build_rec_page() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	var t := Label.new()
	t.text = "Vorgeschlagene Items für %s" % str(g.hero["d"]["name"])
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", pal["hi"])
	vb.add_child(t)
	var hint := Label.new()
	hint.text = "Klick zeigt das Rezept rechts. Rechtsklick kauft das Item (nur in der Basis)."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", pal["dim"])
	vb.add_child(hint)
	rec_cards = VBoxContainer.new()
	rec_cards.add_theme_constant_override("separation", 6)
	vb.add_child(rec_cards)
	for e in RECOMMENDED.get(str(g.hero_key), []):
		rec_cards.add_child(_rec_card(str(e[0]), str(e[1])))
	var t2 := Label.new()
	t2.text = "Für den Anfang"
	t2.add_theme_font_size_override("font_size", 14)
	t2.add_theme_color_override("font_color", pal["hi"])
	vb.add_child(t2)
	var starters := HFlowContainer.new()
	starters.add_theme_constant_override("h_separation", 8)
	for id in ["sword", "armor", "heart", "gloves", "staff", "hat", "potion"]:
		starters.add_child(_tile(id, 48.0))
	vb.add_child(starters)
	return sc


func _rec_card(id: String, note: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", HudStein.box(pal["dark"], pal["border"].darkened(0.3), 2, 3, 6))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	hb.add_child(_tile(id, 52.0))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.text = str(g.items.item[id]["name"])
	nm.add_theme_font_size_override("font_size", 15)
	vb.add_child(nm)
	var nt := Label.new()
	nt.text = note
	nt.add_theme_font_size_override("font_size", 12)
	nt.add_theme_color_override("font_color", pal["dim"])
	vb.add_child(nt)
	hb.add_child(vb)
	return pc


func _build_all_page() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var search_box := LineEdit.new()
	search_box.placeholder_text = "Suchen …"
	search_box.clear_button_enabled = true
	search_box.text_changed.connect(func(tx: String):
		search = tx.strip_edges().to_lower()
		_apply_filter())
	vb.add_child(search_box)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 4)
	for f in [["all", "Alle"], ["atk", "Angriff"], ["magic", "Zauber"], ["def", "Verteidigung"], ["misc", "Sonstiges"]]:
		var b := Button.new()
		b.text = f[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 28)
		var fk: String = f[0]
		b.pressed.connect(func():
			filter = fk
			_apply_filter())
		frow.add_child(b)
	vb.add_child(frow)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	grid_holder = VBoxContainer.new()
	grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_holder.add_theme_constant_override("separation", 6)
	sc.add_child(grid_holder)
	var groups := [["basis", "Starter"], ["teil", "Basis"], ["hut", "Hüte (nur einer im Rucksack)"], ["zwischen", "Zwischenstufen"], ["fertig", "Fertige Items"],
		["verbrauch", "Verbrauchsgegenstände"]]
	for gr in groups:
		var lab := Label.new()
		lab.text = gr[1]
		lab.add_theme_color_override("font_color", pal["hi"])
		lab.set_meta("grp", gr[0])
		grid_holder.add_child(lab)
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		fl.set_meta("grp", gr[0])
		grid_holder.add_child(fl)
		for id in g.items.order:
			if g.items.item[id]["group"] == gr[0]:
				fl.add_child(_tile(str(id), 52.0))
	return vb


func _right() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(340, 0)
	vb.add_theme_constant_override("separation", 6)
	var bt := Label.new()
	bt.text = "Baut zu"
	bt.add_theme_color_override("font_color", pal["hi"])
	vb.add_child(bt)
	builds_row = HBoxContainer.new()
	builds_row.custom_minimum_size = Vector2(0, 52)
	builds_row.add_theme_constant_override("separation", 6)
	vb.add_child(builds_row)
	var tb := Label.new()
	tb.text = "Rezept"
	tb.add_theme_color_override("font_color", pal["hi"])
	vb.add_child(tb)
	tree_box = VBoxContainer.new()
	tree_box.custom_minimum_size = Vector2(0, 110)
	tree_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(tree_box)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	vb.add_child(name_label)
	desc = RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = false
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size = Vector2(0, 50)
	desc.add_theme_color_override("default_color", pal["text"])
	desc.add_theme_font_size_override("normal_font_size", 13)
	vb.add_child(desc)
	note_label = Label.new()
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", pal["dim"])
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note_label)
	buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(_buy_selected)
	vb.add_child(buy_btn)
	return vb


# ---------------------------------------------------------------- Kacheln
## Farbe nach Art des Items: Zauber lila, Angriff rot, Tempo orange, Verteidigung stahlblau, Leben grün, sonst gold
func _cat_color(id: String) -> Color:
	var st: Dictionary = g.items.item[id].get("stats", {})
	for k in ["sp"]:
		if st.has(k):
			return Color("#5a3f94")
	for k in ["dmg", "crit", "ls", "sv"]:
		if st.has(k):
			return Color("#8f3434")
	if st.has("as"):
		return Color("#9a6a22")
	for k in ["armor", "dr"]:
		if st.has(k):
			return Color("#3f607f")
	for k in ["hp", "regen"]:
		if st.has(k):
			return Color("#34753f")
	return Color("#7a6a3a")


func _category(id: String) -> String:
	var st: Dictionary = g.items.item[id].get("stats", {})
	if st.has("sp"):
		return "magic"
	if st.has("dmg") or st.has("crit") or st.has("as") or st.has("ls"):
		return "atk"
	if st.has("armor") or st.has("dr") or st.has("hp") or st.has("regen"):
		return "def"
	return "misc"


func _initials(nm: String) -> String:
	var words := nm.replace("-", " ").split(" ", false)
	if words.size() == 1:
		return words[0].substr(0, 3)
	return words[0].substr(0, 1).to_upper() + words[1].substr(0, 1).to_upper()


func _tile(id: String, size: float) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.text = _initials(str(g.items.item[id]["name"]))
	b.add_theme_font_size_override("font_size", int(size * 0.34))
	var col := _cat_color(id)
	b.add_theme_stylebox_override("normal", HudStein.box(col.darkened(0.25), pal["border"].darkened(0.35), 2, 3, 2))
	b.add_theme_stylebox_override("hover", HudStein.box(col, pal["hi"], 2, 3, 2))
	b.add_theme_stylebox_override("pressed", HudStein.box(col.darkened(0.4), pal["hi"], 2, 3, 2))
	b.tooltip_text = g._item_tip(id)
	var iid: String = id
	b.pressed.connect(func(): _select(iid))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_select(iid)
			_buy_selected())
	vb.add_child(b)
	var pl := Label.new()
	pl.text = str(int(g.items.item[id]["cost"]) if not g.items.item[id].has("parts") else g.items.total_cost(id))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 11)
	pl.add_theme_color_override("font_color", Color("#f2c94c"))
	vb.add_child(pl)
	tiles.append({"id": id, "btn": b, "box": vb, "frame": col})
	return vb


# ---------------------------------------------------------------- Auswahl und Anzeige
func _set_tab(i: int) -> void:
	tab = i
	rec_page.visible = i == 0
	all_page.visible = i == 1
	for k in tab_btns.size():
		(tab_btns[k] as Button).button_pressed = k == i


func _apply_filter() -> void:
	for e in tiles:
		var id: String = e["id"]
		if not all_page.is_ancestor_of(e["box"]):
			continue
		var it: Dictionary = g.items.item[id]
		var ok := true
		if search != "" and not str(it["name"]).to_lower().contains(search):
			ok = false
		if filter != "all" and _category(id) != filter:
			ok = false
		(e["box"] as Control).visible = ok
	for ch in grid_holder.get_children():                       # Gruppen ohne sichtbares Item ausblenden
		if ch is HFlowContainer:
			var any := false
			for t in ch.get_children():
				if t.visible:
					any = true
			ch.visible = any
			var lab: Node = grid_holder.get_child(ch.get_index() - 1)
			lab.visible = any


func _select(id: String, as_root: bool = true) -> void:
	sel = id
	if as_root:
		tree_root = id                              # Klick in der Liste: neuer Rezeptbaum. Klick im Baum: nur der Text wechselt
	for c in builds_row.get_children():
		c.queue_free()
	for c in tree_box.get_children():
		c.queue_free()
	var into: Array = []
	for oid in g.items.order:
		var o: Dictionary = g.items.item[oid]
		if o.has("parts") and (o["parts"] as Array).has(id):
			into.append(oid)
	for oid in into.slice(0, 6):
		builds_row.add_child(_small_tile(str(oid), 38.0))
	if into.is_empty():
		var none := Label.new()
		none.text = "wird nicht weiter verbaut"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", pal["dim"])
		builds_row.add_child(none)
	tree_box.add_child(_tree_node(tree_root, 40.0, 0))
	var it: Dictionary = g.items.item[id]
	name_label.text = str(it["name"])
	var text := str(it["desc"]).replace(" Einmalig –", "\n[color=#%s]Einmalig –[/color]" % (pal["hi"] as Color).to_html(false))
	desc.text = text
	refresh_all()


## Kachel ohne Preis-Label-Eintrag in der Liste (für "Baut zu" und den Rezeptbaum)
func _small_tile(id: String, size: float, in_tree: bool = false) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.text = _initials(str(g.items.item[id]["name"]))
	b.add_theme_font_size_override("font_size", int(size * 0.34))
	var col := _cat_color(id)
	b.add_theme_stylebox_override("normal", HudStein.box(col.darkened(0.25), pal["border"].darkened(0.35), 2, 3, 2))
	b.add_theme_stylebox_override("hover", HudStein.box(col, pal["hi"], 2, 3, 2))
	b.add_theme_stylebox_override("pressed", HudStein.box(col.darkened(0.4), pal["hi"], 2, 3, 2))
	b.tooltip_text = g._item_tip(id)
	var iid: String = id
	if in_tree:
		b.pressed.connect(func(): _select(iid, false))
		if id == sel:
			var hb := HudStein.box(col, pal["hi"], 3, 3, 2)
			b.add_theme_stylebox_override("normal", hb)
			b.add_theme_stylebox_override("hover", hb)
	else:
		b.pressed.connect(func(): _select(iid))
	vb.add_child(b)
	var pl := Label.new()
	var it: Dictionary = g.items.item[id]
	pl.text = str(int(it["cost"]) if not it.has("parts") else g.items.total_cost(id))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 11)
	pl.add_theme_color_override("font_color", Color("#f2c94c"))
	vb.add_child(pl)
	return vb


## Rezeptbaum: das Item oben, darunter nebeneinander seine Teile (jeweils wieder mit ihren Teilen)
func _tree_node(id: String, size: float, depth: int) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var top := _small_tile(id, size, true)
	top.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(top)
	var it: Dictionary = g.items.item[id]
	if it.has("parts"):
		var bar := Label.new()
		bar.text = "│"
		bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bar.add_theme_color_override("font_color", pal["border"])
		vb.add_child(bar)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for part in it["parts"]:
			row.add_child(_tree_node(str(part), maxf(30.0, size - 3.0 * (depth + 1)), depth + 1))
		vb.add_child(row)
	return vb


func _buy_selected() -> void:
	if sel == "" or g.hero.is_empty():
		return
	if not g.items.buy(g.hero, sel):
		var why: String = g.items.buy_reason(g.hero, sel)
		if why != "":
			g._flash_msg(why)
	else:
		_select(sel, false)


## Gold, Kaufen-Knopf und abgedunkelte Kacheln (jedes Bild, nur wenn offen)
func refresh_all() -> void:
	if g.hero.is_empty() or sel == "":
		return
	gold_label.text = "Gold  %d" % int(g.hero["gold"])
	var it: Dictionary = g.items.item[sel]
	var price: int = int(it["cost"]) if it.get("consumable", false) else int(g.items.resolve_buy(sel, g.hero["bag"])["cost"])
	var why: String = g.items.buy_reason(g.hero, sel)
	buy_btn.text = "Kaufen  –  %d Gold" % price
	buy_btn.modulate = Color("#9fe08a") if why == "" else Color(1, 1, 1, 0.6)
	var sell_val := int(floor(g.items.total_cost(sel) * float(g.cfg["sellRatio"]))) if it["group"] != "verbrauch" else 0
	var extra := ""
	if it.has("parts"):
		extra = "Gesamt %d (Rezept %d), vorhandene Teile werden abgezogen." % [g.items.total_cost(sel), int(it["cost"])]
	name_label.text = "%s   %d Gold" % [str(it["name"]), (g.items.total_cost(sel) if it.has("parts") else int(it["cost"]))]
	note_label.text = (extra + ("\n" if extra != "" else "") + ("Nicht möglich: " + why if why != "" else "Bereit zum Kauf (Rechtsklick auf ein Item kauft ebenfalls).") +
		("\nVerkauf: %d Gold" % sell_val if sell_val > 0 else ""))
	for e in tiles:
		var tp: int = int(g.items.item[e["id"]]["cost"]) if g.items.item[e["id"]].get("consumable", false) else int(g.items.resolve_buy(e["id"], g.hero["bag"])["cost"])
		(e["box"] as Control).modulate = Color.WHITE if g.hero["gold"] >= tp else Color(1, 1, 1, 0.55)


func update() -> void:
	if visible():
		refresh_all()
