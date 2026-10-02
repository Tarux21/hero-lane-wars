extends PanelContainer
## Feld einer Fähigkeit in der unteren Leiste. Zeigt beim Darüberfahren einen ausführlichen Hinweis (tooltip_text im BBCode-Format).


func _make_custom_tooltip(for_text: String) -> Object:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#262321")
	sb.border_color = Color("#b49a5c")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(360, 0)
	rt.add_theme_color_override("default_color", Color("#e8dcc0"))
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.text = for_text
	pc.add_child(rt)
	return pc
