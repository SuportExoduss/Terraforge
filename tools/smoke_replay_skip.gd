extends SceneTree
## Teste de fumaça do Passo 69 (DD-038): durante o replay, ESPAÇO/ENTER/ESC/clique/toque pulam para os resultados e o planeta
## final volta completo; outras teclas e o eco de uma tecla não pulam; fora do replay o pedido não faz nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_replay_skip.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _key(code: Key, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	return ev


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


# Começa um replay longo (30 s) e devolve se ele está rodando
func _start_replay(flow: Node, replay: Node) -> bool:
	_bus.match_ended.emit()
	return flow.state == 7 and replay.playing


func _run() -> void:
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var flow: Node = services.flow
	var replay: Node = _match.get_node("MatchReplay")
	services.territory.claim_cap(1, Vector3(0.0, -0.9, 0.4).normalized(), 0.4)
	for i in 5:
		await process_frame

	# Fora do replay o pedido de pular não faz nada
	flow.skip_replay()
	if not _check(flow.state != 8, "skip fora do replay não deveria mudar o estado"): return

	flow.time_up_seconds = 0.0
	flow.tally_seconds = 0.0
	flow.replay_seconds = 30.0
	if not _check(_start_replay(flow, replay), "deveria estar em REPLAY"): return
	replay._unhandled_input(_key(KEY_A))
	replay._unhandled_input(_key(KEY_SPACE, true))   # eco: segurar a tecla não pula
	await process_frame
	if not _check(flow.state == 7 and replay.playing, "tecla qualquer/eco não deveria pular"): return
	replay._unhandled_input(_key(KEY_SPACE))
	await process_frame
	await process_frame
	if not _check(flow.state == 8 and not replay.playing, "ESPAÇO deveria ir aos resultados (estado %d)" % flow.state): return

	# Clique também pula (nova partida em REPLAY: reinicia o fluxo direto no estado)
	flow.state = 7
	flow._wait = 30.0
	replay._begin()
	if not _check(replay.playing, "replay de novo"): return
	replay._unhandled_input(_click())
	await process_frame
	await process_frame
	if not _check(flow.state == 8 and not replay.playing, "clique deveria ir aos resultados (estado %d)" % flow.state): return
	print("OK: ESPAÇO/clique pulam o replay; tecla comum, eco e pedido fora do replay não fazem nada")
	quit(0)
