extends SceneTree
## Teste de fumaça do Passo 21 (replay cinematográfico, DD-037): no estado REPLAY o planeta é repintado do zero em
## velocidade acelerada (passa por um estado parcial) e, ao chegar em RESULTS, volta idêntico ao planeta final.
## Uso: godot_console --headless --path . -s res://tools/smoke_replay.gd

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
	var painter: Node = services.planet.painter
	var flow: Node = services.flow
	var replay: Node = _match.get_node("MatchReplay")

	# Duas conquistas em momentos diferentes da partida (a 2ª só ~0,6 s depois da 1ª)
	services.territory.claim_cap(1, Vector3(0.0, -0.9, 0.4).normalized(), 0.4)
	await create_timer(0.6).timeout
	services.territory.claim_cap(2, Vector3(0.5, 0.5, -0.7).normalized(), 0.4)
	for i in 5:
		await process_frame
	painter.paint_all_now()
	var final_hash: int = hash(painter._own.get_data())
	# Tomar a base da civilização 2 a faz se mudar (DD-100) e pousar de novo, conquistando um disco novo em instante variável:
	# congela as bases para nenhuma conquista nova mexer no planeta depois da foto (era 1 falha em ~10 execuções).
	for base in _match.find_children("*", "HomeTerritory", true, false):
		base.set_process(false)
	var blank := PackedByteArray()
	blank.resize(painter._own.get_data().size())   # tudo zero = nenhum território
	var empty_hash: int = hash(blank)
	if not _check(final_hash != empty_hash, "o planeta final tem território"): return

	# Fim do tempo → REPLAY (12 s por padrão; aqui 1 s): o planeta é apagado e repintado aos poucos
	flow.time_up_seconds = 0.0
	flow.tally_seconds = 0.0
	flow.replay_seconds = 1.0
	_bus.match_ended.emit()
	if not _check(flow.state == 7 and replay.playing, "em REPLAY, repintando (estado %d)" % flow.state): return
	if not _check(hash(painter._own.get_data()) == empty_hash, "o replay recomeça do planeta vazio"): return
	await create_timer(0.45).timeout
	var mid_hash: int = hash(painter._own.get_data())
	if not _check(mid_hash != empty_hash and mid_hash != final_hash, "a meio do replay o planeta está parcialmente pintado"): return

	# RESULTS: o replay acabou e o planeta final volta idêntico
	while flow.state < 8:
		await process_frame
	await process_frame
	if not _check(not replay.playing, "replay encerrado em RESULTS"): return
	if not _check(hash(painter._own.get_data()) == final_hash, "o planeta final volta idêntico ao original"): return
	print("OK")
	quit(0)
