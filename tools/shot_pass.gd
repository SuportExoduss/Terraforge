extends SceneTree
## Fotografa o menu com a faixa do passe e a tela PASSE (3 níveis prontos). Exige janela, sem --headless.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_pass.gd -- <pasta de saída>


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = "user://profile_shot_pass.json"   # nunca grava no perfil de verdade
	_run(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.load_data()
	profile.data["pass"] = {"xp": 150 * 4 + 60, "claimed": ["1", "2"]}
	profile.data["matches"] = 5
	profile.save()
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(1.0).timeout
	print("menu erro=", root.get_texture().get_image().save_png(out + "/passe_menu.png"))
	menu.get_node("Box/Pass").pressed.emit()
	await create_timer(1.0).timeout
	print("passe erro=", root.get_texture().get_image().save_png(out + "/passe_tela.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_shot_pass.json"))
	quit(0)
