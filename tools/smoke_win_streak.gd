extends SceneTree
## Teste de fumaça do Passo 142 (DD-181): SEQUÊNCIA DE VITÓRIAS. (1) a 1ª vitória não tem bônus; da 2ª seguida em diante vêm
## +5 moedas por vitória já encadeada (5, 10, 15, 20, 25), com teto em +25; (2) qualquer não-vitória zera a sequência;
## (3) é só moeda (XP e gemas iguais às de uma vitória comum); (4) o painel mostra a linha só quando há bônus; (5) grava no perfil.
## Perfil só dele. Uso: godot_console --headless --path . -s res://tools/smoke_win_streak.gd

const TEST_PROFILE := "user://profile_smoke_win_streak.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const DAY0 := 5000

var _profile
var _stats := FakeStats.new()


## Placar de mentira: o jogador (1) fica em `place`, com 30% do planeta e sem feitos.
class FakeStats extends RefCounted:
	var place := 1
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


## Joga uma partida em `place` (mesmo dia, sem ausência) e devolve o `last`.
func _play(place: int) -> Dictionary:
	_stats.place = place
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
	DailyMissions.day_override = DAY0
	_profile = load("res://scripts/core/profile.gd")
	_profile.path = TEST_PROFILE
	_profile.data = _profile.defaults()
	_profile.save()
	var step := int(load("res://scripts/core/match_rewards.gd").STREAK_COINS)
	var top := int(load("res://scripts/core/match_rewards.gd").STREAK_MAX)

	# 1. Sequência de vitórias: 1ª sem bônus; depois 5, 10, 15, 20, 25 e fica em 25
	var base_xp := -1
	for n in range(1, 9):
		var last := _play(1)
		var want := step * mini(n - 1, top) if n >= 2 else 0
		if int(last["streak"]) != n or int(last["streak_coins"]) != want:
			_fail("%dª vitória seguida: bônus %s (esperado %d), sequência %s" % [n, last["streak_coins"], want, last["streak"]])
			return
		# só moeda: moedas = base da vitória (10 + 30% + 25) + 1ª vitória do dia + bônus; XP e gemas não mudam
		if int(last["coins"]) != 10 + 30 + 25 + int(last["first_win_coins"]) + want:
			_fail("%dª vitória: moedas %s não batem com a base + bônus %d" % [n, last["coins"], want])
			return
		if n == 2:
			base_xp = int(last["xp"])
		elif n > 2 and int(last["xp"]) != base_xp:
			_fail("só moeda: a %dª vitória muda o XP (%s≠%d)" % [n, last["xp"], base_xp])
			return
		if int(last["gems"]) != 5 * last["new_achievements"].size():   # gemas só de conquista nova (a sequência não dá)
			_fail("só moeda: a %dª vitória dá gemas (%s) além das conquistas" % [n, last["gems"]])
			return
		if want > 0 and not _panel_text(last).contains("%d vitórias seguidas: +%d moedas" % [n, want]):
			_fail("o painel mostra a sequência da %dª vitória" % n)
			return
		if want == 0 and _panel_text(last).contains("vitórias seguidas"):
			_fail("sem bônus, o painel não fala de sequência")
			return
	if int(_profile.data["win_streak"]) != 8:
		_fail("o perfil guarda a sequência (%s)" % _profile.data["win_streak"])
		return

	# 2. Salvou? Recarrega e a sequência continua
	_profile.load_data()
	if int(_profile.data["win_streak"]) != 8:
		_fail("recarregar mantém a sequência (%s)" % _profile.data["win_streak"])
		return

	# 3. Qualquer não-vitória zera (2º e 4º lugar), sem bônus
	for place: int in [2, 4]:
		_play(1)
		var lost := _play(place)
		if int(lost["streak"]) != 0 or int(lost["streak_coins"]) != 0 or int(_profile.data["win_streak"]) != 0:
			_fail("%dº lugar zera a sequência (veio %s)" % [place, lost["streak"]])
			return
		if _panel_text(lost).contains("vitórias seguidas"):
			_fail("derrota: o painel não fala de sequência")
			return

	# 4. Depois de perder, a próxima vitória recomeça em 1, sem bônus
	var again := _play(1)
	if int(again["streak"]) != 1 or int(again["streak_coins"]) != 0:
		_fail("vitória depois da derrota recomeça em 1 (veio %s, bônus %s)" % [again["streak"], again["streak_coins"]])
		return

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
