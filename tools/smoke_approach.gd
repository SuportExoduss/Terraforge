extends SceneTree
## Teste de fumaça do Passo 40 (Cap.03 P01, DD-007: sem tela estática no primeiro clique): JOGAR faz a interface sumir
## e a câmera do menu mergulhar no planeta (atmosfera brilha, imagem escurece) enquanto a partida carrega em segundo
## plano; a cena só troca com os dois prontos; um segundo clique não dispara nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_approach.gd

const DIVE_Z := 10.7   # o fim do mergulho (PlanetBackdrop.CAMERA_DIVE)

var _time := 0.0


func _initialize() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 150.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _run() -> void:
	await process_frame
	var menu := current_scene
	var back: Node = menu.get_node("Backdrop")
	if not _check(menu.approach_seconds > 0.5 and not back.diving, "o mergulho dura mais de meio segundo por padrão e ainda não começou"): return
	var home_z: float = back.camera.position.z
	var home_boost := 1.0   # o brilho do shader antes do mergulho (valor padrão, ainda sem parâmetro gravado)
	menu.approach_seconds = 0.8

	menu.get_node("Box/Play").pressed.emit()
	if not _check(back.diving and menu.get_node("Box").process_mode == Node.PROCESS_MODE_DISABLED, "JOGAR inicia o mergulho e trava os botões"): return
	menu.get_node("Box/Play").pressed.emit()   # segundo clique: ignorado (uma única partida)
	await create_timer(0.5).timeout
	if not _check(current_scene == menu, "a partida só entra no fim do mergulho"): return
	if not _check(back.camera.position.z < home_z - 2.0, "a câmera se aproxima do planeta (z %.1f → %.1f)" % [home_z, back.camera.position.z]): return
	if not _check(menu.get_node("Box").modulate.a < 0.05, "a interface sumiu"): return
	var mid_boost: float = back.get("_atmo_material").get_shader_parameter("boost")
	if not _check(mid_boost > home_boost + 0.2, "a atmosfera brilha durante a descida"): return

	# Fim: câmera dentro da atmosfera, imagem escura, e a partida entra sozinha (carregada em segundo plano)
	var last_z := 99.0
	var last_dark := 1.0
	while is_instance_valid(menu) and _time < 120.0:
		last_z = back.camera.position.z
		last_dark = back.modulate.r
		await process_frame
	await process_frame
	await process_frame
	if not _check(is_instance_valid(current_scene) and current_scene.name == "Match", "a partida entra depois do mergulho"): return
	if not _check(last_z < DIVE_Z + 0.5 and last_dark < 0.05, "terminou dentro da atmosfera e no escuro (z %.2f, brilho %.2f)" % [last_z, last_dark]): return
	if not _check(root.get_node("Services").planet != null and current_scene.get_node_or_null("Main/Runner4") != null, "partida inteira (planeta, corredores)"): return
	print("OK")
	quit(0)
