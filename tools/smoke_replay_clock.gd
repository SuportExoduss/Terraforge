extends SceneTree
## Teste de fumaça do Passo 67 (Cap.03 P11 REPLAY): durante o replay há uma legenda "REPLAY m:ss" com o instante da partida
## que está sendo mostrado; ela some quando o replay acaba. Uso: godot_console --headless --path . -s res://tools/smoke_replay_clock.gd

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


func _run() -> void:
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var flow: Node = services.flow
	var replay: Node = _match.get_node("MatchReplay")
	services.territory.claim_cap(1, Vector3(0.0, -0.9, 0.4).normalized(), 0.4)
	for i in 5:
		await process_frame

	replay._clock = 200.0   # finge uma partida de 200 s (3:20)
	flow.time_up_seconds = 0.0
	flow.tally_seconds = 0.0
	flow.replay_seconds = 1.0
	_bus.match_ended.emit()
	if not _check(replay.playing and replay._caption != null, "em REPLAY deveria haver a legenda"): return
	if not _check(replay._caption.text == "REPLAY  0:00", "legenda inicial (%s)" % replay._caption.text): return
	await create_timer(0.5).timeout
	if not _check(replay._caption.text.begins_with("REPLAY  1:"), "a meio do replay o relógio passa de 1:00 (%s)" % replay._caption.text): return

	while flow.state < 8:
		await process_frame
	await process_frame
	if not _check(not replay.playing and replay._caption == null, "a legenda some quando o replay acaba"): return
	print("OK: legenda do replay mostra o relógio da partida (0:00 → 1:xx) e some ao terminar")
	quit(0)
