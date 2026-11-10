extends SceneTree
## Teste de fumaça do Passo 65 (Cap.03 P11 PLANETA FINAL): na contemplação, TAB gira a câmera até a base da próxima
## civilização (em ordem de id, dando a volta, pulando quem não tem mais base); girar à mão cancela; fora da contemplação não faz nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_contemplation_observe.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2   # civilizações 1, 2 e 3
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _tab(echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	ev.echo = echo
	return ev


## Espera a câmera chegar e devolve o ângulo (rad) entre ela e a base da civilização `id`.
func _arrive_and_angle(cam: Node, camera: Camera3D, planet: Node, id: int) -> float:
	for n in 240:
		await process_frame
		if cam._focus_dir == Vector3.ZERO:
			break
	var base: Vector3 = root.get_node("Services").home_bases[id]["position"]
	return (camera.global_position - planet.center).normalized().angle_to((base - planet.center).normalized())


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var cam: Node = _match.get_node("Main/Contemplation")
	var camera: Camera3D = _match.get_node("Main/Camera")
	var planet: Node = root.get_node("Services").planet
	var bases: Dictionary = root.get_node("Services").home_bases
	cam.approach_smoothing = 30.0
	cam.focus_smoothing = 30.0

	# 1. Partida em andamento: TAB não faz nada
	cam._unhandled_input(_tab())
	if not _check(cam._focus_dir == Vector3.ZERO, "TAB fora da contemplação deve ser ignorado"): return

	# 2. Contemplação: TAB percorre 1 → 2 → 3 → 1; o eco (tecla segurada) não conta
	_bus.match_ended.emit()
	for id in [1, 2, 3, 1]:
		cam._unhandled_input(_tab())
		cam._unhandled_input(_tab(true))
		if not _check(cam._observed_id == id, "TAB deveria ir para a civilização %d (foi %d)" % [id, cam._observed_id]): return
		var angle: float = await _arrive_and_angle(cam, camera, planet, id)
		if not _check(angle < 0.05, "a câmera deveria ficar sobre a base %d (%.3f rad)" % [id, angle]): return

	# 3. Quem não tem mais base é pulado (2 caiu: 1 → 3)
	bases.erase(2)
	cam._unhandled_input(_tab())
	if not _check(cam._observed_id == 3, "sem a base 2, TAB deveria ir para 3 (foi %d)" % cam._observed_id): return

	# 4. Girar à mão cancela o foco
	cam._drag = Vector2(50, 0)
	await process_frame
	if not _check(cam._focus_dir == Vector3.ZERO, "arrastar deveria cancelar o foco"): return

	print("OK: TAB gira a câmera de contemplação para a base da próxima civilização; pula bases caídas; arrastar cancela")
	quit(0)
