extends SceneTree
## Teste de fumaça do Passo 23 (conquistas, cap. 03 parte 11): (1) a tabela dispara só quando o mínimo é atingido;
## (2) numa partida de verdade o conjunto esperado é concedido, aparece nos resultados e grava no perfil;
## (3) conquista já ganha não duplica numa 2ª partida; (4) o contador de conquistas do perfil bate com o salvo.
## Uso: godot_console --headless --path . -s res://tools/smoke_achievements.gd

const TEST_PROFILE := "user://profile_smoke_achievements.json"

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


func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	out.sort()
	return out


func _run() -> void:
	var ach = load("res://scripts/core/achievements.gd")

	# 1. Tabela pura: nada com o snapshot zerado; limites exatos; cada chave dispara a sua
	if not _check(ach.earned({}).is_empty(), "snapshot vazio não ganha nada"): return
	if not _check(_sorted(ach.earned({"loops": 1})) == ["first_area"], "1 área = só Primeira Conquista"): return
	if not _check(_sorted(ach.earned({"loops": 10})) == ["cartographer", "first_area"], "10 áreas = + Cartógrafo"): return
	if not _check(ach.earned({"cuts": 2}).is_empty() and ach.earned({"cuts": 3}) == ["cutter"], "Cortador só com 3 cortes"): return
	if not _check(ach.earned({"converted": 0.099}).is_empty() and ach.earned({"converted": 0.10}) == ["usurper"], "Usurpador só com 10%"): return
	if not _check(ach.earned({"percent": 0.49}).is_empty() and ach.earned({"percent": 0.50}) == ["dominator"], "Dominador só com 50%"): return
	if not _check(ach.earned({"kills": 1}) == ["hunter"] and ach.earned({"matches": 10}) == ["veteran"], "Caçador e Veterano"): return
	if not _check(ach.title_of("conqueror") == "Conquistador" and ach.title_of("nao_existe") == "nao_existe", "nomes"): return

	# 2. Partida de verdade: 2 áreas, 1º lugar com 55%, vivo → Primeira Conquista, Sobrevivente, Conquistador, Dominador
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var profile = load("res://scripts/core/profile.gd")
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	_bus.territory_loop_closed.emit(1, PackedVector3Array())
	_bus.territory_score_changed.emit(1, 0.55)
	_bus.territory_score_changed.emit(2, 0.20)
	_match.get_node("MatchFlow").pace = 0.0
	_bus.match_ended.emit()
	await process_frame
	var expected := ["conqueror", "dominator", "first_area", "survivor"]
	var fresh: Array = services.rewards.last.get("new_achievements", [])
	if not _check(_sorted(fresh) == expected, "conquistas novas: %s (esperado %s)" % [_sorted(fresh), expected]): return
	profile.load_data()
	if not _check(_sorted(profile.data["achievements"].keys()) == expected, "perfil salvo: %s" % [profile.data["achievements"].keys()]): return
	var text: String = _match.get_node("Results/Panel/Box/Columns/Side/Rewards").get_parsed_text()
	if not _check(text.contains("CONQUISTA: Primeira Conquista") and text.contains("CONQUISTA: Dominador"), "painel:\n" + text): return

	# 3. Segunda partida (mesma cena, concessão repetida): nada duplica; o perfil conta 2 partidas
	var rewards: Node = services.rewards
	rewards._done = false
	rewards._grant()
	if not _check(rewards.last.get("new_achievements", ["x"]).is_empty(), "2ª partida não repete conquistas: %s" % [rewards.last.get("new_achievements")]): return
	profile.load_data()
	if not _check(int(profile.data["matches"]) == 2 and profile.data["achievements"].size() == 4, "perfil após 2ª partida: %s" % [profile.data]): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
