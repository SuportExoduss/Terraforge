extends SceneTree
## Teste de fumaça do Passo 19 (apuração, cap. 03 parte 11): (1) circuito fechado = área conquistada; (2) conquista
## que toma terreno de outra civilização conta como território tomado (e terra livre não conta); (3) corte de rastro
## conta para quem cortou; (4) eliminação por corte credita o assassino, eliminação por evento não credita ninguém;
## (5) a tela de resultados mostra as estatísticas do jogador. Uso: godot_console --headless --path . -s res://tools/smoke_stats.gd

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


# Anel de pontos ao redor de `center_dir`, a `angle` rad do centro (um circuito fechado no chão).
func _ring(center_dir: Vector3, angle: float, count: int) -> PackedVector3Array:
	var planet: Node = root.get_node("Services").planet
	var side := center_dir.cross(Vector3.BACK if absf(center_dir.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	var out := PackedVector3Array()
	for i in count:
		var dir := center_dir.rotated(side, angle).rotated(center_dir, TAU * i / count)
		out.append(planet.center + dir * planet.radius)
	return out


func _run() -> void:
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var stats: Node = services.stats
	var territory: Node = services.territory
	if not _check(stats != null, "Services.stats registrado pela partida"): return
	if not _check(stats.get_stat(1, "loops") == 0.0 and stats.get_stat(7, "kills") == 0.0, "tudo começa zerado"): return

	# 1. Circuito fechado = área conquistada (sinal do rastro)
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	if not _check(stats.get_stat(1, "loops") == 2.0 and stats.get_stat(2, "loops") == 0.0, "2 circuitos do jogador"): return

	# 2. Território tomado: civilização 2 ganha uma calota longe; o jogador cerca parte dela (conversão real)
	var far_dir := Vector3(0.3, -0.9, 0.3).normalized()
	territory.claim_cap(2, far_dir, 0.5)
	var before: float = territory.owned_fraction(2)
	if not _check(before > 0.02, "calota da civilização 2 (%.3f)" % before): return
	if not _check(stats.get_stat(1, "converted") == 0.0, "terra livre não conta como território tomado"): return
	territory.claim_loop_interior(1, _ring(far_dir, 0.2, 40))
	var lost: float = before - territory.owned_fraction(2)
	if not _check(lost > 0.005, "a civilização 2 perdeu terreno (%.4f)" % lost): return
	var taken: float = stats.get_stat(1, "converted")
	if not _check(absf(taken - lost) < 0.0005, "território tomado %.4f = perdido %.4f" % [taken, lost]): return
	# o circuito foi chamado direto (sem o sinal do rastro): não mexe na contagem de áreas
	if not _check(stats.get_stat(1, "loops") == 2.0, "claim direto não conta área"): return

	# 3. Corte de rastro conta para quem cortou
	_bus.trail_cut.emit(2, 1)
	_bus.trail_cut.emit(2, 1)
	_bus.trail_cut.emit(1, 2)
	if not _check(stats.get_stat(1, "cuts") == 2.0 and stats.get_stat(2, "cuts") == 1.0, "cortes: 1→%d, 2→%d" % [stats.get_stat(1, "cuts"), stats.get_stat(2, "cuts")]): return

	# 4. Eliminação por corte credita o assassino (pelo Health real); por evento, ninguém
	_bus.civilization_eliminated.emit(5)   # eliminação sem corte (evento/defensor): ninguém ganha crédito
	if not _check(stats.get_stat(1, "kills") == 0.0 and stats.get_stat(2, "kills") == 0.0, "eliminação por evento não credita"): return
	var health: Node = _match.get_node("Main/Runner/Health")
	health.take_damage(health.points - 2)   # sobra 1 corte de vida (cut_damage_points = 2)
	_bus.trail_cut.emit(1, 2)               # o corte da civilização 2 elimina o jogador
	if not _check(health.points == 0, "o corte eliminou o jogador (%d pts)" % health.points): return
	if not _check(stats.get_stat(2, "kills") == 1.0 and stats.get_stat(1, "kills") == 0.0, "o assassino ganha a eliminação"): return

	# 5. Resultados mostram as estatísticas do jogador
	_match.get_node("MatchFlow").pace = 0.0   # pós-jogo instantâneo
	_bus.match_ended.emit()
	await process_frame
	var text: String = _match.get_node("Results/Panel/Box/Stats").get_parsed_text()
	if not _check(text.contains("SUAS ESTATÍSTICAS") and text.contains("Áreas conquistadas: 2") and text.contains("Rastros cortados: 2") and text.contains("Eliminações: 0"), "painel de estatísticas:\n" + text): return
	if not _check(text.contains("Território tomado de rivais: ") and not text.contains("rivais: 0,0%"), "território tomado no painel:\n" + text): return
	print("OK")
	quit(0)
