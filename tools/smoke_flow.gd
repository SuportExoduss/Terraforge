extends SceneTree
## Teste de fumaça do Passo 20 (cap. 04 parte 01, máquina de estados): a partida percorre LOADING→SPAWN→COUNTDOWN→PLAYING,
## alterna PLAYING↔EVENT_ACTIVE conforme os eventos globais, e no fim passa por TIME_UP→TALLY→REPLAY→RESULTS sem pular
## nem voltar; a tela de resultados só aparece em RESULTS. Uso: godot_console --headless --path . -s res://tools/smoke_flow.gd
## Estados: 0 LOADING, 1 SPAWN, 2 COUNTDOWN, 3 PLAYING, 4 EVENT_ACTIVE, 5 TIME_UP, 6 TALLY, 7 REPLAY, 8 RESULTS, 9 MENU

var _match: Node
var _bus: Node
var _seen: Array = []
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.match_state_changed.connect(func(state: int): _seen.append(state))
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
	await process_frame   # a cena entra na árvore depois do _initialize
	var flow: Node = root.get_node("Services").flow
	if not _check(flow != null and flow.state <= 1, "MatchFlow registrado, ainda no carregamento/spawn"): return

	# Abertura: carregamento → spawn → contagem → partida, em ordem e sem pular
	await _bus.match_started
	await process_frame
	if not _check(_seen == [1, 2, 3], "abertura em ordem: %s" % str(_seen)): return
	if not _check(flow.state == 3, "GO = PLAYING"): return

	# Não se volta: pedir um estado anterior não muda nada
	flow.go(1)
	flow.go(0)
	if not _check(flow.state == 3 and _seen == [1, 2, 3], "não volta atrás"): return

	# Eventos globais: PLAYING <-> EVENT_ACTIVE (contando vários ao mesmo tempo)
	_bus.global_event_active_changed.emit(true)
	_bus.global_event_active_changed.emit(true)
	if not _check(flow.state == 4, "evento ativo = EVENT_ACTIVE"): return
	_bus.global_event_active_changed.emit(false)
	if not _check(flow.state == 4, "ainda há um evento ativo"): return
	_bus.global_event_active_changed.emit(false)
	if not _check(flow.state == 3, "sem eventos = volta a PLAYING"): return
	_bus.global_event_active_changed.emit(true)   # um evento ainda ativo quando o tempo acaba

	# Fim do tempo: TIME_UP → TALLY → REPLAY → RESULTS, o painel só no último
	flow.time_up_seconds = 0.3
	flow.tally_seconds = 0.3
	flow.replay_seconds = 0.3
	_seen.clear()
	var panel: Control = _match.get_node("Results/Panel")
	_bus.match_ended.emit()
	if not _check(flow.state == 5 and _seen == [5], "o fim do tempo abre TIME_UP (evento é opcional): %s" % str(_seen)): return
	_bus.global_event_active_changed.emit(false)   # o evento encerra depois: não deve mexer no estado
	if not _check(flow.state == 5 and not panel.visible, "TIME_UP sem painel"): return
	while flow.state < 8:
		if not _check(not panel.visible, "painel escondido até RESULTS (estado %d)" % flow.state): return
		await process_frame
	if not _check(_seen == [5, 6, 7, 8], "pós-jogo em ordem: %s" % str(_seen)): return
	await process_frame
	if not _check(panel.visible, "RESULTS mostra o painel"): return
	if not _check(_match.get_node("Results/Panel/Box/Ranking").get_parsed_text().contains("RESULTADO FINAL"), "apuração feita (TALLY)"): return

	# MENU (STATE-013) e a regra "nada é pulado": um MatchFlow solto percorre toda a ordem
	flow.go(9)
	if not _check(flow.state == 9 and _seen.back() == 9, "MENU"): return
	var lone: Node = load("res://scripts/core/match_flow.gd").new()
	_seen.clear()
	lone.go(8)
	if not _check(_seen == [1, 2, 3, 5, 6, 7, 8], "pedir RESULTS passa por todos os estados: %s" % str(_seen)): return
	lone.free()
	print("OK")
	quit(0)
