extends SceneTree
## Hilfswerkzeug: Szenenbaum eines Modells ausgeben. Aufruf: Godot --headless --path godot --script res://tools/tree.gd -- rpg/Rogue.gltf
func _init() -> void:
	var path := "rpg/Rogue.gltf"
	for a in OS.get_cmdline_user_args():
		path = a
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	doc.append_from_file("res://assets/quaternius/" + path, st)
	var root := doc.generate_scene(st)
	_p(root, 0)
	quit()

func _p(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		extra = " pos=%s rot=%s scale=%s" % [str((n as Node3D).position), str((n as Node3D).rotation_degrees), str((n as Node3D).scale)]
	if n is BoneAttachment3D:
		extra += " bone=" + (n as BoneAttachment3D).bone_name
	print("  ".repeat(d) + n.name + " [" + n.get_class() + "]" + extra)
	for c in n.get_children():
		if d < 5:
			_p(c, d + 1)
