extends RefCounted
## Computer-Spieler (Bots): Entscheidungen für Gegner und Mitspieler. Wird aus dem Browser-Prototyp (botThink usw.) übernommen.
var g: Node


func _init(game: Node) -> void:
	g = game


func setup(_p: Dictionary, _diff: Dictionary, _style: String) -> void:
	pass


func think(_p: Dictionary, _dt: float) -> void:
	pass
