extends SceneTree
## Fotografa a tela de resultados sobre a câmera de contemplação. Exige janela.
## Uso: godot_console --path . -s res://tools/shot_results.gd -- <pasta de saída>

func _initialize() -> void:
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("MatchSetup").bot_count = 0
	root.add_child(match_scene)
	_run(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	var bus := root.get_node("EventBus")
	await bus.match_started
	await create_timer(1.0).timeout
	for entry in [[1, 0.125], [2, 0.40], [3, 0.30], [4, 0.05], [3, 0.0], [4, 0.0]]:
		bus.territory_score_changed.emit(entry[0], entry[1])
	bus.civilization_eliminated.emit(3)
	bus.civilization_eliminated.emit(4)
	bus.match_ended.emit()
	await create_timer(6.0).timeout
	print("foto erro=", root.get_texture().get_image().save_png(out + "/resultados.png"))
	quit(0)
