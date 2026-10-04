extends SkeletonModifier3D
## Dreht den Oberkörper eines Helden um die Hochachse (z. B. zum Ziel beim Schlag im Laufen).
## Läuft nach der Animation: Die Beine bleiben in Laufrichtung, Bauch und Torso drehen sich gemeinsam mit.
## angle: gewünschte Drehung in Radiant relativ zur Blickrichtung der Figur (wird von game.gd gesetzt).

var angle := 0.0
var bones: Array = []           # [Knochen-Index, Anteil an der Drehung]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(angle) < 0.002:
		return
	var up_sk: Vector3 = (sk.global_basis.inverse() * Vector3.UP).normalized()          # "oben" im Raum des Skeletts
	for e in bones:
		var b: int = e[0]
		var gb: Basis = sk.get_bone_global_pose(b).basis.orthonormalized()
		var axis_local: Vector3 = (gb.inverse() * up_sk).normalized()                    # Hochachse im Raum dieses Knochens
		var q: Quaternion = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, q * Quaternion(axis_local, angle * float(e[1])))
