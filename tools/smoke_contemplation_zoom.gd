extends SceneTree
## Teste de fumaça do Passo 64 (Cap.03 P11 PLANETA FINAL): na contemplação a roda do mouse e +/- aproximam e afastam a
## câmera do planeta, com limites; fora da contemplação o zoom não faz nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_contemplation_zoom.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
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


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


## Distância da câmera ao centro do planeta em múltiplos do raio, depois de assentar.
func _settled_factor(cam: Node, camera: Camera3D, planet: Node) -> float:
	for n in 30:
		await process_frame
	return (camera.global_position - planet.center).length() / planet.radius


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var cam: Node = _match.get_node("Main/Contemplation")
	var camera: Camera3D = _match.get_node("Main/Camera")
	var planet: Node = root.get_node("Services").planet
	cam.approach_smoothing = 30.0   # assenta em poucos quadros

	# 1. Partida em andamento: o zoom é ignorado
	cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	if not _check(is_equal_approx(cam._factor, cam.distance_factor), "zoom fora da contemplação deve ser ignorado (%.2f)" % cam._factor): return

	# 2. Contemplação: roda para cima aproxima, para baixo afasta; a câmera acompanha
	_bus.match_ended.emit()
	var base: float = cam.distance_factor
	if not _check(absf(await _settled_factor(cam, camera, planet) - base) < 0.05, "a câmera deveria assentar em %.2f" % base): return
	cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	if not _check(cam._factor < base, "roda para cima deveria aproximar (%.2f)" % cam._factor): return
	var closer: float = await _settled_factor(cam, camera, planet)
	if not _check(absf(closer - cam._factor) < 0.05, "a câmera deveria chegar em %.2f (%.2f)" % [cam._factor, closer]): return
	cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	if not _check(cam._factor > base, "duas rodas para baixo deveriam afastar além do início (%.2f)" % cam._factor): return

	# 3. Teclas + e -
	var before: float = cam._factor
	cam._unhandled_input(_key(KEY_EQUAL))
	if not _check(cam._factor < before, "tecla + deveria aproximar"): return
	cam._unhandled_input(_key(KEY_MINUS))
	if not _check(is_equal_approx(cam._factor, before), "tecla - deveria desfazer o +"): return

	# 4. Limites
	for n in 60:
		cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	if not _check(is_equal_approx(cam._factor, cam.min_factor), "limite de aproximação %.2f (%.2f)" % [cam.min_factor, cam._factor]): return
	if not _check(await _settled_factor(cam, camera, planet) > 1.5, "a câmera não pode entrar no planeta"): return
	for n in 60:
		cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	if not _check(is_equal_approx(cam._factor, cam.max_factor), "limite de afastamento %.2f (%.2f)" % [cam.max_factor, cam._factor]): return

	print("OK: roda do mouse e +/- aproximam/afastam a câmera de contemplação, com limites")
	quit(0)
