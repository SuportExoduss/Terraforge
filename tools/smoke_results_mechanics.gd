extends SceneTree
## Teste de fumaça do Passo 151 (DD-190): o resultado mostra sprints, habilidades e defensores capturados do jogador,
## numa linha só e SÓ o que aconteceu (partida sem nenhum dos três não ganha a linha).
## Uso: godot_console --headless --path . -s res://tools/smoke_results_mechanics.gd

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
	var panel: Node = _match.get_node("Results")

	# a. Nada aconteceu: a linha não existe
	var text: String = panel._stats_text()
	if not _check(not text.contains("Sprints") and not text.contains("Habilidades") and not text.contains("capturados"), "sem sprint/habilidade/captura não há a linha:\n%s" % text): return

	# b. Só sprints (e rivais não contam)
	_bus.sprint_used.emit(1, 3.5)
	_bus.sprint_used.emit(1, 3.5)
	_bus.sprint_used.emit(2, 3.5)
	text = panel._stats_text()
	if not _check(text.contains("Sprints: 2") and not text.contains("Habilidades") and not text.contains("capturados"), "só sprints do jogador:\n%s" % text): return

	# c. Os três juntos, na ordem, na mesma linha e antes dos eventos globais
	_bus.ability_used.emit(1, "lasso")
	_bus.defender_captured.emit(1, 2)
	text = panel._stats_text()
	if not _check(text.contains("Sprints: 2 · Habilidades: 1 · Defensores capturados: 1"), "os três na mesma linha:\n%s" % text): return
	if not _check(text.find("Sprints: 2") < text.find("Eventos globais"), "a linha vem antes dos eventos globais"): return

	# d. Aparece na tela de resultado de verdade
	_match.get_node("MatchFlow").pace = 0.0
	_bus.match_ended.emit()
	await process_frame
	var shown: String = _match.find_child("Stats", true, false).get_parsed_text()
	if not _check(shown.contains("Defensores capturados: 1"), "na tela de resultado:\n%s" % shown): return
	print("OK")
	quit(0)
