extends SceneTree
## Hilfswerkzeug: gibt Knochenpositionen eines Modells aus. Aufruf: Godot --headless --path godot --script res://tools/bones.gd -- rpg/Rogue.gltf
func _init() -> void:
	var path := "rpg/Rogue.gltf"
	for a in OS.get_cmdline_user_args():
		path = a
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	doc.append_from_file("res://assets/quaternius/" + path, st)
	var root := doc.generate_scene(st)
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in skel.get_bone_count():
		var tr := skel.get_bone_global_rest(i)
		print("%-12s o=(%.2f %.2f %.2f) y=(%.2f %.2f %.2f) z=(%.2f %.2f %.2f)" % [skel.get_bone_name(i), tr.origin.x, tr.origin.y, tr.origin.z, tr.basis.y.x, tr.basis.y.y, tr.basis.y.z, tr.basis.z.x, tr.basis.z.y, tr.basis.z.z])
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		print("MESH %s aabb %s" % [mi.name, str((mi as MeshInstance3D).get_aabb())])
	quit()
