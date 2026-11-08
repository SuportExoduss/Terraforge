extends SceneTree
## Inspeção: para onde o GLB do corredor "olha" ao longo da animação (espaço do nó raiz do GLB).
## Uso: godot_console --headless --path . -s res://tools/inspect_runner.gd

func _initialize() -> void:
	var node: Node3D = load("res://art/models/cowboy/CowboyRunner.glb").instantiate()
	root.add_child(node)
	await process_frame
	var skel: Skeleton3D = node.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false)[0]
	var anim := ap.get_animation(ap.get_animation_list()[0])
	print("anim len=", anim.length, " skeleton xf=", skel.global_transform)
	ap.play(ap.get_animation_list()[0])
	for t in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
		if t >= anim.length:
			break
		ap.seek(t, true)
		await process_frame
		var xf := node.global_transform.affine_inverse() * skel.global_transform
		var fwd := Vector3.ZERO
		for side in ["L", "R"]:
			var foot := xf * skel.get_bone_global_pose(skel.find_bone(side + "_Foot")).origin
			var toe := xf * skel.get_bone_global_pose(skel.find_bone(side + "_ToeBase")).origin
			fwd += (toe - foot)
		var l := xf * skel.get_bone_global_pose(skel.find_bone("L_Upperarm")).origin
		var r := xf * skel.get_bone_global_pose(skel.find_bone("R_Upperarm")).origin
		var hip := xf * skel.get_bone_global_pose(skel.find_bone("Hip")).origin
		var head := xf * skel.get_bone_global_pose(skel.find_bone("Head")).origin
		var by_arms := Vector3.UP.cross(r - l)
		print("t=%.1f  pe->dedo=%s  ombros(up x (R-L))=%s  hip=%s  head=%s" % [t, fwd.normalized(), by_arms.normalized(), hip, head])
	quit(0)
