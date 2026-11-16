extends SceneTree
## Teste de fumaça do Passo 135 (DD-174): PRIMEIRA VITÓRIA DO DIA. (1) a 1ª vitória do dia rende +40 moedas e grava o dia;
## (2) a 2ª vitória no mesmo dia não rende; (3) derrota não gasta o bônus (a vitória seguinte ainda ganha); (4) no dia seguinte
## o bônus volta; (5) a tela de missões avisa do bônus (e vira ✓ depois). Perfil só dele; só moedas (sem poder).
## Uso: godot_console --headless --path . -s res://tools/smoke_first_win.gd

const TEST_PROFILE := "user://profile_smoke_first_win.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")

var _profile
var _stats := FakeStats.new()


## Placar de mentira: o jogador (1) fica em `place`, com 30% do planeta e sem feitos.
class FakeStats extends RefCounted:
	var place := 1
	func ranking() -> Array: return [1] if place == 1 else [2, 1]
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


## Entrega uma partida (place 1 = vitória) e devolve as moedas que o perfil ganhou; `last` fica em `_last`.
var _last := {}
func _play(place: int) -> int:
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	_stats.place = place
	root.get_node("Services").stats = _stats
	var before := int(_profile.data["coins"])
	rewards._grant()
	_last = rewards.last
	rewards.free()
	return int(_profile.data["coins"]) - before


func _run() -> void:
	await process_frame
	_profile = load("res://scripts/core/profile.gd")
	_profile.path = TEST_PROFILE
	_profile.data = _profile.defaults()
	_profile.save()
	var cfg = load("res://scripts/core/match_rewards.gd")
	var bonus: int = cfg.FIRST_WIN_COINS
	var base: int = cfg.COINS_PARTICIPATION + roundi(30.0 * cfg.COINS_PER_PERCENT)
	DailyMissions.day_override = 2000

	# Tela de missões, antes de jogar: avisa do bônus
	var screen = load("res://scripts/ui/missions_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var note: Label = screen.find_child("FirstWin", true, false)
	if note == null or not note.text.contains("+%d moedas" % bonus):
		_fail("a tela de missões avisa do bônus da 1ª vitória (%s)" % (note.text if note else "sem aviso"))
		return
	screen.free()

	# 3. Derrota antes de vencer: não rende nem gasta o bônus
	if _play(2) != base or not DailyMissions.first_win_ready() or int(_last["first_win_coins"]) != 0:
		_fail("derrota não rende nem gasta o bônus")
		return
	# 1. Primeira vitória: moedas + bônus, dia gravado
	var win_one := _play(1)
	if win_one != base + cfg.COINS_WIN + bonus or int(_last["first_win_coins"]) != bonus or DailyMissions.first_win_ready():
		_fail("1ª vitória do dia = base + vitória + %d (veio %d)" % [bonus, win_one])
		return
	if int(_profile.data["first_win_day"]) != 2000:
		_fail("grava o dia do bônus")
		return
	# 2. Segunda vitória no mesmo dia: sem bônus
	if _play(1) != base + cfg.COINS_WIN or int(_last["first_win_coins"]) != 0:
		_fail("2ª vitória no mesmo dia não rende o bônus")
		return
	# O dia gravado sobrevive a salvar e recarregar
	_profile.load_data()
	if DailyMissions.first_win_ready():
		_fail("o bônus gasto continua gasto depois de recarregar o perfil")
		return
	# 5. Tela de missões depois do bônus: ✓
	screen = load("res://scripts/ui/missions_screen.gd").new()
	root.add_child(screen)
	await process_frame
	note = screen.find_child("FirstWin", true, false)
	if note == null or not note.text.contains("✓"):
		_fail("a tela de missões marca o bônus como feito (%s)" % (note.text if note else "sem aviso"))
		return
	screen.free()
	# 4. Dia seguinte: o bônus volta
	DailyMissions.day_override = 2001
	if not DailyMissions.first_win_ready() or _play(1) != base + cfg.COINS_WIN + bonus:
		_fail("no dia seguinte a 1ª vitória rende o bônus de novo")
		return

	root.get_node("Services").stats = null
	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
