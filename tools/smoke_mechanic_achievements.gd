extends SceneTree
## Teste de fumaça do Passo 149 (DD-188): sprint, habilidade do bioma e defensor capturado contam no placar e rendem conquista.
## (1) a tabela dispara nos limites (8 sprints, 3 habilidades, 1 captura); (2) numa partida só conta o que o JOGADOR fez
## (os rivais têm o placar deles); (3) o snapshot da recompensa leva as 3 chaves: Mestre da Habilidade e Domador saem, Corredor não
## (7 sprints); (4) mais 1 sprint na mesma partida concede só o Corredor, sem repetir as outras.
## Uso: godot_console --headless --path . -s res://tools/smoke_mechanic_achievements.gd

const TEST_PROFILE := "user://profile_smoke_mechanic_achievements.json"

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
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


func _run() -> void:
	var ach = load("res://scripts/core/achievements.gd")

	# 1. Tabela pura: limites exatos
	if not _check(ach.earned({"sprints": 7}).is_empty() and ach.earned({"sprints": 8}) == ["sprinter"], "Corredor só com 8 sprints"): return
	if not _check(ach.earned({"abilities": 2}).is_empty() and ach.earned({"abilities": 3}) == ["caster"], "Mestre da Habilidade só com 3 usos"): return
	if not _check(ach.earned({"captures": 0}).is_empty() and ach.earned({"captures": 1}) == ["tamer"], "Domador só com 1 captura"): return
	if not _check(ach.title_of("tamer") == "Domador" and ach.description_of("sprinter").contains("8"), "nomes e descrições"): return

	# 2. Na partida só o jogador conta para o jogador: rivais têm o placar deles
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var stats: Node = services.stats
	for i in 7:
		_bus.sprint_used.emit(1, 3.5)
	for i in 5:
		_bus.sprint_used.emit(2, 3.5)
	for i in 3:
		_bus.ability_used.emit(1, "lasso")
	_bus.ability_used.emit(2, "emp")
	_bus.defender_captured.emit(1, 2)
	_bus.defender_captured.emit(2, 1)
	_bus.defender_captured.emit(2, 3)
	if not _check(stats.get_stat(1, "sprints") == 7 and stats.get_stat(2, "sprints") == 5, "sprints por civilização"): return
	if not _check(stats.get_stat(1, "abilities") == 3 and stats.get_stat(2, "abilities") == 1, "habilidades por civilização"): return
	if not _check(stats.get_stat(1, "captures") == 1 and stats.get_stat(2, "captures") == 2, "capturas creditam o conquistador"): return

	# 3. Fim da partida: Mestre da Habilidade e Domador saem; Corredor (7 sprints) ainda não
	_bus.territory_score_changed.emit(1, 0.30)
	_bus.territory_score_changed.emit(2, 0.20)
	_match.get_node("MatchFlow").pace = 0.0
	_bus.match_ended.emit()
	await process_frame
	var rewards: Node = services.rewards
	var fresh: Array = rewards.last.get("new_achievements", [])
	if not _check(fresh.has("caster") and fresh.has("tamer") and not fresh.has("sprinter"), "conquistas novas: %s" % [fresh]): return
	var text: String = _match.get_node("Results/Panel/Box/Columns/Side/Rewards").get_parsed_text()
	if not _check(text.contains("CONQUISTA: Domador"), "painel mostra o Domador:\n" + text): return

	# 4. Mais 1 sprint e a concessão repetida: só o Corredor é novo
	_bus.sprint_used.emit(1, 3.5)
	rewards._done = false
	rewards._grant()
	var again: Array = rewards.last.get("new_achievements", [])
	if not _check(again == ["sprinter"], "só o Corredor é novo: %s" % [again]): return
	var profile = load("res://scripts/core/profile.gd")
	profile.load_data()
	if not _check(profile.data["achievements"].has("sprinter") and profile.data["achievements"].has("tamer"), "perfil guardou as conquistas novas"): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK: sprint, habilidade e captura contam só para quem fez e rendem conquista")
	quit(0)
