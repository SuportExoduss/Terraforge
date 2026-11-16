extends SceneTree
## Teste de fumaça do Passo 137 (DD-176): HISTÓRICO DAS ÚLTIMAS PARTIDAS. (1) conta nova: histórico vazio e a tela avisa;
## (2) cada partida entra na frente com colocação, % do planeta, variação de habilidade e dia; (3) só as últimas 8 ficam
## (a mais antiga sai); (4) sobrevive a salvar e reabrir o perfil; (5) o texto da linha (Hoje/Ontem/Há N dias, 1º lugar,
## Sem pontuar, +/−); (6) a tela mostra uma linha por partida, vitória em destaque. Perfil só dele; só leitura (sem poder).
## Uso: godot_console --headless --path . -s res://tools/smoke_history.gd

const TEST_PROFILE := "user://profile_smoke_history.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")

var _profile
var _stats := FakeStats.new()


## Placar de mentira: o jogador (1) fica em `place` (0 = nunca pontuou), com 30% do planeta e sem feitos.
class FakeStats extends RefCounted:
	var place := 1
	func ranking() -> Array:
		var list := []
		for i in range(1, place):
			list.append(100 + i)
		if place > 0:
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


func _play(place: int) -> void:
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	_stats.place = place
	root.get_node("Services").stats = _stats
	rewards._grant()
	rewards.free()


func _run() -> void:
	await process_frame
	_profile = load("res://scripts/core/profile.gd")
	_profile.path = TEST_PROFILE
	_profile.data = _profile.defaults()
	_profile.save()
	var screen_script = load("res://scripts/ui/profile_screen.gd")
	DailyMissions.day_override = 2000

	# 1. Conta nova: vazio, e a tela diz o que fazer
	if not _profile.data["history"].is_empty():
		_fail("conta nova começa sem histórico")
		return
	var screen = screen_script.new()
	root.add_child(screen)
	await process_frame
	if screen.find_child("HistoryEmpty", true, false) == null or screen.find_child("H_0", true, false) != null:
		_fail("sem partidas a tela avisa e não tem linhas")
		return
	screen.free()

	# 2. Três partidas: 2º (+10), 1º (+25), 4º (−15); a mais nova na frente
	_play(2)
	_play(1)
	_play(4)
	var history: Array = _profile.data["history"]
	if history.size() != 3:
		_fail("3 partidas = 3 linhas (veio %d)" % history.size())
		return
	var want := [[4, -15], [1, 25], [2, 10]]
	for i in 3:
		var h: Dictionary = history[i]
		if int(h["place"]) != want[i][0] or int(h["delta"]) != want[i][1] or not is_equal_approx(float(h["percent"]), 0.3) or int(h["day"]) != 2000:
			_fail("linha %d errada: %s (esperado lugar %d, variação %d)" % [i, h, want[i][0], want[i][1]])
			return

	# 3. Só as últimas 8: joga mais 7 (total 10); sai a mais antiga e a de cima é a última jogada
	for i in 7:
		_play(3)
	_play(0)   # nunca pontuou: variação −15 (a 11ª partida)
	history = _profile.data["history"]
	if history.size() != _profile.HISTORY_MAX or int(history[0]["place"]) != 0 or int(history[0]["delta"]) != -15:
		_fail("o histórico guarda só %d e a mais nova fica em cima (tem %d)" % [_profile.HISTORY_MAX, history.size()])
		return
	if int(history[7]["place"]) != 3:
		_fail("as partidas antigas (2º, 1º, 4º) saíram do histórico")
		return

	# 4. Reabrir o perfil: continua lá (o JSON devolve números como float; o texto usa int)
	_profile.load_data()
	if _profile.data["history"].size() != 8 or int(_profile.data["history"][0]["place"]) != 0 or int(_profile.data["history"][0]["day"]) != 2000:
		_fail("o histórico sobrevive a salvar e reabrir")
		return

	# 5. Texto da linha
	var line: String = screen_script.history_line({"day": 2000, "place": 1, "percent": 0.34, "delta": 25})
	if line != "Hoje  ·  1º lugar  ·  34% do planeta  ·  +25":
		_fail("linha de vitória: '%s'" % line)
		return
	line = screen_script.history_line({"day": 1999.0, "place": 4, "percent": 0.1, "delta": -15})
	if not line.begins_with("Ontem") or not line.contains("4º lugar") or not line.ends_with("−15"):
		_fail("linha de derrota (Ontem, −15): '%s'" % line)
		return
	line = screen_script.history_line({"day": 1997, "place": 0, "percent": 0.0, "delta": 0})
	if not line.begins_with("Há 3 dias") or not line.contains("Sem pontuar") or not line.ends_with("+0"):
		_fail("linha sem pontuar (Há 3 dias): '%s'" % line)
		return

	# 6. A tela: uma linha por partida (8), a mais nova em cima, vitória em destaque, e só lê o perfil
	_profile.data["history"][3]["place"] = 1   # (uma vitória no meio, para ver o destaque)
	var xp_before := int(_profile.data["xp"])
	screen = screen_script.new()
	root.add_child(screen)
	await process_frame
	var rows := 0
	for i in 12:
		if screen.find_child("H_%d" % i, true, false) != null:
			rows += 1
	var top: Label = screen.find_child("H_0", true, false)
	var win: Label = screen.find_child("H_3", true, false)
	var loss: Label = screen.find_child("H_1", true, false)
	if rows != 8 or top == null or not top.text.contains("Sem pontuar") or screen.find_child("HistoryEmpty", true, false) != null:
		_fail("a tela mostra 8 linhas, a mais nova em cima (linhas: %d)" % rows)
		return
	if win == null or loss == null or win.modulate == loss.modulate or win.modulate.b > 0.5:
		_fail("a vitória aparece em destaque e a derrota não")
		return
	if int(_profile.data["xp"]) != xp_before:
		_fail("a tela só lê o perfil")
		return
	screen.free()

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_history")
	quit(0)
