extends PanelContainer
## Feld einer Fähigkeit in der unteren Leiste. Zeigt beim Darüberfahren einen ausführlichen Hinweis (tooltip_text im BBCode-Format).
## Der Text darf den Trenner "@@ALT@@" enthalten: alles danach erscheint nur bei gedrückter Alt-Taste (Rang-Übersicht).

const SkillTip := preload("res://scripts/skill_tip.gd")
const ALT_MARK := "@@ALT@@"


func _label(txt: String, pal: Dictionary) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(380, 0)
	rt.add_theme_color_override("default_color", pal.get("text", Color("#e8dcc0")))
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.text = txt
	return rt


func _make_custom_tooltip(for_text: String) -> Object:
	var pc := SkillTip.new()
	var sb := StyleBoxFlat.new()
	var pal: Dictionary = get_meta("pal", {})
	sb.bg_color = pal.get("dark", Color("#262321"))
	sb.border_color = pal.get("border", Color("#b49a5c"))
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	var parts := for_text.split(ALT_MARK)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	vb.add_child(_label(parts[0], pal))
	if parts.size() > 1:
		var hint := Label.new()
		hint.text = "Alt halten: was die nächsten Ränge verbessern"
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", pal.get("dim", Color("#9a917c")))
		vb.add_child(hint)
		var extra := VBoxContainer.new()
		extra.add_theme_constant_override("separation", 6)
		var line := ColorRect.new()
		line.color = pal.get("border", Color("#b49a5c"))
		line.custom_minimum_size = Vector2(0, 2)
		extra.add_child(line)
		extra.add_child(_label(parts[1], pal))
		extra.visible = Input.is_key_pressed(KEY_ALT)
		hint.visible = not extra.visible
		vb.add_child(extra)
		pc.extra = extra
		pc.hint = hint
	return pc
