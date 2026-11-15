extends SceneTree
## Passo 125: fotografa o menu com o planeta Gelo escolhido e a tela de escolha de planeta. Exige janela, sem --headless.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_planet_screen.gd -- <pasta de saída>


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = "user://profile_shot_planet.json"   # nunca grava no perfil de verdade
	_run(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.load_data()
	profile.data["planet"] = "gelo"
	profile.data["matches"] = 5
	profile.save()
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(1.0).timeout
	print("menu erro=", root.get_texture().get_image().save_png(out + "/planeta_menu.png"))
	menu.get_node("Box/Planet").pressed.emit()
	await create_timer(1.0).timeout
	print("tela erro=", root.get_texture().get_image().save_png(out + "/planeta_tela.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_shot_planet.json"))
	quit(0)
