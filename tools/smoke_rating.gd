extends SceneTree
## Teste de fumaça do Passo 53 (nível de habilidade, Cap.03 P02 matchmaking): o perfil novo começa em 1000; a tabela
## rating_after sobe/desce conforme a colocação (nunca abaixo de 0); a apuração da partida grava o novo rating no perfil
## salvo; a tela PERFIL mostra "Habilidade N".
## Uso: godot_console --headless --path . -s res://tools/smoke_rating.gd

const TEST_PROFILE := "user://profile_smoke_rating.json"

var _match: Node
var _time := 0.0


func _initialize() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	var bus: Node = root.get_node("EventBus")
	var services: Node = root.get_node("Services")

	# Perfil novo e tabela de colocações
	if not _check(int(profile.data["rating"]) == 1000 and profile.defaults()["rating"] == profile.RATING_START, "perfil novo começa em 1000"): return
	var table := {1: 1025, 2: 1010, 3: 1000, 4: 985, 0: 985}   # colocação → rating depois de partir de 1000
	for place: int in table:
		if not _check(profile.rating_after(1000, place) == table[place], "colocação %d: %d, esperado %d" % [place, profile.rating_after(1000, place), table[place]]): return
	if not _check(profile.rating_after(5, 4) == 0, "o rating nunca fica abaixo de 0"): return

	# Fim da partida em 1º lugar: o rating sobe e fica gravado em disco
	await bus.match_started
	await process_frame
	bus.territory_score_changed.emit(1, 0.55)
	bus.territory_score_changed.emit(2, 0.20)
	_match.get_node("MatchFlow").pace = 0.0
	bus.match_ended.emit()
	await process_frame
	var last: Dictionary = services.rewards.last
	if not _check(last.get("place", 0) == 1 and last.get("rating_before", -1) == 1000 and last.get("rating", -1) == 1025, "recompensa traz o rating: %s" % last): return
	profile.load_data()   # relê do disco
	if not _check(int(profile.data["rating"]) == 1025, "rating 1025 gravado no perfil: %s" % profile.data["rating"]): return

	# A tela PERFIL mostra a habilidade
	profile.data["rating"] = 1234
	var screen = load("res://scripts/ui/profile_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var label = screen.find_child("Rating", true, false)
	if not _check(label != null and label.text == "Habilidade 1234", "a tela mostra a habilidade"): return

	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_rating")
	quit(0)
