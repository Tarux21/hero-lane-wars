extends Node
## Lädt das Regelwerk (Zahlen für Helden, Monster, Items, Schwierigkeit ...) aus data/daten.json.
## Die Datei wird aus dem Browser-Prototyp exportiert (export-regelwerk.js) und hier nicht von Hand geändert.

var raw: Dictionary = {}
var cfg: Dictionary = {}
var units: Dictionary = {}
var heroes: Dictionary = {}
const UserSettings := preload("res://scripts/user_settings.gd")
var user: UserSettings = null                       # Einstellungen des Spielers (user_settings.gd), siehe Optionen


func _ready() -> void:
	user = UserSettings.new()
	var f := FileAccess.open("res://data/daten.json", FileAccess.READ)
	if f == null:
		push_error("data/daten.json nicht gefunden")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		raw = parsed
		cfg = raw["cfg"]
		units = raw["units"]
		heroes = raw["heroes"]
	else:
		push_error("data/daten.json ist kein gültiges JSON")

## Auswahl aus dem Startmenü; bleibt beim Neuladen der Szene (Revanche) erhalten.
var sel_team := 1
var sel_hero := "damage"
var sel_diff := "normal"
var sel_style := "random"
var autostart := false
