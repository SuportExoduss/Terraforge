extends SceneTree
## Teste de fumaça do Passo 140 (DD-179): PRESENTE DO DIA. (1) pegar rende as moedas do dia 1 e só uma vez por dia; (2) dias seguidos
## sobem o calendário (10,15,...,60) e o 7º dá também gemas, depois recomeça; (3) faltar um dia volta ao dia 1; (4) o aviso do menu
## (badge) conta o presente e some ao pegar; (5) sobrevive a salvar/recarregar; (6) a tela mostra os 7 dias e o botão PEGAR funciona.
## Perfil só dele; só moedas/gemas (sem poder). Uso: godot_console --headless --path . -s res://tools/smoke_daily_gift.gd

const TEST_PROFILE := "user://profile_smoke_daily_gift.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const DAY0 := 3000


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	profile.data = profile.defaults()
	profile.data["coins"] = 0
	profile.data["gems"] = 0
	profile.save()
	var table: Array = DailyMissions.GIFT_COINS
	# 1. Dia 1: pega uma vez só
	DailyMissions.day_override = DAY0
	if not DailyMissions.gift_ready() or DailyMissions.gift_slot() != 0:
		_fail("perfil novo: presente pronto, dia 1")
		return
	var base_badge := DailyMissions.badge()
	if base_badge != DailyMissions.claimable() + 1:
		_fail("o aviso do menu conta o presente (%d)" % base_badge)
		return
	if not DailyMissions.gift_claim() or int(profile.data["coins"]) != int(table[0]):
		_fail("dia 1 dá %d moedas (veio %s)" % [table[0], profile.data["coins"]])
		return
	if DailyMissions.gift_claim() or int(profile.data["coins"]) != int(table[0]) or DailyMissions.gift_ready():
		_fail("o presente só vale uma vez por dia")
		return
	if DailyMissions.badge() != base_badge - 1:
		_fail("pegou: o aviso do menu perde 1")
		return
	# 2. Dias seguidos: 2..7 sobem a tabela; o 7º traz gemas
	var total: int = int(table[0])
	for i in range(1, table.size()):
		DailyMissions.day_override = DAY0 + i
		if DailyMissions.gift_slot() != i:
			_fail("dia %d do calendário (slot %d)" % [i + 1, DailyMissions.gift_slot()])
			return
		var gems_before := int(profile.data["gems"])
		DailyMissions.gift_claim()
		total += int(table[i])
		var want_gems := DailyMissions.GIFT_GEMS if i == table.size() - 1 else 0
		if int(profile.data["coins"]) != total or int(profile.data["gems"]) - gems_before != want_gems:
			_fail("dia %d: moedas %s (esperado %d), gemas +%d (esperado +%d)" % [i + 1, profile.data["coins"], total,
					int(profile.data["gems"]) - gems_before, want_gems])
			return
	# depois do 7º, o calendário recomeça no dia 1 (sem faltar nenhum dia)
	DailyMissions.day_override = DAY0 + table.size()
	if DailyMissions.gift_slot() != 0 or not DailyMissions.gift_ready():
		_fail("depois do dia 7 recomeça no dia 1 (slot %d)" % DailyMissions.gift_slot())
		return
	DailyMissions.gift_claim()
	# 3. Faltar um dia: volta ao dia 1
	DailyMissions.day_override = DAY0 + table.size() + 2
	if DailyMissions.gift_run() != 0 or DailyMissions.gift_slot() != 0:
		_fail("faltou um dia: volta ao dia 1 (slot %d)" % DailyMissions.gift_slot())
		return
	# 5. Salvou? Recarrega e continua igual
	profile.data["coins"] = 0
	DailyMissions.gift_claim()
	profile.load_data()
	if DailyMissions.gift_ready() or int(profile.data["coins"]) != int(table[0]) or DailyMissions.gift_run() != 1:
		_fail("pegar grava o perfil (moedas %s, sequência %d)" % [profile.data["coins"], DailyMissions.gift_run()])
		return
	# 6. Tela
	DailyMissions.day_override = DAY0 + table.size() + 3
	profile.data["coins"] = 0
	var screen = load("res://scripts/ui/missions_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var button: Button = screen.find_child("GiftClaim", true, false)
	if button == null or button.disabled or not button.text.begins_with("PEGAR") or not button.text.contains("%d moedas" % int(table[1])):
		_fail("a tela mostra o botão PEGAR do dia 2 (%s)" % (button.text if button else "sem botão"))
		return
	if button.custom_minimum_size.y < 48.0 or screen.find_child("GiftDays", true, false).get_child_count() != table.size():
		_fail("botão com altura de dedo e 7 dias no calendário")
		return
	button.pressed.emit()
	await process_frame
	await process_frame
	button = screen.find_child("GiftClaim", true, false)
	if int(profile.data["coins"]) != int(table[1]) or button == null or not button.disabled or not button.text.begins_with("PEGO"):
		_fail("clicar pega o presente e o botão vira PEGO (moedas %s)" % profile.data["coins"])
		return

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
