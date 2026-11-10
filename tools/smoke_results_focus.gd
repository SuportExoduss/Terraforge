extends SceneTree
## Teste de fumaça do Passo 71 (DD-038 "vontade imediata de jogar novamente"): ao abrir os resultados o botão JOGAR DE NOVO
## ganha foco (ENTER/ESPAÇO o aciona), mas só depois de uma pequena espera, para não reiniciar por um toque do replay.
## Uso: godot_console --headless --path . -s res://tools/smoke_results_focus.gd

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
	if _time > 30.0:
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
	var button: Button = _match.get_node("Results/Panel/Box/Buttons/PlayAgain")
	if not _check(not button.has_focus(), "durante a partida o botão não tem foco"): return

	_match.get_node("MatchFlow").pace = 0.0   # pós-jogo instantâneo
	_bus.match_ended.emit()
	await process_frame
	if not _check(_match.get_node("Results/Panel").visible, "painel aberto"): return
	if not _check(not button.has_focus(), "logo ao abrir os resultados o foco ainda não está no botão"): return
	await create_timer(0.8).timeout
	if not _check(button.has_focus(), "depois da espera o foco deveria estar em JOGAR DE NOVO"): return
	print("OK: JOGAR DE NOVO ganha foco 0,6 s depois de abrir os resultados (ENTER joga de novo)")
	quit(0)
