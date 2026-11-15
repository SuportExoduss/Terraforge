extends SceneTree
## Teste de fumaça do Passo 115 (missões diárias e sequência, DD-155): 3 missões por dia (uma por faixa), iguais no mesmo dia
## e variando entre dias; a partida soma o progresso (soma ou melhor partida); só resgata pronta e uma vez; moedas e gemas
## entram no perfil; a sequência continua no dia seguinte, recomeça se faltar um dia e dá 5 gemas no 7º; a tela mostra tudo
## e o botão RESGATAR funciona; dia novo = progresso zerado. Só moeda/gema (sem poder na partida).
## Uso: godot_console --headless --path . -s res://tools/smoke_missions.gd

const TEST_PROFILE := "user://profile_smoke_missions.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const MissionsScreen := preload("res://scripts/ui/missions_screen.gd")


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


## Deixa a missão `m` pronta hoje (como se tivesse jogado).
func _finish(m: Array) -> void:
	DailyMissions.state()["progress"][m[0]] = int(m[3])


## Termina e resgata a 1ª missão do dia (para andar com a sequência).
func _claim_first() -> void:
	var m: Array = DailyMissions.todays()[0]
	_finish(m)
	DailyMissions.claim(m[0])


func _run() -> void:
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()
	DailyMissions.day_override = 1000

	# 3 missões por dia, uma por faixa, iguais no mesmo dia, variando entre dias
	var today := DailyMissions.todays()
	if not _check(today.size() == 3, "3 missões por dia"): return
	for n in 3:
		if not _check(DailyMissions.TIERS[n].has(today[n]), "a missão %d vem da faixa %d" % [n, n]): return
	if not _check(DailyMissions.todays() == today, "mesmo dia = mesmas missões"): return
	var seen := {}
	for d in range(1000, 1040):
		DailyMissions.day_override = d
		var ids := []
		for m: Array in DailyMissions.todays():
			ids.append(m[0])
		seen[ids] = true
	DailyMissions.day_override = 1000
	if not _check(seen.size() >= 4, "os dias variam (%d combinações em 40 dias)" % seen.size()): return

	# Progresso: a partida soma (ou guarda a melhor); percent vira pontos inteiros
	var a: Array = today[0]
	var b: Array = today[1]
	var c: Array = today[2]
	if not _check(DailyMissions.claimable() == 0 and DailyMissions.progress_of(a) == 0, "começa zerado"): return
	DailyMissions.record({"loops": 4, "cuts": 1, "kills": 0, "percent": 0.25, "alive": 1, "won": 0, "matches": 1})
	DailyMissions.record({"loops": 3, "cuts": 2, "kills": 1, "percent": 0.15, "alive": 1, "won": 1, "matches": 2})
	var want := {"play": 2, "loops": 7, "cuts": 3, "alive": 2, "percent": 25, "kills": 1, "win": 1}   # percent = melhor partida (25), o resto soma
	for m: Array in today:
		if not _check(DailyMissions.progress_of(m) == int(want[m[0]]), "%s soma %d (deu %d)" % [m[0], int(want[m[0]]), DailyMissions.progress_of(m)]): return

	# Resgate: só pronta, só uma vez; paga moedas; 1º resgate do dia abre a sequência
	profile.data["coins"] = 0
	profile.data["gems"] = 0
	DailyMissions.state()["progress"][b[0]] = 0
	if not _check(not DailyMissions.claim(b[0]), "não resgata missão sem terminar"): return
	if not _check(not DailyMissions.claim("naoexiste"), "id inexistente recusado"): return
	if not _check(DailyMissions.claimable() == 2, "2 prontas (a e c)"): return
	if not _check(DailyMissions.claim(a[0]) and int(profile.data["coins"]) == int(a[4]), "resgata a 1ª e recebe as moedas"): return
	if not _check(not DailyMissions.claim(a[0]) and int(profile.data["coins"]) == int(a[4]), "não resgata duas vezes"): return
	if not _check(DailyMissions.streak_days() == 1 and int(profile.data["gems"]) == 0, "sequência 1, sem gema ainda"): return
	if not _check(DailyMissions.claim(c[0]) and DailyMissions.streak_days() == 1, "2º resgate do dia não soma sequência"): return
	_finish(b)
	if not _check(DailyMissions.claim(b[0]) and int(profile.data["gems"]) == DailyMissions.ALL_BONUS_GEMS, "as 3 resgatadas dão a gema"): return
	if not _check(int(profile.data["coins"]) == int(a[4]) + int(b[4]) + int(c[4]), "moedas das 3"): return

	# Persiste no arquivo
	profile.load_data()
	if not _check(DailyMissions.is_claimed(a) and DailyMissions.streak_days() == 1 and DailyMissions.claimable() == 0, "resgates e sequência sobrevivem a recarregar"): return

	# Sequência: ontem resgatou -> 2; faltou um dia -> recomeça em 1
	DailyMissions.day_override = 1001
	if not _check(DailyMissions.streak_days() == 1 and not DailyMissions.is_claimed(DailyMissions.todays()[0]), "dia novo: progresso zerado, sequência ainda viva"): return
	_claim_first()
	if not _check(DailyMissions.streak_days() == 2, "dia seguinte = sequência 2"): return
	DailyMissions.day_override = 1003
	if not _check(DailyMissions.streak_days() == 0, "faltou um dia = sequência zerada na tela"): return
	_claim_first()
	if not _check(DailyMissions.streak_days() == 1, "recomeça em 1"): return

	# 7º dia seguido: +5 gemas (só uma vez, no 1º resgate do dia)
	profile.data["gems"] = 0
	for d in range(1004, 1009):   # sequência 2..6
		DailyMissions.day_override = d
		_claim_first()
	if not _check(DailyMissions.streak_days() == 6 and int(profile.data["gems"]) == 0, "6 dias seguidos, sem prêmio ainda"): return
	if not _check(DailyMissions.days_to_streak_prize() == 1, "falta 1 dia"): return
	DailyMissions.day_override = 1009
	_claim_first()
	if not _check(DailyMissions.streak_days() == 7 and int(profile.data["gems"]) == DailyMissions.STREAK_GEMS, "7º dia: +%d gemas" % DailyMissions.STREAK_GEMS): return
	var second: Array = DailyMissions.todays()[1]
	_finish(second)
	DailyMissions.claim(second[0])
	if not _check(int(profile.data["gems"]) == DailyMissions.STREAK_GEMS, "o prêmio de sequência não repete no mesmo dia"): return

	# Tela: mostra 3 cartões, sequência e o botão RESGATAR funciona
	DailyMissions.day_override = 2000
	profile.data["streak"] = {"count": 3, "last_day": 1999}
	profile.data["coins"] = 0
	var screen := MissionsScreen.new()
	root.add_child(screen)
	await process_frame
	for m: Array in DailyMissions.todays():
		if not _check(screen.find_child("M_" + String(m[0]), true, false) != null, "cartão de " + String(m[0])): return
	if not _check(screen.find_child("Streak", true, false).text == "Sequência: 3 dias", "mostra a sequência"): return
	var first: Array = DailyMissions.todays()[0]
	var button: Button = screen.find_child("M_" + String(first[0]), true, false).find_child("Claim", true, false)
	if not _check(button.disabled, "sem terminar, o botão fica desligado"): return
	_finish(first)
	screen.queue_free()
	await process_frame
	screen = MissionsScreen.new()
	root.add_child(screen)
	await process_frame
	button = screen.find_child("M_" + String(first[0]), true, false).find_child("Claim", true, false)
	if not _check(not button.disabled and button.text.begins_with("RESGATAR"), "pronta: botão ligado (%s)" % button.text): return
	button.pressed.emit()
	await process_frame
	await process_frame
	if not _check(int(profile.data["coins"]) == int(first[4]) and DailyMissions.streak_days() == 4, "clicar resgata e a sequência sobe"): return
	button = screen.find_child("M_" + String(first[0]), true, false).find_child("Claim", true, false)
	if not _check(button.disabled and button.text.begins_with("RESGATADA"), "depois de resgatar: RESGATADA"): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_missions")
	quit(0)
