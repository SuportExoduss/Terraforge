extends SceneTree
## Teste de fumaça do Passo 141 (DD-180): BÔNUS DE RETORNO. (1) days_away conta os dias desde a última partida (0 sem histórico);
## (2) longe há 3 dias ou mais, a próxima partida rende +60 XP; com 0–2 dias não; (3) só vale uma vez (a partida seguinte, no mesmo dia,
## já não); (4) é só XP: moedas e gemas iguais às de uma partida comum; (5) o painel de resultados mostra a linha só quando há.
## Perfil só dele. Uso: godot_console --headless --path . -s res://tools/smoke_comeback.gd

const TEST_PROFILE := "user://profile_smoke_comeback.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const DAY0 := 4000

var _profile
var _stats := FakeStats.new()


## Placar de mentira: o jogador (1) fica em `place`, com 30% do planeta e sem feitos.
class FakeStats extends RefCounted:
	var place := 2
	func ranking() -> Array:
		var list := []
		for i in range(1, place):
			list.append(100 + i)
		list.append(1)
		return list
	func dominance(_id) -> float: return 0.3
	func is_eliminated(_id) -> bool: return false
	func get_stat(_id, _key) -> float: return 0.0


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _initialize() -> void:
	_run()


## Joga uma partida (2º lugar, sempre igual) no dia `day` e devolve o `last`.
func _play(day: int) -> Dictionary:
	DailyMissions.day_override = day
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	root.get_node("Services").stats = _stats
	rewards._grant()
	var last: Dictionary = rewards.last
	rewards.free()
	return last


func _panel_text(last: Dictionary) -> String:
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	rewards.last = last
	root.get_node("Services").rewards = rewards
	var panel = load("res://scripts/ui/results_panel.gd").new()
	var text: String = panel._rewards_text()
	panel.free()
	root.get_node("Services").rewards = null
	rewards.free()
	return text


func _run() -> void:
	await process_frame
	_profile = load("res://scripts/core/profile.gd")
	_profile.path = TEST_PROFILE
	_profile.data = _profile.defaults()
	_profile.save()
	var bonus := int(load("res://scripts/core/match_rewards.gd").COMEBACK_XP)
	var days := int(load("res://scripts/core/match_rewards.gd").COMEBACK_DAYS)

	# 1. days_away
	if _profile.days_away(DAY0) != 0:
		_fail("sem histórico: 0 dias fora")
		return
	_profile.data["history"] = [{"day": DAY0, "place": 2, "percent": 0.3, "delta": 0}]
	for row: Array in [[DAY0, 0], [DAY0 + 2, 2], [DAY0 + 3, 3], [DAY0 + 10, 10], [DAY0 - 1, 0]]:
		if _profile.days_away(row[0]) != row[1]:
			_fail("days_away(%d) = %d (esperado %d)" % [row[0], _profile.days_away(row[0]), row[1]])
			return

	# 2. Partida comum (perfil novo, sem histórico): sem bônus; é a referência
	_profile.data = _profile.defaults()
	_profile.save()
	var base := _play(DAY0)
	if int(base["comeback_xp"]) != 0:
		_fail("perfil novo não ganha bônus de retorno (veio %s)" % base["comeback_xp"])
		return
	if _panel_text(base).contains("Bem-vindo de volta"):
		_fail("sem bônus, o painel não fala dele")
		return

	# 3. Voltou em 2 dias: sem bônus. Em `days` dias: +60 XP, só XP
	var last := _play(DAY0 + days - 1)
	if int(last["comeback_xp"]) != 0 or int(last["xp"]) != int(base["xp"]):
		_fail("fora há %d dias ainda não conta (bônus %s)" % [days - 1, last["comeback_xp"]])
		return
	var coins0 := int(last["coins"])
	var gems0 := int(last["gems"])   # (a conquista nova da 1ª partida já foi paga; esta é a referência sem bônus)
	last = _play(DAY0 + days - 1 + days)
	if int(last["comeback_xp"]) != bonus or int(last["xp"]) != int(base["xp"]) + bonus:
		_fail("fora há %d dias: +%d XP (bônus %s, XP %s, referência %s)" % [days, bonus, last["comeback_xp"], last["xp"], base["xp"]])
		return
	if int(last["coins"]) != coins0 or int(last["gems"]) != gems0:
		_fail("só XP: moedas %s (esperado %d) e gemas %s (esperado %d) não mudam" % [last["coins"], coins0, last["gems"], gems0])
		return
	if not _panel_text(last).contains("Bem-vindo de volta! +%d XP" % bonus):
		_fail("o painel mostra o bônus de retorno")
		return

	# 4. Uma vez só: a partida seguinte no mesmo dia não paga de novo
	last = _play(DAY0 + days - 1 + days)
	if int(last["comeback_xp"]) != 0 or int(last["xp"]) != int(base["xp"]):
		_fail("a segunda partida do dia não leva o bônus (veio %s)" % last["comeback_xp"])
		return

	# 5. Sobrevive a salvar/recarregar: o histórico guarda o dia e uma nova ausência paga de novo
	_profile.load_data()
	last = _play(DAY0 + days - 1 + days + 5)
	if int(last["comeback_xp"]) != bonus:
		_fail("depois de recarregar, nova ausência de 5 dias paga de novo (veio %s)" % last["comeback_xp"])
		return

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
