extends SceneTree
## Teste de fumaça do Passo 136 (DD-175): META DA SEMANA. (1) só vitórias contam (derrota/empate não), de segunda a domingo;
## (2) com 5 vitórias a meta fica pronta e RESGATAR dá 3 gemas, uma vez só; (3) o aviso do menu (claimable) conta a meta pronta;
## (4) sobrevive a salvar/recarregar e vale até domingo; na segunda zera; (5) a tela mostra o cartão e o botão resgata.
## Perfil só dele; só gemas (sem poder). Uso: godot_console --headless --path . -s res://tools/smoke_weekly_goal.gd

const TEST_PROFILE := "user://profile_smoke_weekly_goal.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const MONDAY := 2097   # 7*300-3: segunda-feira (o dia 0, 1970-01-01, foi quinta)


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
	profile.save()
	var goal := int(DailyMissions.WEEKLY[3])
	var gems := int(DailyMissions.WEEKLY[4])
	DailyMissions.day_override = MONDAY

	# 1. Só vitória conta; a meta só fica pronta na 5ª
	DailyMissions.record({"won": 0})
	if DailyMissions.weekly_wins() != 0:
		_fail("derrota não conta para a meta da semana")
		return
	for n in goal - 1:
		DailyMissions.record({"won": 1})
	if DailyMissions.weekly_wins() != goal - 1 or DailyMissions.weekly_done() or DailyMissions.weekly_claim():
		_fail("com %d vitórias a meta ainda não está pronta nem resgata (%d)" % [goal - 1, DailyMissions.weekly_wins()])
		return
	DailyMissions.day_override = MONDAY + 3   # (quinta: a vitória da semana conta em qualquer dia)
	DailyMissions.record({"won": 1})
	if not DailyMissions.weekly_done() or DailyMissions.weekly_wins() != goal:
		_fail("a 5ª vitória deixa a meta pronta")
		return
	# 3. O aviso do menu conta a meta pronta (e apaga ao resgatar, abaixo)
	if DailyMissions.claimable() < 1:
		_fail("o aviso do menu conta a meta da semana")
		return
	var before_claimable := DailyMissions.claimable()
	# 2. Resgate: gemas, uma vez só
	profile.data["gems"] = 0
	if not DailyMissions.weekly_claim() or int(profile.data["gems"]) != gems:
		_fail("resgatar a meta dá %d gemas (tem %s)" % [gems, profile.data["gems"]])
		return
	if DailyMissions.weekly_claim() or int(profile.data["gems"]) != gems or DailyMissions.claimable() != before_claimable - 1:
		_fail("a meta não resgata duas vezes e o aviso apaga")
		return
	DailyMissions.record({"won": 1})
	if DailyMissions.weekly_wins() != goal or DailyMissions.weekly_claim():
		_fail("vitórias a mais na mesma semana não resgatam de novo")
		return
	# 4. Salvou? Domingo ainda é a mesma semana; segunda zera
	profile.load_data()
	DailyMissions.day_override = MONDAY + 6
	if not DailyMissions.weekly_claimed() or int(profile.data["gems"]) != gems:
		_fail("resgate e gemas sobrevivem a recarregar e valem até domingo")
		return
	DailyMissions.day_override = MONDAY + 7
	if DailyMissions.weekly_wins() != 0 or DailyMissions.weekly_claimed() or DailyMissions.weekly_done():
		_fail("na segunda a meta da semana zera")
		return

	# 5. Tela: o cartão da semana aparece, e o botão resgata
	for n in goal:
		DailyMissions.record({"won": 1})
	profile.data["gems"] = 0
	var screen = load("res://scripts/ui/missions_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var card: Node = screen.find_child("M_" + String(DailyMissions.WEEKLY[0]), true, false)
	var button: Button = card.find_child("Claim", true, false) if card else null
	if card == null or button == null or button.disabled or not button.text.begins_with("RESGATAR") or not button.text.contains("gemas"):
		_fail("a tela mostra a meta da semana pronta com o botão RESGATAR (%s)" % (button.text if button else "sem cartão"))
		return
	if button.custom_minimum_size.y < 48.0:
		_fail("botão com altura de dedo")
		return
	button.pressed.emit()
	await process_frame
	await process_frame
	if int(profile.data["gems"]) != gems or not DailyMissions.weekly_claimed():
		_fail("clicar resgata a meta da semana (gemas %s)" % profile.data["gems"])
		return

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
