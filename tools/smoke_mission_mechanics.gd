extends SceneTree
## Teste de fumaça do Passo 150 (DD-189): as mecânicas novas (sprint, habilidade, captura) também viram missão do dia.
## (1) cada faixa tem a missão nova e a chave dela é a mesma do snapshot da partida; (2) existe dia em que cada uma sai;
## (3) naquele dia a missão avança só com o que a partida registrou (soma de partidas) e fica pronta na meta.
## Uso: godot_console --headless --path . -s res://tools/smoke_mission_mechanics.gd

const TEST_PROFILE := "user://profile_smoke_mission_mechanics.json"
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const NEW := {"sprints": 6, "abilities": 2, "captures": 1}   # id da missão -> meta


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# 1. Uma por faixa (fácil, média, difícil), com a chave do snapshot igual ao id e a meta combinada
	var found := {}
	for tier: Array in DailyMissions.TIERS:
		for m: Array in tier:
			if NEW.has(m[0]):
				found[m[0]] = m
	if not _check(found.size() == 3, "as 3 missões novas existem: %s" % [found.keys()]): return
	for id: String in NEW:
		if not _check(found[id][2] == id and int(found[id][3]) == int(NEW[id]) and found[id][5], "%s: chave, meta e soma entre partidas" % id): return
	if not _check(DailyMissions.TIERS[0].has(found["sprints"]) and DailyMissions.TIERS[1].has(found["abilities"]) and DailyMissions.TIERS[2].has(found["captures"]), "faixas: sprint fácil, habilidade média, captura difícil"): return

	# 2/3. Num dia em que sai, a missão avança com o snapshot e fecha na meta
	for id: String in NEW:
		var day := -1
		for d in range(1000, 1200):
			DailyMissions.day_override = d
			if DailyMissions.todays().any(func(m: Array) -> bool: return m[0] == id):
				day = d
				break
		if not _check(day >= 0, "%s sai em algum dia (200 dias)" % id): return
		DailyMissions.day_override = day
		var mission: Array = found[id]
		var half := int(NEW[id]) / 2
		DailyMissions.record({id: half})
		if not _check(DailyMissions.progress_of(mission) == half and (half == 0 or not DailyMissions.is_done(mission)), "%s: progresso parcial (%d)" % [id, DailyMissions.progress_of(mission)]): return
		DailyMissions.record({id: int(NEW[id]) - half})
		if not _check(DailyMissions.progress_of(mission) == int(NEW[id]) and DailyMissions.is_done(mission), "%s: pronta na meta" % id): return

	DailyMissions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK: sprint, habilidade e captura viram missão do dia e avançam entre partidas")
	quit(0)
