extends SceneTree
## Teste de fumaça do Passo 68 (Cap.03 P11 REPLAY "grandes eventos"): o replay anota cada evento global (uma vez por aviso, não
## uma por segundo de contagem) e mostra o nome na legenda quando chega ao instante dele, por event_caption_seconds.
## Uso: godot_console --headless --path . -s res://tools/smoke_replay_events.gd

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

	# Um aviso (contagem 5, 4, 3) no segundo 50 e outro no 150: duas entradas, não seis
	replay._clock = 50.0
	for n in [5, 4, 3]:
		_bus.global_event_warning.emit("TSUNAMI", n)
	replay._clock = 150.0
	for n in [5, 4]:
		_bus.global_event_warning.emit("TERREMOTO", n)
	if not _check(replay._events.size() == 2, "dois avisos = dois eventos (%d)" % replay._events.size()): return

	replay._clock = 200.0
	replay.event_caption_seconds = 0.2
	flow.time_up_seconds = 0.0
	flow.tally_seconds = 0.0
	flow.replay_seconds = 1.0
	_bus.match_ended.emit()
	if not _check(replay.playing and not replay._caption.text.contains("TSUNAMI"), "no começo não há evento na legenda"): return
	await create_timer(0.35).timeout   # 0,25 s de replay = o instante 50 s da partida
	if not _check(replay._caption.text.contains("TSUNAMI"), "o replay chegou no tsunami (%s)" % replay._caption.text): return
	await create_timer(0.3).timeout    # 0,2 s depois ele já saiu da legenda
	if not _check(not replay._caption.text.contains("TSUNAMI"), "o nome saiu da legenda"): return
	print("OK: replay anota 2 eventos (aviso conta uma vez) e mostra o nome na legenda no instante certo")
	quit(0)
