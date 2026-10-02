extends PanelContainer
## Hinweisfenster einer Fähigkeit: oben das, was sie jetzt kann; mit gedrückter Alt-Taste klappt darunter die Erweiterung auf
## (was sich auf den nächsten Rängen ändert). Die Taste wird jedes Bild geprüft, solange der Hinweis offen ist.

var extra: Control
var hint: Control
var forced := false                   # Test: Erweiterung immer zeigen


func _process(_delta: float) -> void:
	var on := forced or Input.is_key_pressed(KEY_ALT)
	if extra != null and extra.visible != on:
		extra.visible = on
		if hint != null:
			hint.visible = not on
		reset_size()
