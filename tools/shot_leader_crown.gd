extends SceneTree
## Fotografa a coroa do líder sobre o corredor do jogador (perfil de teste; exige janela).
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_leader_crown.gd -- <pasta de saída>

func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = "user://profile_shot.json"
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("MatchSetup").bot_count = 2
	root.add_child(match_scene)
	_run(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	var bus := root.get_node("EventBus")
	await bus.match_started
	await create_timer(2.0).timeout
	bus.territory_score_changed.emit(1, 0.30)
	bus.territory_score_changed.emit(2, 0.10)
	await create_timer(1.2).timeout
	print("foto erro=", root.get_texture().get_image().save_png(out + "/coroa.png"))
	quit(0)
