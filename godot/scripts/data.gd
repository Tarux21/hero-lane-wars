extends Node
## Lädt das Regelwerk (Zahlen für Helden, Monster, Items, Schwierigkeit ...) aus data/daten.json.
## Die Datei wird aus dem Browser-Prototyp exportiert (export-regelwerk.js) und hier nicht von Hand geändert.

var raw: Dictionary = {}
var cfg: Dictionary = {}
var units: Dictionary = {}
var heroes: Dictionary = {}


func _ready() -> void:
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
