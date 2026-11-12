extends SceneTree
## Teste de fumaça do Passo 86 (Cap.03 P11 RESULTADO): a apuração conta os eventos globais da partida (um por aviso, mesmo
## com dois avisos intercalados) e em quais deles o jogador levou dano (só dano dele, só de evento, uma vez por evento);
## a tela de resultado mostra "Eventos globais: N — escapou de X, atingido por Y".
## Uso: godot_console --headless --path . -s res://tools/smoke_results_events.gd

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


func _warn(event_name: String, counts: Array) -> void:
	for n in counts:
		_bus.global_event_warning.emit(event_name, n)


func _run() -> void:
	await _bus.match_started
	await process_frame
	var stats: Node = root.get_node("Services").stats
	if not _check(stats.events_seen() == 0 and stats.events_hit() == 0, "a partida começa sem eventos"): return

	# a. Tsunami (aviso 5..3): 1 evento; dano dele duas vezes = atingido uma vez
	_warn("TSUNAMI VINDO", [5, 4, 3])
	_bus.damage_taken.emit(1, 2, "TSUNAMI")
	_bus.damage_taken.emit(1, 1, "TSUNAMI")
	if not _check(stats.events_seen() == 1 and stats.events_hit() == 1, "tsunami: 1 visto, 1 atingido (%d/%d)" % [stats.events_seen(), stats.events_hit()]): return

	# b. Meteoro e verme com avisos intercalados: 2 eventos (não 4); IMPACTO vale para o mais recente (o verme)
	for n in [5, 4]:
		_warn("METEORO CAINDO", [n])
		_warn("VERME GIGANTE IMINENTE", [n])
	if not _check(stats.events_seen() == 3, "avisos intercalados contam 2 eventos (%d no total)" % stats.events_seen()): return
	_bus.damage_taken.emit(2, 4, "IMPACTO")      # outro jogador: não conta
	_bus.damage_taken.emit(1, 1, "DEFENSOR")     # não é evento
	_bus.damage_taken.emit(1, 1, "RASTRO CORTADO")
	_bus.damage_taken.emit(1, 1, "DANO")
	if not _check(stats.events_hit() == 1, "dano dos outros e de não-evento não conta (%d)" % stats.events_hit()): return
	_bus.damage_taken.emit(1, 2, "IMPACTO")
	if not _check(stats.events_hit() == 2, "o impacto atingiu o jogador (%d)" % stats.events_hit()): return

	# c. Terremoto sem dano; d. outro tsunami (a contagem sobe de novo) = outro evento
	_warn("TERREMOTO IMINENTE", [5])
	_warn("TSUNAMI VINDO", [5])
	_bus.damage_taken.emit(1, 1, "TSUNAMI")
	if not _check(stats.events_seen() == 5 and stats.events_hit() == 3, "no fim: 5 vistos, 3 atingidos (%d/%d)" % [stats.events_seen(), stats.events_hit()]): return

	# A tela de resultado mostra o resumo
	_match.get_node("MatchFlow").pace = 0.0   # pós-jogo instantâneo
	_bus.match_ended.emit()
	await process_frame
	var text: String = _match.find_child("Stats", true, false).get_parsed_text()
	if not _check(text.contains("Eventos globais: 5 — escapou de 2, atingido por 3"), "resumo na tela:\n%s" % text): return
	print("OK")
	quit(0)
