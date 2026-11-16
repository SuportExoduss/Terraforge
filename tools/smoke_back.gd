extends SceneTree
## Teste de fumaça do Passo 128 (DD-167): botão VOLTAR do Android. (1) o projeto não fecha o jogo no voltar; (2) o aviso
## WM_GO_BACK_REQUEST e a tecla BACK viram ui_cancel, uma vez só por toque; (3) configurações fecham; (4) no menu principal o
## primeiro voltar avisa e o segundo (em 2 s) sai; (5) a pausa não engole o voltar do pós-jogo; (6) os resultados voltam ao
## menu, mas não nos primeiros 1 s; (7) o replay é pulado pelo voltar.
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/smoke_back.gd

var _bus: Node
var _failed := false
var _seen := 0


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _esc() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _run() -> void:
	Profile.path = "user://profile_smoke_back.json"   # perfil próprio, de quem já jogou: não suja o profile_headless.json dos outros testes
	Profile.data = Profile.defaults()
	Profile.data["matches"] = 1
	Profile.save()
	_bus = root.get_node("EventBus")
	var services: Node = root.get_node("Services")

	# 1 e 2. O voltar vira ui_cancel (uma vez por toque)
	_check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "quit_on_go_back deve estar desligado")
	var back: Node = root.get_node_or_null("BackButton")
	_check(back != null, "o autoload BackButton deve existir")
	var probe := Node.new()
	probe.set_script(load("res://tools/probe_back.gd"))
	root.add_child(probe)
	probe.hit.connect(func() -> void: _seen += 1)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # é assim que o Android avisa
	await _frames(2)
	_check(_seen == 1, "o aviso do Android vira um ui_cancel (%d)" % _seen)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # logo em seguida: trava de toque duplo
	await _frames(2)
	_check(_seen == 1, "dois avisos em 250 ms contam um só (%d)" % _seen)
	OS.delay_msec(300)
	var key := InputEventKey.new()
	key.keycode = KEY_BACK
	key.pressed = true
	Input.parse_input_event(key)   # alguns aparelhos mandam a tecla BACK
	await _frames(2)
	_check(_seen == 2, "a tecla BACK também vira ui_cancel (%d)" % _seen)
	probe.free()

	# 3 e 4. Menu principal
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(3)
	var quits := [0]
	menu.quit_action = func() -> void: quits[0] += 1
	menu._open_settings()
	await _frames(2)
	_check(menu.get_node_or_null("SettingsPanel") != null, "CONFIGURAÇÕES abre")
	menu.get_node("SettingsPanel")._unhandled_input(_esc())
	await _frames(2)
	_check(menu.get_node_or_null("SettingsPanel") == null, "o voltar fecha as configurações")
	_check(quits[0] == 0 and menu.get_node_or_null("ExitHint") == null, "fechar uma tela não avisa nem sai")
	menu._unhandled_input(_esc())
	var hint := menu.get_node_or_null("ExitHint") as Label
	_check(hint != null and hint.visible and quits[0] == 0, "o primeiro voltar no menu só avisa")
	menu._unhandled_input(_esc())
	_check(quits[0] == 1, "o segundo voltar em 2 s sai")
	menu._back_msec = Time.get_ticks_msec() - menu.EXIT_WINDOW_MSEC - 50
	menu._unhandled_input(_esc())
	_check(quits[0] == 1, "passados 2 s o voltar só avisa de novo")
	menu.free()

	# 5, 6 e 7. Partida: pausa x pós-jogo, resultados, replay
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("MatchSetup").bot_count = 0
	match_scene.get_node("Meteors").min_seconds_between = 100000.0
	match_scene.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(match_scene)
	await _bus.match_started
	await _frames(5)
	var flow = services.flow
	var pause: Node = match_scene.get_node("Pause")
	var replay: Node = match_scene.get_node("MatchReplay")
	var results: Node = match_scene.get_node("Results")
	flow.state = flow.State.REPLAY
	replay.playing = true
	_check(pause.is_open == false and not pause.can_open(), "no replay a pausa não abre")
	flow.replay_seconds = 30.0
	flow._wait = 30.0
	replay._unhandled_input(_esc())
	_check(flow._wait == 0.0, "o voltar pula o replay")
	replay.playing = false
	flow.state = flow.State.RESULTS
	_bus.match_state_changed.emit(flow.State.RESULTS)
	_check(results._panel.visible, "o painel de resultados abre")
	results._unhandled_input(_esc())
	await _frames(2)
	_check(current_scene == null or current_scene.scene_file_path != "res://scenes/menu.tscn", "nos primeiros 1 s o voltar não sai dos resultados")
	OS.delay_msec(1100)
	results._unhandled_input(_esc())
	await _frames(3)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn", "depois de 1 s o voltar leva ao menu")

	if not _failed:
		print("OK")
		quit(0)
