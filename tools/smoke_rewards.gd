extends SceneTree
## Teste de fumaça do Passo 22 (recompensas, cap. 03 parte 11 / DD-038): ao fim da partida o desempenho do jogador vira
## XP e moedas (fórmula = constantes de MatchRewards), grava no perfil salvo, aparece na tela de resultados e o perfil
## sobrevive a recarregar do arquivo. Nada disso compra vantagem na partida (só perfil + cosmético).
## Uso: godot_console --headless --path . -s res://tools/smoke_rewards.gd

const TEST_PROFILE := "user://profile_smoke_rewards.json"

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	# Perfil de teste, sempre começando do zero (o arquivo "de verdade" nunca é tocado)
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
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
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


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
	var profile = load("res://scripts/core/profile.gd")
	var cfg = load("res://scripts/core/match_rewards.gd")
	if not _check(services.rewards != null, "Services.rewards registrado pela partida"): return

	# Desempenho: 2 áreas, 1 corte, território tomado de verdade, jogador em 1º com 55% (civilização 2 com 20%)
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	var far_dir := Vector3(0.3, -0.9, 0.3).normalized()
	services.territory.claim_cap(2, far_dir, 0.5)
	services.territory.claim_loop_interior(1, _ring(far_dir, 0.2, 40))
	_bus.trail_cut.emit(2, 1)
	_bus.territory_score_changed.emit(1, 0.55)
	_bus.territory_score_changed.emit(2, 0.20)
	var taken: float = services.stats.get_stat(1, "converted")
	if not _check(taken > 0.005, "território tomado (%.4f)" % taken): return

	var xp_expected: int = cfg.XP_PARTICIPATION + 2 * cfg.XP_PER_LOOP + 1 * cfg.XP_PER_CUT \
			+ roundi(taken * 100.0 * cfg.XP_PER_PERCENT_TAKEN) + cfg.XP_SURVIVED + cfg.XP_PLACE[0]
	var coins_expected: int = cfg.COINS_PARTICIPATION + roundi(0.55 * 100.0 * cfg.COINS_PER_PERCENT) + cfg.COINS_WIN

	# Fim da partida (pós-jogo instantâneo): a recompensa é concedida na apuração
	_match.get_node("MatchFlow").pace = 0.0
	_bus.match_ended.emit()
	await process_frame
	var last: Dictionary = services.rewards.last
	if not _check(last.get("xp", -1) == xp_expected and last.get("coins", -1) == coins_expected,
			"recompensa %s, esperado xp=%d moedas=%d" % [last, xp_expected, coins_expected]): return
	if not _check(last.get("place", 0) == 1 and absf(last.get("percent", 0.0) - 0.55) < 0.0001, "colocação/percentual: %s" % last): return
	if not _check(last["level_before"] == 1 and last["level"] == profile.level(xp_expected), "nível %d → %d" % [last["level_before"], last["level"]]): return

	# Gravado no perfil salvo: recarrega do arquivo e confere
	profile.load_data()
	var d: Dictionary = profile.data
	if not _check(int(d["xp"]) == xp_expected and int(d["coins"]) == coins_expected, "perfil salvo xp=%s moedas=%s" % [d["xp"], d["coins"]]): return
	if not _check(int(d["matches"]) == 1 and int(d["wins"]) == 1 and absf(float(d["best_percent"]) - 0.55) < 0.0001, "partidas/vitórias/melhor: %s" % d): return
	if not _check(int(d["loops"]) == 2 and int(d["cuts"]) == 1 and int(d["kills"]) == 0, "totais do perfil: %s" % d): return

	# Tela de resultados mostra a recompensa
	var text: String = _match.get_node("Results/Panel/Box/Rewards").get_parsed_text()
	if not _check(text.contains("RECOMPENSAS") and text.contains("+%d XP" % xp_expected) and text.contains("+%d moedas" % coins_expected), "painel de recompensas:\n" + text): return
	if not _check(text.contains("Nível %d" % last["level"]), "nível no painel:\n" + text): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
